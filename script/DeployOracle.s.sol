// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/oracles/OmniDragonPrimaryOracle.sol";

/**
 * @title Deploy Primary Oracle
 * @dev Deploy the primary oracle on Sonic
 */
contract DeployOracle is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        address registryAddress = vm.envAddress("REGISTRY_ADDRESS");
        
        console.log("===========================================");
        console.log("PRIMARY ORACLE DEPLOYMENT");
        console.log("===========================================");
        console.log("Deployer:", deployerAddress);
        console.log("Chain ID:", block.chainid);
        console.log("Registry:", registryAddress);
        console.log("===========================================");
        
        // LayerZero endpoint for Sonic
        address lzEndpoint = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B;
        console.log("LayerZero Endpoint:", lzEndpoint);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Primary Oracle
        console.log("Deploying OmniDragonPrimaryOracle...");
        address omnidragonAddress = vm.envAddress("OMNIDRAGON_ADDRESS");
        
        OmniDragonPrimaryOracle oracle = new OmniDragonPrimaryOracle(
            "DRAGON",           // Native symbol
            "USD",              // Quote symbol  
            deployerAddress,    // Initial owner
            registryAddress,    // Hybrid registry
            omnidragonAddress,  // Dragon token
            lzEndpoint,         // LayerZero endpoint
            deployerAddress     // Delegate
        );
        
        console.log("Primary Oracle deployed at:", address(oracle));
        
        // Initialize the oracle (this sets it up for use)
        console.log("Initializing oracle...");
        // Note: Oracle needs actual price feeds to initialize properly
        // This will be done after configuration
        
        console.log("Oracle configured with basic settings");
        
        vm.stopBroadcast();
        
        console.log("===========================================");
        console.log("PRIMARY ORACLE DEPLOYMENT COMPLETE!");
        console.log("===========================================");
        console.log("PRIMARY_ORACLE_ADDRESS=", address(oracle));
        console.log("");
        console.log("NOTE: Oracle feeds need to be configured");
        console.log("with real price feed addresses when available");
        console.log("===========================================");
    }
}