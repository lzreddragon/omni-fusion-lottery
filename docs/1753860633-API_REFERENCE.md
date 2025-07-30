# 📖 API Reference - omni-fusion-lottery

## 🏗️ **Contract Addresses**

### **Testnet Deployments**
```javascript
// Sonic Testnet
const REGISTRY_ADDRESS = "0x69...7777" // Vanity address
const DRAGON_ADDRESS = "0x[deployed_address]"

// Arbitrum Testnet  
const REGISTRY_ADDRESS = "0x69...7777" // Same address
const DRAGON_ADDRESS = "0x[deployed_address]"
```

## 📋 **omniDRAGON Token API**

### **Core ERC20 Functions**

```solidity
// Basic token information
function name() external view returns (string memory);          // "omniDRAGON"
function symbol() external view returns (string memory);        // "DRAGON"
function decimals() external view returns (uint8);              // 18
function totalSupply() external view returns (uint256);         // 6,942,000 * 10^18

// Balance and transfer
function balanceOf(address account) external view returns (uint256);
function transfer(address to, uint256 amount) external returns (bool);
function transferFrom(address from, address to, uint256 amount) external returns (bool);

// Allowances
function allowance(address owner, address spender) external view returns (uint256);
function approve(address spender, uint256 amount) external returns (bool);
```

### **Fee Management**

```solidity
// Fee structure
struct Fees {
    uint16 jackpot;   // Basis points for jackpot (690 = 6.9%)
    uint16 veDRAGON;  // Basis points for revenue (241 = 2.41%)
    uint16 burn;      // Basis points to burn (69 = 0.69%)
    uint16 total;     // Total basis points (1000 = 10%)
}

// View fee configuration
function getBuyFees() external view returns (Fees memory);
function getSellFees() external view returns (Fees memory);
function calculateFees(uint256 amount, bool isBuy) external view returns (
    uint256 jackpotFee, 
    uint256 revenueFee, 
    uint256 burnFee
);

// Admin: Update fees (onlyOwner)
function setFees(Fees calldata buyFees, Fees calldata sellFees) external;
function setFeesEnabled(bool enabled) external;
```

### **Vault Management**

```solidity
// View vault addresses
function jackpotVault() external view returns (address);
function revenueVault() external view returns (address);

// Admin: Configure vaults (onlyOwner)
function setVaults(address _jackpotVault, address _revenueVault) external;
```

### **DEX Pair Management**

```solidity
// Check if address is a DEX pair
function isPair(address account) external view returns (bool);

// Admin: Add/remove DEX pairs (onlyOwner)
function setPair(address pair, bool listed) external;
```

### **Cross-Chain Functions**

```solidity
// Cross-chain transfer
function crossChainTransfer(
    uint32 dstEid,              // Destination endpoint ID
    address to,                 // Recipient address
    uint256 amount,             // Amount to transfer
    bytes calldata extraOptions // LayerZero options
) external payable returns (bytes32 guid);

// Quote cross-chain transfer fee
function quoteCrossChainTransfer(
    uint32 dstEid,
    address to,
    uint256 amount,
    bytes calldata extraOptions
) external view returns (uint256 fee);
```

### **Control Functions**

```solidity
// Control flags
struct ControlFlags {
    bool feesEnabled;
    bool tradingEnabled;
    bool initialMintCompleted;
    bool paused;
    bool emergencyMode;
}

function getControlFlags() external view returns (ControlFlags memory);

// Admin controls (onlyOwner)
function setTradingEnabled(bool enabled) external;
function toggleEmergencyMode() external;
function emergencyWithdraw(address token, uint256 amount) external;
```

## 🗂️ **OmniDragonRegistry API**

### **Chain Configuration**

```solidity
// Chain information structure
struct ChainConfig {
    uint16 chainId;
    string chainName;
    address wrappedNativeToken;     // WETH, WAVAX, WS, etc.
    string wrappedNativeSymbol;     // "WETH", "WAVAX", "WS"
    address uniswapV2Router;        // DEX router address
    address uniswapV2Factory;       // DEX factory address
    bool isActive;                  // Whether chain is active
}

// View chain information
function getChainConfig(uint16 chainId) external view returns (ChainConfig memory);
function getSupportedChains() external view returns (uint16[] memory);
function getCurrentChainId() external view returns (uint16);
```

