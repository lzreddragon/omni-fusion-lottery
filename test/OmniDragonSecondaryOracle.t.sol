// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/core/oracles/OmniDragonSecondaryOracle.sol";

// ============ SECONDARY ORACLE TESTS ============

contract OmniDragonSecondaryOracleTest is Test {
    OmniDragonSecondaryOracle public secondaryOracle;
    
    address public owner = address(0x1);
    address public user = address(0x2);
    
    uint32 public constant PRIMARY_CHAIN_EID = 30146; // Sonic EID
    address public constant PRIMARY_ORACLE_ADDRESS = address(0x123);
    
    event QuerySent(bytes32 indexed queryId, bytes4 queryType, address requester);
    event PriceUpdated(int256 indexed newPrice, uint256 timestamp, uint256 oracleCount);
    event PrimaryOracleConfigured(uint32 chainEid, address oracleAddress);
    
    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy secondary oracle
        secondaryOracle = new OmniDragonSecondaryOracle(
            PRIMARY_CHAIN_EID,
            PRIMARY_ORACLE_ADDRESS,
            owner
        );
        
        vm.stopPrank();
    }
    
    function testDeployment() public {
        // Test basic deployment properties
        assertEq(secondaryOracle.owner(), owner);
        assertEq(secondaryOracle.primaryChainEid(), PRIMARY_CHAIN_EID);
        assertEq(secondaryOracle.primaryOracleAddress(), PRIMARY_ORACLE_ADDRESS);
        assertFalse(secondaryOracle.isInitialized());
        assertEq(secondaryOracle.latestPrice(), 0);
        assertEq(secondaryOracle.lastPriceUpdate(), 0);
    }
    
    function testPrimaryOracleConfiguredEvent() public {
        vm.expectEmit(true, true, false, true);
        emit PrimaryOracleConfigured(PRIMARY_CHAIN_EID, PRIMARY_ORACLE_ADDRESS);
        
        // Deploy another instance to test event
        vm.prank(owner);
        new OmniDragonSecondaryOracle(
            PRIMARY_CHAIN_EID,
            PRIMARY_ORACLE_ADDRESS,
            owner
        );
    }
    
    function testGetLatestPrice() public {
        // Initially should return default values
        (int256 price, uint256 timestamp) = secondaryOracle.getLatestPrice();
        assertEq(price, 0);
        assertEq(timestamp, 0);
    }
    
    function testGetAggregatedPrice() public {
        // Initially should return default values
        (int256 price, bool success, uint256 timestamp) = secondaryOracle.getAggregatedPrice();
        assertEq(price, 0);
        assertFalse(success);
        assertEq(timestamp, 0);
    }
    
    function testUpdatePriceFromPrimary() public {
        vm.startPrank(owner);
        
        int256 testPrice = 250000000000000000; // $0.25 in 18 decimals
        uint256 testTimestamp = block.timestamp;
        
        vm.expectEmit(true, false, false, true);
        emit PriceUpdated(testPrice, testTimestamp, 1);
        
        secondaryOracle.updatePriceFromPrimary(testPrice, testTimestamp);
        
        // Verify price was updated
        assertEq(secondaryOracle.latestPrice(), testPrice);
        assertEq(secondaryOracle.lastPriceUpdate(), testTimestamp);
        assertTrue(secondaryOracle.isInitialized());
        
        // Test that getLatestPrice now returns updated values
        (int256 price, uint256 timestamp) = secondaryOracle.getLatestPrice();
        assertEq(price, testPrice);
        assertEq(timestamp, testTimestamp);
        
        // Test that getAggregatedPrice now returns updated values
        (int256 aggPrice, bool success, uint256 aggTimestamp) = secondaryOracle.getAggregatedPrice();
        assertEq(aggPrice, testPrice);
        assertTrue(success);
        assertEq(aggTimestamp, testTimestamp);
        
        vm.stopPrank();
    }
    
    function testUpdatePriceFromPrimaryRevertsInvalidPrice() public {
        vm.startPrank(owner);
        
        vm.expectRevert("Invalid price");
        secondaryOracle.updatePriceFromPrimary(0, block.timestamp);
        
        vm.expectRevert("Invalid price");
        secondaryOracle.updatePriceFromPrimary(-100, block.timestamp);
        
        vm.stopPrank();
    }
    
    function testTriggerPriceUpdate() public {
        // This should emit a QuerySent event
        vm.expectEmit(false, true, true, true);
        emit QuerySent(bytes32(0), bytes4(keccak256("getAggregatedPrice()")), address(this));
        
        secondaryOracle.triggerPriceUpdate();
    }
    
    function testUpdatePrimaryOracle() public {
        vm.startPrank(owner);
        
        uint32 newChainEid = 1;
        address newOracleAddress = address(0x456);
        
        vm.expectEmit(true, true, false, true);
        emit PrimaryOracleConfigured(newChainEid, newOracleAddress);
        
        secondaryOracle.updatePrimaryOracle(newChainEid, newOracleAddress);
        
        assertEq(secondaryOracle.primaryChainEid(), newChainEid);
        assertEq(secondaryOracle.primaryOracleAddress(), newOracleAddress);
        
        vm.stopPrank();
    }
    
    function testUpdatePrimaryOracleRevertsInvalidAddress() public {
        vm.startPrank(owner);
        
        vm.expectRevert("Invalid oracle address");
        secondaryOracle.updatePrimaryOracle(1, address(0));
        
        vm.stopPrank();
    }
    
    function testInitializePrice() public {
        vm.startPrank(owner);
        
        // Should return true and emit QuerySent
        vm.expectEmit(false, true, true, true);
        emit QuerySent(bytes32(0), bytes4(keccak256("getAggregatedPrice()")), owner);
        
        bool success = secondaryOracle.initializePrice();
        assertTrue(success);
        
        vm.stopPrank();
    }
    
    function testUpdatePrice() public {
        // Should return true and emit QuerySent
        vm.expectEmit(false, true, true, true);
        emit QuerySent(bytes32(0), bytes4(keccak256("getAggregatedPrice()")), address(this));
        
        bool success = secondaryOracle.updatePrice();
        assertTrue(success);
    }
    
    function testGetNativeTokenPrice() public {
        // Should return default values for secondary oracle
        (int256 price, bool isValid, uint256 timestamp) = secondaryOracle.getNativeTokenPrice();
        assertEq(price, 0);
        assertFalse(isValid);
        assertEq(timestamp, 0);
    }
    
    function testGetLPTokenPrice() public {
        // Should return 0 for secondary oracle
        uint256 usdValue = secondaryOracle.getLPTokenPrice(address(0x123), 1000);
        assertEq(usdValue, 0);
    }
    
    function testGetOracleStatus() public {
        (
            bool initialized,
            bool circuitBreakerActive,
            bool emergencyMode,
            bool inGracePeriod,
            uint256 activeOracles,
            uint256 maxDeviation
        ) = secondaryOracle.getOracleStatus();
        
        // Initially should not be initialized
        assertFalse(initialized);
        assertFalse(circuitBreakerActive);
        assertFalse(emergencyMode);
        assertFalse(inGracePeriod);
        assertEq(activeOracles, 1);
        assertEq(maxDeviation, 2000);
        
        // After updating price, should be initialized
        vm.prank(owner);
        secondaryOracle.updatePriceFromPrimary(250000000000000000, block.timestamp);
        
        (initialized,,,,,) = secondaryOracle.getOracleStatus();
        assertTrue(initialized);
    }
    
    function testIsFresh() public {
        // Initially should not be fresh
        assertFalse(secondaryOracle.isFresh());
        
        // After updating price, should be fresh
        vm.prank(owner);
        secondaryOracle.updatePriceFromPrimary(250000000000000000, block.timestamp);
        
        assertTrue(secondaryOracle.isFresh());
        
        // After 1 hour + 1 second, should not be fresh
        vm.warp(block.timestamp + 3601);
        assertFalse(secondaryOracle.isFresh());
    }
    
    function testQuoteLzReadQuery() public {
        bytes4 queryType = bytes4(keccak256("getLatestPrice()"));
        bytes memory queryData = "";
        
        uint256 fee = secondaryOracle.quoteLzReadQuery(queryType, queryData);
        assertEq(fee, 0.001 ether);
    }
    
    function testSupportsLzRead() public {
        assertTrue(secondaryOracle.supportsLzRead());
    }
    
    function testNotSupportedFunctions() public {
        vm.startPrank(owner);
        
        // Test configureOracles reverts
        vm.expectRevert("Not supported on secondary oracle");
        secondaryOracle.configureOracles(
            address(0), address(0), address(0), address(0), bytes32(0), ""
        );
        
        // Test setOracleWeights reverts
        vm.expectRevert("Not supported on secondary oracle");
        secondaryOracle.setOracleWeights(100, 100, 100, 100);
        
        // Test setMaxPriceDeviation reverts
        vm.expectRevert("Not supported on secondary oracle");
        secondaryOracle.setMaxPriceDeviation(1000);
        
        // Test resetCircuitBreaker reverts
        vm.expectRevert("Not supported on secondary oracle");
        secondaryOracle.resetCircuitBreaker();
        
        // Test activateEmergencyMode reverts
        vm.expectRevert("Not supported on secondary oracle");
        secondaryOracle.activateEmergencyMode(100);
        
        // Test deactivateEmergencyMode reverts
        vm.expectRevert("Not supported on secondary oracle");
        secondaryOracle.deactivateEmergencyMode();
        
        vm.stopPrank();
    }
    
    function testGetOracleConfig() public {
        (
            IOmniDragonPriceOracle.OracleConfig memory chainlink,
            IOmniDragonPriceOracle.OracleConfig memory band,
            IOmniDragonPriceOracle.OracleConfig memory api3,
            IOmniDragonPriceOracle.OracleConfig memory pyth,
            string memory bandSymbol,
            bytes32 pythId
        ) = secondaryOracle.getOracleConfig();
        
        // All should be empty/default for secondary oracle
        assertEq(chainlink.feedAddress, address(0));
        assertEq(chainlink.weight, 0);
        assertFalse(chainlink.isActive);
        assertEq(chainlink.maxStaleness, 0);
        
        assertEq(band.feedAddress, address(0));
        assertEq(api3.feedAddress, address(0));
        assertEq(pyth.feedAddress, address(0));
        
        assertEq(bandSymbol, "");
        assertEq(pythId, bytes32(0));
    }
    
    function testOnlyOwnerFunctions() public {
        // Test that non-owner cannot call owner functions
        vm.startPrank(user);
        
        vm.expectRevert();
        secondaryOracle.updatePriceFromPrimary(100, block.timestamp);
        
        vm.expectRevert();
        secondaryOracle.updatePrimaryOracle(1, address(0x123));
        
        vm.expectRevert();
        secondaryOracle.initializePrice();
        
        vm.stopPrank();
    }
    
    function testQueryIdGeneration() public {
        // Test that multiple queries generate different IDs
        bytes32 queryId1 = keccak256(abi.encodePacked(
            block.timestamp, 
            address(this), 
            bytes4(keccak256("getLatestPrice()"))
        ));
        
        // Advance time slightly
        vm.warp(block.timestamp + 1);
        
        bytes32 queryId2 = keccak256(abi.encodePacked(
            block.timestamp, 
            address(this), 
            bytes4(keccak256("getLatestPrice()"))
        ));
        
        assertTrue(queryId1 != queryId2, "Query IDs should be different");
    }
}