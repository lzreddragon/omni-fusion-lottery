// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

/**
 * @title Deploy Complete OmniDRAGON Ecosystem
 * @dev Master deployment script that orchestrates the entire deployment
 * 
 * Usage:
 * forge script script/DeployAll.s.sol --rpc-url $RPC_URL_SONIC --broadcast --verify
 * 
 * This script will guide you through the complete deployment process
 */
contract DeployAll is Script {
    
    function run() external view {
        console.log("DRAGON OMNIDRAGON ECOSYSTEM DEPLOYMENT GUIDE");
        console.log("==========================================");
        console.log("");
        console.log("This script will guide you through deploying the complete");
        console.log("omniDRAGON ecosystem. Follow these steps in order:");
        console.log("");
        
        console.log(" DEPLOYMENT CHECKLIST:");
        console.log("");
        
        console.log("PREPARE ENVIRONMENT");
        console.log("    Ensure .env file is configured");
        console.log("    Set PRIVATE_KEY, RPC URLs, API keys");
        console.log("    Fund deployer wallet with native tokens");
        console.log("");
        
        console.log("DEPLOY REGISTRY (Run once per chain)");
        console.log("    Command:");
        console.log("   forge script script/01_DeployRegistry.s.sol \\");
        console.log("     --rpc-url $RPC_URL_SONIC --broadcast --verify");
        console.log("");
        console.log("    Update .env with:");
        console.log("   REGISTRY_ADDRESS=<deployed_address>");
        console.log("");
        
        console.log("DEPLOY OMNIDRAGON TOKEN");
        console.log("    Command:");
        console.log("   forge script script/02_DeployOmniDRAGON.s.sol \\");
        console.log("     --rpc-url $RPC_URL_SONIC --broadcast --verify");
        console.log("");
        console.log("    Update .env with:");
        console.log("   OMNIDRAGON_ADDRESS=<deployed_address>");
        console.log("");
        
        console.log("DEPLOY ORACLE SYSTEM");
        console.log("    Primary Oracle (Sonic):");
        console.log("   forge script script/03_DeployOracles.s.sol \\");
        console.log("     --rpc-url $RPC_URL_SONIC --broadcast --verify");
        console.log("");
        console.log("    Secondary Oracles (Other chains):");
        console.log("   forge script script/03_DeployOracles.s.sol \\");
        console.log("     --rpc-url $RPC_URL_ARBITRUM --broadcast --verify");
        console.log("");
        console.log("    Update .env with oracle addresses");
        console.log("");
        
        console.log("DEPLOY LOTTERY SYSTEM");
        console.log("    Command:");
        console.log("   forge script script/04_DeployLottery.s.sol \\");
        console.log("     --rpc-url $RPC_URL_SONIC --broadcast --verify");
        console.log("");
        console.log("    Update .env with lottery addresses");
        console.log("");
        
        console.log("6  CONFIGURE SYSTEM");
        console.log("    Command:");
        console.log("   forge script script/05_ConfigureSystem.s.sol \\");
        console.log("     --rpc-url $RPC_URL_SONIC --broadcast");
        console.log("");
        
        console.log("7  MULTI-CHAIN DEPLOYMENT");
        console.log("    Repeat steps 1-2 on each target chain:");
        console.log("   - Arbitrum: $RPC_URL_ARBITRUM");
        console.log("   - Avalanche: $RPC_URL_AVALANCHE");
        console.log("   - Base: $RPC_URL_BASE (if configured)");
        console.log("");
        
        console.log("8  CONFIGURE CROSS-CHAIN PEERS");
        console.log("    Set up LayerZero OApp peers for cross-chain transfers");
        console.log("    Configure oracle synchronization");
        console.log("");
        
        console.log("9  TEST SYSTEM");
        console.log("    Run Dragon MCP test suite:");
        console.log("   python test_dragon_mcp.py");
        console.log("");
        console.log("    Test basic functionality:");
        console.log("   - Token transfers");
        console.log("   - Lottery entries");
        console.log("   - Cross-chain transfers");
        console.log("   - Oracle price feeds");
        console.log("");
        
        console.log("  PRODUCTION SETUP");
        console.log("    Configure real oracle feeds");
        console.log("    Set up monitoring and alerts");
        console.log("    Deploy frontend");
        console.log("    Set up multisig governance");
        console.log("");
        
        console.log("==========================================");
        console.log(" CURRENT STATUS CHECK:");
        console.log("==========================================");
        
        // Check current deployment status
        address registryAddr = vm.envOr("REGISTRY_ADDRESS", address(0));
        address dragonAddr = vm.envOr("OMNIDRAGON_ADDRESS", address(0));
        address lotteryAddr = vm.envOr("LOTTERY_MANAGER_ADDRESS", address(0));
        address jackpotAddr = vm.envOr("JACKPOT_VAULT_ADDRESS", address(0));
        
        console.log("Registry:         ", registryAddr == address(0) ? " NOT DEPLOYED" : " DEPLOYED");
        console.log("omniDRAGON:       ", dragonAddr == address(0) ? " NOT DEPLOYED" : " DEPLOYED");
        console.log("Lottery Manager:  ", lotteryAddr == address(0) ? " NOT DEPLOYED" : " DEPLOYED");
        console.log("Jackpot Vault:    ", jackpotAddr == address(0) ? " NOT DEPLOYED" : " DEPLOYED");
        
        console.log("");
        console.log(" NEXT STEP:");
        if (registryAddr == address(0)) {
            console.log("Deploy Registry first (step 2)");
        } else if (dragonAddr == address(0)) {
            console.log("Deploy omniDRAGON token (step 3)");
        } else if (lotteryAddr == address(0)) {
            console.log("Deploy Oracle system (step 4)");
            console.log("Then deploy Lottery system (step 5)");
        } else {
            console.log("Configure system (step 6)");
        }
        
        console.log("==========================================");
    }
}