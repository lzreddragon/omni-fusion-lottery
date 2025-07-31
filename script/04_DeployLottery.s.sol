// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/lottery/OmniDragonLotteryManager.sol";
import {DragonJackpotVault} from "../contracts/core/lottery/DragonJackpotVault.sol";
import "../contracts/core/governance/voting/veDRAGONRevenueDistributor.sol";
import "../contracts/core/config/OmniDragonRegistry.sol";

/**
 * @title Deploy Lottery System
 * @dev Deployment script for lottery manager and jackpot vault
 * 
 * Prerequisites:
 * - OmniDragonRegistry must be deployed first
 * - omniDRAGON token must be deployed
 * - Oracle system should be deployed
 * 
 * Usage:
 * forge script script/04_DeployLottery.s.sol --rpc-url $RPC_URL_SONIC --broadcast --verify
 */
contract DeployLottery is Script {
    
    function run() external {
        // Get environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        address registryAddress = vm.envAddress("REGISTRY_ADDRESS");
        address omnidragonAddress = vm.envAddress("OMNIDRAGON_ADDRESS");
        
        console.log("===========================================");
        console.log(" LOTTERY SYSTEM DEPLOYMENT");
        console.log("===========================================");
        console.log("Deployer:", deployerAddress);
        console.log("Chain ID:", block.chainid);
        console.log("Registry:", registryAddress);
        console.log("omniDRAGON:", omnidragonAddress);
        console.log("===========================================");
        
        // Validate prerequisites
        require(registryAddress != address(0), "Registry address not set in .env");
        require(omnidragonAddress != address(0), "omniDRAGON address not set in .env");
        
        // Get oracle address (may not be set yet)
        address oracleAddress = vm.envOr("PRIMARY_ORACLE_ADDRESS", address(0));
        if (block.chainid != 146) {
            // For non-Sonic chains, use secondary oracle
            string memory envVar = string.concat("ORACLE_ADDRESS_", vm.toString(block.chainid));
            oracleAddress = vm.envOr(envVar, address(0));
        }
        
        console.log(" Oracle:", oracleAddress);
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy DragonJackpotVault first
        console.log(" Deploying DragonJackpotVault...");
        
        // Get wrapped native token address from registry
        OmniDragonRegistry registry = OmniDragonRegistry(registryAddress);
        address wrappedNative = registry.getChainConfig(uint16(block.chainid)).wrappedNativeToken;
        
        DragonJackpotVault jackpotVault = new DragonJackpotVault(
            deployerAddress, // Owner
            wrappedNative    // Wrapped native token (wS/WETH/WAVAX/etc)
        );
        
        console.log(" DragonJackpotVault deployed at:", address(jackpotVault));
        
        // Deploy veDRAGONRevenueDistributor
        console.log(" Deploying veDRAGONRevenueDistributor...");
        
        veDRAGONRevenueDistributor revenueDistributor = new veDRAGONRevenueDistributor(
            address(0)         // veDRAGON token (deploy separately or set manually)
        );
        
        console.log(" veDRAGONRevenueDistributor deployed at:", address(revenueDistributor));
        
        // Deploy OmniDragonLotteryManager
        console.log(" Deploying OmniDragonLotteryManager...");
        
        OmniDragonLotteryManager lotteryManager = new OmniDragonLotteryManager(
            address(jackpotVault),          // Jackpot distributor
            address(0),                     // veDRAGON token (set manually later)
            oracleAddress,                  // Price oracle
            block.chainid                   // Chain ID
        );
        
        console.log(" OmniDragonLotteryManager deployed at:", address(lotteryManager));
        
        // Configure lottery settings
        console.log(" Configuring lottery settings...");
        
        // Configure instant lottery
        lotteryManager.configureInstantLottery(
            1000,        // baseWinProbability: 10% (1000 out of 10000)
            10 * 1e6,    // minSwapAmount: $10 minimum
            500,         // rewardPercentage: 5% of jackpot
            true,        // isActive
            true         // useVRFForInstant
        );
        
        // Note: Rate limiting is built into the contract
        
        console.log(" Lottery configured: $10 min entry, 10% max win chance, $1000 base reward");
        
        // Note: Jackpot vault is ready to receive funds from trading fees
        
        vm.stopBroadcast();
        
        console.log("===========================================");
        console.log(" LOTTERY SYSTEM DEPLOYMENT COMPLETE!");
        console.log("===========================================");
        console.log(" SAVE THESE ADDRESSES TO .env:");
        console.log("LOTTERY_MANAGER_ADDRESS=", address(lotteryManager));
        console.log("JACKPOT_VAULT_ADDRESS=", address(jackpotVault));
        console.log("REVENUE_DISTRIBUTOR_ADDRESS=", address(revenueDistributor));
        console.log("");
        console.log("  NEXT STEPS:");
        console.log("1. Configure vault addresses in omniDRAGON token");
        console.log("2. Set lottery manager in omniDRAGON token");
        console.log("3. Enable trading in omniDRAGON");
        console.log("4. Fund jackpot vault");
        console.log("5. Deploy VRF system if needed");
        console.log("===========================================");
    }
}