// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/core/vrf/ChainlinkVRFIntegratorV2_5.sol";
import "../contracts/core/config/OmniDragonRegistry.sol";

// Mock LayerZero Endpoint for tests
contract MockLayerZeroEndpoint {
    function send(
        uint32 /* _dstEid */,
        bytes32 /* _receiver */,
        bytes calldata /* _message */,
        bytes calldata /* _options */,
        address /* _refundAddress */
    ) external payable returns (uint64 /* nonce */, uint256 /* fee */) {
        return (1, msg.value);
    }
    
    function quote(
        uint32 /* _dstEid */,
        bytes32 /* _receiver */,
        bytes calldata /* _message */,
        bytes calldata /* _options */,
        bool /* _payInLzToken */
    ) external pure returns (uint256 /* fee */) {
        return 0.001 ether;
    }
    
    function oAppVersion() external pure returns (uint64, uint64) {
        return (1, 1);
    }
    
    function defaultReceiveLibrary(uint32 /* _eid */) external pure returns (address) {
        return address(0);
    }
    
    function defaultSendLibrary(uint32 /* _eid */) external pure returns (address) {
        return address(0);
    }
    
    function isSupportedEid(uint32 /* _eid */) external pure returns (bool) {
        return true;
    }
    
    function setDelegate(address /* _delegate */) external {}
}

// ============ VRF INTEGRATOR TESTS USING REGISTRY ============

contract ChainlinkVRFIntegratorV2_5Test is Test {
    ChainlinkVRFIntegratorV2_5 public vrfIntegrator;
    OmniDragonRegistry public registry;
    MockLayerZeroEndpoint public mockEndpoint;
    
    address public owner = address(0x1234567890123456789012345678901234567890);
    address public user = address(0x2345678901234567890123456789012345678901);
    
    uint32 public constant ARBITRUM_EID = 30110;
    uint16 public constant SONIC_CHAIN_ID = 146;
    
    event GasLimitUpdated(uint32 oldLimit, uint32 newLimit);
    event RequestExpired(uint64 indexed sequence, address indexed provider);
    
    function setUp() public {
        // Give owner some ETH for gas
        vm.deal(owner, 100 ether);
        
        vm.startPrank(owner);
        
        // Deploy mock endpoint first
        mockEndpoint = new MockLayerZeroEndpoint();
        
        // Deploy registry
        registry = new OmniDragonRegistry(owner);
        
        // Deploy VRF integrator with mock endpoint directly (bypass registry's hardcoded endpoint)
        vrfIntegrator = new ChainlinkVRFIntegratorV2_5(address(mockEndpoint), owner);
        
        vm.stopPrank();
    }
    
    function testDeployment() public view {
        // Test basic deployment properties
        assertEq(vrfIntegrator.owner(), owner);
        assertEq(vrfIntegrator.requestCounter(), 0);
        assertEq(vrfIntegrator.defaultGasLimit(), 690420);
        assertEq(vrfIntegrator.requestTimeout(), 1 hours);
    }
    
    function testSetDefaultGasLimit() public {
        uint32 newGasLimit = 1000000;
        
        vm.expectEmit(true, true, false, true);
        emit GasLimitUpdated(690420, newGasLimit);
        
        vm.prank(owner);
        vrfIntegrator.setDefaultGasLimit(newGasLimit);
        
        assertEq(vrfIntegrator.defaultGasLimit(), newGasLimit);
    }
    
    function testSetRequestTimeout() public {
        uint256 newTimeout = 2 hours;
        
        vm.prank(owner);
        vrfIntegrator.setRequestTimeout(newTimeout);
        
        assertEq(vrfIntegrator.requestTimeout(), newTimeout);
    }
    
    function testGetRandomWordForNonExistentRequest() public view {
        // Test with non-existent request
        (uint256 randomWord, bool fulfilled) = vrfIntegrator.getRandomWord(999);
        assertEq(randomWord, 0);
        assertFalse(fulfilled);
    }
    
    function testCheckRequestStatusForNonExistentRequest() public view {
        // Test with non-existent request
        (bool fulfilled, bool exists, address provider, uint256 randomWord, uint256 timestamp, bool expired) = 
            vrfIntegrator.checkRequestStatus(999);
        
        assertFalse(fulfilled);
        assertFalse(exists);
        assertEq(provider, address(0));
        assertEq(randomWord, 0);
        assertEq(timestamp, 0);
        assertFalse(expired);
    }
    
    function testWithdrawWhenEmpty() public {
        // Test withdraw when contract has no balance - should not revert even with 0 balance
        uint256 contractBalanceBefore = address(vrfIntegrator).balance;
        
        vm.prank(owner);
        vrfIntegrator.withdraw();
        
        // Contract balance should still be 0
        assertEq(address(vrfIntegrator).balance, 0);
        assertEq(contractBalanceBefore, 0);
    }
    
    function testWithdrawWithBalance() public {
        // Fund the contract
        vm.deal(address(vrfIntegrator), 1 ether);
        
        uint256 contractBalanceBefore = address(vrfIntegrator).balance;
        uint256 ownerBalanceBefore = owner.balance;
        
        vm.prank(owner);
        vrfIntegrator.withdraw();
        
        // Contract should be empty, owner should have received the funds
        assertEq(address(vrfIntegrator).balance, 0);
        assertTrue(owner.balance > ownerBalanceBefore); // Account for gas costs
        assertEq(contractBalanceBefore, 1 ether);
    }
    
    function testOnlyOwnerFunctions() public {
        vm.startPrank(user);
        
        vm.expectRevert();
        vrfIntegrator.setDefaultGasLimit(1000000);
        
        vm.expectRevert();
        vrfIntegrator.setRequestTimeout(2 hours);
        
        vm.expectRevert();
        vrfIntegrator.withdraw();
        
        vm.stopPrank();
    }
    
    function testReceiveETH() public {
        vm.deal(user, 1 ether);
        
        uint256 contractBalanceBefore = address(vrfIntegrator).balance;
        
        vm.prank(user);
        (bool success,) = address(vrfIntegrator).call{value: 0.5 ether}("");
        assertTrue(success);
        
        assertEq(address(vrfIntegrator).balance, contractBalanceBefore + 0.5 ether);
    }
    
    function testCleanupEmptyExpiredRequests() public {
        // Test cleanup with empty array
        uint64[] memory emptyIds = new uint64[](0);
        
        // Should not revert
        vrfIntegrator.cleanupExpiredRequests(emptyIds);
    }
    
    function testRegisterMeSucceeds() public {
        // In test environment, calls to non-existent addresses return success=true
        // So registerMe() will succeed and emit the event
        vm.expectEmit(true, true, false, true);
        emit FeeMRegistered(address(vrfIntegrator), 143);
        
        vrfIntegrator.registerMe();
    }
    
    event FeeMRegistered(address indexed contractAddress, uint256 indexed feeId);
    
    function testConstants() public view {
        // Test that constants are set correctly
        // These are internal to the test to verify the contract setup
        assertTrue(address(vrfIntegrator) != address(0));
        assertTrue(vrfIntegrator.requestTimeout() > 0);
        assertTrue(vrfIntegrator.defaultGasLimit() > 0);
    }
}