### **Chain Management**

```solidity
// Admin: Register new chain (onlyOwner)
function registerChain(
    uint16 _chainId,
    string calldata _chainName,
    address _wrappedNativeToken,
    address _uniswapV2Router,
    address _uniswapV2Factory,
    bool _isActive
) external;

// Admin: Update chain configuration (onlyOwner)
function updateChain(
    uint16 _chainId,
    string calldata _chainName,
    address _wrappedNativeToken,
    address _uniswapV2Router,
    address _uniswapV2Factory
) external;

// Admin: Set chain status (onlyOwner)
function setChainStatus(uint16 _chainId, bool _isActive) external;
```

### **LayerZero Configuration**

```solidity
// LayerZero endpoint mapping
function layerZeroEndpoints(uint16 chainId) external view returns (address);
function chainIdToEid(uint256 chainId) external view returns (uint32);
function eidToChainId(uint32 eid) external view returns (uint256);

// Admin: Configure LayerZero (onlyOwner)
function setLayerZeroEndpoint(uint16 _chainId, address _endpoint) external;
function setChainIdToEid(uint256 _chainId, uint32 _eid) external;
```

## 📱 **Frontend Integration Examples**

### **React/TypeScript Integration**

```typescript
import { ethers } from 'ethers';

// Contract ABI imports
import omniDRAGON_ABI from './abi/omniDRAGON.json';
import OmniDragonRegistry_ABI from './abi/OmniDragonRegistry.json';

// Contract addresses
const DRAGON_ADDRESS = "0x[deployed_address]";
const REGISTRY_ADDRESS = "0x69...7777";

// Initialize contracts
const provider = new ethers.providers.Web3Provider(window.ethereum);
const signer = provider.getSigner();

const dragonContract = new ethers.Contract(DRAGON_ADDRESS, omniDRAGON_ABI, signer);
const registryContract = new ethers.Contract(REGISTRY_ADDRESS, OmniDragonRegistry_ABI, provider);

// Example: Get token balance
async function getBalance(address: string): Promise<string> {
    const balance = await dragonContract.balanceOf(address);
    return ethers.utils.formatEther(balance);
}

// Example: Transfer tokens
async function transfer(to: string, amount: string): Promise<string> {
    const amountWei = ethers.utils.parseEther(amount);
    const tx = await dragonContract.transfer(to, amountWei);
    await tx.wait();
    return tx.hash;
}

// Example: Cross-chain transfer
async function crossChainTransfer(
    dstChainId: number,
    to: string, 
    amount: string
): Promise<string> {
    const amountWei = ethers.utils.parseEther(amount);
    const dstEid = await registryContract.chainIdToEid(dstChainId);
    
    // Get quote for transfer
    const fee = await dragonContract.quoteCrossChainTransfer(
        dstEid, to, amountWei, "0x"
    );
    
    // Execute transfer
    const tx = await dragonContract.crossChainTransfer(
        dstEid, to, amountWei, "0x", { value: fee }
    );
    
    await tx.wait();
    return tx.hash;
}

// Example: Get fee information
async function getFeeInfo(amount: string): Promise<{
    jackpot: string;
    revenue: string;
    burn: string;
}> {
    const amountWei = ethers.utils.parseEther(amount);
    const [jackpotFee, revenueFee, burnFee] = await dragonContract.calculateFees(
        amountWei, true // true for buy fees
    );
    
    return {
        jackpot: ethers.utils.formatEther(jackpotFee),
        revenue: ethers.utils.formatEther(revenueFee),
        burn: ethers.utils.formatEther(burnFee)
    };
}
```

### **Web3.py Integration**

```python
from web3 import Web3
import json

# Initialize Web3
w3 = Web3(Web3.HTTPProvider('https://rpc.soniclabs.com'))

# Load contract ABIs
with open('abi/omniDRAGON.json') as f:
    dragon_abi = json.load(f)

# Initialize contracts
dragon_contract = w3.eth.contract(
    address='0x[deployed_address]',
    abi=dragon_abi
)

# Example: Get balance
def get_balance(address):
    balance = dragon_contract.functions.balanceOf(address).call()
    return w3.fromWei(balance, 'ether')

# Example: Transfer tokens
def transfer_tokens(private_key, to_address, amount):
    account = w3.eth.account.from_key(private_key)
    amount_wei = w3.toWei(amount, 'ether')
    
    # Build transaction
    transaction = dragon_contract.functions.transfer(
        to_address, amount_wei
    ).buildTransaction({
        'from': account.address,
        'gas': 100000,
        'gasPrice': w3.toWei('20', 'gwei'),
        'nonce': w3.eth.get_transaction_count(account.address)
    })
    
    # Sign and send
    signed_txn = w3.eth.account.sign_transaction(transaction, private_key)
    tx_hash = w3.eth.send_raw_transaction(signed_txn.rawTransaction)
    
    return tx_hash.hex()
```

