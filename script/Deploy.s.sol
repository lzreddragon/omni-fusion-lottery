// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/config/OmniDragonRegistry.sol";

/**
 * @title Simple OmniDRAGON Deployment
 * @dev Simple deployment script without Unicode characters
 */
contract Deploy is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        console.log("===========================================");
        console.log("OMNIDRAGON DEPLOYMENT STARTING");
        console.log("===========================================");
        console.log("Deployer:", deployerAddress);
        console.log("Chain ID:", block.chainid);
        console.log("===========================================");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy OmniDragonRegistry
        console.log("Deploying OmniDragonRegistry...");
        OmniDragonRegistry registry = new OmniDragonRegistry(deployerAddress);
        console.log("Registry deployed at:", address(registry));
        
        vm.stopBroadcast();
        
        console.log("===========================================");
        console.log("DEPLOYMENT COMPLETE!");
        console.log("===========================================");
        console.log("REGISTRY_ADDRESS=", address(registry));
        console.log("===========================================");
    }
}