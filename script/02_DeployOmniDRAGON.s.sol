// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/tokens/omniDRAGON.sol";
import "../contracts/interfaces/tokens/IOmniDRAGON.sol";
import "../contracts/core/config/OmniDragonRegistry.sol";

/**
 * @title Deploy omniDRAGON Token
 * @dev Deployment script for the omniDRAGON LayerZero OFT token
 * 
 * Prerequisites:
 * - OmniDragonRegistry must be deployed first
 * - Set REGISTRY_ADDRESS in .env
 * 
 * Usage:
 * forge script script/02_DeployOmniDRAGON.s.sol --rpc-url $RPC_URL_SONIC --broadcast --verify
 */
contract DeployOmniDRAGON is Script {
    
    function run() external {
        // Get environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        address registryAddress = vm.envAddress("REGISTRY_ADDRESS");
        
        console.log("===========================================");
        console.log("DRAGON OMNIDRAGON TOKEN DEPLOYMENT");
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
        
        // Deploy omniDRAGON token
        console.log(" Deploying omniDRAGON token...");
        
        omniDRAGON dragon = new omniDRAGON(
            "Red Dragon",         // Token name
            "DRAGON",            // Token symbol
            deployerAddress,     // Initial delegate
            registryAddress,     // Registry address
            deployerAddress      // Initial owner
        );
        
        console.log(" omniDRAGON deployed at:", address(dragon));
        
        // Configure initial settings
        console.log(" Configuring initial settings...");
        
        // Set fee structure (10% total: 4% jackpot, 4% revenue, 2% burn)
        dragon.updateFees(true, 400, 400, 200);   // Buy fees: 4% jackpot, 4% veDRAGON, 2% burn
        dragon.updateFees(false, 400, 400, 200);  // Sell fees: 4% jackpot, 4% veDRAGON, 2% burn
        console.log(" Fee structure configured: 10% total (4% jackpot, 4% revenue, 2% burn)");
        
        // Note: Initial supply is automatically minted to owner on Sonic chain during construction
        // Note: Fees are enabled by default
        
        vm.stopBroadcast();
        
        console.log("===========================================");
        console.log(" DEPLOYMENT COMPLETE!");
        console.log("===========================================");
        console.log(" SAVE THIS ADDRESS TO .env:");
        console.log("OMNIDRAGON_ADDRESS=", address(dragon));
        console.log("");
        console.log("  NEXT STEPS:");
        console.log("1. Deploy oracle system");
        console.log("2. Deploy lottery manager"); 
        console.log("3. Deploy jackpot vault");
        console.log("4. Configure vaults in omniDRAGON");
        console.log("5. Enable trading");
        console.log("===========================================");
    }
}