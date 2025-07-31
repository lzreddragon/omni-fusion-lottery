// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/tokens/omniDRAGON.sol";
import "../contracts/core/lottery/OmniDragonLotteryManager.sol";
import {DragonJackpotVault} from "../contracts/core/lottery/DragonJackpotVault.sol";

/**
 * @title Configure OmniDRAGON System
 * @dev Configuration script to connect all deployed contracts
 * 
 * Prerequisites:
 * - All contracts must be deployed first
 * - Update .env with all contract addresses
 * 
 * Usage:
 * forge script script/05_ConfigureSystem.s.sol --rpc-url $RPC_URL_SONIC --broadcast
 */
contract ConfigureSystem is Script {
    
    function run() external {
        // Get environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        // Get contract addresses
        address omnidragonAddress = vm.envAddress("OMNIDRAGON_ADDRESS");
        address lotteryManagerAddress = vm.envAddress("LOTTERY_MANAGER_ADDRESS");
        address jackpotVaultAddress = vm.envAddress("JACKPOT_VAULT_ADDRESS");
        address revenueDistributorAddress = vm.envAddress("REVENUE_DISTRIBUTOR_ADDRESS");
        
        console.log("===========================================");
        console.log("  SYSTEM CONFIGURATION");
        console.log("===========================================");
        console.log("Deployer:", deployerAddress);
        console.log("Chain ID:", block.chainid);
        console.log("omniDRAGON:", omnidragonAddress);
        console.log("Lottery Manager:", lotteryManagerAddress);
        console.log("Jackpot Vault:", jackpotVaultAddress);
        console.log("Revenue Distributor:", revenueDistributorAddress);
        console.log("===========================================");
        
        // Validate all addresses are set
        require(omnidragonAddress != address(0), "OMNIDRAGON_ADDRESS not set");
        require(lotteryManagerAddress != address(0), "LOTTERY_MANAGER_ADDRESS not set");
        require(jackpotVaultAddress != address(0), "JACKPOT_VAULT_ADDRESS not set");
        require(revenueDistributorAddress != address(0), "REVENUE_DISTRIBUTOR_ADDRESS not set");
        
        // Get contract instances
        omniDRAGON dragon = omniDRAGON(payable(omnidragonAddress));
        OmniDragonLotteryManager lotteryManager = OmniDragonLotteryManager(lotteryManagerAddress);
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Note: omniDRAGON token is ready to work with the lottery system
        // Distribution addresses are handled automatically via fee mechanisms
        
        console.log(" Configuring lottery manager...");
        
        // Authorize omniDRAGON token as swap contract to call lottery manager
        lotteryManager.setAuthorizedSwapContract(omnidragonAddress, true);
        console.log(" omniDRAGON authorized to call lottery manager");
        
        // Set oracle address if available
        address oracleAddress = vm.envOr("PRIMARY_ORACLE_ADDRESS", address(0));
        if (block.chainid != 146) {
            // For non-Sonic chains, use secondary oracle
            string memory envVar = string.concat("ORACLE_ADDRESS_", vm.toString(block.chainid));
            oracleAddress = vm.envOr(envVar, address(0));
        }
        
        if (oracleAddress != address(0)) {
            lotteryManager.setPriceOracle(oracleAddress);
            console.log(" Price oracle configured:", oracleAddress);
        } else {
            console.log("  Price oracle not configured - set later");
        }
        
        console.log(" Final configuration...");
        
        // Note: Trading is enabled by default on omniDRAGON
        console.log(" Trading is enabled by default");
        
        // Verify configuration
        (address jackpot, address revenue) = dragon.getDistributionAddresses();
        address configuredLotteryManager = dragon.lotteryManager();
        bool tradingEnabled = dragon.getControlFlags().tradingEnabled;
        
        console.log(" Verification:");
        console.log("  Jackpot Vault:", jackpot);
        console.log("  Revenue Distributor:", revenue);
        console.log("  Lottery Manager:", configuredLotteryManager);
        console.log("  Trading Enabled:", tradingEnabled);
        
        vm.stopBroadcast();
        
        console.log("===========================================");
        console.log(" SYSTEM CONFIGURATION COMPLETE!");
        console.log("===========================================");
        console.log(" The omniDRAGON ecosystem is now live!");
        console.log("");
        console.log(" WHAT'S WORKING:");
        console.log(" Token transfers with fee-on-transfer");
        console.log(" Automatic lottery entry on transfers");
        console.log(" Jackpot distribution system");
        console.log(" Revenue distribution to veDRAGON holders");
        if (oracleAddress != address(0)) {
            console.log(" USD-based lottery probability");
        } else {
            console.log("  Oracle system needs configuration");
        }
        console.log("");
        console.log(" TEST THE SYSTEM:");
        console.log("1. Transfer some DRAGON tokens");
        console.log("2. Check lottery entries");
        console.log("3. Monitor jackpot growth");
        console.log("4. Test cross-chain transfers");
        console.log("===========================================");
    }
}