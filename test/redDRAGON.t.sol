// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/core/tokens/redDRAGON.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

/**
 * @title redDRAGON ERC-4626 Vault Test Suite
 * @dev Comprehensive tests for redDRAGON ERC-4626 vault
 * 
 * TESTING COVERAGE:
 * ✅ ERC-4626 vault functionality (deposit/withdraw/mint/redeem)
 * ✅ LP token auto-compounding and share appreciation
 * ✅ Fee-on-transfer mechanics (6.9% total fee, immediate distribution)
 * ✅ Pair detection and fee triggers
 * ✅ Simple lottery manager integration (processEntry calls)
 * ✅ FeeM integration (`registerMe()`)
 * ✅ Administrative functions (pause, fee configuration)
 * ✅ Preview functions and share/asset conversions
 */
contract RedDRAGONTest is Test {
    // ==================== TEST SETUP ====================
    
    redDRAGON public vault;
    MockLPToken public lpToken;
    MockJackpotVault public jackpotVault;
    MockRevenueDistributor public revenueDistributor;
    MockLotteryManager public lotteryManager;
    MockUniV2Pair public dexPair;
    
    address public owner;
    address public user1;
    address public user2;
    address public feeExcluded;
    
    uint256 public constant INITIAL_LP_SUPPLY = 1000000 * 1e18;
    
    // Events to test
    event ImmediateDistributionExecuted(address indexed recipient, uint256 amount, EventCategory distributionType);
    event PairUpdated(address indexed pair, bool indexed isPair);
    event FeeExclusionUpdated(address indexed account, bool excluded);
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);
    
    function setUp() public {
        console.log("=== redDRAGON ERC-4626 Vault Test Setup ===");
        
        // Set up test accounts
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        feeExcluded = address(0x3);
        
        // Deploy mock contracts
        lpToken = new MockLPToken("DRAGON-SONIC LP", "DRAGON-LP", INITIAL_LP_SUPPLY);
        jackpotVault = new MockJackpotVault();
        revenueDistributor = new MockRevenueDistributor();
        lotteryManager = new MockLotteryManager();
        dexPair = new MockUniV2Pair(address(lpToken), address(0x456)); // Mock pair with LP token
        
        // Deploy redDRAGON ERC-4626 vault with LP token as underlying asset
        vault = new redDRAGON(
            ERC20(address(lpToken)), // underlying LP token
            "redDRAGON Vault",
            "redDRAGON"
        );
        
        // Initialize redDRAGON vault
        vault.initialize(
            owner, // owner
            address(jackpotVault),
            address(revenueDistributor),
            address(lotteryManager)
        );
        
        // Configure DEX pair
        vault.setPair(address(dexPair), true);
        
        // Set up some LP tokens for testing
        lpToken.transfer(user1, 100000 * 1e18);
        lpToken.transfer(user2, 100000 * 1e18);
        lpToken.transfer(address(dexPair), 200000 * 1e18); // Provide liquidity to mock pair
        
        console.log("redDRAGON Vault deployed at:", address(vault));
        console.log("LP Token deployed at:", address(lpToken));
        console.log("DEX Pair configured at:", address(dexPair));
        console.log("Setup completed successfully");
    }
    
    // ==================== ERC-4626 VAULT FUNCTIONALITY ====================
    
    function testBasicVaultDeposit() public {
        console.log("\n=== Testing Basic Vault Deposit ===");
        
        uint256 depositAmount = 1000 * 1e18;
        
        vm.startPrank(user1);
        lpToken.approve(address(vault), depositAmount);
        
        // Preview deposit to see expected shares
        uint256 expectedShares = vault.previewDeposit(depositAmount);
        console.log("Expected shares for", depositAmount, "LP tokens:", expectedShares);
        
        // Perform deposit
        vm.expectEmit(true, true, false, true);
        emit Deposit(user1, user1, depositAmount, expectedShares);
        
        uint256 shares = vault.deposit(depositAmount, user1);
        vm.stopPrank();
        
        // Check results
        assertEq(shares, expectedShares, "Shares should match preview");
        assertEq(vault.balanceOf(user1), shares, "User should have correct shares");
        assertEq(vault.totalAssets(), depositAmount, "Vault should hold LP tokens");
        assertEq(lpToken.balanceOf(address(vault)), depositAmount, "Vault should hold LP tokens");
        
        console.log("LP deposited:", depositAmount);
        console.log("Shares received:", shares);
        console.log("Share rate:", (depositAmount * 1e18) / shares);
        console.log("SUCCESS: Basic vault deposit working");
    }
    
    function testBasicVaultWithdraw() public {
        console.log("\n=== Testing Basic Vault Withdraw ===");
        
        // First deposit
        uint256 depositAmount = 3000 * 1e18;
        vm.startPrank(user1);
        lpToken.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, user1);
        vm.stopPrank();
        
        // Now withdraw half the LP tokens
        uint256 withdrawAmount = 1500 * 1e18;
        uint256 expectedShares = vault.previewWithdraw(withdrawAmount);
        
        uint256 initialLPBalance = lpToken.balanceOf(user1);
        
        vm.expectEmit(true, true, true, true);
        emit Withdraw(user1, user1, user1, withdrawAmount, expectedShares);
        
        vm.prank(user1);
        uint256 sharesRedeemed = vault.withdraw(withdrawAmount, user1, user1);
        
        // Check results
        assertEq(sharesRedeemed, expectedShares, "Shares redeemed should match preview");
        assertEq(lpToken.balanceOf(user1), initialLPBalance + withdrawAmount, "LP tokens should be returned");
        assertEq(vault.balanceOf(user1), shares - sharesRedeemed, "Remaining shares should be correct");
        assertEq(vault.totalAssets(), depositAmount - withdrawAmount, "Vault should hold remaining LP tokens");
        
        console.log("LP withdrawn:", withdrawAmount);
        console.log("Shares redeemed:", sharesRedeemed);
        console.log("SUCCESS: Basic vault withdraw working");
    }
    
    function testVaultAutoCompounding() public {
        console.log("\n=== Testing Vault Auto-Compounding ===");
        
        // Initial deposit
        uint256 depositAmount = 1000 * 1e18;
        vm.startPrank(user1);
        lpToken.approve(address(vault), depositAmount);
        uint256 initialShares = vault.deposit(depositAmount, user1);
        vm.stopPrank();
        
        console.log("Initial deposit:", depositAmount);
        console.log("Initial shares:", initialShares);
        console.log("Initial assets per share:", vault.convertToAssets(1e18));
        
        // Simulate LP token appreciation by sending more LP tokens to vault
        // (In reality, this would happen through Uniswap V2 trading fees)
        uint256 appreciation = 100 * 1e18; // 10% appreciation
        lpToken.transfer(address(vault), appreciation);
        
        console.log("LP appreciation:", appreciation);
        console.log("Total assets after appreciation:", vault.totalAssets());
        console.log("Assets per share after appreciation:", vault.convertToAssets(1e18));
        
        // Check that user can now withdraw more LP tokens with same shares
        uint256 withdrawableAssets = vault.convertToAssets(initialShares);
        console.log("Withdrawable assets:", withdrawableAssets);
        
        assertGt(withdrawableAssets, depositAmount, "Should be able to withdraw more than deposited");
        assertEq(withdrawableAssets, depositAmount + appreciation, "Should include appreciation");
        
        // Verify user gets the appreciated amount
        vm.prank(user1);
        uint256 actualWithdrawn = vault.redeem(initialShares, user1, user1);
        
        assertEq(actualWithdrawn, withdrawableAssets, "Should withdraw appreciated amount");
        
        console.log("Actual withdrawn:", actualWithdrawn);
        console.log("Profit from appreciation:", actualWithdrawn - depositAmount);
        console.log("SUCCESS: Vault auto-compounding working");
    }
    
    function testPreviewFunctions() public {
        console.log("\n=== Testing Preview Functions ===");
        
        uint256 depositAmount = 1000 * 1e18;
        
        // Test preview functions before any deposits
        uint256 previewShares = vault.previewDeposit(depositAmount);
        uint256 previewAssets = vault.previewWithdraw(depositAmount);
        uint256 previewMint = vault.previewMint(previewShares);
        uint256 previewRedeem = vault.previewRedeem(previewShares);
        
        console.log("Preview deposit (1000 LP -> shares):", previewShares);
        console.log("Preview withdraw (1000 LP <- shares):", previewAssets);
        console.log("Preview mint (shares -> LP):", previewMint);
        console.log("Preview redeem (shares -> LP):", previewRedeem);
        
        // For initial deposits, should be 1:1
        assertEq(previewShares, depositAmount, "Initial deposit should be 1:1");
        assertEq(previewMint, depositAmount, "Initial mint should be 1:1");
        
        console.log("SUCCESS: Preview functions working");
    }
    
    // ==================== FEE MECHANICS ====================
    
    function testFeeOnPairTransactions() public {
        console.log("\n=== Testing Fee on Pair Transactions ===");
        
        // Deposit LP tokens to get vault shares
        uint256 depositAmount = 10000 * 1e18;
        vm.startPrank(user1);
        lpToken.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);
        vm.stopPrank();
        
        // Transfer some shares to pair for initial balance
        vm.prank(user1);
        vault.transfer(address(dexPair), 5000 * 1e18);
        
        uint256 swapAmount = 1000 * 1e18; // 1000 vault shares
        
        // Record initial balances
        uint256 initialJackpotBalance = vault.balanceOf(address(jackpotVault));
        uint256 initialRevenueBalance = vault.balanceOf(address(revenueDistributor));
        
        // Simulate buy (pair -> user) - should trigger fees
        vm.expectEmit(true, true, false, true);
        emit ImmediateDistributionExecuted(address(jackpotVault), (swapAmount * 690 * 6900) / (10000 * 10000), EventCategory.BUY_JACKPOT);
        
        vm.prank(address(dexPair));
        vault.transfer(user2, swapAmount);
        
        // Check fees were collected
        uint256 totalFee = (swapAmount * 690) / 10000; // 6.9% total fee
        uint256 expectedJackpotFee = (totalFee * 6900) / 10000; // 69% to jackpot
        uint256 expectedRevenueFee = (totalFee * 3100) / 10000; // 31% to revenue
        
        uint256 finalJackpotBalance = vault.balanceOf(address(jackpotVault));
        uint256 finalRevenueBalance = vault.balanceOf(address(revenueDistributor));
        
        assertEq(finalJackpotBalance - initialJackpotBalance, expectedJackpotFee, "Jackpot should receive 69% of fees");
        assertEq(finalRevenueBalance - initialRevenueBalance, expectedRevenueFee, "Revenue should receive 31% of fees");
        
        // User should receive amount minus fees
        uint256 expectedUserAmount = swapAmount - totalFee;
        assertEq(vault.balanceOf(user2), expectedUserAmount, "User should receive amount minus fees");
        
        console.log("Swap amount:", swapAmount);
        console.log("Total fee (6.9%):", totalFee);
        console.log("Jackpot fee (69%):", expectedJackpotFee);
        console.log("Revenue fee (31%):", expectedRevenueFee);
        console.log("User received:", vault.balanceOf(user2));
        console.log("SUCCESS: Fee on pair transactions working");
    }
    
    function testNoFeesOnRegularTransfers() public {
        console.log("\n=== Testing No Fees on Regular Transfers ===");
        
        // Deposit LP tokens first
        uint256 depositAmount = 5000 * 1e18;
        vm.startPrank(user1);
        lpToken.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);
        vm.stopPrank();
        
        uint256 transferAmount = 1000 * 1e18;
        
        // Record initial balances
        uint256 initialJackpotBalance = vault.balanceOf(address(jackpotVault));
        uint256 initialRevenueBalance = vault.balanceOf(address(revenueDistributor));
        
        // Regular transfer (user -> user) - should NOT trigger fees
        vm.prank(user1);
        vault.transfer(user2, transferAmount);
        
        // Check no fees were collected
        assertEq(vault.balanceOf(address(jackpotVault)), initialJackpotBalance, "No fees to jackpot on regular transfer");
        assertEq(vault.balanceOf(address(revenueDistributor)), initialRevenueBalance, "No fees to revenue on regular transfer");
        
        // User should receive full amount
        assertEq(vault.balanceOf(user2), transferAmount, "User should receive full amount");
        
        console.log("Transfer amount:", transferAmount);
        console.log("User received:", vault.balanceOf(user2));
        console.log("SUCCESS: No fees on regular transfers");
    }
    
    // ==================== SIMPLE LOTTERY INTEGRATION ====================
    
    function testLotteryManagerIntegration() public {
        console.log("\n=== Testing Simple Lottery Manager Integration ===");
        
        // Deposit LP tokens and setup pair
        uint256 depositAmount = 10000 * 1e18;
        vm.startPrank(user1);
        lpToken.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);
        vm.stopPrank();
        
        vm.prank(user1);
        vault.transfer(address(dexPair), 5000 * 1e18);
        
        uint256 swapAmount = 100 * 1e18;
        
        // Buy transaction (pair -> user) should call lottery manager
        vm.prank(address(dexPair));
        vault.transfer(user2, swapAmount);
        
        // Check lottery manager was called (simple integration)
        assertTrue(lotteryManager.processEntryCalled(), "Lottery manager should have been called");
        assertEq(lotteryManager.lastUser(), user2, "Lottery should be for the buyer");
        
        // Amount should be the received amount (after fees)
        uint256 expectedAmount = swapAmount - (swapAmount * 690) / 10000;
        assertEq(lotteryManager.lastAmount(), expectedAmount, "Lottery amount should be after-fee amount");
        
        console.log("Swap amount:", swapAmount);
        console.log("After-fee amount:", expectedAmount);
        console.log("SUCCESS: Simple lottery manager integration working");
    }
    
    function testNoLotteryOnSell() public {
        console.log("\n=== Testing No Lottery on Sell ===");
        
        // Deposit LP tokens
        uint256 depositAmount = 5000 * 1e18;
        vm.startPrank(user1);
        lpToken.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);
        vm.stopPrank();
        
        // Reset lottery manager call tracking
        lotteryManager.reset();
        
        // Sell transaction (user -> pair) should NOT trigger lottery
        vm.prank(user1);
        vault.transfer(address(dexPair), 1000 * 1e18);
        
        // Check lottery manager was NOT called
        assertFalse(lotteryManager.processEntryCalled(), "Lottery manager should NOT be called on sell");
        
        console.log("SUCCESS: No lottery on sell transactions");
    }
    
    // ==================== FEEM INTEGRATION ====================
    
    function testFeeMIntegration() public {
        console.log("\n=== Testing FeeM Integration ===");
        
        // Call registerMe function (owner only)
        vault.registerMe();
        
        // Should complete without reverting
        // Note: registerMe() doesn't return a value, successful execution means success
        
        console.log("SUCCESS: FeeM integration working");
    }
    
    // ==================== ADMINISTRATIVE FUNCTIONS ====================
    
    function testPairManagement() public {
        console.log("\n=== Testing Pair Management ===");
        
        address newPair = address(0x789);
        
        // Add new pair
        vm.expectEmit(true, true, false, true);
        emit PairUpdated(newPair, true);
        
        vault.setPair(newPair, true);
        assertTrue(vault.isPair(newPair), "New pair should be added");
        
        // Remove pair
        vm.expectEmit(true, true, false, true);
        emit PairUpdated(newPair, false);
        
        vault.setPair(newPair, false);
        assertFalse(vault.isPair(newPair), "Pair should be removed");
        
        console.log("SUCCESS: Pair management working");
    }
    
    function testFeeExclusion() public {
        console.log("\n=== Testing Fee Exclusion ===");
        
        // Add fee exclusion
        vm.expectEmit(true, true, false, true);
        emit FeeExclusionUpdated(feeExcluded, true);
        
        vault.setExcludeFromFees(feeExcluded, true);
        assertTrue(vault.isExcludedFromFees(feeExcluded), "Account should be excluded from fees");
        
        // Remove fee exclusion
        vm.expectEmit(true, true, false, true);
        emit FeeExclusionUpdated(feeExcluded, false);
        
        vault.setExcludeFromFees(feeExcluded, false);
        assertFalse(vault.isExcludedFromFees(feeExcluded), "Account should not be excluded from fees");
        
        console.log("SUCCESS: Fee exclusion working");
    }
    
    function testPauseUnpause() public {
        console.log("\n=== Testing Pause/Unpause ===");
        
        // Pause contract
        vault.setPaused(true);
        assertTrue(vault.paused(), "Contract should be paused");
        
        // Try deposit while paused - should revert
        vm.startPrank(user1);
        lpToken.approve(address(vault), 100 * 1e18);
        vm.expectRevert();
        vault.deposit(100 * 1e18, user1);
        vm.stopPrank();
        
        // Unpause contract
        vault.setPaused(false);
        assertFalse(vault.paused(), "Contract should be unpaused");
        
        console.log("SUCCESS: Pause/unpause working");
    }
    
    // ==================== EDGE CASES AND SECURITY ====================
    
    function testZeroAmountTransactions() public {
        console.log("\n=== Testing Zero Amount Transactions ===");
        
        // Deposit some LP tokens first
        uint256 depositAmount = 1000 * 1e18;
        vm.startPrank(user1);
        lpToken.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);
        vm.stopPrank();
        
        // Zero amount transfer should work
        vm.prank(user1);
        vault.transfer(user2, 0);
        
        assertEq(vault.balanceOf(user2), 0, "Zero transfer should not change balance");
        
        console.log("SUCCESS: Zero amount transactions handled");
    }
    
    function testMaximumValues() public {
        console.log("\n=== Testing Maximum Values ===");
        
        // Test with large amounts (within reasonable limits)
        uint256 largeAmount = 1e9 * 1e18; // 1 billion LP tokens
        
        // Give user1 large amount of LP tokens
        lpToken.mint(user1, largeAmount);
        
        vm.startPrank(user1);
        lpToken.approve(address(vault), largeAmount);
        uint256 shares = vault.deposit(largeAmount, user1);
        vm.stopPrank();
        
        assertEq(vault.balanceOf(user1), shares, "Large amount deposit should work");
        assertEq(vault.totalAssets(), largeAmount, "Vault should hold large amount");
        
        console.log("Large amount deposited:", largeAmount);
        console.log("Shares received:", shares);
        console.log("SUCCESS: Maximum values handled");
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    function testViewFunctions() public {
        console.log("\n=== Testing View Functions ===");
        
        // Test getTotalFees
        (uint256 jackpotFees, uint256 revenueFees) = vault.getTotalFees();
        // Should be zero initially
        assertEq(jackpotFees, 0, "Initial jackpot fees should be zero");
        assertEq(revenueFees, 0, "Initial revenue fees should be zero");
        
        // Test isInitialized
        assertTrue(vault.isInitialized(), "Contract should be initialized");
        
        // Test getUnderlyingLPToken
        address underlyingLP = vault.getUnderlyingLPToken();
        assertEq(underlyingLP, address(lpToken), "Should return correct LP token address");
        
        // Test ERC-4626 view functions
        assertEq(address(vault.asset()), address(lpToken), "Asset should be LP token");
        assertEq(vault.totalAssets(), 0, "Initial total assets should be zero");
        
        console.log("Underlying LP token:", underlyingLP);
        console.log("Vault asset:", address(vault.asset()));
        console.log("Total assets:", vault.totalAssets());
        console.log("SUCCESS: View functions working");
    }
}

// ==================== MOCK CONTRACTS ====================

contract MockLPToken is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol, 18) {
        _mint(msg.sender, initialSupply);
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockJackpotVault {
    // Mock implementation - just holds tokens
}

contract MockRevenueDistributor {
    // Mock implementation - just holds tokens
}

contract MockLotteryManager {
    bool public processEntryCalled;
    address public lastUser;
    uint256 public lastAmount;
    
    function processEntry(address user, uint256 amount) external {
        processEntryCalled = true;
        lastUser = user;
        lastAmount = amount;
    }
    
    function reset() external {
        processEntryCalled = false;
        lastUser = address(0);
        lastAmount = 0;
    }
}

contract MockUniV2Pair {
    address public token0;
    address public token1;
    
    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }
}