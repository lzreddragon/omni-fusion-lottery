# 🚀 Deployment Guide - omni-fusion-lottery

## 📋 **Prerequisites**

### **Required Tools**
- ✅ **Foundry** (forge, cast, anvil)
- ✅ **Node.js** 18+ 
- ✅ **Git**
- ✅ **MetaMask** or hardware wallet

### **Environment Setup**
```bash
# Clone repository
git clone https://github.com/lzreddragon/omni-fusion-lottery.git
cd omni-fusion-lottery

# Install dependencies
forge install

# Build contracts
forge build

# Run tests
forge test
```

### **Required Information**
- LayerZero endpoint addresses for target chains
- Initial owner address (deployer)
- Delegate address (for LayerZero configuration)
- Vault addresses (jackpot and revenue)

## 🌐 **Multi-Chain Deployment Strategy**

### **Deployment Order**
1. **Primary Chain (Sonic)**: Deploy registry and token
2. **Secondary Chains**: Deploy token with same registry address
3. **Configuration**: Set up cross-chain peers
4. **Verification**: Test cross-chain transfers

### **Vanity Address Generation**
Target: `0x69...7777`

```bash
# Install vanity address generator
npm install -g ethereum-vanity-address-generator

# Generate vanity address
ethereum-vanity-address-generator --prefix 69 --suffix 7777 --workers 4
```

## 📝 **Step-by-Step Deployment**

### **Step 1: Prepare Environment**

Create `.env` file:
```bash
# Network RPC URLs
SONIC_RPC_URL=https://rpc.soniclabs.com
ARBITRUM_RPC_URL=https://arb1.arbitrum.io/rpc
AVALANCHE_RPC_URL=https://api.avax.network/ext/bc/C/rpc

# Private key (use hardware wallet for mainnet)
PRIVATE_KEY=your_private_key_here

# Etherscan API keys for verification
ETHERSCAN_API_KEY=your_etherscan_key
ARBISCAN_API_KEY=your_arbiscan_key
SNOWTRACE_API_KEY=your_snowtrace_key

# LayerZero endpoints
SONIC_LZ_ENDPOINT=0x6F475642a6e85809B1c36Fa62763669b1b48DD5B
ARBITRUM_LZ_ENDPOINT=0x1a44076050125825900e736c501f859c50fE728c
AVALANCHE_LZ_ENDPOINT=0x1a44076050125825900e736c501f859c50fE728c
TAC_LZ-ENDPOINT=0x6F475642a6e85809B1c36Fa62763669b1b48DD5B

# Deployment addresses
OWNER_ADDRESS=your_owner_address
DELEGATE_ADDRESS=your_delegate_address
JACKPOT_VAULT=your_jackpot_vault
REVENUE_VAULT=your_revenue_vault
```

### **Step 2: Deploy on Sonic (Primary Chain)**

```bash
# Deploy OmniDragonRegistry
forge script scripts/deploy/01_DeployRegistry.s.sol \
    --rpc-url $SONIC_RPC_URL \
    --broadcast \
    --verify

# Deploy omniDRAGON Token  
forge script scripts/deploy/02_DeployDragon.s.sol \
    --rpc-url $SONIC_RPC_URL \
    --broadcast \
    --verify
```

**Expected Outputs**:
- `OmniDragonRegistry`: `0x69...7777` (if using vanity address)
- `omniDRAGON`: `0x[token_address]`

### **Step 3: Configure Primary Chain**

```bash
# Set up initial chain configuration
cast send $REGISTRY_ADDRESS \
    "registerChain(uint16,string,address,address,address,bool)" \
    146 "Sonic" $WS_ADDRESS $SONIC_ROUTER $SONIC_FACTORY true \
    --rpc-url $SONIC_RPC_URL \
    --private-key $PRIVATE_KEY

# Configure vaults
cast send $DRAGON_ADDRESS \
    "setVaults(address,address)" \
    $JACKPOT_VAULT $REVENUE_VAULT \
    --rpc-url $SONIC_RPC_URL \
    --private-key $PRIVATE_KEY

# Enable trading
cast send $DRAGON_ADDRESS \
    "setTradingEnabled(bool)" true \
    --rpc-url $SONIC_RPC_URL \
    --private-key $PRIVATE_KEY
```

### **Step 4: Deploy on Secondary Chains**

**Arbitrum Deployment**:
```bash
# Deploy registry at same address (CREATE2)
forge script scripts/deploy/01_DeployRegistry.s.sol \
    --rpc-url $ARBITRUM_RPC_URL \
    --broadcast \
    --verify

# Deploy omniDRAGON token
forge script scripts/deploy/02_DeployDragon.s.sol \
    --rpc-url $ARBITRUM_RPC_URL \
    --broadcast \
    --verify
```

**Avalanche Deployment**:
```bash
# Deploy registry at same address (CREATE2)
forge script scripts/deploy/01_DeployRegistry.s.sol \
    --rpc-url $AVALANCHE_RPC_URL \
    --broadcast \
    --verify

# Deploy omniDRAGON token
forge script scripts/deploy/02_DeployDragon.s.sol \
    --rpc-url $AVALANCHE_RPC_URL \
    --broadcast \
    --verify
```

### **Step 5: Configure Cross-Chain Peers**

