// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/core/lottery/OmniDragonLotteryManager.sol";

// ============ MOCK CONTRACTS ============

contract MockJackpotDistributor {
    uint256 public currentJackpot = 10000 * 1e18; // 10k DRAGON
    bool public shouldFail = false;
    
    event JackpotDistributed(address winner, uint256 amount);
    
    function getCurrentJackpot() external view returns (uint256) {
        return currentJackpot;
    }
    
    function distributeJackpot(address winner, uint256 amount) external {
        if (shouldFail) {
            revert("Distribution failed");
        }
        emit JackpotDistributed(winner, amount);
    }
    
    function setCurrentJackpot(uint256 amount) external {
        currentJackpot = amount;
    }
    
    function setShouldFail(bool _shouldFail) external {
        shouldFail = _shouldFail;
    }
}

contract MockJackpotVault {
    uint256 public jackpotBalance = 5000 * 1e18;
    bool public shouldFail = false;
    
    event JackpotPaid(address winner, uint256 amount);
    
    function getJackpotBalance() external view returns (uint256) {
        return jackpotBalance;
    }
    
    function payJackpot(address winner, uint256 amount) external {
        if (shouldFail) {
            revert("Vault payment failed");
        }
        emit JackpotPaid(winner, amount);
    }
    
    function getLastWinTime() external view returns (uint256) {
        return block.timestamp - 1 hours;
    }
    
    function setJackpotBalance(uint256 amount) external {
        jackpotBalance = amount;
    }
    
    function setShouldFail(bool _shouldFail) external {
        shouldFail = _shouldFail;
    }
}

contract MockVeDRAGONToken {
    mapping(address => uint256) public balances;
    uint256 public totalSupply = 1000000 * 1e18;
    
    function balanceOf(address user) external view returns (uint256) {
        return balances[user];
    }
    
    function setBalance(address user, uint256 amount) external {
        balances[user] = amount;
    }
    
    function setTotalSupply(uint256 amount) external {
        totalSupply = amount;
    }
}

contract MockRedDRAGONToken {
    mapping(address => uint256) public balances;
    uint256 public totalSupply = 5000000 * 1e18;
    
    function balanceOf(address user) external view returns (uint256) {
        return balances[user];
    }
    
    function setBalance(address user, uint256 amount) external {
        balances[user] = amount;
    }
    
    function setTotalSupply(uint256 amount) external {
        totalSupply = amount;
    }
}

contract MockPriceOracle {
    int256 public price = 250000000; // $2.50 in 8 decimals
    bool public success = true;
    uint256 public timestamp = block.timestamp;
    
    function getAggregatedPrice() external view returns (int256, bool, uint256) {
        return (price, success, timestamp);
    }
    
    function getNativeTokenPrice() external view returns (int256, bool, uint256) {
        return (300000000000, success, timestamp); // $3000 SONIC price in 8 decimals
    }
    
    function setPrice(int256 _price) external {
        price = _price;
        timestamp = block.timestamp;
    }
    
    function setSuccess(bool _success) external {
        success = _success;
    }
}

contract MockVRFIntegrator {
    uint64 public nextSequence = 1;
    mapping(uint64 => bool) public pendingRequests;
    
    event RandomnessRequested(uint64 sequence);
    
    function requestRandomWordsSimple(uint32) external returns (
        MessagingReceipt memory receipt,
        uint64 sequence
    ) {
        sequence = nextSequence++;
        pendingRequests[sequence] = true;
        emit RandomnessRequested(sequence);
        
        // Return mock receipt
        receipt = MessagingReceipt({
            guid: bytes32(uint256(sequence)),
            nonce: sequence,
            fee: MessagingFee({
                nativeFee: 0.001 ether,
                lzTokenFee: 0
            })
        });
    }
    
    function fulfillRandomness(address lotteryManager, uint64 sequence, uint256 randomness) external {
        require(pendingRequests[sequence], "Invalid sequence");
        pendingRequests[sequence] = false;
        
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomness;
        
        // This function is now just for tracking - actual VRF calls are done directly in tests
        // to avoid reentrancy issues
    }
    
    function setAuthorizedCaller(address, bool) external pure {
        // Mock function - always succeeds
    }
}

