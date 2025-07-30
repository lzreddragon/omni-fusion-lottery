// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/core/vrf/OmniDragonVRFConsumerV2_5.sol";
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

// ============ VRF CONSUMER TESTS USING REGISTRY ============

contract OmniDragonVRFConsumerV2_5Test is Test {
    OmniDragonVRFConsumerV2_5 public vrfConsumer;
    OmniDragonRegistry public registry;
    MockLayerZeroEndpoint public mockEndpoint;
    
    address public owner = address(0x1234567890123456789012345678901234567890);
    address public user = address(0x2345678901234567890123456789012345678901);
    address public mockVRFCoordinator = address(0x4567890123456789012345678901234567890123);
    
    uint32 public constant SONIC_EID = 30332;
    uint32 public constant ETHEREUM_EID = 30101;
    uint32 public constant ARBITRUM_EID = 30110;
    uint16 public constant ARBITRUM_CHAIN_ID = 42161;
    uint256 public constant SUBSCRIPTION_ID = 123;
    bytes32 public constant KEY_HASH = keccak256("test_key_hash");
    
    event LocalCallerAuthorized(address indexed caller, bool authorized);
    event VRFConfigUpdated(uint256 subscriptionId, bytes32 keyHash, uint32 callbackGasLimit, uint16 requestConfirmations);
    event MinimumBalanceUpdated(uint256 oldBalance, uint256 newBalance);
    event ChainSupportUpdated(uint32 chainEid, bool supported, uint32 gasLimit);
    event ContractFunded(address indexed funder, uint256 amount, uint256 newBalance);
    
    function setUp() public {
        // Give owner some ETH for gas
        vm.deal(owner, 100 ether);
        
        vm.startPrank(owner);
        
        // Deploy mock endpoint first
        mockEndpoint = new MockLayerZeroEndpoint();
        
        // Deploy registry
        registry = new OmniDragonRegistry(owner);
        
        // Deploy VRF consumer with mock endpoint directly (bypass registry's hardcoded endpoint)
        vrfConsumer = new OmniDragonVRFConsumerV2_5(
            address(mockEndpoint),
            owner,
            mockVRFCoordinator,
            SUBSCRIPTION_ID,
            KEY_HASH
        );
        
        vm.stopPrank();
    }
    
    function testDeployment() public view {
        // Test basic deployment properties
        assertEq(vrfConsumer.owner(), owner);
        assertEq(address(vrfConsumer.vrfCoordinator()), mockVRFCoordinator);
        assertEq(vrfConsumer.subscriptionId(), SUBSCRIPTION_ID);
        assertEq(vrfConsumer.keyHash(), KEY_HASH);
        assertEq(vrfConsumer.callbackGasLimit(), 2500000);
        assertEq(vrfConsumer.requestConfirmations(), 3);
        assertEq(vrfConsumer.numWords(), 1);
        assertFalse(vrfConsumer.nativePayment());
        
        // Test supported chains
        assertTrue(vrfConsumer.supportedChains(SONIC_EID));
        assertTrue(vrfConsumer.supportedChains(ETHEREUM_EID));
        
        // Test owner is authorized for local requests
        assertTrue(vrfConsumer.authorizedLocalCallers(owner));
    }
    
    function testSetLocalCallerAuthorization() public {
        vm.expectEmit(true, true, false, true);
        emit LocalCallerAuthorized(user, true);
        
        vm.prank(owner);
        vrfConsumer.setLocalCallerAuthorization(user, true);
        
        assertTrue(vrfConsumer.authorizedLocalCallers(user));
        
        // Test deauthorization
        vm.expectEmit(true, true, false, true);
        emit LocalCallerAuthorized(user, false);
        
        vm.prank(owner);
        vrfConsumer.setLocalCallerAuthorization(user, false);
        
        assertFalse(vrfConsumer.authorizedLocalCallers(user));
    }
    
    function testGetUserLocalRequestsEmpty() public view {
        uint256[] memory userRequests = vrfConsumer.getUserLocalRequests(user);
        assertEq(userRequests.length, 0);
    }
    
    function testGetRequestStats() public view {
        (uint256 totalLocalRequests, uint256 totalCrossChainRequests) = vrfConsumer.getRequestStats();
        assertEq(totalLocalRequests, 0);
        assertEq(totalCrossChainRequests, 0);
    }
    
    function testSetSupportedChain() public {
        uint32 newChainEid = 999;
        uint32 gasLimit = 3000000;
        
        vm.expectEmit(true, true, false, true);
        emit ChainSupportUpdated(newChainEid, true, gasLimit);
        
        vm.prank(owner);
        vrfConsumer.setSupportedChain(newChainEid, true, gasLimit);
        
        assertTrue(vrfConsumer.supportedChains(newChainEid));
        assertEq(vrfConsumer.chainGasLimits(newChainEid), gasLimit);
    }
    
    function testAddNewChain() public {
        uint32 newChainEid = 888;
        string memory chainName = "TestChain";
        uint32 gasLimit = 4000000;
        
        vm.prank(owner);
        vrfConsumer.addNewChain(newChainEid, chainName, gasLimit);
        
        assertTrue(vrfConsumer.supportedChains(newChainEid));
        assertEq(vrfConsumer.chainNames(newChainEid), chainName);
        assertEq(vrfConsumer.chainGasLimits(newChainEid), gasLimit);
    }
    
    function testGetSupportedChains() public view {
        (uint32[] memory eids, bool[] memory supported, uint32[] memory gasLimits) = 
            vrfConsumer.getSupportedChains();
        
        assertTrue(eids.length > 0);
        assertEq(eids.length, supported.length);
        assertEq(eids.length, gasLimits.length);
        
        // Check that Sonic is in the list and supported
        bool sonicFound = false;
        for (uint i = 0; i < eids.length; i++) {
            if (eids[i] == SONIC_EID) {
                sonicFound = true;
                assertTrue(supported[i]);
                break;
            }
        }
        assertTrue(sonicFound);
    }
    
    function testSetVRFConfig() public {
        uint256 newSubscriptionId = 456;
        bytes32 newKeyHash = keccak256("new_key_hash");
        uint32 newCallbackGasLimit = 2000000;
        uint16 newRequestConfirmations = 5;
        bool newNativePayment = true;
        
        vm.expectEmit(true, true, true, true);
        emit VRFConfigUpdated(newSubscriptionId, newKeyHash, newCallbackGasLimit, newRequestConfirmations);
        
        vm.prank(owner);
        vrfConsumer.setVRFConfig(
            newSubscriptionId,
            newKeyHash,
            newCallbackGasLimit,
            newRequestConfirmations,
            newNativePayment
        );
        
        assertEq(vrfConsumer.subscriptionId(), newSubscriptionId);
        assertEq(vrfConsumer.keyHash(), newKeyHash);
        assertEq(vrfConsumer.callbackGasLimit(), newCallbackGasLimit);
        assertEq(vrfConsumer.requestConfirmations(), newRequestConfirmations);
        assertEq(vrfConsumer.nativePayment(), newNativePayment);
    }
    
    function testSetVRFConfigInvalidParams() public {
        vm.startPrank(owner);
        
        // Invalid subscription ID
        vm.expectRevert("Invalid subscription ID");
        vrfConsumer.setVRFConfig(0, KEY_HASH, 2000000, 5, false);
        
        // Invalid key hash
        vm.expectRevert("Invalid key hash");
        vrfConsumer.setVRFConfig(456, bytes32(0), 2000000, 5, false);
        
        // Invalid callback gas limit (too low)
        vm.expectRevert("Invalid callback gas limit");
        vrfConsumer.setVRFConfig(456, KEY_HASH, 30000, 5, false);
        
        // Invalid callback gas limit (too high)
        vm.expectRevert("Invalid callback gas limit");
        vrfConsumer.setVRFConfig(456, KEY_HASH, 3000000, 5, false);
        
        // Invalid request confirmations (too low)
        vm.expectRevert("Invalid request confirmations");
        vrfConsumer.setVRFConfig(456, KEY_HASH, 2000000, 2, false);
        
        // Invalid request confirmations (too high)
        vm.expectRevert("Invalid request confirmations");
        vrfConsumer.setVRFConfig(456, KEY_HASH, 2000000, 250, false);
        
        vm.stopPrank();
    }
    
    function testSetMinimumBalance() public {
        uint256 newMinimumBalance = 0.01 ether;
        
        vm.expectEmit(true, true, false, true);
        emit MinimumBalanceUpdated(0.005 ether, newMinimumBalance);
        
        vm.prank(owner);
        vrfConsumer.setMinimumBalance(newMinimumBalance);
        
        assertEq(vrfConsumer.minimumBalance(), newMinimumBalance);
    }
    
    function testSetMinimumBalanceTooHigh() public {
        vm.expectRevert("Minimum balance too high");
        vm.prank(owner);
        vrfConsumer.setMinimumBalance(2 ether);
    }
    
    function testSetDefaultGasLimit() public {
        uint32 newGasLimit = 3500000;
        
        vm.prank(owner);
        vrfConsumer.setDefaultGasLimit(newGasLimit);
        
        assertEq(vrfConsumer.defaultGasLimit(), newGasLimit);
    }
    
    function testSetDefaultGasLimitInvalid() public {
        vm.startPrank(owner);
        
        // Too low
        vm.expectRevert("Invalid gas limit");
        vrfConsumer.setDefaultGasLimit(50000);
        
        // Too high
        vm.expectRevert("Invalid gas limit");
        vrfConsumer.setDefaultGasLimit(15000000);
        
        vm.stopPrank();
    }
    
    function testFundContract() public {
        uint256 fundAmount = 5 ether;
        
        vm.deal(user, fundAmount);
        
        vm.expectEmit(true, true, false, true);
        emit ContractFunded(user, fundAmount, fundAmount);
        
        vm.prank(user);
        vrfConsumer.fundContract{value: fundAmount}();
        
        assertEq(address(vrfConsumer).balance, fundAmount);
    }
    
    function testFundContractZeroAmount() public {
        vm.expectRevert("Must send ETH to fund contract");
        vm.prank(user);
        vrfConsumer.fundContract{value: 0}();
    }
    
    function testGetContractStatus() public {
        // Fund contract first
        vm.deal(address(vrfConsumer), 10 ether);
        
        (uint256 balance, uint256 minBalance, bool canSendResponses, uint32 gasLimit, uint256 supportedChainsCount) = 
            vrfConsumer.getContractStatus();
        
        assertEq(balance, 10 ether);
        assertEq(minBalance, 0.005 ether);
        assertTrue(canSendResponses);
        assertEq(gasLimit, 2500000);
        assertTrue(supportedChainsCount > 0);
    }
    
    function testWithdraw() public {
        // Fund contract first
        vm.deal(address(vrfConsumer), 5 ether);
        
        uint256 ownerBalanceBefore = owner.balance;
        
        vm.prank(owner);
        vrfConsumer.withdraw();
        
        assertEq(address(vrfConsumer).balance, 0);
        // Account for gas costs
        assertTrue(owner.balance >= ownerBalanceBefore + 5 ether - 0.01 ether);
    }
    
    function testWithdrawNoBalance() public {
        vm.expectRevert("No balance to withdraw");
        vm.prank(owner);
        vrfConsumer.withdraw();
    }
    
    function testReceiveETH() public {
        vm.deal(user, 1 ether);
        
        uint256 contractBalanceBefore = address(vrfConsumer).balance;
        
        vm.prank(user);
        (bool success,) = address(vrfConsumer).call{value: 0.3 ether}("");
        assertTrue(success);
        
        assertEq(address(vrfConsumer).balance, contractBalanceBefore + 0.3 ether);
    }
    
    function testOnlyOwnerFunctions() public {
        vm.startPrank(user);
        
        vm.expectRevert();
        vrfConsumer.setLocalCallerAuthorization(user, true);
        
        vm.expectRevert();
        vrfConsumer.setSupportedChain(999, true, 1000000);
        
        vm.expectRevert();
        vrfConsumer.setVRFConfig(456, keccak256("test"), 1000000, 5, true);
        
        vm.expectRevert();
        vrfConsumer.withdraw();
        
        vm.stopPrank();
    }
    
    function testGetRequestBySequenceNonExistent() public view {
        (uint256 requestId, bool exists, bool fulfilled, bool responseSent, uint256 randomWord, uint32 sourceChainEid, uint256 timestamp) = 
            vrfConsumer.getRequestBySequence(999);
        
        assertEq(requestId, 0);
        assertFalse(exists);
        assertFalse(fulfilled);
        assertFalse(responseSent);
        assertEq(randomWord, 0);
        assertEq(sourceChainEid, 0);
        assertEq(timestamp, 0);
    }
    
    function testGetRequestByIdNonExistent() public view {
        (uint64 sequence, bool exists, bool fulfilled, bool responseSent, uint256 randomWord, uint32 sourceChainEid, uint256 timestamp) = 
            vrfConsumer.getRequestById(999);
        
        assertEq(sequence, 0);
        assertFalse(exists);
        assertFalse(fulfilled);
        assertFalse(responseSent);
        assertEq(randomWord, 0);
        assertEq(sourceChainEid, 0);
        assertEq(timestamp, 0);
    }
}