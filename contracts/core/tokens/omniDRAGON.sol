// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OFT} from "@layerzerolabs/oft-evm/contracts/oft/OFT.sol";
import {MessagingFee, SendParam} from "@layerzerolabs/oft-evm/contracts/oft/interfaces/IOFT.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Dragon ecosystem interfaces
import {IOmniDragonLotteryManager} from "../../interfaces/lottery/IOmniDragonLotteryManager.sol";
import {IOmniDragonRegistry} from "../../interfaces/config/IOmniDragonRegistry.sol";
import {DragonErrors} from "../../libraries/DragonErrors.sol";
import {LayerZeroOptionsHelper} from "../../libraries/LayerZeroOptionsHelper.sol";

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
contract omniDRAGON is OFT, ReentrancyGuard {
  using SafeERC20 for IERC20;

  // Constants
  uint256 public constant MAX_SUPPLY = 6_942_000 * 10 ** 18;
  uint256 public constant INITIAL_SUPPLY = 6_942_000 * 10 ** 18;
  uint256 public constant MAX_SINGLE_TRANSFER = 1_000_000 * 10 ** 18;
  uint256 public constant BASIS_POINTS = 10000;
  uint256 public constant SONIC_CHAIN_ID = 146;
  uint256 public constant MAX_FEE_BPS = 2500;
  address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

  // Fee structure (packed for gas efficiency)
  struct Fees {
    uint16 jackpot; // Basis points for jackpot
    uint16 veDRAGON; // Basis points for veDRAGON holders
    uint16 burn; // Basis points to burn for both buy and sell
    uint16 total; // Total basis points
  }

  // Pack control flags into a single storage slot for gas efficiency
  struct ControlFlags {
    bool feesEnabled;
    bool tradingEnabled;
    bool initialMintCompleted;
    bool paused;
    bool emergencyMode;
  }

  // Registry integration
  IOmniDragonRegistry public immutable REGISTRY;
  address public immutable DELEGATE;

  // Core addresses
  address public jackpotVault;
  address public revenueDistributor;
  address public lotteryManager;

  // Fee configuration
  Fees public buyFees = Fees(690, 241, 69, 1000);
  Fees public sellFees = Fees(690, 241, 69, 1000);

  ControlFlags public controlFlags =
    ControlFlags(
      true, // feesEnabled
      true, // tradingEnabled
      false, // initialMintCompleted
      false, // paused
      false // emergencyMode
    );

  // Mappings
  mapping(address => bool) public isPair;
  mapping(address => bool) public isExcludedFromFees;
  mapping(address => bool) public isExcludedFromMaxTransfer;

  // Modifiers
  modifier notPaused() {
    if (controlFlags.paused) revert DragonErrors.ContractPaused();
    _;
  }

  modifier validAddress(address _addr) {
    if (_addr == address(0)) revert DragonErrors.ZeroAddress();
    _;
  }

  /// @dev Constructor
  constructor(
    string memory _name,
    string memory _symbol,
    address _delegate,
    address _registry,
    address _owner
  ) OFT(_name, _symbol, _getLayerZeroEndpoint(_registry), _delegate) Ownable(_owner) {
    if (_registry == address(0)) revert DragonErrors.ZeroAddress();
    if (_delegate == address(0)) revert DragonErrors.ZeroAddress();
    if (_owner == address(0)) revert DragonErrors.ZeroAddress();

    // Validate LayerZero endpoint
    address lzEndpoint = _getLayerZeroEndpoint(_registry);
    if (lzEndpoint == address(0)) revert("Invalid LZ endpoint");

    REGISTRY = IOmniDragonRegistry(_registry);
    DELEGATE = _delegate;

    // Exclude owner and contract from fees and max transfer
    isExcludedFromFees[_owner] = true;
    isExcludedFromFees[address(this)] = true;
    isExcludedFromMaxTransfer[_owner] = true;
    isExcludedFromMaxTransfer[address(this)] = true;

    // Mint initial supply only on Sonic chain
    if (block.chainid == SONIC_CHAIN_ID) {
      _mint(_owner, INITIAL_SUPPLY);
      controlFlags.initialMintCompleted = true;
      emit InitialMintCompleted(_owner, INITIAL_SUPPLY, block.chainid);
    }
  }

  // Events
  event FeesUpdated(bool indexed isBuy, uint16 indexed jackpot, uint16 indexed veDRAGON, uint16 burn, uint16 total);
  event PairUpdated(address indexed pair, bool indexed isActive);
  event FeeExclusionUpdated(address indexed account, bool indexed isExcluded);
  event TradingToggled(bool indexed enabled);
  event DistributionAddressesUpdated(address indexed jackpotVault, address indexed revenueDistributor);
  event InitialMintCompleted(address indexed to, uint256 amount, uint256 indexed chainId);
  event EmergencyModeToggled(bool indexed enabled);
  event ContractPausedEvent(bool indexed paused);
  event LotteryManagerUpdated(address indexed oldManager, address indexed newManager);
  event ImmediateDistributionExecuted(
    address indexed recipient,
    uint256 amount,
    EventCategory indexed distributionType
  );
  event TokensBurned(uint256 amount, EventCategory indexed burnType);
  event DexPairConfigured(address indexed pair, bool indexed isPair);
  event MaxTransferExclusionUpdated(address indexed account, bool indexed isExcluded);
  event FeesToggled(bool indexed enabled);
  event VaultsUpdated(address indexed jackpotVault, address indexed revenueDistributor);
  event EmergencyWithdrawal(address indexed to, uint256 amount, bool isNative);

  function transfer(address to, uint256 amount) public override notPaused returns (bool) {
    if (!isExcludedFromMaxTransfer[msg.sender] && amount > MAX_SINGLE_TRANSFER) {
      revert DragonErrors.MaxTransferExceeded();
    }
    return _transferWithFees(msg.sender, to, amount);
  }

  function transferFrom(address from, address to, uint256 amount) public override notPaused returns (bool) {
    // Fixed: Only check 'from' for max transfer exclusion
    if (!isExcludedFromMaxTransfer[from] && amount > MAX_SINGLE_TRANSFER) {
      revert DragonErrors.MaxTransferExceeded();
    }
    _spendAllowance(from, _msgSender(), amount);
    return _transferWithFees(from, to, amount);
  }

  /// @dev Internal transfer with fee logic
  function _transferWithFees(address from, address to, uint256 amount) internal returns (bool) {
    if (from == address(0) || to == address(0)) revert DragonErrors.ZeroAddress();

    // Check if trading is enabled (skip for excluded addresses)
    if (!controlFlags.tradingEnabled && !isExcludedFromFees[from] && !isExcludedFromFees[to]) {
      revert DragonErrors.TradingDisabled();
    }

    // Determine transaction type
    bool fromIsPair = isPair[from];
    bool toIsPair = isPair[to];

    if (fromIsPair && !toIsPair) {
      // Buy transaction: from a pair to a user
      return _processBuy(from, to, amount);
    } else if (!fromIsPair && toIsPair) {
      // Sell transaction: from a user to a pair
      return _processSell(from, to, amount);
    } else {
      // Standard transfer (user to user, or edge case: pair to pair)
      _transfer(from, to, amount);
      return true;
    }
  }

  /// @dev Process buy transaction
  function _processBuy(address from, address to, uint256 amount) internal returns (bool) {
    if (controlFlags.feesEnabled && !isExcludedFromFees[to]) {
      uint256 feeAmount = (amount * buyFees.total) / BASIS_POINTS;
      uint256 transferAmount = amount - feeAmount;

      // Transfer fees to contract first, then distribute
      _transfer(from, address(this), feeAmount);
      _transfer(from, to, transferAmount);
      _distributeBuyFeesFromContract(feeAmount);

      // Trigger lottery with hybrid pricing support
      if (lotteryManager != address(0)) {
        _safeTriggerLotteryWithPricing(from, to, amount);
      }
    } else {
      _transfer(from, to, amount);
    }

    return true;
  }

  /// @dev Process sell transaction
  function _processSell(address from, address to, uint256 amount) internal returns (bool) {
    if (controlFlags.feesEnabled && !isExcludedFromFees[from]) {
      uint256 feeAmount = (amount * sellFees.total) / BASIS_POINTS;
      uint256 transferAmount = amount - feeAmount;

      // Transfer fees to contract first, then distribute
      _transfer(from, address(this), feeAmount);
      _transfer(from, to, transferAmount);
      _distributeSellFeesFromContract(feeAmount);

      // NO LOTTERY ON SELLS
    } else {
      _transfer(from, to, amount);
    }

    return true;
  }

  /// @dev Distribute buy fees - Direct DRAGON distribution
  function _distributeBuyFeesFromContract(uint256 feeAmount) internal {
    if (feeAmount == 0) return;

    uint256 jackpotAmount = (feeAmount * buyFees.jackpot) / buyFees.total;
    uint256 revenueAmount = (feeAmount * buyFees.veDRAGON) / buyFees.total;
    uint256 burnAmount = feeAmount - jackpotAmount - revenueAmount;

    if (jackpotAmount > 0 && jackpotVault != address(0)) {
      _transfer(address(this), jackpotVault, jackpotAmount);
      emit ImmediateDistributionExecuted(jackpotVault, jackpotAmount, EventCategory.BUY_JACKPOT);
    }

    if (revenueAmount > 0 && revenueDistributor != address(0)) {
      _transfer(address(this), revenueDistributor, revenueAmount);
      emit ImmediateDistributionExecuted(revenueDistributor, revenueAmount, EventCategory.BUY_REVENUE);
    }

    if (burnAmount > 0) {
      _transfer(address(this), DEAD_ADDRESS, burnAmount);
      emit TokensBurned(burnAmount, EventCategory.BUY_BURN);
    }
  }

  /// @dev Distribute sell fees - Direct DRAGON distribution
  function _distributeSellFeesFromContract(uint256 feeAmount) internal {
    if (feeAmount == 0) return;

    uint256 jackpotAmount = (feeAmount * sellFees.jackpot) / sellFees.total;
    uint256 revenueAmount = (feeAmount * sellFees.veDRAGON) / sellFees.total;
    uint256 burnAmount = feeAmount - jackpotAmount - revenueAmount;

    if (jackpotAmount > 0 && jackpotVault != address(0)) {
      _transfer(address(this), jackpotVault, jackpotAmount);
      emit ImmediateDistributionExecuted(jackpotVault, jackpotAmount, EventCategory.SELL_JACKPOT);
    }

    if (revenueAmount > 0 && revenueDistributor != address(0)) {
      _transfer(address(this), revenueDistributor, revenueAmount);
      emit ImmediateDistributionExecuted(revenueDistributor, revenueAmount, EventCategory.SELL_REVENUE);
    }

    if (burnAmount > 0) {
      _transfer(address(this), DEAD_ADDRESS, burnAmount);
      emit TokensBurned(burnAmount, EventCategory.SELL_BURN);
    }
  }

  /// @dev Get LayerZero endpoint
  function _getLayerZeroEndpoint(address _registry) internal view returns (address) {
    if (_registry == address(0)) return address(0);

    try IOmniDragonRegistry(_registry).getLayerZeroEndpoint(uint16(block.chainid)) returns (address endpoint) {
      return endpoint;
    } catch {
      return address(0);
    }
  }

  /**
   * @dev Safely triggers lottery entry without reverting on failure
   * @param user The user to enter into the lottery
   * @param amount The amount involved in the transaction
   */
  function _safeTriggerLottery(address user, uint256 amount) internal {
    if (lotteryManager == address(0) || user == address(0) || amount == 0) {
      return;
    }

    try IOmniDragonLotteryManager(lotteryManager).processEntry(user, amount) {
      // Lottery entry successful
    } catch {
      // Lottery entry failed - continue without reverting
    }
  }

  /**
   * @notice Trigger lottery - pricing logic handled by lottery manager
   */
  function _safeTriggerLotteryWithPricing(address /* from */, address to, uint256 amount) internal {
    // Let lottery manager handle all pricing logic
    _safeTriggerLottery(to, amount);
  }

  // ========== ADMIN FUNCTIONS ==========

  /**
   * @notice Updates the vault addresses for fee distribution
   * @dev Only callable by owner. Validates addresses are non-zero.
   * @param _jackpotVault Address to receive jackpot fees
   * @param _revenueDistributor Address to receive revenue share fees
   */
  function updateVaults(address _jackpotVault, address _revenueDistributor) external onlyOwner {
    if (_jackpotVault == address(0) || _revenueDistributor == address(0)) {
      revert DragonErrors.ZeroAddress();
    }
    jackpotVault = _jackpotVault;
    revenueDistributor = _revenueDistributor;
    emit VaultsUpdated(_jackpotVault, _revenueDistributor);
  }

  /**
   * @notice Configures a DEX pair address for fee application
   * @dev Only callable by owner. Pairs are subject to fee logic on transfers.
   * @param pair Address of the DEX pair contract
   * @param isActive Whether this address should be treated as a DEX pair
   */
  function setPair(address pair, bool isActive) external onlyOwner validAddress(pair) {
    isPair[pair] = isActive;
    emit PairUpdated(pair, isActive);
  }

  /**
   * @notice Excludes or includes an address from fee calculations
   * @dev Only callable by owner. Excluded addresses bypass all fee logic.
   * @param account Address to update exclusion status
   * @param excluded Whether the address should be excluded from fees
   */
  function setExcludeFromFees(address account, bool excluded) external onlyOwner validAddress(account) {
    isExcludedFromFees[account] = excluded;
    emit FeeExclusionUpdated(account, excluded);
  }

  /**
   * @notice Excludes or includes an address from max transfer limits
   * @dev Only callable by owner. Excluded addresses can transfer without limit.
   * @param account Address to update exclusion status
   * @param excluded Whether the address should be excluded from max transfer limits
   */
  function setExcludeFromMaxTransfer(address account, bool excluded) external onlyOwner validAddress(account) {
    isExcludedFromMaxTransfer[account] = excluded;
    emit MaxTransferExclusionUpdated(account, excluded);
  }

  /**
   * @notice Updates fee percentages for buy or sell transactions
   * @dev Only callable by owner. Total fees cannot exceed MAX_FEE_BPS (25%) or be zero.
   * @param isBuy True for buy fees, false for sell fees
   * @param _jackpot Percentage for jackpot (in basis points)
   * @param _veDRAGON Percentage for veDRAGON holders (in basis points)
   * @param _burn Percentage to burn (in basis points) - applies to both buy and sell
   */
  function updateFees(bool isBuy, uint16 _jackpot, uint16 _veDRAGON, uint16 _burn) external onlyOwner {
    uint16 total = _jackpot + _veDRAGON + _burn;
    if (total == 0) revert DragonErrors.InvalidFeeStructure();
    if (total > MAX_FEE_BPS) revert DragonErrors.InvalidFeeConfiguration();

    if (isBuy) {
      buyFees = Fees(_jackpot, _veDRAGON, _burn, total);
    } else {
      sellFees = Fees(_jackpot, _veDRAGON, _burn, total);
    }

    emit FeesUpdated(isBuy, _jackpot, _veDRAGON, _burn, total);
  }

  /**
   * @notice Updates the lottery manager contract address
   * @dev Only callable by owner. Set to zero address to disable lottery integration.
   * @param _lotteryManager Address of the lottery manager contract
   */
  function setLotteryManager(address _lotteryManager) external onlyOwner {
    address oldManager = lotteryManager;
    lotteryManager = _lotteryManager;
    emit LotteryManagerUpdated(oldManager, _lotteryManager);
  }

  /**
   * @notice Toggles trading functionality on or off
   * @dev Only callable by owner. When disabled, only fee-excluded addresses can transfer.
   */
  function toggleTrading() external onlyOwner {
    controlFlags.tradingEnabled = !controlFlags.tradingEnabled;
    emit TradingToggled(controlFlags.tradingEnabled);
  }

  /**
   * @notice Toggles fee collection on or off
   * @dev Only callable by owner. When disabled, all transfers bypass fee logic.
   */
  function toggleFees() external onlyOwner {
    controlFlags.feesEnabled = !controlFlags.feesEnabled;
    emit FeesToggled(controlFlags.feesEnabled);
  }

  /**
   * @notice Toggles contract pause state
   * @dev Only callable by owner. When paused, all transfers are blocked.
   */
  function togglePause() external onlyOwner {
    controlFlags.paused = !controlFlags.paused;
    emit ContractPausedEvent(controlFlags.paused);
  }

  // ========== EMERGENCY FUNCTIONS ==========

  /**
   * @notice Enables emergency mode allowing withdrawal of stuck funds
   * @dev Only callable by owner. Should only be used in extreme circumstances.
   */
  function toggleEmergencyMode() external onlyOwner {
    controlFlags.emergencyMode = !controlFlags.emergencyMode;
    emit EmergencyModeToggled(controlFlags.emergencyMode);
  }

  /**
   * @notice Emergency withdrawal of native currency (ETH/SONIC/etc)
   * @dev Only callable by owner when emergency mode is enabled.
   * @param amount Amount of native currency to withdraw
   */
  function emergencyWithdrawNative(uint256 amount) external onlyOwner {
    if (!controlFlags.emergencyMode) revert DragonErrors.EmergencyModeDisabled();
    if (amount > address(this).balance) revert DragonErrors.InsufficientBalance();

    (bool success, ) = payable(owner()).call{value: amount}("");
    if (!success) revert DragonErrors.TransferFailed();

    emit EmergencyWithdrawal(owner(), amount, true);
  }

  /**
   * @notice Emergency withdrawal of ERC20 tokens
   * @dev Only callable by owner when emergency mode is enabled. Uses SafeERC20.
   * @param token Address of the ERC20 token to withdraw
   * @param amount Amount of tokens to withdraw
   */
  function emergencyWithdrawToken(address token, uint256 amount) external onlyOwner {
    if (!controlFlags.emergencyMode) revert DragonErrors.EmergencyModeDisabled();
    if (token == address(0)) revert DragonErrors.ZeroAddress();

    uint256 tokenBalance = IERC20(token).balanceOf(address(this));
    if (tokenBalance < amount) revert DragonErrors.InsufficientBalance();

    IERC20(token).safeTransfer(owner(), amount);
    emit EmergencyWithdrawal(owner(), amount, false);
  }

  // ========== VIEW FUNCTIONS ==========

  /**
   * @notice Returns the current buy and sell fee structures
   * @return buyFees_ The buy fee structure
   * @return sellFees_ The sell fee structure
   */
  function getFees() external view returns (Fees memory buyFees_, Fees memory sellFees_) {
    return (buyFees, sellFees);
  }

  /**
   * @notice Returns the current control flags state
   * @return The control flags structure
   */
  function getControlFlags() external view returns (ControlFlags memory) {
    return controlFlags;
  }

  /**
   * @notice Returns the distribution addresses
   * @return jackpot The jackpot vault address
   * @return revenue The revenue distributor address
   */
  function getDistributionAddresses() external view returns (address jackpot, address revenue) {
    return (jackpotVault, revenueDistributor);
  }

  /**
   * @notice Checks if contract supports a given interface
   * @param interfaceId The interface identifier to check
   * @return Whether the interface is supported
   */
  function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
    return interfaceId == type(IERC20).interfaceId || interfaceId == type(IERC165).interfaceId;
  }

  // ========== FEEM REGISTRATION ==========

  /**
   * @notice Registers the contract with Sonic FeeM system
   * @dev Only callable by owner. Makes external call to FeeM contract.
   * @dev Consider using DragonFeeMHelper for advanced FeeM integration
   */
  function registerMe() external onlyOwner {
    (bool _success, ) = address(0xDC2B0D2Dd2b7759D97D50db4eabDC36973110830).call(
      abi.encodeWithSignature("selfRegister(uint256)", 143)
    );
    require(_success, "FeeM registration failed");
  }

  // ========== LAYERZERO V2 OVERRIDES ==========

  /**
   * @notice Gets a quote for the fee required to send tokens cross-chain
   * @dev Overrides LayerZero OFT quoteSend function
   * @param _sendParam Parameters for the cross-chain send operation
   * @param _payInLzToken Whether to pay fees in LayerZero token
   * @return msgFee The messaging fee structure containing native and LZ token amounts
   */
  function quoteSend(
    SendParam calldata _sendParam,
    bool _payInLzToken
  ) public view override returns (MessagingFee memory msgFee) {
    (, uint256 amountReceivedLD) = _debitView(_sendParam.amountLD, _sendParam.minAmountLD, _sendParam.dstEid);
    (bytes memory message, bytes memory options) = _buildMsgAndOptions(_sendParam, amountReceivedLD);
    
    // Ensure extraOptions are properly formatted to avoid LZ_ULN_InvalidWorkerOptions
    options = LayerZeroOptionsHelper.ensureValidOptions(options);
    
    return _quote(_sendParam.dstEid, message, options, _payInLzToken);
  }

  /**
   * @notice Validates and returns the amount to be debited for cross-chain transfer
   * @dev Internal view function that ensures amount meets minimum requirements
   * @param _amountLD The amount in local decimals to transfer
   * @param _minAmountLD The minimum acceptable amount
   * @return amountSentLD The amount that will be sent
   * @return amountReceivedLD The amount that will be received (same as sent for this token)
   */
  function _debitView(
    uint256 _amountLD,
    uint256 _minAmountLD,
    uint32 /*_dstEid*/
  ) internal pure override returns (uint256 amountSentLD, uint256 amountReceivedLD) {
    if (_amountLD < _minAmountLD) revert DragonErrors.AmountBelowMinimum();
    amountSentLD = _amountLD;
    amountReceivedLD = _amountLD;
  }

  // ========== RECEIVE FUNCTION ==========

  /**
   * @notice Allows contract to receive native currency
   * @dev Protected by nonReentrant modifier for safety
   */
  receive() external payable nonReentrant {
    // Accept native tokens
  }
}