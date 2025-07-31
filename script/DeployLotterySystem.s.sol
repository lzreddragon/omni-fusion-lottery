// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/lottery/OmniDragonLotteryManager.sol";
import "../contracts/core/governance/voting/veDRAGONRevenueDistributor.sol";

// Import DragonJackpotVault separately to avoid naming conflicts
import {DragonJackpotVault} from "../contracts/core/lottery/DragonJackpotVault.sol";

/**
 * @title Deploy Lottery System
 * @dev Deploy lottery manager, jackpot vault, and revenue distributor
 */
contract DeployLotterySystem is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        address registryAddress = vm.envAddress("REGISTRY_ADDRESS");
        address omnidragonAddress = vm.envAddress("OMNIDRAGON_ADDRESS");
        address oracleAddress = vm.envAddress("PRIMARY_ORACLE_ADDRESS");
        
        console.log("===========================================");
        console.log("LOTTERY SYSTEM DEPLOYMENT");
        console.log("===========================================");
        console.log("Deployer:", deployerAddress);
        console.log("omniDRAGON:", omnidragonAddress);
        console.log("Oracle:", oracleAddress);
        console.log("===========================================");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy DragonJackpotVault first
        console.log("Deploying DragonJackpotVault...");
        
        // Use wS (wrapped Sonic) as the native token on Sonic
        address wrappedNative = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;
        
        DragonJackpotVault jackpotVault = new DragonJackpotVault(
            deployerAddress,  // Owner
            wrappedNative     // Wrapped native token (wS)
        );
        
        console.log("DragonJackpotVault deployed at:", address(jackpotVault));
        
        // 2. Deploy veDRAGONRevenueDistributor
        console.log("Deploying veDRAGONRevenueDistributor...");
        
        veDRAGONRevenueDistributor revenueDistributor = new veDRAGONRevenueDistributor(
            address(0)             // veDRAGON token (deploy separately or set manually)
        );
        
        console.log("veDRAGONRevenueDistributor deployed at:", address(revenueDistributor));
        
        // 3. Deploy OmniDragonLotteryManager
        console.log("Deploying OmniDragonLotteryManager...");
        
        OmniDragonLotteryManager lotteryManager = new OmniDragonLotteryManager(
            address(jackpotVault),          // Jackpot distributor
            address(0),                     // veDRAGON token (set manually later)
            oracleAddress,                  // Price oracle
            block.chainid                   // Chain ID
        );
        
        console.log("OmniDragonLotteryManager deployed at:", address(lotteryManager));
        
        // 4. Configure lottery settings
        console.log("Configuring lottery settings...");
        
        // Configure instant lottery
        lotteryManager.configureInstantLottery(
            1000,        // baseWinProbability: 10% (1000 out of 10000)
            10 * 1e6,    // minSwapAmount: $10 minimum
            500,         // rewardPercentage: 5% of jackpot
            true,        // isActive
            true         // useVRFForInstant
        );
        
        console.log("Instant lottery configured: $10 min, 10% win probability, 5% jackpot reward");
        
        // Note: Rate limiting is built into the contract
        
        vm.stopBroadcast();
        
        console.log("===========================================");
        console.log("LOTTERY SYSTEM DEPLOYMENT COMPLETE!");
        console.log("===========================================");
        console.log("LOTTERY_MANAGER_ADDRESS=", address(lotteryManager));
        console.log("JACKPOT_VAULT_ADDRESS=", address(jackpotVault));
        console.log("REVENUE_DISTRIBUTOR_ADDRESS=", address(revenueDistributor));
        console.log("");
        console.log("Next steps:");
        console.log("1. Connect lottery manager to omniDRAGON token");
        console.log("2. Set distribution addresses in omniDRAGON");
        console.log("3. Enable trading");
        console.log("===========================================");
    }
}