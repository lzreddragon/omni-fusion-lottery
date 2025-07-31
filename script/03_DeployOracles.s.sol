// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/oracles/OmniDragonPrimaryOracle.sol";
import "../contracts/core/oracles/OmniDragonSecondaryOracle.sol";
import "../contracts/core/config/OmniDragonRegistry.sol";

/**
 * @title Deploy Oracle System
 * @dev Deployment script for OmniDragon oracle network
 * 
 * Prerequisites:
 * - OmniDragonRegistry must be deployed first
 * - Set REGISTRY_ADDRESS in .env
 * 
 * Usage:
 * # Deploy Primary Oracle on Sonic
 * forge script script/03_DeployOracles.s.sol --rpc-url $RPC_URL_SONIC --broadcast --verify
 * 
 * # Deploy Secondary Oracle on other chains
 * forge script script/03_DeployOracles.s.sol --rpc-url $RPC_URL_ARBITRUM --broadcast --verify
 */
contract DeployOracles is Script {
    
    function run() external {
        // Get environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        address registryAddress = vm.envAddress("REGISTRY_ADDRESS");
        address dragonAddress = vm.envAddress("OMNIDRAGON_ADDRESS");
        
        console.log("===========================================");
        console.log(" OMNIDRAGON ORACLE DEPLOYMENT");
        console.log("===========================================");
        console.log("Deployer:", deployerAddress);
        console.log("Chain ID:", block.chainid);
        console.log("Registry:", registryAddress);
        console.log("===========================================");
        
        // Validate registry exists
        require(registryAddress != address(0), "Registry address not set in .env");
        
        // Get LayerZero endpoint from registry
        OmniDragonRegistry registry = OmniDragonRegistry(registryAddress);
        address lzEndpoint = registry.layerZeroEndpoints(uint16(block.chainid));
        require(lzEndpoint != address(0), "LayerZero endpoint not configured for this chain");
        
        console.log(" LayerZero Endpoint:", lzEndpoint);
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        if (block.chainid == 146) {
            // Deploy Primary Oracle on Sonic
            console.log(" Deploying Primary Oracle on Sonic...");
            
            OmniDragonPrimaryOracle primaryOracle = new OmniDragonPrimaryOracle(
                "S",               // Native symbol
                "USD",             // Quote symbol
                deployerAddress,   // Initial owner
                registryAddress,   // Hybrid registry
                dragonAddress,     // Dragon token
                lzEndpoint,        // LayerZero endpoint
                deployerAddress    // Delegate
            );
            
            console.log(" Primary Oracle deployed at:", address(primaryOracle));
            
            // Configure oracle feeds (using placeholder addresses - update with real feeds)
            console.log(" Configuring oracle feeds...");
            
            // Configure placeholder oracle feeds - UPDATE WITH REAL ADDRESSES
            primaryOracle.configureOracles(
                address(0), // Chainlink feed (not available on Sonic yet)
                address(0), // Band Protocol feed  
                address(0), // API3 feed
                address(0), // Pyth feed
                bytes32(0), // Pyth price ID
                "DRAGON"    // Band base symbol
            );
            
            // Set oracle weights (equal weight for testing)
            primaryOracle.setOracleWeights(
                2500, // Chainlink: 25%
                2500, // Band: 25%
                2500, // API3: 25%
                2500  // Pyth: 25%
            );
            
            // Set maximum price deviation (10%)
            primaryOracle.setMaxPriceDeviation(1000); // 10% in basis points
            
            // Initialize with a test price ($1.00)
            // primaryOracle.initializePrice(); // Uncomment when oracle feeds are configured
            
            console.log(" Primary Oracle configured with placeholder feeds");
            console.log("  UPDATE ORACLE FEEDS WITH REAL ADDRESSES!");
            
            console.log(" SAVE THIS ADDRESS TO .env:");
            console.log("PRIMARY_ORACLE_ADDRESS=", address(primaryOracle));
            
        } else {
            // Deploy Secondary Oracle on other chains
            console.log("Deploying Secondary Oracle...");
            
            // Get primary oracle address (should be set after Sonic deployment)
            address primaryOracleAddress = vm.envOr("PRIMARY_ORACLE_ADDRESS", address(0));
            if (primaryOracleAddress == address(0)) {
                console.log("  WARNING: PRIMARY_ORACLE_ADDRESS not set in .env");
                console.log("Setting placeholder address - UPDATE AFTER PRIMARY DEPLOYMENT");
                primaryOracleAddress = address(0x1); // Placeholder
            }
            
            uint32 primaryChainEid = uint32(vm.envUint("SONIC_EID"));
            
            OmniDragonSecondaryOracle secondaryOracle = new OmniDragonSecondaryOracle(
                primaryChainEid,      // Primary chain EID (Sonic)
                primaryOracleAddress, // Primary oracle address
                deployerAddress       // Initial owner
            );
            
            console.log(" Secondary Oracle deployed at:", address(secondaryOracle));
            
            string memory chainName = "Unknown";
            if (block.chainid == 42161) chainName = "Arbitrum";
            else if (block.chainid == 43114) chainName = "Avalanche";
            else if (block.chainid == 1) chainName = "Ethereum";
            else if (block.chainid == 8453) chainName = "Base";
            
            console.log(" SAVE THIS ADDRESS TO .env:");
            console.log(string.concat(chainName, "_ORACLE_ADDRESS="), address(secondaryOracle));
        }
        
        vm.stopBroadcast();
        
        console.log("===========================================");
        console.log(" ORACLE DEPLOYMENT COMPLETE!");
        console.log("===========================================");
    }
}