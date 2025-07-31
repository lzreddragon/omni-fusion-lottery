// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/config/OmniDragonRegistry.sol";

/**
 * @title Deploy OmniDragonRegistry
 * @dev Deployment script for the OmniDragonRegistry contract
 * 
 * Usage:
 * forge script script/01_DeployRegistry.s.sol --rpc-url $RPC_URL_SONIC --broadcast --verify
 */
contract DeployRegistry is Script {
    
    function run() external {
        // Get environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        console.log("===========================================");
        console.log("OMNIDRAGON REGISTRY DEPLOYMENT");
        console.log("===========================================");
        console.log("Deployer:", deployerAddress);
        console.log("Chain ID:", block.chainid);
        console.log("===========================================");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy OmniDragonRegistry
        console.log(" Deploying OmniDragonRegistry...");
        OmniDragonRegistry registry = new OmniDragonRegistry(deployerAddress);
        
        console.log(" OmniDragonRegistry deployed at:", address(registry));
        
        // Set current chain configuration
        uint16 currentChainId = uint16(block.chainid);
        console.log(" Setting current chain ID:", currentChainId);
        registry.setCurrentChainId(currentChainId);
        
        // Configure initial chain settings based on chain ID
        if (block.chainid == 146) {
            // Sonic configuration
            console.log("Configuring Sonic chain...");
            registry.registerChain(
                146,
                "Sonic",
                0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38, // wS token
                0xBcE4D6750fa1e06f1f3a504EB7B5F0DB8E91e5D0, // Sonic DEX router (example)
                0x33B4bBF2B0d2b5D8E0C4e12b3f6E1b4C8b4B8A52, // Sonic DEX factory (example)
                true
            );
            
            // Set LayerZero endpoint
            address sonicEndpoint = vm.envAddress("SONIC_LZ_ENDPOINT");
            uint32 sonicEid = uint32(vm.envUint("SONIC_EID"));
            registry.setLayerZeroEndpoint(146, sonicEndpoint);
            registry.setChainIdToEid(146, sonicEid);
            console.log("LayerZero endpoint configured:", sonicEndpoint);
            
        } else if (block.chainid == 42161) {
            // Arbitrum configuration
            console.log(" Configuring Arbitrum chain...");
            registry.registerChain(
                42161,
                "Arbitrum",
                0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, // WETH on Arbitrum
                0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506, // Sushiswap router
                0xc35DADB65012eC5796536bD9864eD8773aBc74C4, // Sushiswap factory
                true
            );
            
            // Set LayerZero endpoint
            address arbEndpoint = vm.envAddress("ARBITRUM_LZ_ENDPOINT");
            uint32 arbEid = uint32(vm.envUint("ARBITRUM_EID"));
            registry.setLayerZeroEndpoint(42161, arbEndpoint);
            registry.setChainIdToEid(42161, arbEid);
            console.log(" LayerZero endpoint configured:", arbEndpoint);
            
        } else if (block.chainid == 43114) {
            // Avalanche configuration
            console.log("Configuring Avalanche chain...");
            registry.registerChain(
                43114,
                "Avalanche",
                0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7, // WAVAX
                0x60aE616a2155Ee3d9A68541Ba4544862310933d4, // Trader Joe router
                0x9Ad6C38BE94206cA50bb0d90783181662f0Cfa10, // Trader Joe factory
                true
            );
            
            // Set LayerZero endpoint
            address avaxEndpoint = vm.envAddress("AVALANCHE_LZ_ENDPOINT");
            uint32 avaxEid = uint32(vm.envUint("AVALANCHE_EID"));
            registry.setLayerZeroEndpoint(43114, avaxEndpoint);
            registry.setChainIdToEid(43114, avaxEid);
            console.log(" LayerZero endpoint configured:", avaxEndpoint);
        }
        
        vm.stopBroadcast();
        
        console.log("===========================================");
        console.log(" DEPLOYMENT COMPLETE!");
        console.log("===========================================");
        console.log(" SAVE THESE ADDRESSES TO .env:");
        console.log("REGISTRY_ADDRESS=", address(registry));
        console.log("===========================================");
    }
}