contract MockLocalVRFConsumer {
    uint256 public nextRequestId = 1;
    mapping(uint256 => bool) public pendingRequests;
    
    event LocalRandomnessRequested(uint256 requestId);
    
    function requestRandomWordsLocal() external returns (uint256 requestId) {
        requestId = nextRequestId++;
        pendingRequests[requestId] = true;
        emit LocalRandomnessRequested(requestId);
    }
    
    function fulfillRandomness(address lotteryManager, uint256 requestId, uint256 randomness) external {
        require(pendingRequests[requestId], "Invalid request ID");
        pendingRequests[requestId] = false;
        
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomness;
        
        // This function is now just for tracking - actual VRF calls are done directly in tests
        // to avoid reentrancy issues
    }
    
    function setLocalCallerAuthorization(address, bool) external pure {
        // Mock function - always succeeds
    }
}

/**
 * @title OmniDragonLotteryManager Test Suite
 * @dev Comprehensive tests for lottery mechanics, VRF integration, and veDRAGON boosts
 */
contract OmniDragonLotteryManagerTest is Test {
    OmniDragonLotteryManager public lotteryManager;
    MockJackpotDistributor public mockDistributor;
    MockJackpotVault public mockVault;
    MockVeDRAGONToken public mockVeDRAGON;
    MockRedDRAGONToken public mockRedDRAGON;
    MockPriceOracle public mockOracle;
    MockVRFIntegrator public mockVRFIntegrator;
    MockLocalVRFConsumer public mockLocalVRF;
    
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public swapContract = address(0x4);
    
    uint256 public constant CHAIN_ID = 146; // Sonic
    
    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy mock contracts
        mockDistributor = new MockJackpotDistributor();
        mockVault = new MockJackpotVault();
        mockVeDRAGON = new MockVeDRAGONToken();
        mockRedDRAGON = new MockRedDRAGONToken();
        mockOracle = new MockPriceOracle();
        mockVRFIntegrator = new MockVRFIntegrator();
        mockLocalVRF = new MockLocalVRFConsumer();
        
        console.log("Mock contracts deployed");
        
        // Deploy lottery manager
        lotteryManager = new OmniDragonLotteryManager(
            address(mockDistributor),
            address(mockVeDRAGON),
            address(mockOracle),
            CHAIN_ID
        );
        
        console.log("Lottery manager deployed at:", address(lotteryManager));
        
        // Configure lottery manager
        lotteryManager.setJackpotVault(address(mockVault));
        lotteryManager.setRedDRAGONToken(address(mockRedDRAGON));
        lotteryManager.setVRFIntegrator(address(mockVRFIntegrator));
        lotteryManager.setLocalVRFConsumer(address(mockLocalVRF));
        lotteryManager.setAuthorizedSwapContract(swapContract, true);
        
        // Configure instant lottery
        lotteryManager.configureInstantLottery(
            40, // 40 PPM base win probability
            10e6, // $10 minimum
            6900, // 69% of jackpot as reward
            true, // active
            true // use VRF
        );
        
        console.log("Lottery manager configured");
        
        vm.stopPrank();
        
        // Fund test accounts
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        
        console.log("Setup completed successfully");
    }
    
    function testBasicLotteryEntry() public {
        console.log("\n=== Testing Basic Lottery Entry ===");
        
        // Advance time to avoid rate limiting (7+ seconds)
        vm.warp(block.timestamp + 10);
        
        uint256 dragonAmount = 1000 * 1e18; // 1000 DRAGON tokens
        
        // Mock price: $2.50 per DRAGON = $2500 USD swap
        mockOracle.setPrice(250000000); // $2.50 in 8 decimals
        
        vm.startPrank(swapContract);
        
        // Record initial state
        (uint256 initialSwaps,,,, uint256 initialLastSwap) = lotteryManager.getUserStats(user1);
        
        // Process lottery entry
        lotteryManager.processEntry(user1, dragonAmount);
        
        vm.stopPrank();
        
        // Complete the VRF callback in separate transaction
        uint256 requestId = mockLocalVRF.nextRequestId() - 1;
        
        vm.startPrank(address(mockLocalVRF));
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 500000; // Non-winning number
        lotteryManager.receiveRandomWords(requestId, randomWords);
        vm.stopPrank();
        
        // Check user stats updated
        (uint256 finalSwaps, uint256 totalVolume,,, uint256 finalLastSwap) = lotteryManager.getUserStats(user1);
        
        assertEq(finalSwaps, initialSwaps + 1, "Swap count should increase");
        assertEq(totalVolume, 2500 * 1e6, "Volume should be $2500 in 6 decimals");
        assertGt(finalLastSwap, initialLastSwap, "Last swap time should update");
        
        console.log("SUCCESS: Basic lottery entry processed");
        console.log("Total volume:", totalVolume);
        console.log("Swap count:", finalSwaps);
    }
    
    function testWinProbabilityCalculation() public {
        console.log("\n=== Testing Win Probability Calculation ===");
        
        // Test different swap amounts and expected probabilities
        uint256[5] memory swapAmounts = [uint256(10e6), 100e6, 1000e6, 5000e6, 15000e6]; // $10, $100, $1k, $5k, $15k
        uint256[5] memory expectedBaseProbabilities = [uint256(40), 400, 4000, 20000, 40000]; // PPM values
        
        for (uint256 i = 0; i < swapAmounts.length; i++) {
            (uint256 baseProbability, uint256 boostedProbability) = lotteryManager.calculateWinProbability(
                user1, 
                swapAmounts[i]
            );
            
            console.log("Swap amount:", swapAmounts[i]);
            console.log("Base probability (PPM):", baseProbability);
            console.log("Expected:", expectedBaseProbabilities[i]);
            
            // Allow small rounding differences
            assertApproxEqRel(baseProbability, expectedBaseProbabilities[i], 0.01e18, "Base probability calculation incorrect");
            
            // With no veDRAGON tokens, boosted should equal base
            assertEq(boostedProbability, baseProbability, "Boosted probability should equal base with no tokens");
        }
        
        console.log("SUCCESS: Win probability calculations correct");
    }
    
    function testVeDRAGONBoost() public {
        console.log("\n=== Testing veDRAGON Boost Mechanics ===");
        
        uint256 swapAmount = 1000e6; // $1000 swap
        
        // Give user1 some veDRAGON and redDRAGON tokens (10% of total supply)
        mockVeDRAGON.setBalance(user1, 100000 * 1e18); // 10% of 1M total
        mockRedDRAGON.setBalance(user1, 500000 * 1e18); // 10% of 5M total
        
        (uint256 baseProbability, uint256 boostedProbability) = lotteryManager.calculateWinProbability(
            user1, 
            swapAmount
        );
        
        console.log("Base probability (PPM):", baseProbability);
        console.log("Boosted probability (PPM):", boostedProbability);
        
        // User should get boost (10% of tokens = significant boost)
        assertGt(boostedProbability, baseProbability, "Boosted probability should be higher than base");
        
        // Boost should not exceed maximum (100,000 PPM = 10%)
        assertLe(boostedProbability, 100000, "Boosted probability should not exceed maximum");
        
        console.log("SUCCESS: veDRAGON boost working correctly");
    }
    
    function testVRFLotteryFlow() public {
        console.log("\n=== Testing VRF Lottery Flow ===");
        
        // Advance time to avoid rate limiting
        vm.warp(block.timestamp + 10);
        
        uint256 dragonAmount = 4000 * 1e18; // 4000 DRAGON = $10k at $2.50
        mockOracle.setPrice(250000000); // $2.50 per DRAGON
        
        vm.startPrank(swapContract);
        
        // Process lottery entry - should trigger LocalVRF request (primary)
        lotteryManager.processEntry(user1, dragonAmount);
        
        vm.stopPrank();
        
        // Check that LocalVRF request was made (LocalVRF has priority)
        uint256 requestId = mockLocalVRF.nextRequestId() - 1;
        assertTrue(mockLocalVRF.pendingRequests(requestId), "LocalVRF request should be pending");
        
        // Simulate LocalVRF callback with winning number (low random number = win)
        uint256 winningRandomness = 10000; // Should win with max probability (40,000 PPM)
        
        // LocalVRF callback must be called from the LocalVRF consumer in a separate transaction
        vm.startPrank(address(mockLocalVRF));
        
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = winningRandomness;
        
        lotteryManager.receiveRandomWords(requestId, randomWords);
        
        vm.stopPrank();
        
        // Check user stats for win
        (,, uint256 totalWins, uint256 totalRewards,) = lotteryManager.getUserStats(user1);
        
        assertEq(totalWins, 1, "User should have 1 win");
        assertGt(totalRewards, 0, "User should have received rewards");
        
        console.log("SUCCESS: VRF lottery flow completed");
    }
    
    function testRateLimiting() public {
        console.log("\n=== Testing Rate Limiting ===");
        
        // Advance time to avoid rate limiting initially
        vm.warp(block.timestamp + 10);
        
        uint256 dragonAmount = 1000 * 1e18;
        mockOracle.setPrice(250000000);
        
        vm.startPrank(swapContract);
        
        // First entry should succeed
        lotteryManager.processEntry(user1, dragonAmount);
        
        // Second entry immediately should fail due to rate limiting
        vm.expectRevert("Swap too frequent");
        lotteryManager.processEntry(user1, dragonAmount);
        
        vm.stopPrank();
        
        // Complete first VRF callback
        uint256 requestId1 = mockLocalVRF.nextRequestId() - 1;
        vm.startPrank(address(mockLocalVRF));
        uint256[] memory randomWords1 = new uint256[](1);
        randomWords1[0] = 500000;
        lotteryManager.receiveRandomWords(requestId1, randomWords1);
        vm.stopPrank();
        
        // Wait for rate limit to pass
        vm.warp(block.timestamp + 8); // 7 seconds + 1
        
        vm.startPrank(swapContract);
        
        // Now should succeed
        lotteryManager.processEntry(user1, dragonAmount);
        
        vm.stopPrank();
        
        // Complete second VRF callback
        uint256 requestId2 = mockLocalVRF.nextRequestId() - 1;
        vm.startPrank(address(mockLocalVRF));
        uint256[] memory randomWords2 = new uint256[](1);
        randomWords2[0] = 500000;
        lotteryManager.receiveRandomWords(requestId2, randomWords2);
        vm.stopPrank();
        
        console.log("SUCCESS: Rate limiting working correctly");
    }
    
    function testMinimumSwapThreshold() public {
        console.log("\n=== Testing Minimum Swap Threshold ===");
        
        // Advance time to avoid rate limiting
        vm.warp(block.timestamp + 10);
        
        // Test below minimum ($5 swap)
        uint256 smallAmount = 20 * 1e18; // 20 DRAGON = $5 at $0.25
        mockOracle.setPrice(25000000); // $0.25 per DRAGON
        
        vm.startPrank(swapContract);
        
        uint256 initialEntries = lotteryManager.totalLotteryEntries();
        
        // Should not create lottery entry (below $10 minimum)
        lotteryManager.processEntry(user1, smallAmount);
        
        uint256 finalEntries = lotteryManager.totalLotteryEntries();
        
        assertEq(finalEntries, initialEntries, "No lottery entry should be created below minimum");
        
        // Test above minimum ($15 swap)
        uint256 largeAmount = 60 * 1e18; // 60 DRAGON = $15 at $0.25
        lotteryManager.processEntry(user1, largeAmount);
        
        vm.stopPrank();
        
        // Complete VRF callback for the large amount entry
        uint256 requestId = mockLocalVRF.nextRequestId() - 1;
        vm.startPrank(address(mockLocalVRF));
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 500000; // Non-winning number
        lotteryManager.receiveRandomWords(requestId, randomWords);
        vm.stopPrank();
        
        uint256 finalEntries2 = lotteryManager.totalLotteryEntries();
        assertGt(finalEntries2, finalEntries, "Lottery entry should be created above minimum");
        
        console.log("SUCCESS: Minimum swap threshold working");
    }
    
    function testConfigurationChanges() public {
        console.log("\n=== Testing Configuration Changes ===");
        
        vm.startPrank(owner);
        
        // Test changing instant lottery config
        lotteryManager.configureInstantLottery(
            80, // 80 PPM base win probability  
            20e6, // $20 minimum
            5000, // 50% of jackpot as reward
            true, // active
            true // use VRF
        );
        
        (uint256 baseWinProbability, uint256 minSwapAmount, uint256 rewardPercentage, bool isActive, bool useVRFForInstant) = 
            lotteryManager.getInstantLotteryConfig();
            
        assertEq(baseWinProbability, 80, "Base win probability should be updated");
        assertEq(minSwapAmount, 20e6, "Min swap amount should be updated");
        assertEq(rewardPercentage, 5000, "Reward percentage should be updated");
        assertTrue(isActive, "Should still be active");
        assertTrue(useVRFForInstant, "Should still use VRF");
        
        vm.stopPrank();
        
        console.log("SUCCESS: Configuration changes applied correctly");
    }
}