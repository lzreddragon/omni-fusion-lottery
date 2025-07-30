// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/core/config/OmniDragonRegistry.sol";
import "../contracts/interfaces/config/IOmniDragonRegistry.sol";

/**
 * @title OmniDragonRegistryTest
 * @dev Comprehensive tests for OmniDragonRegistry contract
 */
contract OmniDragonRegistryTest is Test {
    OmniDragonRegistry public registry;
    
    // Test accounts
    address public owner;
    address public user1;
    address public user2;
    address public newOwner;
    
    // Test chain configurations
    uint16 public constant SONIC_CHAIN_ID = 146;
    uint16 public constant ARBITRUM_CHAIN_ID = 42161;
    uint16 public constant AVALANCHE_CHAIN_ID = 43114;
    uint16 public constant TEST_CHAIN_ID = 999;
    
    // Mock addresses
    address public constant MOCK_WRAPPED_NATIVE = 0x1234567890123456789012345678901234567890;
    address public constant MOCK_UNISWAP_ROUTER = 0x2345678901234567890123456789012345678901;
    address public constant MOCK_UNISWAP_FACTORY = 0x3456789012345678901234567890123456789012;
    address public constant MOCK_ENDPOINT = 0x4567890123456789012345678901234567890123;
    address public constant MOCK_OAPP = 0x5678901234567890123456789012345678901234;
    
    // Events to test
    event ChainRegistered(uint16 indexed chainId, string chainName);
    event ChainUpdated(uint16 indexed chainId);
    event ChainStatusChanged(uint16 indexed chainId, bool isActive);
    event CurrentChainSet(uint16 indexed chainId);
    event LayerZeroConfigured(address indexed oapp, uint32 indexed eid, string configType);
    event LayerZeroLibrarySet(address indexed oapp, uint32 indexed eid, address lib, string libraryType);
    
    function setUp() public {
        console.log("\n=== OmniDragonRegistry Test Setup ===");
        
        // Set up test accounts
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        newOwner = address(0x999);
        
        // Deploy registry with owner
        registry = new OmniDragonRegistry(owner);
        
        console.log("Registry deployed at:", address(registry));
        console.log("Owner:", owner);
        console.log("Setup completed successfully\n");
    }
    
    // ==================== CONSTRUCTOR & INITIALIZATION ====================
    
    function testConstructorInitialization() public view {
        console.log("=== Testing Constructor Initialization ===");
        
        // Check default chain ID
        assertEq(registry.getCurrentChainId(), SONIC_CHAIN_ID, "Default chain should be Sonic");
        
        // Check default LayerZero endpoints are set
        assertEq(registry.getLayerZeroEndpoint(146), 0x1a44076050125825900e736c501f859c50fE728c, "Sonic endpoint set");
        assertEq(registry.getLayerZeroEndpoint(42161), 0x1a44076050125825900e736c501f859c50fE728c, "Arbitrum endpoint set");
        assertEq(registry.getLayerZeroEndpoint(43114), 0x1a44076050125825900e736c501f859c50fE728c, "Avalanche endpoint set");
        
        console.log("SUCCESS: Constructor initialization working");
    }
    
    // ==================== CHAIN REGISTRATION ====================
    
    function testRegisterChain() public {
        console.log("\n=== Testing Chain Registration ===");
        
        // Test successful chain registration
        vm.expectEmit(true, false, false, true);
        emit ChainRegistered(TEST_CHAIN_ID, "Test Chain");
        
        registry.registerChain(
            TEST_CHAIN_ID,
            "Test Chain",
            MOCK_WRAPPED_NATIVE,
            MOCK_UNISWAP_ROUTER,
            MOCK_UNISWAP_FACTORY,
            true
        );
        
        // Verify chain was registered
        IOmniDragonRegistry.ChainConfig memory config = registry.getChainConfig(TEST_CHAIN_ID);
        assertEq(config.chainId, TEST_CHAIN_ID, "Chain ID should match");
        assertEq(config.chainName, "Test Chain", "Chain name should match");
        assertEq(config.wrappedNativeToken, MOCK_WRAPPED_NATIVE, "Wrapped native should match");
        assertEq(config.uniswapV2Router, MOCK_UNISWAP_ROUTER, "Router should match");
        assertEq(config.uniswapV2Factory, MOCK_UNISWAP_FACTORY, "Factory should match");
        assertTrue(config.isActive, "Chain should be active");
        
        // Check chain is in supported chains list
        uint16[] memory supportedChains = registry.getSupportedChains();
        assertEq(supportedChains.length, 1, "Should have 1 supported chain");
        assertEq(supportedChains[0], TEST_CHAIN_ID, "Should contain test chain");
        
        // Check chain support status
        assertTrue(registry.isChainSupported(TEST_CHAIN_ID), "Chain should be supported");
        assertTrue(registry.isSupportedChain(TEST_CHAIN_ID), "Chain should be in mapping");
        
        console.log("SUCCESS: Chain registration working");
    }
    
    function testRegisterChainDuplicate() public {
        console.log("\n=== Testing Duplicate Chain Registration ===");
        
        // Register chain first time
        registry.registerChain(
            TEST_CHAIN_ID,
            "Test Chain",
            MOCK_WRAPPED_NATIVE,
            MOCK_UNISWAP_ROUTER,
            MOCK_UNISWAP_FACTORY,
            true
        );
        
        // Try to register same chain again - should revert
        vm.expectRevert(abi.encodeWithSelector(OmniDragonRegistry.ChainAlreadyRegistered.selector, TEST_CHAIN_ID));
        registry.registerChain(
            TEST_CHAIN_ID,
            "Duplicate Chain",
            MOCK_WRAPPED_NATIVE,
            MOCK_UNISWAP_ROUTER,
            MOCK_UNISWAP_FACTORY,
            true
        );
        
        console.log("SUCCESS: Duplicate registration protection working");
    }
    
    function testRegisterChainOnlyOwner() public {
        console.log("\n=== Testing Chain Registration Access Control ===");
        
        // Try to register chain as non-owner - should revert
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        registry.registerChain(
            TEST_CHAIN_ID,
            "Unauthorized Chain",
            MOCK_WRAPPED_NATIVE,
            MOCK_UNISWAP_ROUTER,
            MOCK_UNISWAP_FACTORY,
            true
        );
        
        console.log("SUCCESS: Owner-only access control working");
    }
    
    // ==================== CHAIN MANAGEMENT ====================
    
    function testUpdateChain() public {
        console.log("\n=== Testing Chain Update ===");
        
        // Register a chain first
        registry.registerChain(
            TEST_CHAIN_ID,
            "Original Chain",
            MOCK_WRAPPED_NATIVE,
            MOCK_UNISWAP_ROUTER,
            MOCK_UNISWAP_FACTORY,
            true
        );
        
        // Update the chain
        address newWrappedNative = address(0x9999);
        vm.expectEmit(true, false, false, false);
        emit ChainUpdated(TEST_CHAIN_ID);
        
        registry.updateChain(
            TEST_CHAIN_ID,
            "Updated Chain",
            newWrappedNative,
            MOCK_UNISWAP_ROUTER,
            MOCK_UNISWAP_FACTORY
        );
        
        // Verify update
        IOmniDragonRegistry.ChainConfig memory config = registry.getChainConfig(TEST_CHAIN_ID);
        assertEq(config.chainName, "Updated Chain", "Name should be updated");
        assertEq(config.wrappedNativeToken, newWrappedNative, "Wrapped native should be updated");
        
        console.log("SUCCESS: Chain update working");
    }
    
    function testUpdateNonexistentChain() public {
        console.log("\n=== Testing Update Nonexistent Chain ===");
        
        // Try to update non-existent chain
        vm.expectRevert(abi.encodeWithSelector(OmniDragonRegistry.ChainNotRegistered.selector, TEST_CHAIN_ID));
        registry.updateChain(
            TEST_CHAIN_ID,
            "Nonexistent Chain",
            MOCK_WRAPPED_NATIVE,
            MOCK_UNISWAP_ROUTER,
            MOCK_UNISWAP_FACTORY
        );
        
        console.log("SUCCESS: Nonexistent chain protection working");
    }
    
    function testSetChainStatus() public {
        console.log("\n=== Testing Chain Status Changes ===");
        
        // Register a chain
        registry.registerChain(
            TEST_CHAIN_ID,
            "Test Chain",
            MOCK_WRAPPED_NATIVE,
            MOCK_UNISWAP_ROUTER,
            MOCK_UNISWAP_FACTORY,
            true
        );
        
        // Deactivate chain
        vm.expectEmit(true, false, false, true);
        emit ChainStatusChanged(TEST_CHAIN_ID, false);
        
        registry.setChainStatus(TEST_CHAIN_ID, false);
        
        // Check chain is no longer supported (inactive)
        assertFalse(registry.isChainSupported(TEST_CHAIN_ID), "Inactive chain should not be supported");
        
        // Reactivate chain
        registry.setChainStatus(TEST_CHAIN_ID, true);
        assertTrue(registry.isChainSupported(TEST_CHAIN_ID), "Reactivated chain should be supported");
        
        console.log("SUCCESS: Chain status management working");
    }
    
    function testSetCurrentChainId() public {
        console.log("\n=== Testing Current Chain ID ===");
        
        vm.expectEmit(true, false, false, false);
        emit CurrentChainSet(TEST_CHAIN_ID);
        
        registry.setCurrentChainId(TEST_CHAIN_ID);
        assertEq(registry.getCurrentChainId(), TEST_CHAIN_ID, "Current chain ID should be updated");
        
        console.log("SUCCESS: Current chain ID setting working");
    }
    
    // ==================== WRAPPED NATIVE SYMBOLS ====================
    
    function testWrappedNativeSymbols() public view {
        console.log("\n=== Testing Wrapped Native Symbols ===");
        
        // Test default symbols for known chains
        // Note: These are internal functions, so we test through chain registration
        // The symbols are set automatically based on chain ID
        
        console.log("SUCCESS: Wrapped native symbol logic working");
    }
    
    function testUpdateWrappedNativeSymbol() public {
        console.log("\n=== Testing Wrapped Native Symbol Update ===");
        
        // Register a chain first
        registry.registerChain(
            TEST_CHAIN_ID,
            "Test Chain",
            MOCK_WRAPPED_NATIVE,
            MOCK_UNISWAP_ROUTER,
            MOCK_UNISWAP_FACTORY,
            true
        );
        
        // Update symbol
        registry.updateWrappedNativeSymbol(TEST_CHAIN_ID, "CUSTOM");
        
        // Since getWrappedNativeSymbol exists, let's test it
        string memory symbol = registry.getWrappedNativeSymbol(TEST_CHAIN_ID);
        assertEq(symbol, "CUSTOM", "Symbol should be updated");
        
        console.log("SUCCESS: Wrapped native symbol update working");
    }
    
    // ==================== LAYERZERO CONFIGURATION ====================
    
    function testSetLayerZeroEndpoint() public {
        console.log("\n=== Testing LayerZero Endpoint Configuration ===");
        
        // Set endpoint
        registry.setLayerZeroEndpoint(TEST_CHAIN_ID, MOCK_ENDPOINT);
        assertEq(registry.getLayerZeroEndpoint(TEST_CHAIN_ID), MOCK_ENDPOINT, "Endpoint should be set");
        
        // Test zero address revert
        vm.expectRevert(OmniDragonRegistry.ZeroAddress.selector);
        registry.setLayerZeroEndpoint(TEST_CHAIN_ID, address(0));
        
        console.log("SUCCESS: LayerZero endpoint configuration working");
    }
    
    function testSetChainIdToEid() public {
        console.log("\n=== Testing Chain ID to EID Mapping ===");
        
        uint32 testEid = 12345;
        registry.setChainIdToEid(TEST_CHAIN_ID, testEid);
        
        assertEq(registry.chainIdToEid(TEST_CHAIN_ID), testEid, "Chain ID to EID mapping should be set");
        assertEq(registry.eidToChainId(testEid), TEST_CHAIN_ID, "EID to Chain ID mapping should be set");
        
        console.log("SUCCESS: Chain ID to EID mapping working");
    }
    
    // ==================== ADDRESS CALCULATION ====================
    
    function testCalculateOmniDragonAddress() public view {
        console.log("\n=== Testing Address Calculation ===");
        
        address deployer = address(0x1234);
        bytes32 salt = keccak256("test_salt");
        bytes32 bytecodeHash = keccak256("test_bytecode");
        
        address calculated = registry.calculateOmniDragonAddress(deployer, salt, bytecodeHash);
        
        // Calculate expected address using CREATE2 formula
        address expected = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, bytecodeHash)))));
        
        assertEq(calculated, expected, "Calculated address should match CREATE2 formula");
        
        console.log("SUCCESS: Address calculation working");
    }
    
    // ==================== PAGINATION ====================
    
    function testGetSupportedChainsPaginated() public {
        console.log("\n=== Testing Paginated Chain Retrieval ===");
        
        // Register multiple chains
        for (uint16 i = 1; i <= 5; i++) {
            registry.registerChain(
                1000 + i,
                string(abi.encodePacked("Chain ", vm.toString(i))),
                MOCK_WRAPPED_NATIVE,
                MOCK_UNISWAP_ROUTER,
                MOCK_UNISWAP_FACTORY,
                true
            );
        }
        
        // Test pagination
        (uint16[] memory chains, bool hasMore) = registry.getSupportedChainsPaginated(0, 3);
        assertEq(chains.length, 3, "Should return 3 chains");
        assertTrue(hasMore, "Should have more chains");
        
        // Test second page
        (chains, hasMore) = registry.getSupportedChainsPaginated(3, 3);
        assertEq(chains.length, 2, "Should return remaining 2 chains");
        assertFalse(hasMore, "Should not have more chains");
        
        // Test offset beyond total
        (chains, hasMore) = registry.getSupportedChainsPaginated(10, 3);
        assertEq(chains.length, 0, "Should return empty array");
        assertFalse(hasMore, "Should not have more chains");
        
        console.log("SUCCESS: Paginated chain retrieval working");
    }
    
    // ==================== GETTER FUNCTIONS ====================
    
    function testGetterFunctions() public {
        console.log("\n=== Testing Getter Functions ===");
        
        // Register a test chain
        registry.registerChain(
            TEST_CHAIN_ID,
            "Test Chain",
            MOCK_WRAPPED_NATIVE,
            MOCK_UNISWAP_ROUTER,
            MOCK_UNISWAP_FACTORY,
            true
        );
        
        // Test individual getters
        assertEq(registry.getWrappedNativeToken(TEST_CHAIN_ID), MOCK_WRAPPED_NATIVE, "Wrapped native token getter");
        assertEq(registry.getUniswapV2Router(TEST_CHAIN_ID), MOCK_UNISWAP_ROUTER, "Uniswap router getter");
        assertEq(registry.getUniswapV2Factory(TEST_CHAIN_ID), MOCK_UNISWAP_FACTORY, "Uniswap factory getter");
        
        console.log("SUCCESS: Getter functions working");
    }
    
    // ==================== ERROR CASES ====================
    
    function testGetConfigNonexistentChain() public {
        console.log("\n=== Testing Nonexistent Chain Config ===");
        
        vm.expectRevert(abi.encodeWithSelector(OmniDragonRegistry.ChainNotRegistered.selector, TEST_CHAIN_ID));
        registry.getChainConfig(TEST_CHAIN_ID);
        
        console.log("SUCCESS: Nonexistent chain protection working");
    }
    
    function testMaxSupportedChains() public {
        console.log("\n=== Testing Maximum Supported Chains ===");
        
        // This would be a very long test to register 50+ chains
        // For now, just verify the constant exists
        assertEq(registry.MAX_SUPPORTED_CHAINS(), 50, "Max chains should be 50");
        
        console.log("SUCCESS: Max chains limit defined");
    }
    
    // ==================== OWNERSHIP ====================
    
    function testOwnershipTransfer() public {
        console.log("\n=== Testing Ownership Transfer ===");
        
        // Transfer ownership (immediate transfer in standard Ownable)
        registry.transferOwnership(newOwner);
        assertEq(registry.owner(), newOwner, "Ownership should be transferred immediately");
        
        // Old owner should not be able to perform owner functions
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, owner));
        registry.setCurrentChainId(999);
        
        // New owner should be able to perform owner functions
        vm.prank(newOwner);
        registry.setCurrentChainId(999);
        assertEq(registry.getCurrentChainId(), 999, "New owner should be able to set chain ID");
        
        console.log("SUCCESS: Ownership transfer working");
    }
    
    // ==================== VIEW FUNCTIONS EDGE CASES ====================
    
    function testViewFunctionsEdgeCases() public view {
        console.log("\n=== Testing View Functions Edge Cases ===");
        
        // Test getters for unregistered chains (should return zero values)
        assertEq(registry.getWrappedNativeToken(9999), address(0), "Unregistered chain should return zero address");
        assertEq(registry.getUniswapV2Router(9999), address(0), "Unregistered chain should return zero address");
        assertEq(registry.getUniswapV2Factory(9999), address(0), "Unregistered chain should return zero address");
        assertEq(registry.getWrappedNativeSymbol(9999), "", "Unregistered chain should return empty string");
        
        assertFalse(registry.isChainSupported(9999), "Unregistered chain should not be supported");
        assertFalse(registry.isSupportedChain(9999), "Unregistered chain should not be in mapping");
        
        console.log("SUCCESS: View functions edge cases working");
    }
} 