Set up LayerZero peers for each chain:

```bash
# Configure Sonic → Arbitrum
cast send $DRAGON_ADDRESS_SONIC \
    "setPeer(uint32,bytes32)" \
    30110 $(cast to-bytes32 $DRAGON_ADDRESS_ARBITRUM) \
    --rpc-url $SONIC_RPC_URL \
    --private-key $PRIVATE_KEY

# Configure Arbitrum → Sonic  
cast send $DRAGON_ADDRESS_ARBITRUM \
    "setPeer(uint32,bytes32)" \
    30146 $(cast to-bytes32 $DRAGON_ADDRESS_SONIC) \
    --rpc-url $ARBITRUM_RPC_URL \
    --private-key $PRIVATE_KEY

# Repeat for all chain pairs...
```

## 🧪 **Testing Deployment**

### **Unit Tests**
```bash
# Run all tests
forge test -vv

# Test specific contract
forge test --match-contract omniDRAGONTest -vvv

# Test with gas reporting
forge test --gas-report
```

### **Integration Tests**
```bash
# Test cross-chain functionality
forge script scripts/test/TestCrossChain.s.sol \
    --rpc-url $SONIC_RPC_URL

# Test fee distribution
forge script scripts/test/TestFeeDistribution.s.sol \
    --rpc-url $SONIC_RPC_URL
```

### **Mainnet Fork Testing**
```bash
# Fork Sonic mainnet
anvil --fork-url $SONIC_RPC_URL --fork-block-number latest

# Run tests against fork
forge test --fork-url http://localhost:8545
```

## 🔧 **Post-Deployment Configuration**

### **1. Set DEX Pairs**
```bash
# Add Uniswap V2 pair
cast send $DRAGON_ADDRESS \
    "setPair(address,bool)" \
    $UNISWAP_PAIR_ADDRESS true \
    --rpc-url $SONIC_RPC_URL \
    --private-key $PRIVATE_KEY

# Add SonicSwap pair
cast send $DRAGON_ADDRESS \
    "setPair(address,bool)" \
    $SONICSWAP_PAIR_ADDRESS true \
    --rpc-url $SONIC_RPC_URL \
    --private-key $PRIVATE_KEY
```

### **2. Configure Registry Chains**
```bash
# Register all supported chains
for chain in sonic arbitrum avalanche ethereum polygon fantom bsc; do
    forge script scripts/config/RegisterChain.s.sol \
        --sig "registerChain(string)" $chain \
        --rpc-url $SONIC_RPC_URL \
        --broadcast
done
```

### **3. Verify Deployments**
```bash
# Verify all contracts on block explorers
forge verify-contract $REGISTRY_ADDRESS \
    contracts/core/config/OmniDragonRegistry.sol:OmniDragonRegistry \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --chain sonic

forge verify-contract $DRAGON_ADDRESS \
    contracts/core/tokens/omniDRAGON.sol:omniDRAGON \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --chain sonic
```

## 📊 **Deployment Checklist**

### **Pre-Deployment**
- [ ] Environment variables configured
- [ ] Vanity addresses generated (if desired)
- [ ] All tests passing
- [ ] Gas estimates calculated
- [ ] Security review completed

### **During Deployment**
- [ ] Registry deployed to all chains
- [ ] Token deployed to all chains
- [ ] Cross-chain peers configured
- [ ] Initial chain configurations set

### **Post-Deployment**
- [ ] Contracts verified on block explorers
- [ ] DEX pairs configured
- [ ] Vaults configured
- [ ] Trading enabled
- [ ] Cross-chain transfers tested
- [ ] Fee distribution tested

### **Production Readiness**
- [ ] Multi-sig ownership transferred
- [ ] Emergency procedures documented
- [ ] Monitoring systems deployed
- [ ] User documentation published

## ⚠️ **Security Considerations**

### **Mainnet Deployment**
1. **Use Hardware Wallet**: Never use private keys directly
2. **Multi-sig Ownership**: Transfer ownership to multi-sig
3. **Gradual Rollout**: Start with small amounts
4. **Emergency Procedures**: Have pause/emergency plans ready
5. **Insurance**: Consider smart contract insurance

### **Key Management**
```bash
# Use Ledger for mainnet deployments
forge script scripts/deploy/01_DeployRegistry.s.sol \
    --rpc-url $MAINNET_RPC_URL \
    --ledger \
    --sender $LEDGER_ADDRESS \
    --broadcast
```

### **Rate Limiting**
- Start with conservative transfer limits
- Monitor cross-chain message volume
- Implement circuit breakers if needed

## 📈 **Cost Estimates**

### **Deployment Costs** (approximate)
| Contract | Sonic | Arbitrum | Avalanche |
|----------|-------|----------|-----------|
| Registry | ~$5 | ~$15 | ~$10 |
| omniDRAGON | ~$8 | ~$25 | ~$15 |
| **Total** | **~$13** | **~$40** | **~$25** |

### **Operational Costs**
- Cross-chain messages: $0.10-$1.00 per transfer
- Administrative updates: $1-5 per transaction
- Emergency actions: $5-20 per action

---

**Deployment Status**: 🔧 **Ready for Testnet** → 🚀 **Mainnet Ready**