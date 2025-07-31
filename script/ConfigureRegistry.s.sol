// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/config/OmniDragonRegistry.sol";

/**
 * @title Configure OmniDragonRegistry
 * @dev Script to configure LayerZero endpoints and chain settings
 */
contract ConfigureRegistry is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        address registryAddress = vm.envAddress("REGISTRY_ADDRESS");
        
        console.log("===========================================");
        console.log("CONFIGURING OMNIDRAGON REGISTRY");
        console.log("===========================================");
        console.log("Deployer:", deployerAddress);
        console.log("Chain ID:", block.chainid);
        console.log("Registry:", registryAddress);
        console.log("===========================================");
        
        OmniDragonRegistry registry = OmniDragonRegistry(registryAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        if (block.chainid == 146) {
            // Configure Sonic chain
            console.log("Configuring Sonic chain...");
            
            // LayerZero endpoint for Sonic
            address sonicEndpoint = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B;
            uint32 sonicEid = 30332; // Sonic EID from LayerZero docs
            
            // Set LayerZero endpoint
            registry.setLayerZeroEndpoint(146, sonicEndpoint);
            console.log("Set LayerZero endpoint:", sonicEndpoint);
            
            // Set chain ID to EID mapping
            registry.setChainIdToEid(146, sonicEid);
            console.log("Set EID:", sonicEid);
            
            // Register chain configuration
            registry.registerChain(
                146,                                               // chainId
                "Sonic",                                          // name
                0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38,        // wS token
                0x1D368773735ee1E678950B7A97bcA2CafB330CDc,        // Shadow Router
                0x2dA25E7446A70D7be65fd4c053948BEcAA6374c8,        // Shadow PairFactory
                true                                              // isActive
            );
            console.log("Registered Sonic chain configuration");
            
        } else if (block.chainid == 42161) {
            // Configure Arbitrum chain
            console.log("Configuring Arbitrum chain...");
            
            address arbEndpoint = 0x1a44076050125825900e736c501f859c50fE728c;
            uint32 arbEid = 30110;
            
            registry.setLayerZeroEndpoint(42161, arbEndpoint);
            registry.setChainIdToEid(42161, arbEid);
            
            registry.registerChain(
                42161,                                            // chainId
                "Arbitrum",                                       // name
                0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,        // WETH
                0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506,        // Sushiswap router
                0xc35DADB65012eC5796536bD9864eD8773aBc74C4,        // Sushiswap factory
                true                                              // isActive
            );
            console.log("Registered Arbitrum chain configuration");
            
        } else if (block.chainid == 43114) {
            // Configure Avalanche chain
            console.log("Configuring Avalanche chain...");
            
            address avaxEndpoint = 0x1a44076050125825900e736c501f859c50fE728c;
            uint32 avaxEid = 30106;
            
            registry.setLayerZeroEndpoint(43114, avaxEndpoint);
            registry.setChainIdToEid(43114, avaxEid);
            
            registry.registerChain(
                43114,                                            // chainId
                "Avalanche",                                      // name
                0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7,        // WAVAX
                0x60aE616a2155Ee3d9A68541Ba4544862310933d4,        // Trader Joe router
                0x9Ad6C38BE94206cA50bb0d90783181662f0Cfa10,        // Trader Joe factory
                true                                              // isActive
            );
            console.log("Registered Avalanche chain configuration");
        }
        
        vm.stopBroadcast();
        
        // Verify configuration
        address configuredEndpoint = registry.layerZeroEndpoints(uint16(block.chainid));
        uint32 configuredEid = registry.chainIdToEid(uint16(block.chainid));
        
        console.log("===========================================");
        console.log("CONFIGURATION COMPLETE!");
        console.log("===========================================");
        console.log("Chain ID:", block.chainid);
        console.log("LayerZero Endpoint:", configuredEndpoint);
        console.log("LayerZero EID:", configuredEid);
        console.log("===========================================");
    }
}