## 🔔 **Events Reference**

### **omniDRAGON Events**

```solidity
// ERC20 events
event Transfer(address indexed from, address indexed to, uint256 value);
event Approval(address indexed owner, address indexed spender, uint256 value);

// Fee distribution events
event FeeDistributed(address indexed vault, uint256 amount, string category);
event FeesUpdated(Fees newFees);
event FeesEnabled(bool enabled);

// Administrative events
event VaultUpdated(address indexed vault, string vaultType);
event TradingEnabled(bool enabled);
event PairUpdated(address indexed pair, bool isListed);
event LotteryManagerUpdated(address indexed newManager);
event EmergencyModeToggled(bool enabled);

// Cross-chain events
event CrossChainTransferInitiated(
    uint32 indexed dstEid,
    address indexed to,
    uint256 amount,
    uint256 fee
);

// Lottery events (future)
event LotteryTriggered(address indexed trader, uint256 amount, uint256 tickets);
```

### **Registry Events**

```solidity
// Chain management events
event ChainRegistered(uint16 indexed chainId, string chainName);
event ChainUpdated(uint16 indexed chainId);
event ChainStatusChanged(uint16 indexed chainId, bool isActive);

// LayerZero configuration events
event LayerZeroEndpointSet(uint16 indexed chainId, address endpoint);
event ChainIdToEidSet(uint256 chainId, uint32 eid);
```

## 🚨 **Error Reference**

### **omniDRAGON Errors**

```solidity
error InvalidFeeConfiguration();    // Fee structure invalid
error FeesTooHigh();                // Fees exceed 25% limit
error TradingDisabled();            // Trading not enabled
error TransferAmountTooHigh();      // Exceeds max transfer limit
error ZeroAddress();                // Zero address provided
error InvalidAmount();              // Invalid amount (zero or overflow)
error Unauthorized();               // Access denied
error EmergencyModeActive();        // Emergency mode engaged
error ContractPaused();             // Contract is paused
```

### **Registry Errors**

```solidity
error ChainAlreadyRegistered(uint16 chainId);
error ChainNotRegistered(uint16 chainId);
error ZeroAddress();
```

## 💡 **Usage Examples**

### **Basic Token Operations**
```javascript
// Check balance
const balance = await dragonContract.balanceOf(userAddress);

// Transfer tokens
await dragonContract.transfer(recipientAddress, ethers.utils.parseEther("100"));

// Approve spending
await dragonContract.approve(spenderAddress, ethers.utils.parseEther("1000"));
```

### **Fee Calculation**
```javascript
// Calculate fees for a trade
const [jackpot, revenue, burn] = await dragonContract.calculateFees(
    ethers.utils.parseEther("1000"), // amount
    true // isBuy
);

console.log(`Jackpot fee: ${ethers.utils.formatEther(jackpot)} DRAGON`);
console.log(`Revenue fee: ${ethers.utils.formatEther(revenue)} DRAGON`);
console.log(`Burn fee: ${ethers.utils.formatEther(burn)} DRAGON`);
```

### **Cross-Chain Transfer**
```javascript
// Get destination chain EID
const dstEid = await registryContract.chainIdToEid(42161); // Arbitrum

// Quote transfer fee
const fee = await dragonContract.quoteCrossChainTransfer(
    dstEid,
    recipientAddress,
    ethers.utils.parseEther("100"),
    "0x" // no extra options
);

// Execute transfer
const tx = await dragonContract.crossChainTransfer(
    dstEid,
    recipientAddress,
    ethers.utils.parseEther("100"),
    "0x",
    { value: fee }
);
```

---

**API Status**: 🟢 **Stable** - Ready for integration