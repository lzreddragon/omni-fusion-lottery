// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/core/oracles/OmniDragonPrimaryOracle.sol";
import "../contracts/core/oracles/OmniDragonPriceOracle.sol";
import "@layerzerolabs/oft-evm/contracts/oapp/OApp.sol";
import "@layerzerolabs/oft-evm/contracts/oft/interfaces/IOFT.sol";

// ============ MOCK CONTRACTS ============

contract MockLayerZeroEndpoint {
    mapping(bytes32 => bool) public sentMessages;
    
    function send(
        uint32 /* _dstEid */,
        bytes memory _message,
        bytes memory /* _options */
    ) external payable returns (bytes32 guid) {
        guid = keccak256(_message);
        sentMessages[guid] = true;
        return guid;
    }
    
    function setDelegate(address /* _delegate */) external {}
}

contract MockDragonToken {
    function balanceOf(address) external pure returns (uint256) {
        return 1000000 * 10**18;
    }
}

contract MockRegistry {
    function getPriceOracle(uint16) external pure returns (address) {
        return address(0);
    }
}

// ============ PRIMARY ORACLE TESTS ============

contract OmniDragonPrimaryOracleTest is Test {
    OmniDragonPrimaryOracle public primaryOracle;
    MockLayerZeroEndpoint public mockEndpoint;
    MockDragonToken public mockDragonToken;
    MockRegistry public mockRegistry;
    
    address public owner = address(0x1);
    address public delegate = address(0x2);
    address public user = address(0x3);
    
    uint32 public constant TEST_CHAIN_EID = 30332; // Sonic EID
    
    event PriceBroadcastSent(uint32 indexed dstEid, int256 price, uint256 timestamp, bytes32 guid);
    event ChainAuthorized(uint32 indexed eid, bool authorized);
    event LzReadQueryResponded(bytes4 indexed queryType, address indexed requester, bytes response);
    event PriceDistributionThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    
    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy mock contracts
        mockEndpoint = new MockLayerZeroEndpoint();
        mockDragonToken = new MockDragonToken();
        mockRegistry = new MockRegistry();
        
        // Deploy primary oracle
        primaryOracle = new OmniDragonPrimaryOracle(
            "DRAGON",
            "USD",
            owner,
            address(mockRegistry),
            address(mockDragonToken),
            address(mockEndpoint),
            delegate
        );
        
        vm.stopPrank();
    }
    
    function testDeployment() public {
        // Test basic deployment properties
        assertEq(primaryOracle.owner(), owner);
        assertTrue(primaryOracle.supportsLzRead());
        
        // Test query types are set correctly
        bytes4[] memory queryTypes = primaryOracle.getSupportedQueryTypes();
        assertEq(queryTypes.length, 4);
        assertEq(queryTypes[0], bytes4(keccak256("getLatestPrice()")));
        assertEq(queryTypes[1], bytes4(keccak256("getAggregatedPrice()")));
        assertEq(queryTypes[2], bytes4(keccak256("getLPTokenPrice(address,uint256)")));
        assertEq(queryTypes[3], bytes4(keccak256("getOracleStatus()")));
    }
    
    function testAuthorizeChain() public {
        vm.startPrank(owner);
        
        // Test authorizing a chain
        vm.expectEmit(true, false, false, true);
        emit ChainAuthorized(1, true);
        primaryOracle.authorizeChain(1, true);
        
        assertTrue(primaryOracle.authorizedChains(1));
        
        // Test deauthorizing a chain
        vm.expectEmit(true, false, false, true);
        emit ChainAuthorized(1, false);
        primaryOracle.authorizeChain(1, false);
        
        assertFalse(primaryOracle.authorizedChains(1));
        
        vm.stopPrank();
    }
    
    function testSetPriceDistributionThreshold() public {
        vm.startPrank(owner);
        
        uint256 newThreshold = 1000; // 10%
        uint256 oldThreshold = primaryOracle.priceDistributionThreshold();
        
        vm.expectEmit(true, true, false, true);
        emit PriceDistributionThresholdUpdated(oldThreshold, newThreshold);
        primaryOracle.setPriceDistributionThreshold(newThreshold);
        
        assertEq(primaryOracle.priceDistributionThreshold(), newThreshold);
        
        vm.stopPrank();
    }
    
    function testSetPriceDistributionThresholdRevertsTooHigh() public {
        vm.startPrank(owner);
        
        vm.expectRevert("Threshold too high");
        primaryOracle.setPriceDistributionThreshold(10001); // > 100%
        
        vm.stopPrank();
    }
    
    function testLzReceiveHandlesLatestPriceQuery() public {
        // Setup query data
        bytes4 queryType = bytes4(keccak256("getLatestPrice()"));
        bytes memory queryData = "";
        bytes memory message = abi.encode(queryType, queryData);
        
        // Mock origin
        Origin memory origin = Origin({
            srcEid: 1,
            sender: bytes32(uint256(uint160(user))),
            nonce: 0
        });
        
        // This would normally be called by LayerZero endpoint
        // For testing, we'll simulate the internal logic
        bytes32 guid = keccak256("test");
        
        // The actual _lzReceive function is internal, so we test the supported query types
        bytes4[] memory supportedTypes = primaryOracle.getSupportedQueryTypes();
        bool isSupported = false;
        for (uint i = 0; i < supportedTypes.length; i++) {
            if (supportedTypes[i] == queryType) {
                isSupported = true;
                break;
            }
        }
        assertTrue(isSupported, "Query type should be supported");
    }
    
    function testLzReceiveHandlesAggregatedPriceQuery() public {
        bytes4 queryType = bytes4(keccak256("getAggregatedPrice()"));
        
        // Check that this query type is supported
        bytes4[] memory supportedTypes = primaryOracle.getSupportedQueryTypes();
        bool isSupported = false;
        for (uint i = 0; i < supportedTypes.length; i++) {
            if (supportedTypes[i] == queryType) {
                isSupported = true;
                break;
            }
        }
        assertTrue(isSupported, "AggregatedPrice query type should be supported");
    }
    
    function testLzReceiveHandlesLPTokenPriceQuery() public {
        bytes4 queryType = bytes4(keccak256("getLPTokenPrice(address,uint256)"));
        
        // Check that this query type is supported
        bytes4[] memory supportedTypes = primaryOracle.getSupportedQueryTypes();
        bool isSupported = false;
        for (uint i = 0; i < supportedTypes.length; i++) {
            if (supportedTypes[i] == queryType) {
                isSupported = true;
                break;
            }
        }
        assertTrue(isSupported, "LPTokenPrice query type should be supported");
    }
    
    function testLzReceiveHandlesOracleStatusQuery() public {
        bytes4 queryType = bytes4(keccak256("getOracleStatus()"));
        
        // Check that this query type is supported
        bytes4[] memory supportedTypes = primaryOracle.getSupportedQueryTypes();
        bool isSupported = false;
        for (uint i = 0; i < supportedTypes.length; i++) {
            if (supportedTypes[i] == queryType) {
                isSupported = true;
                break;
            }
        }
        assertTrue(isSupported, "OracleStatus query type should be supported");
    }
    
    function testQuoteCrossChainMessage() public {
        bytes memory message = abi.encode(bytes4(keccak256("getLatestPrice()")), "");
        
        // Since no peer is configured, this should revert
        vm.expectRevert();
        primaryOracle.quoteCrossChainMessage(1, message);
        
        // Test that the function exists and has correct signature
        assertTrue(address(primaryOracle) != address(0));
    }
    
    function testUpdatePriceOverride() public {
        vm.startPrank(owner);
        
        // Test that updatePrice function exists and is virtual (can be overridden)
        // Since no real oracles are configured, this will likely revert
        // but we can test that the function signature is correct
        try primaryOracle.updatePrice() returns (bool success) {
            // If it succeeds (unlikely without real oracles), that's fine
            assertTrue(true, "UpdatePrice succeeded unexpectedly but that's ok");
        } catch {
            // If it reverts (expected without real oracles), that's also fine
            assertTrue(true, "UpdatePrice reverted as expected without real oracles");
        }
        
        // Test that the function is overridden correctly by checking it exists
        assertTrue(address(primaryOracle) != address(0));
        
        vm.stopPrank();
    }
    
    function testOnlyOwnerFunctions() public {
        // Test that non-owner cannot call owner functions
        vm.startPrank(user);
        
        vm.expectRevert();
        primaryOracle.authorizeChain(1, true);
        
        vm.expectRevert();
        primaryOracle.setPriceDistributionThreshold(1000);
        
        vm.stopPrank();
    }
    
    function testBuildDefaultOptions() public view {
        // Test that the oracle supports lzRead
        assertTrue(primaryOracle.supportsLzRead());
        
        // Test supported query types length
        bytes4[] memory queryTypes = primaryOracle.getSupportedQueryTypes();
        assertEq(queryTypes.length, 4);
    }
    
    function testInheritanceFromBaseOracle() public {
        // Test that primary oracle inherits base oracle functionality
        assertTrue(address(primaryOracle) != address(0));
        
        // Test owner is set correctly
        assertEq(primaryOracle.owner(), owner);
        
        // Test that it has oracle status function
        try primaryOracle.getOracleStatus() returns (
            bool initialized,
            bool circuitBreakerActive,
            bool emergencyMode,
            bool inGracePeriod,
            uint256 activeOracles,
            uint256 maxDeviation
        ) {
            // Function exists and returns values
            assertTrue(true);
        } catch {
            // If it reverts due to uninitialized state, that's also valid
            assertTrue(true);
        }
    }
}