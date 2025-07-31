// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/tokens/omniDRAGON.sol";
import "../contracts/core/oracles/OmniDragonPrimaryOracle.sol";

/**
 * @title Connect System Components
 * @dev Connect oracle to omniDRAGON and configure basic settings
 */
contract ConnectSystem is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        address registryAddress = vm.envAddress("REGISTRY_ADDRESS");
        address omnidragonAddress = vm.envAddress("OMNIDRAGON_ADDRESS");
        address oracleAddress = vm.envAddress("PRIMARY_ORACLE_ADDRESS");
        
        console.log("===========================================");
        console.log("CONNECTING SYSTEM COMPONENTS");
        console.log("===========================================");
        console.log("Deployer:", deployerAddress);
        console.log("Registry:", registryAddress);
        console.log("omniDRAGON:", omnidragonAddress);
        console.log("Oracle:", oracleAddress);
        console.log("===========================================");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Get contract instances
        OmniDragonPrimaryOracle oracle = OmniDragonPrimaryOracle(oracleAddress);
        
        // Note: omniDRAGON oracle integration happens through lottery manager
        console.log("Oracle will be connected via lottery manager later...");
        
        // Configure oracle basic settings
        console.log("Configuring oracle settings...");
        
        // Set price distribution threshold
        oracle.setPriceDistributionThreshold(100 * 1e18); // 100 DRAGON tokens
        console.log("Price distribution threshold set");
        
        console.log("Oracle configured for basic operation");
        console.log("Note: Price feeds will be configured when available");
        
        vm.stopBroadcast();
        
        console.log("===========================================");
        console.log("SYSTEM CONNECTION COMPLETE!");
        console.log("===========================================");
        console.log("Next steps:");
        console.log("1. Configure oracle price feeds when available");
        console.log("2. Deploy lottery system");
        console.log("3. Connect all vaults and distributors");
        console.log("===========================================");
    }
}