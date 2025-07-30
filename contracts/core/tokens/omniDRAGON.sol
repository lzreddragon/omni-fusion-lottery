// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OFT} from "@layerzerolabs/oft-evm/contracts/oft/OFT.sol";
import {MessagingFee, SendParam, MessagingReceipt, OFTReceipt} from "@layerzerolabs/oft-evm/contracts/oft/interfaces/IOFT.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Dragon ecosystem interfaces
import {IOmniDragonRegistry} from "../../interfaces/config/IOmniDragonRegistry.sol";
import {IOmniDRAGON} from "../../interfaces/tokens/IOmniDRAGON.sol";

// Event Categories for gas optimization
enum EventCategory {
  BUY_JACKPOT,
  BUY_REVENUE,
  BUY_BURN,
  SELL_JACKPOT,
  SELL_REVENUE,
  SELL_BURN
}

/**
 * @title omniDRAGON
 * @author 0xakita.eth
 * @notice Cross-chain token with LayerZero V2 OFT capabilities and immediate fee distribution
 * @dev Implements ERC20 with fee-on-transfer mechanics for buy/sell transactions through DEX pairs.
 * Fees are distributed immediately as DRAGON tokens to designated vaults.
 *
 * Key Features:
 * - LayerZero V2 OFT for cross-chain transfers
 * - Immediate fee distribution (no accumulation/swapping)
 * - Lottery integration (triggers only on buys)
 *
 * Security Features:
 * - ReentrancyGuard protection
 * - SafeERC20 for token interactions
 * - Custom errors for gas efficiency
 * - Try-catch for external lottery calls
 *
 * https://x.com/sonicreddragon
 * https://t.me/sonicreddragon
 */
