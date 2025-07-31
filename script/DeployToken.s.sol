// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/tokens/omniDRAGON.sol";

/**
 * @title Deploy omniDRAGON Token
 * @dev Simple deployment script for the omniDRAGON token
 */
contract DeployToken is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        address registryAddress = vm.envAddress("REGISTRY_ADDRESS");
        
        console.log("===========================================");
        console.log("OMNIDRAGON TOKEN DEPLOYMENT");
        console.log("===========================================");
        console.log("Deployer:", deployerAddress);
        console.log("Chain ID:", block.chainid);
        console.log("Registry:", registryAddress);
        console.log("===========================================");
        
        // LayerZero endpoint for Sonic (from LayerZero docs)
        address lzEndpoint = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B;
        console.log("LayerZero Endpoint:", lzEndpoint);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy omniDRAGON token
        console.log("Deploying omniDRAGON token...");
        omniDRAGON dragon = new omniDRAGON(
            "omniDRAGON",       // Token name
            "DRAGON",           // Token symbol
            deployerAddress,    // Initial delegate
            registryAddress,    // Registry address
            deployerAddress     // Initial owner
        );
        
        console.log("omniDRAGON deployed at:", address(dragon));
        console.log("Initial supply automatically minted on Sonic");
        
        vm.stopBroadcast();
        
        console.log("===========================================");
        console.log("TOKEN DEPLOYMENT COMPLETE!");
        console.log("===========================================");
        console.log("OMNIDRAGON_ADDRESS=", address(dragon));
        console.log("===========================================");
    }
}