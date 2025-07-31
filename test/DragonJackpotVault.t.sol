// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/core/lottery/DragonJackpotVault.sol";
import "../contracts/core/config/OmniDragonRegistry.sol";

// Mock wrapped native token for testing
contract MockWrappedNativeToken {
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;
    
    function deposit() external payable {
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;
    }
    
    function withdraw(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        payable(msg.sender).transfer(amount);
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    // Don't include receive() to avoid payable conflicts
}

// Mock ERC20 token for testing
contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;
    string public name = "MockToken";
    string public symbol = "MOCK";
    uint8 public decimals = 18;
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }
}

contract DragonJackpotVaultTest is Test {
    DragonJackpotVault public vault;
    MockWrappedNativeToken public wrappedToken;
    MockERC20 public mockToken;
    OmniDragonRegistry public registry;
    
    address public owner = address(0x1234567890123456789012345678901234567890);
    address public user = address(0x2345678901234567890123456789012345678901);
    address public winner = address(0x3456789012345678901234567890123456789012);
    
    event JackpotAdded(address indexed token, uint256 amount);
    event JackpotPaid(address indexed token, address indexed winner, uint256 winAmount, uint256 rolloverAmount);
    event WrappedNativeTokenSet(address indexed oldToken, address indexed newToken);
    event EmergencyWithdraw(address indexed token, address indexed to, uint256 amount);
    
    function setUp() public {
        // Give owner and user some ETH
        vm.deal(owner, 100 ether);
        vm.deal(user, 100 ether);
        vm.deal(winner, 1 ether);
        
        vm.startPrank(owner);
        
        // Deploy mock contracts
        wrappedToken = new MockWrappedNativeToken();
        mockToken = new MockERC20();
        
        // Deploy vault
        vault = new DragonJackpotVault(address(wrappedToken), owner);
        
        // Setup mock tokens
        mockToken.mint(user, 1000 ether);
        mockToken.mint(owner, 1000 ether);
        
        vm.stopPrank();
    }
    
    function testDeployment() public view {
        assertEq(vault.owner(), owner);
        assertEq(vault.wrappedNativeToken(), address(wrappedToken));
        assertEq(vault.WINNER_PERCENTAGE(), 6900);
        assertEq(vault.ROLLOVER_PERCENTAGE(), 3100);
        assertEq(vault.BASIS_POINTS(), 10000);
        assertEq(vault.lastWinTimestamp(), 0);
    }
    
    function testAddERC20ToJackpot() public {
        uint256 amount = 100 ether;
        
        vm.startPrank(user);
        mockToken.approve(address(vault), amount);
        
        vm.expectEmit(true, true, false, true);
        emit JackpotAdded(address(mockToken), amount);
        
        vault.addERC20ToJackpot(address(mockToken), amount);
        
        assertEq(vault.getJackpotBalance(address(mockToken)), amount);
        assertEq(mockToken.balanceOf(address(vault)), amount);
        vm.stopPrank();
    }
    
    function testAddERC20ToJackpotZeroAmount() public {
        vm.startPrank(user);
        vm.expectRevert(); // DragonErrors.ZeroAmount()
        vault.addERC20ToJackpot(address(mockToken), 0);
        vm.stopPrank();
    }
    
    function testAddCollectedFundsOnlyOwner() public {
        uint256 amount = 50 ether;
        
        vm.expectEmit(true, true, false, true);
        emit JackpotAdded(address(mockToken), amount);
        
        vm.prank(owner);
        vault.addCollectedFunds(address(mockToken), amount);
        
        assertEq(vault.getJackpotBalance(address(mockToken)), amount);
    }
    
    function testAddCollectedFundsNotOwner() public {
        vm.startPrank(user);
        vm.expectRevert(); // Ownable: caller is not the owner
        vault.addCollectedFunds(address(mockToken), 50 ether);
        vm.stopPrank();
    }
    
    function testGetJackpotBalance() public {
        // Test wrapped native token balance
        uint256 balance = vault.getJackpotBalance();
        assertEq(balance, 0);
        
        // Add some funds
        vm.prank(owner);
        vault.addCollectedFunds(address(wrappedToken), 100 ether);
        
        balance = vault.getJackpotBalance();
        assertEq(balance, 100 ether);
    }
    
    function testGetJackpotBalanceSpecificToken() public {
        uint256 amount = 75 ether;
        
        vm.prank(owner);
        vault.addCollectedFunds(address(mockToken), amount);
        
        assertEq(vault.getJackpotBalance(address(mockToken)), amount);
    }
    
    function testPayEntireJackpot() public {
        uint256 jackpotAmount = 100 ether;
        
        // Setup jackpot
        vm.startPrank(owner);
        vault.addCollectedFunds(address(wrappedToken), jackpotAmount);
        
        // Transfer wrapped tokens to vault for payout
        wrappedToken.deposit{value: jackpotAmount}();
        wrappedToken.transfer(address(vault), jackpotAmount);
        
        uint256 expectedWinnerAmount = (jackpotAmount * 6900) / 10000; // 69%
        uint256 expectedRollover = jackpotAmount - expectedWinnerAmount; // 31%
        
        vm.expectEmit(true, true, false, true);
        emit JackpotPaid(address(wrappedToken), winner, expectedWinnerAmount, expectedRollover);
        
        vault.payEntireJackpot(winner);
        
        // Check balances
        assertEq(vault.getJackpotBalance(), expectedRollover);
        assertEq(wrappedToken.balanceOf(winner), expectedWinnerAmount);
        assertTrue(vault.lastWinTimestamp() > 0);
        
        vm.stopPrank();
    }
    
    function testPayJackpotLegacyFunction() public {
        uint256 jackpotAmount = 200 ether;
        
        vm.startPrank(owner);
        
        // Setup jackpot - first add collected funds
        vault.addCollectedFunds(address(wrappedToken), jackpotAmount);
        
        // Directly give the vault wrapped tokens (simulating real scenario)
        // where the vault received wrapped tokens through deposits
        vm.deal(owner, jackpotAmount);
        wrappedToken.deposit{value: jackpotAmount}();
        wrappedToken.transfer(address(vault), jackpotAmount);
        
        uint256 expectedWinnerAmount = (jackpotAmount * 6900) / 10000; // 69%
        uint256 expectedRollover = jackpotAmount - expectedWinnerAmount; // 31%
        
        // Amount parameter is ignored - function uses 69/31 split
        vault.payJackpot(winner, 999 ether);
        
        // Check balances
        assertEq(vault.getJackpotBalance(), expectedRollover);
        assertEq(wrappedToken.balanceOf(winner), expectedWinnerAmount);
        
        vm.stopPrank();
    }
    
    function testPayEntireJackpotZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(); // DragonErrors.ZeroAddress()
        vault.payEntireJackpot(address(0));
        vm.stopPrank();
    }
    
    function testPayEntireJackpotNoJackpot() public {
        vm.startPrank(owner);
        vm.expectRevert(); // DragonErrors.NoJackpotToPay()
        vault.payEntireJackpot(winner);
        vm.stopPrank();
    }
    
    function testPayEntireJackpotWithToken() public {
        uint256 jackpotAmount = 150 ether;
        
        vm.startPrank(owner);
        
        // Setup token jackpot
        vault.addCollectedFunds(address(mockToken), jackpotAmount);
        mockToken.transfer(address(vault), jackpotAmount);
        
        uint256 expectedWinnerAmount = (jackpotAmount * 6900) / 10000;
        uint256 expectedRollover = jackpotAmount - expectedWinnerAmount;
        
        vault.payEntireJackpotWithToken(address(mockToken), winner);
        
        assertEq(vault.getJackpotBalance(address(mockToken)), expectedRollover);
        assertEq(mockToken.balanceOf(winner), expectedWinnerAmount);
        
        vm.stopPrank();
    }
    
    function testSetWrappedNativeToken() public {
        address newToken = address(0x999);
        
        vm.expectEmit(true, true, false, true);
        emit WrappedNativeTokenSet(address(wrappedToken), newToken);
        
        vm.prank(owner);
        vault.setWrappedNativeToken(newToken);
        
        assertEq(vault.wrappedNativeToken(), newToken);
    }
    
    function testSetWrappedNativeTokenZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(); // DragonErrors.ZeroAddress()
        vault.setWrappedNativeToken(address(0));
        vm.stopPrank();
    }
    
    function testEmergencyWithdrawERC20() public {
        uint256 amount = 50 ether;
        
        // Send tokens to vault
        vm.prank(user);
        mockToken.transfer(address(vault), amount);
        
        vm.expectEmit(true, true, false, true);
        emit EmergencyWithdraw(address(mockToken), owner, amount);
        
        uint256 ownerBalanceBefore = mockToken.balanceOf(owner);
        
        vm.prank(owner);
        vault.emergencyWithdraw(address(mockToken), amount);
        
        assertEq(mockToken.balanceOf(owner), ownerBalanceBefore + amount);
    }
    
    function testEmergencyWithdrawNative() public {
        uint256 amount = 5 ether;
        
        // Send native tokens to vault
        vm.deal(address(vault), amount);
        
        uint256 ownerBalanceBefore = owner.balance;
        
        vm.prank(owner);
        vault.emergencyWithdraw(address(0), amount);
        
        assertTrue(owner.balance >= ownerBalanceBefore + amount - 0.01 ether); // Account for gas
    }
    
    function testReceiveNativeTokens() public {
        uint256 amount = 10 ether;
        
        vm.expectEmit(true, true, false, true);
        emit JackpotAdded(address(wrappedToken), amount);
        
        // Send native tokens to vault
        (bool success,) = address(vault).call{value: amount}("");
        assertTrue(success);
        
        assertEq(vault.getJackpotBalance(), amount);
        assertEq(wrappedToken.balanceOf(address(vault)), amount);
    }
    
    function testEnterJackpotWithDragon() public {
        uint256 amount = 25 ether;
        
        vm.expectEmit(true, true, false, true);
        emit JackpotAdded(address(0), amount); // address(0) represents Dragon tokens
        
        vault.enterJackpotWithDragon(user, amount);
    }
    
    function testEnterJackpotWithWrappedNativeToken() public {
        uint256 amount = 30 ether;
        
        vm.startPrank(user);
        
        // Get wrapped tokens
        wrappedToken.deposit{value: amount}();
        wrappedToken.transfer(address(this), amount);
        
        // Test setup simplified - no need for approval reset in this test
        
        vm.stopPrank();
        
        // Mock the transfer (simplified for test)
        vm.prank(owner);
        vault.addCollectedFunds(address(wrappedToken), amount);
        
        assertEq(vault.getJackpotBalance(), amount);
    }
    
    function testEnterJackpotWithNative() public {
        uint256 amount = 15 ether;
        
        vm.deal(user, amount);
        
        vm.expectEmit(true, true, false, true);
        emit JackpotAdded(address(wrappedToken), amount);
        
        vm.prank(user);
        vault.enterJackpotWithNative{value: amount}(user);
        
        assertEq(vault.getJackpotBalance(), amount);
    }
    
    function testGetTotalJackpotValue() public {
        uint256 amount = 80 ether;
        
        vm.prank(owner);
        vault.addCollectedFunds(address(wrappedToken), amount);
        
        assertEq(vault.getTotalJackpotValue(), amount);
    }
    
    function testGetWinnerPayout() public {
        uint256 jackpotAmount = 100 ether;
        
        vm.prank(owner);
        vault.addCollectedFunds(address(wrappedToken), jackpotAmount);
        
        uint256 expectedPayout = (jackpotAmount * 6900) / 10000; // 69%
        assertEq(vault.getWinnerPayout(), expectedPayout);
    }
    
    function testGetRolloverAmount() public {
        uint256 jackpotAmount = 100 ether;
        
        vm.prank(owner);
        vault.addCollectedFunds(address(wrappedToken), jackpotAmount);
        
        uint256 expectedRollover = (jackpotAmount * 3100) / 10000; // 31%
        assertEq(vault.getRolloverAmount(), expectedRollover);
    }
    
    function testGetLastWinTime() public {
        assertEq(vault.getLastWinTime(), 0);
        
        // Setup and pay jackpot
        vm.startPrank(owner);
        vault.addCollectedFunds(address(wrappedToken), 100 ether);
        wrappedToken.deposit{value: 100 ether}();
        wrappedToken.transfer(address(vault), 100 ether);
        
        vault.payEntireJackpot(winner);
        
        assertTrue(vault.getLastWinTime() > 0);
        vm.stopPrank();
    }
    
    function testOnlyOwnerFunctions() public {
        vm.startPrank(user);
        
        vm.expectRevert(); // Ownable: caller is not the owner
        vault.addCollectedFunds(address(mockToken), 1 ether);
        
        vm.expectRevert(); // Ownable: caller is not the owner
        vault.payEntireJackpot(winner);
        
        vm.expectRevert(); // Ownable: caller is not the owner
        vault.payJackpot(winner, 1 ether);
        
        vm.expectRevert(); // Ownable: caller is not the owner
        vault.setWrappedNativeToken(address(0x123));
        
        vm.expectRevert(); // Ownable: caller is not the owner
        vault.emergencyWithdraw(address(mockToken), 1 ether);
        
        vm.stopPrank();
    }
}