contract omniDRAGON is OFT, ReentrancyGuard, IOmniDRAGON {
  using SafeERC20 for IERC20;

  // Constants
  uint256 public constant MAX_SUPPLY = 6_942_000 * 10 ** 18;
  uint256 public constant INITIAL_SUPPLY = 6_942_000 * 10 ** 18;
  uint256 public constant MAX_SINGLE_TRANSFER = 1_000_000 * 10 ** 18;
  uint256 public constant BASIS_POINTS = 10000;
  uint256 public constant SONIC_CHAIN_ID = 146;
  uint256 public constant MAX_FEE_BPS = 2500;
  address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

  // Registry integration
  IOmniDragonRegistry public immutable REGISTRY;
  address public immutable DELEGATE;

  // Core addresses
  address public jackpotVault;
  address public revenueVault;
  address public lotteryManager;

  // Fee configurations
  Fees public buyFees;
  Fees public sellFees;
  
  // Control flags
  ControlFlags public controlFlags;

  // DEX pairs for fee detection
  mapping(address => bool) public isPair;
  
  // Custom errors for gas efficiency
  error InvalidFeeConfiguration();
  error FeesTooHigh();
  error TradingDisabled();
  error TransferAmountTooHigh();
  error ZeroAddress();
  error InvalidAmount();
  error Unauthorized();
  error EmergencyModeActive();
  error ContractPaused();

  // Modifiers
  modifier whenTradingEnabled() {
    if (!controlFlags.tradingEnabled) revert TradingDisabled();
    _;
  }

  modifier whenNotPaused() {
    if (controlFlags.paused) revert ContractPaused();
    _;
  }

  modifier whenNotEmergency() {
    if (controlFlags.emergencyMode) revert EmergencyModeActive();
    _;
  }

  modifier validAddress(address addr) {
    if (addr == address(0)) revert ZeroAddress();
    _;
  }

  /**
   * @notice Constructor for omniDRAGON token
   * @param _lzEndpoint LayerZero endpoint address
   * @param _registry OmniDragonRegistry address
   * @param _delegate Initial delegate address
   * @param _owner Initial owner address
   */
  constructor(
    address _lzEndpoint,
    address _registry,
    address _delegate,
    address _owner
  ) OFT("omniDRAGON", "DRAGON", _lzEndpoint, _delegate) Ownable(_owner) validAddress(_registry) validAddress(_delegate) {
    REGISTRY = IOmniDragonRegistry(_registry);
    DELEGATE = _delegate;

    // Set initial fee structure (10% total on buys/sells)
    buyFees = Fees({
      jackpot: 690,  // 6.9%
      veDRAGON: 241, // 2.41%
      burn: 69,      // 0.69%
      total: 1000    // 10%
    });

    sellFees = Fees({
      jackpot: 690,  // 6.9%
      veDRAGON: 241, // 2.41%
      burn: 69,      // 0.69%
      total: 1000    // 10%
    });

    // Initialize control flags
    controlFlags = ControlFlags({
      feesEnabled: true,
      tradingEnabled: false, // Will be enabled after initial setup
      initialMintCompleted: false,
      paused: false,
      emergencyMode: false
    });

    // Mint initial supply to owner
    _mint(_owner, INITIAL_SUPPLY);
    controlFlags.initialMintCompleted = true;

    emit FeesUpdated(buyFees);
  }

  /**
   * @notice Override transfer to implement fee-on-transfer mechanics
   */
  function _update(
    address from,
    address to,
    uint256 amount
  ) internal override whenNotPaused whenNotEmergency {
    // Skip fees for mint/burn operations
    if (from == address(0) || to == address(0)) {
      super._update(from, to, amount);
      return;
    }

    // Check transfer limits
    if (amount > MAX_SINGLE_TRANSFER) revert TransferAmountTooHigh();

    // Determine if this is a buy or sell transaction
    bool isBuy = isPair[from];
    bool isSell = isPair[to];
    
    uint256 finalAmount = amount;

    // Apply fees if enabled and this is a DEX trade
    if (controlFlags.feesEnabled && (isBuy || isSell)) {
      if (!controlFlags.tradingEnabled) revert TradingDisabled();
      
      (uint256 jackpotFee, uint256 revenueFee, uint256 burnFee) = calculateFees(amount, isBuy);
      
      // Distribute fees immediately
      if (jackpotFee > 0 && jackpotVault != address(0)) {
        super._update(from, jackpotVault, jackpotFee);
        emit FeeDistributed(jackpotVault, jackpotFee, isBuy ? "BUY_JACKPOT" : "SELL_JACKPOT");
      }
      
      if (revenueFee > 0 && revenueVault != address(0)) {
        super._update(from, revenueVault, revenueFee);
        emit FeeDistributed(revenueVault, revenueFee, isBuy ? "BUY_REVENUE" : "SELL_REVENUE");
      }
      
      if (burnFee > 0) {
        super._update(from, DEAD_ADDRESS, burnFee);
        emit FeeDistributed(DEAD_ADDRESS, burnFee, isBuy ? "BUY_BURN" : "SELL_BURN");
      }
      
      finalAmount = amount - jackpotFee - revenueFee - burnFee;
      
      // Trigger lottery on buys only
      if (isBuy && lotteryManager != address(0)) {
        _triggerLottery(to, amount);
      }
    }

    super._update(from, to, finalAmount);
  }

  /**
   * @notice Calculate fees for a transaction
   * @param amount Transaction amount
   * @param isBuy Whether this is a buy transaction
   * @return jackpotFee Amount for jackpot vault
   * @return revenueFee Amount for revenue vault  
   * @return burnFee Amount to burn
   */
  function calculateFees(uint256 amount, bool isBuy) 
    public view returns (uint256 jackpotFee, uint256 revenueFee, uint256 burnFee) {
    
    Fees memory fees = isBuy ? buyFees : sellFees;
    
    jackpotFee = (amount * fees.jackpot) / BASIS_POINTS;
    revenueFee = (amount * fees.veDRAGON) / BASIS_POINTS;
    burnFee = (amount * fees.burn) / BASIS_POINTS;
  }

  /**
   * @notice Trigger lottery entry (internal function with try-catch)
   * @param trader Address of the trader
   * @param amount Trade amount
   */
  function _triggerLottery(address trader, uint256 amount) internal {
    if (lotteryManager == address(0)) return;
    
    try IOmniDragonLotteryManager(lotteryManager).enterLottery(trader, amount) {
      emit LotteryTriggered(trader, amount, amount / (10 ** 17)); // 1 ticket per 0.1 DRAGON
    } catch {
      // Silently fail lottery entry to prevent blocking trades
    }
  }

  /**
   * @notice Cross-chain transfer using LayerZero OFT
   * @param dstEid Destination endpoint ID
   * @param to Recipient address
   * @param amount Amount to transfer
   * @param extraOptions Additional LayerZero options
   * @return guid LayerZero message GUID
   */
  function crossChainTransfer(
    uint32 dstEid,
    address to,
    uint256 amount,
    bytes calldata extraOptions
  ) external payable nonReentrant whenTradingEnabled returns (bytes32 guid) {
    if (to == address(0)) revert ZeroAddress();
    if (amount == 0) revert InvalidAmount();
    
    SendParam memory sendParam = SendParam({
      dstEid: dstEid,
      to: bytes32(uint256(uint160(to))),
      amountLD: amount,
      minAmountLD: amount,
      extraOptions: extraOptions,
      composeMsg: "",
      oftCmd: ""
    });
    
    MessagingFee memory fee = this.quoteSend(sendParam, false);
    if (msg.value < fee.nativeFee) revert InvalidAmount();
    
    (MessagingReceipt memory receipt, ) = this.send(sendParam, fee, payable(msg.sender));
    guid = receipt.guid;
    
    emit CrossChainTransferInitiated(dstEid, to, amount, fee.nativeFee);
  }

  /**
   * @notice Quote cross-chain transfer fee
   * @param dstEid Destination endpoint ID
   * @param to Recipient address
   * @param amount Amount to transfer
   * @param extraOptions Additional LayerZero options
   * @return fee Required native fee
   */
  function quoteCrossChainTransfer(
    uint32 dstEid,
    address to,
    uint256 amount,
    bytes calldata extraOptions
  ) external view returns (uint256 fee) {
    SendParam memory sendParam = SendParam({
      dstEid: dstEid,
      to: bytes32(uint256(uint160(to))),
      amountLD: amount,
      minAmountLD: amount,
      extraOptions: extraOptions,
      composeMsg: "",
      oftCmd: ""
    });
    
    MessagingFee memory messagingFee = this.quoteSend(sendParam, false);
    return messagingFee.nativeFee;
  }

  // =============================================================
  //                        ADMIN FUNCTIONS
  // =============================================================

  /**
   * @notice Set buy and sell fees
   * @param _buyFees New buy fee structure
   * @param _sellFees New sell fee structure
   */
  function setFees(Fees calldata _buyFees, Fees calldata _sellFees) external onlyOwner {
    if (_buyFees.total > MAX_FEE_BPS || _sellFees.total > MAX_FEE_BPS) {
      revert FeesTooHigh();
    }
    
    if (_buyFees.jackpot + _buyFees.veDRAGON + _buyFees.burn != _buyFees.total ||
        _sellFees.jackpot + _sellFees.veDRAGON + _sellFees.burn != _sellFees.total) {
      revert InvalidFeeConfiguration();
    }
    
    buyFees = _buyFees;
    sellFees = _sellFees;
    
    emit FeesUpdated(_buyFees);
  }

  /**
   * @notice Set vault addresses
   * @param _jackpotVault Address for jackpot vault
   * @param _revenueVault Address for revenue vault
   */
  function setVaults(address _jackpotVault, address _revenueVault) 
    external onlyOwner validAddress(_jackpotVault) validAddress(_revenueVault) {
    
    jackpotVault = _jackpotVault;
    revenueVault = _revenueVault;
    
    emit VaultUpdated(_jackpotVault, "JACKPOT");
    emit VaultUpdated(_revenueVault, "REVENUE");
  }

  /**
   * @notice Set lottery manager contract
   * @param _lotteryManager Address of lottery manager
   */
  function setLotteryManager(address _lotteryManager) external onlyOwner {
    lotteryManager = _lotteryManager;
    emit LotteryManagerUpdated(_lotteryManager);
  }

  /**
   * @notice Add or remove DEX pair
   * @param pair Pair contract address
   * @param listed Whether pair should be listed
   */
  function setPair(address pair, bool listed) external onlyOwner validAddress(pair) {
    isPair[pair] = listed;
    emit PairUpdated(pair, listed);
  }

  /**
   * @notice Enable/disable trading
   * @param enabled Whether trading should be enabled
   */
  function setTradingEnabled(bool enabled) external onlyOwner {
    controlFlags.tradingEnabled = enabled;
    emit TradingEnabled(enabled);
  }

  /**
   * @notice Enable/disable fees
   * @param enabled Whether fees should be enabled
   */
  function setFeesEnabled(bool enabled) external onlyOwner {
    controlFlags.feesEnabled = enabled;
    emit FeesEnabled(enabled);
  }

  /**
   * @notice Toggle emergency mode
   */
  function toggleEmergencyMode() external onlyOwner {
    controlFlags.emergencyMode = !controlFlags.emergencyMode;
    emit EmergencyModeToggled(controlFlags.emergencyMode);
  }

  /**
   * @notice Emergency withdraw function
   * @param token Token address (use address(0) for ETH)
   * @param amount Amount to withdraw
   */
  function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
    if (!controlFlags.emergencyMode) revert Unauthorized();
    
    if (token == address(0)) {
      payable(owner()).transfer(amount);
    } else {
      IERC20(token).safeTransfer(owner(), amount);
    }
  }

  // =============================================================
  //                        VIEW FUNCTIONS
  // =============================================================

  function getBuyFees() external view returns (Fees memory) {
    return buyFees;
  }

  function getSellFees() external view returns (Fees memory) {
    return sellFees;
  }

  function getControlFlags() external view returns (ControlFlags memory) {
    return controlFlags;
  }

  function registry() external view returns (address) {
    return address(REGISTRY);
  }

  /**
   * @notice Get current chain configuration from registry
   * @return config Chain configuration
   */
  function getChainConfig() external view returns (IOmniDragonRegistry.ChainConfig memory config) {
    return REGISTRY.getChainConfig(uint16(block.chainid));
  }

  /**
   * @notice Check if contract supports interface
   * @param interfaceId Interface ID to check
   * @return Whether interface is supported
   */
  function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
    return interfaceId == type(IOmniDRAGON).interfaceId || 
           interfaceId == type(IERC20).interfaceId ||
           interfaceId == type(IERC165).interfaceId;
  }

  /**
   * @notice Receive function for native token transfers
   */
  receive() external payable {}
}

/**
 * @dev Temporary interface for lottery manager (to be replaced with actual implementation)
 */
interface IOmniDragonLotteryManager {
  function enterLottery(address trader, uint256 amount) external;
}