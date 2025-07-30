// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/core/tokens/omniDRAGON.sol";
import "../contracts/interfaces/tokens/IOmniDRAGON.sol";
import "../contracts/core/config/OmniDragonRegistry.sol";
import "./mocks/MockLayerZeroEndpoint.sol";

/**
 * @title omniDRAGONTest
 * @dev Comprehensive tests for omniDRAGON contract
 */
contract omniDRAGONTest is Test {
    omniDRAGON public dragon;
    OmniDragonRegistry public registry;
    MockLayerZeroEndpoint public mockEndpoint;
    
    // Test accounts
    address public owner;
    address public user1;
    address public user2;
    address public jackpotVault;
    address public revenueVault;
    address public lotteryManager;
    address public pair1;
    address public pair2;
    
    // Mock LayerZero endpoint
    address public constant MOCK_LZ_ENDPOINT = address(0x1234567890123456789012345678901234567890);
    
    // Constants for testing
    uint256 public constant INITIAL_SUPPLY = 6_942_000 * 10 ** 18;
    uint256 public constant TEST_AMOUNT = 1000 * 10 ** 18;
    uint256 public constant BASIS_POINTS = 10000;
    
    // Events to test
    event FeesUpdated(IOmniDRAGON.Fees newFees);
    event VaultUpdated(address indexed vault, string vaultType);
    event TradingEnabled(bool enabled);
    event FeesEnabled(bool enabled);
    event PairUpdated(address indexed pair, bool isListed);
    event LotteryManagerUpdated(address indexed newManager);
    event FeeDistributed(address indexed vault, uint256 amount, string category);
    
    function setUp() public {
        // Set up test accounts
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        jackpotVault = makeAddr("jackpotVault");
        revenueVault = makeAddr("revenueVault");
        lotteryManager = makeAddr("lotteryManager");
        pair1 = makeAddr("pair1");
        pair2 = makeAddr("pair2");
        
        vm.startPrank(owner);
        
        // Deploy mock LayerZero endpoint
        mockEndpoint = new MockLayerZeroEndpoint();
        
        // Deploy registry first
        registry = new OmniDragonRegistry(owner);
        
        // Deploy omniDRAGON
        dragon = new omniDRAGON(
            address(mockEndpoint),
            address(registry),
            owner, // delegate
            owner
        );
        
        vm.stopPrank();
    }
    
    // =============================================================
    //                    DEPLOYMENT TESTS
    // =============================================================
    
    function testDeployment() public {
        // Check basic token properties
        assertEq(dragon.name(), "omniDRAGON");
        assertEq(dragon.symbol(), "DRAGON");
        assertEq(dragon.decimals(), 18);
        assertEq(dragon.totalSupply(), INITIAL_SUPPLY);
        assertEq(dragon.balanceOf(owner), INITIAL_SUPPLY);
        
        // Check immutable addresses
        assertEq(address(dragon.REGISTRY()), address(registry));
        assertEq(dragon.DELEGATE(), owner);
        
        // Check initial fee structure (10% total)
        IOmniDRAGON.Fees memory buyFees = dragon.getBuyFees();
        assertEq(buyFees.jackpot, 690);  // 6.9%
        assertEq(buyFees.veDRAGON, 241); // 2.41%
        assertEq(buyFees.burn, 69);      // 0.69%
        assertEq(buyFees.total, 1000);   // 10%
        
        IOmniDRAGON.Fees memory sellFees = dragon.getSellFees();
        assertEq(sellFees.jackpot, 690);
        assertEq(sellFees.veDRAGON, 241);
        assertEq(sellFees.burn, 69);
        assertEq(sellFees.total, 1000);
        
        // Check initial control flags
        IOmniDRAGON.ControlFlags memory flags = dragon.getControlFlags();
        assertTrue(flags.feesEnabled);
        assertTrue(flags.initialMintCompleted);
        assertFalse(flags.tradingEnabled); // Disabled by default
        assertFalse(flags.paused);
        assertFalse(flags.emergencyMode);
    }
    
    function testDeploymentWithZeroAddressFails() public {
        vm.expectRevert();
        new omniDRAGON(
            MOCK_LZ_ENDPOINT,
            address(0), // Zero registry address should fail
            owner,
            owner
        );
        
        vm.expectRevert();
        new omniDRAGON(
            MOCK_LZ_ENDPOINT,
            address(registry),
            address(0), // Zero delegate address should fail
            owner
        );
    }
    
    // =============================================================
    //                    FEE CALCULATION TESTS
    // =============================================================
    
    function testCalculateFees() public {
        uint256 amount = 1000 * 10 ** 18;
        
        // Test buy fees
        (uint256 jackpotFee, uint256 revenueFee, uint256 burnFee) = dragon.calculateFees(amount, true);
        assertEq(jackpotFee, 69 * 10 ** 18);  // 6.9%
        assertEq(revenueFee, 24.1 * 10 ** 18); // 2.41%
        assertEq(burnFee, 6.9 * 10 ** 18);    // 0.69%
        
        // Test sell fees (same structure initially)
        (jackpotFee, revenueFee, burnFee) = dragon.calculateFees(amount, false);
        assertEq(jackpotFee, 69 * 10 ** 18);
        assertEq(revenueFee, 24.1 * 10 ** 18);
        assertEq(burnFee, 6.9 * 10 ** 18);
    }
    
    function testCalculateFeesWithDifferentAmounts() public {
        // Test with small amount
        (uint256 jackpotFee, uint256 revenueFee, uint256 burnFee) = dragon.calculateFees(100, true);
        assertEq(jackpotFee, 6);   // 6.9% of 100
        assertEq(revenueFee, 2);   // 2.41% of 100
        assertEq(burnFee, 0);      // 0.69% of 100 (rounds down)
        
        // Test with zero amount
        (jackpotFee, revenueFee, burnFee) = dragon.calculateFees(0, true);
        assertEq(jackpotFee, 0);
        assertEq(revenueFee, 0);
        assertEq(burnFee, 0);
    }
    
    // =============================================================
    //                    TRANSFER TESTS
    // =============================================================
    
    function testBasicTransfer() public {
        vm.prank(owner);
        dragon.transfer(user1, TEST_AMOUNT);
        
        assertEq(dragon.balanceOf(user1), TEST_AMOUNT);
        assertEq(dragon.balanceOf(owner), INITIAL_SUPPLY - TEST_AMOUNT);
    }
    
    function testTransferWithoutFees() public {
        // Enable trading first
        vm.prank(owner);
        dragon.setTradingEnabled(true);
        
        // Transfer between regular addresses (no fees)
        vm.prank(owner);
        dragon.transfer(user1, TEST_AMOUNT);
        
        assertEq(dragon.balanceOf(user1), TEST_AMOUNT);
        assertEq(dragon.balanceOf(owner), INITIAL_SUPPLY - TEST_AMOUNT);
    }
    
    function testBuyTransferWithFees() public {
        // Setup
        vm.startPrank(owner);
        dragon.setVaults(jackpotVault, revenueVault);
        dragon.setPair(pair1, true);
        dragon.setTradingEnabled(true);
        
        // Transfer tokens to pair first
        dragon.transfer(pair1, TEST_AMOUNT);
        vm.stopPrank();
        
        // Simulate buy (transfer from pair to user)
        uint256 buyAmount = 100 * 10 ** 18;
        
        vm.expectEmit(true, false, false, true);
        emit FeeDistributed(jackpotVault, 6.9 * 10 ** 18, "BUY_JACKPOT");
        
        vm.expectEmit(true, false, false, true);
        emit FeeDistributed(revenueVault, 2.41 * 10 ** 18, "BUY_REVENUE");
        
        vm.expectEmit(true, false, false, true);
        emit FeeDistributed(dragon.DEAD_ADDRESS(), 0.69 * 10 ** 18, "BUY_BURN");
        
        vm.prank(pair1);
        dragon.transfer(user1, buyAmount);
        
        // Check balances
        uint256 expectedUserBalance = buyAmount - 10 * 10 ** 18; // 10% fees
        assertEq(dragon.balanceOf(user1), expectedUserBalance);
        assertEq(dragon.balanceOf(jackpotVault), 6.9 * 10 ** 18);
        assertEq(dragon.balanceOf(revenueVault), 2.41 * 10 ** 18);
        assertEq(dragon.balanceOf(dragon.DEAD_ADDRESS()), 0.69 * 10 ** 18);
    }
    
    function testSellTransferWithFees() public {
        // Setup
        vm.startPrank(owner);
        dragon.setVaults(jackpotVault, revenueVault);
        dragon.setPair(pair1, true);
        dragon.setTradingEnabled(true);
        dragon.transfer(user1, TEST_AMOUNT);
        vm.stopPrank();
        
        // Simulate sell (transfer from user to pair)
        uint256 sellAmount = 100 * 10 ** 18;
        
        vm.expectEmit(true, false, false, true);
        emit FeeDistributed(jackpotVault, 6.9 * 10 ** 18, "SELL_JACKPOT");
        
        vm.prank(user1);
        dragon.transfer(pair1, sellAmount);
        
        // Check that fees were deducted from user's balance
        uint256 expectedUserBalance = TEST_AMOUNT - sellAmount;
        assertEq(dragon.balanceOf(user1), expectedUserBalance);
        assertEq(dragon.balanceOf(jackpotVault), 6.9 * 10 ** 18);
    }
    
    function testTransferWhenTradingDisabled() public {
        // Setup pair but don't enable trading
        vm.startPrank(owner);
        dragon.setPair(pair1, true);
        dragon.transfer(pair1, TEST_AMOUNT);
        vm.stopPrank();
        
        // Should revert when trying to trade through pair
        vm.expectRevert();
        vm.prank(pair1);
        dragon.transfer(user1, 100 * 10 ** 18);
    }
    
    function testTransferExceedsMaxLimit() public {
        uint256 maxTransfer = dragon.MAX_SINGLE_TRANSFER();
        
        vm.expectRevert();
        vm.prank(owner);
        dragon.transfer(user1, maxTransfer + 1);
    }
    
    function testTransferWhenPaused() public {
        vm.startPrank(owner);
        // Note: There's no pause function in the current contract
        // This test would need the pause functionality to be implemented
        vm.stopPrank();
    }
    
    // =============================================================
    //                    ADMIN FUNCTION TESTS
    // =============================================================
    
    function testSetFees() public {
        IOmniDRAGON.Fees memory newBuyFees = IOmniDRAGON.Fees({
            jackpot: 500,  // 5%
            veDRAGON: 300, // 3%
            burn: 200,     // 2%
            total: 1000    // 10%
        });
        
        IOmniDRAGON.Fees memory newSellFees = IOmniDRAGON.Fees({
            jackpot: 400,  // 4%
            veDRAGON: 400, // 4%
            burn: 200,     // 2%
            total: 1000    // 10%
        });
        
        vm.expectEmit(false, false, false, true);
        emit FeesUpdated(newBuyFees);
        
        vm.prank(owner);
        dragon.setFees(newBuyFees, newSellFees);
        
        IOmniDRAGON.Fees memory updatedBuyFees = dragon.getBuyFees();
        assertEq(updatedBuyFees.jackpot, 500);
        assertEq(updatedBuyFees.veDRAGON, 300);
        assertEq(updatedBuyFees.burn, 200);
        assertEq(updatedBuyFees.total, 1000);
    }
    
    function testSetFeesTooHigh() public {
        IOmniDRAGON.Fees memory highFees = IOmniDRAGON.Fees({
            jackpot: 1500,  // 15%
            veDRAGON: 1000, // 10%
            burn: 500,      // 5%
            total: 3000     // 30% - exceeds MAX_FEE_BPS (25%)
        });
        
        vm.expectRevert();
        vm.prank(owner);
        dragon.setFees(highFees, highFees);
    }
    
    function testSetFeesInvalidConfiguration() public {
        IOmniDRAGON.Fees memory invalidFees = IOmniDRAGON.Fees({
            jackpot: 500,
            veDRAGON: 300,
            burn: 100,  // Sum (900) != total (1000)
            total: 1000
        });
        
        vm.expectRevert();
        vm.prank(owner);
        dragon.setFees(invalidFees, invalidFees);
    }
    
    function testSetFeesUnauthorized() public {
        IOmniDRAGON.Fees memory newFees = IOmniDRAGON.Fees({
            jackpot: 500,
            veDRAGON: 300,
            burn: 200,
            total: 1000
        });
        
        vm.expectRevert();
        vm.prank(user1);
        dragon.setFees(newFees, newFees);
    }
    
    function testSetVaults() public {
        vm.expectEmit(true, false, false, true);
        emit VaultUpdated(jackpotVault, "JACKPOT");
        
        vm.expectEmit(true, false, false, true);
        emit VaultUpdated(revenueVault, "REVENUE");
        
        vm.prank(owner);
        dragon.setVaults(jackpotVault, revenueVault);
        
        assertEq(dragon.jackpotVault(), jackpotVault);
        assertEq(dragon.revenueVault(), revenueVault);
    }
    
    function testSetVaultsZeroAddress() public {
        vm.expectRevert();
        vm.prank(owner);
        dragon.setVaults(address(0), revenueVault);
        
        vm.expectRevert();
        vm.prank(owner);
        dragon.setVaults(jackpotVault, address(0));
    }
    
    function testSetLotteryManager() public {
        vm.expectEmit(true, false, false, false);
        emit LotteryManagerUpdated(lotteryManager);
        
        vm.prank(owner);
        dragon.setLotteryManager(lotteryManager);
        
        assertEq(dragon.lotteryManager(), lotteryManager);
    }
    
    function testSetPair() public {
        vm.expectEmit(true, false, false, true);
        emit PairUpdated(pair1, true);
        
        vm.prank(owner);
        dragon.setPair(pair1, true);
        
        assertTrue(dragon.isPair(pair1));
        
        // Remove pair
        vm.expectEmit(true, false, false, true);
        emit PairUpdated(pair1, false);
        
        vm.prank(owner);
        dragon.setPair(pair1, false);
        
        assertFalse(dragon.isPair(pair1));
    }
    
    function testSetTradingEnabled() public {
        vm.expectEmit(false, false, false, true);
        emit TradingEnabled(true);
        
        vm.prank(owner);
        dragon.setTradingEnabled(true);
        
        IOmniDRAGON.ControlFlags memory flags = dragon.getControlFlags();
        assertTrue(flags.tradingEnabled);
    }
    
    function testSetFeesEnabled() public {
        vm.expectEmit(false, false, false, true);
        emit FeesEnabled(false);
        
        vm.prank(owner);
        dragon.setFeesEnabled(false);
        
        IOmniDRAGON.ControlFlags memory flags = dragon.getControlFlags();
        assertFalse(flags.feesEnabled);
    }
    
    function testToggleEmergencyMode() public {
        vm.prank(owner);
        dragon.toggleEmergencyMode();
        
        IOmniDRAGON.ControlFlags memory flags = dragon.getControlFlags();
        assertTrue(flags.emergencyMode);
        
        // Toggle back
        vm.prank(owner);
        dragon.toggleEmergencyMode();
        
        flags = dragon.getControlFlags();
        assertFalse(flags.emergencyMode);
    }
    
    // =============================================================
    //                    VIEW FUNCTION TESTS
    // =============================================================
    
    function testViewFunctions() public {
        // Test getter functions
        IOmniDRAGON.Fees memory buyFees = dragon.getBuyFees();
        assertEq(buyFees.total, 1000);
        
        IOmniDRAGON.Fees memory sellFees = dragon.getSellFees();
        assertEq(sellFees.total, 1000);
        
        IOmniDRAGON.ControlFlags memory flags = dragon.getControlFlags();
        assertTrue(flags.feesEnabled);
        
        assertEq(dragon.registry(), address(registry));
    }
    
    function testSupportsInterface() public {
        // Test ERC165 interface support
        assertTrue(dragon.supportsInterface(type(IOmniDRAGON).interfaceId));
        assertTrue(dragon.supportsInterface(type(IERC20).interfaceId));
    }
    
    // =============================================================
    //                    CROSS-CHAIN TESTS (MOCK)
    // =============================================================
    
    function testCrossChainTransferQuote() public {
        // This is a basic test - real implementation would need LayerZero setup
        uint32 dstEid = 1; // Ethereum
        address to = user1;
        uint256 amount = 1000 * 10 ** 18;
        bytes memory extraOptions = "";
        
        // This will likely revert in current setup since we're using a mock endpoint
        vm.expectRevert();
        dragon.quoteCrossChainTransfer(dstEid, to, amount, extraOptions);
    }
    
    // =============================================================
    //                    EDGE CASE TESTS
    // =============================================================
    
    function testFeesWithZeroVaults() public {
        // Setup pair and enable trading without setting vaults
        vm.startPrank(owner);
        dragon.setPair(pair1, true);
        dragon.setTradingEnabled(true);
        dragon.transfer(pair1, TEST_AMOUNT);
        vm.stopPrank();
        
        // Should not revert but fees go nowhere
        vm.prank(pair1);
        dragon.transfer(user1, 100 * 10 ** 18);
        
        // User should still receive reduced amount
        uint256 expectedAmount = 90 * 10 ** 18; // 100 - 10% fees
        assertEq(dragon.balanceOf(user1), expectedAmount);
    }
    
    function testMultiplePairs() public {
        vm.startPrank(owner);
        dragon.setPair(pair1, true);
        dragon.setPair(pair2, true);
        dragon.setVaults(jackpotVault, revenueVault);
        dragon.setTradingEnabled(true);
        dragon.transfer(pair1, TEST_AMOUNT);
        dragon.transfer(pair2, TEST_AMOUNT);
        vm.stopPrank();
        
        // Both pairs should trigger fees
        vm.prank(pair1);
        dragon.transfer(user1, 100 * 10 ** 18);
        
        vm.prank(pair2);
        dragon.transfer(user2, 100 * 10 ** 18);
        
        // Both users should have same balance after fees
        assertEq(dragon.balanceOf(user1), 90 * 10 ** 18);
        assertEq(dragon.balanceOf(user2), 90 * 10 ** 18);
        
        // Jackpot vault should have fees from both transactions
        assertEq(dragon.balanceOf(jackpotVault), 13.8 * 10 ** 18); // 6.9% * 2
    }
    
    // =============================================================
    //                    FUZZ TESTS
    // =============================================================
    
    function testFuzzTransferAmount(uint256 amount) public {
        vm.assume(amount > 0 && amount <= dragon.MAX_SINGLE_TRANSFER());
        vm.assume(amount <= dragon.balanceOf(owner));
        
        vm.prank(owner);
        dragon.transfer(user1, amount);
        
        assertEq(dragon.balanceOf(user1), amount);
    }
    
    function testFuzzFeeCalculation(uint256 amount) public {
        vm.assume(amount <= type(uint128).max); // Prevent overflow
        
        (uint256 jackpotFee, uint256 revenueFee, uint256 burnFee) = dragon.calculateFees(amount, true);
        
        // Fees should never exceed the original amount
        assertTrue(jackpotFee + revenueFee + burnFee <= amount);
        
        // Individual fees should be reasonable
        assertTrue(jackpotFee <= (amount * 690) / BASIS_POINTS);
        assertTrue(revenueFee <= (amount * 241) / BASIS_POINTS);
        assertTrue(burnFee <= (amount * 69) / BASIS_POINTS);
    }
}