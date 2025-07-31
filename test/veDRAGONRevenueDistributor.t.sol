// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/core/governance/voting/veDRAGONRevenueDistributor.sol";

// Mock veDRAGON contract for testing
contract MockVeDRAGON {
    mapping(address => uint256) public votingPower;
    mapping(address => mapping(uint256 => uint256)) public votingPowerAt;
    uint256 public totalVotingPower;
    
    function setVotingPower(address user, uint256 power) external {
        votingPower[user] = power;
    }
    
    function setVotingPowerAt(address user, uint256 timestamp, uint256 power) external {
        votingPowerAt[user][timestamp] = power;
    }
    
    function setTotalVotingPower(uint256 power) external {
        totalVotingPower = power;
    }
    
    function getTotalVotingPower() external view returns (uint256) {
        return totalVotingPower;
    }
    
    function getVotingPowerAt(address user, uint256 timestamp) external view returns (uint256) {
        return votingPowerAt[user][timestamp];
    }
    
    function getVotingPower(address user) external view returns (uint256) {
        return votingPower[user];
    }
    
    // Additional IveDRAGON interface functions (stubs)
    function lock(uint256 amount, uint256 lockDuration) external {}
    function extendLock(uint256 newLockDuration) external {}
    function increaseLock(uint256 amount) external {}
    function withdraw() external {}
    function getLockInfo(address user) external pure returns (uint256 amount, uint256 unlockTime) {
        return (0, 0);
    }
    function isLockExpired(address user) external pure returns (bool) {
        return false;
    }
}

// Mock ERC20 token for testing
contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;
    string public name = "MockDRAGON";
    string public symbol = "MDRAGON";
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

contract veDRAGONRevenueDistributorTest is Test {
    veDRAGONRevenueDistributor public distributor;
    MockVeDRAGON public mockVeDRAGON;
    MockERC20 public rewardToken;
    MockERC20 public feeToken;
    
    address public owner = address(0x1234567890123456789012345678901234567890);
    address public user1 = address(0x2345678901234567890123456789012345678901);
    address public user2 = address(0x3456789012345678901234567890123456789012);
    address public user3 = address(0x4567890123456789012345678901234567890123);
    
    event FeesReceived(uint256 indexed epoch, address indexed token, uint256 amount);
    event FeesClaimed(address indexed user, uint256 indexed epoch, address indexed token, uint256 amount);
    event WrappedTokenSet(address indexed oldToken, address indexed newToken);
    event EpochRolled(uint256 indexed newEpoch, uint256 startTime, uint256 endTime);
    event RewardsReceived(uint256 amount);
    event RewardsDistributed(uint256 amount);
    event RewardTokenUpdated(address indexed oldToken, address indexed newToken);
    event FeesDeposited(uint256 indexed partnerId, address indexed token, uint256 amount, address indexed user);
    event VeDRAGONAddressUpdated(address indexed oldAddress, address indexed newAddress);
    
    function setUp() public {
        // Give accounts some ETH
        vm.deal(owner, 100 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        
        vm.startPrank(owner);
        
        // Deploy mock contracts
        mockVeDRAGON = new MockVeDRAGON();
        rewardToken = new MockERC20();
        feeToken = new MockERC20();
        
        // Deploy distributor
        distributor = new veDRAGONRevenueDistributor(address(mockVeDRAGON));
        
        // Setup tokens
        rewardToken.mint(owner, 10000 ether);
        rewardToken.mint(user1, 1000 ether);
        feeToken.mint(owner, 10000 ether);
        feeToken.mint(user1, 1000 ether);
        
        vm.stopPrank();
    }
    
    function testDeployment() public view {
        assertEq(address(distributor.veDRAGON()), address(mockVeDRAGON));
        assertEq(distributor.owner(), owner);
        assertEq(distributor.currentEpoch(), 1);
        assertEq(distributor.epochDuration(), 7 days);
        assertTrue(distributor.epochStartTime(1) > 0);
        assertTrue(distributor.epochEndTime(1) > distributor.epochStartTime(1));
    }
    
    function testSetRewardToken() public {
        vm.expectEmit(true, true, false, true);
        emit RewardTokenUpdated(address(0), address(rewardToken));
        
        vm.prank(owner);
        distributor.setRewardToken(address(rewardToken));
        
        assertEq(address(distributor.rewardToken()), address(rewardToken));
    }
    
    function testSetRewardTokenZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert("Invalid token address");
        distributor.setRewardToken(address(0));
        vm.stopPrank();
    }
    
    function testSetWrappedToken() public {
        address wrappedToken = address(0x999);
        
        vm.expectEmit(true, true, false, true);
        emit WrappedTokenSet(address(0), wrappedToken);
        
        vm.prank(owner);
        distributor.setWrappedToken(wrappedToken);
        
        assertEq(distributor.wrappedNativeToken(), wrappedToken);
    }
    
    function testSetEpochDuration() public {
        uint256 newDuration = 14 days;
        
        vm.prank(owner);
        distributor.setEpochDuration(newDuration);
        
        assertEq(distributor.epochDuration(), newDuration);
    }
    
    function testSetEpochDurationInvalid() public {
        vm.startPrank(owner);
        
        // Too short
        vm.expectRevert("Invalid duration");
        distributor.setEpochDuration(12 hours);
        
        // Too long
        vm.expectRevert("Invalid duration");
        distributor.setEpochDuration(31 days);
        
        vm.stopPrank();
    }
    
    function testReceiveRewards() public {
        uint256 amount = 100 ether;
        
        vm.startPrank(owner);
        distributor.setRewardToken(address(rewardToken));
        rewardToken.approve(address(distributor), amount);
        
        vm.expectEmit(true, true, false, true);
        emit RewardsReceived(amount);
        
        distributor.receiveRewards(amount);
        
        assertEq(distributor.accumulatedRewards(), amount);
        assertEq(rewardToken.balanceOf(address(distributor)), amount);
        
        vm.stopPrank();
    }
    
    function testReceiveRewardsNoToken() public {
        vm.startPrank(owner);
        vm.expectRevert("Reward token not set");
        distributor.receiveRewards(100 ether);
        vm.stopPrank();
    }
    
    function testDistributeRewards() public {
        uint256 amount = 200 ether;
        
        vm.startPrank(owner);
        
        // Setup
        distributor.setRewardToken(address(rewardToken));
        rewardToken.approve(address(distributor), amount);
        distributor.receiveRewards(amount);
        
        vm.expectEmit(true, true, false, true);
        emit RewardsDistributed(amount);
        
        distributor.distributeRewards();
        
        assertEq(distributor.accumulatedRewards(), 0);
        assertEq(distributor.getEpochFees(1, address(rewardToken)), amount);
        
        vm.stopPrank();
    }
    
    function testDistributeGeneralFees() public {
        uint256 amount = 50 ether;
        
        vm.startPrank(user1);
        feeToken.approve(address(distributor), amount);
        
        vm.expectEmit(true, true, false, true);
        emit FeesReceived(1, address(feeToken), amount);
        
        distributor.distributeGeneralFees(address(feeToken), amount);
        
        assertEq(distributor.getEpochFees(1, address(feeToken)), amount);
        assertEq(feeToken.balanceOf(address(distributor)), amount);
        
        vm.stopPrank();
    }
    
    function testDistributeGeneralFeesNative() public {
        uint256 amount = 5 ether;
        
        // Send native tokens to distributor first
        vm.deal(address(distributor), amount);
        
        vm.expectEmit(true, true, false, true);
        emit FeesReceived(1, address(0), amount);
        
        distributor.distributeGeneralFees(address(0), amount);
        
        assertEq(distributor.getEpochFees(1, address(0)), amount);
    }
    
    function testDepositFees() public {
        uint256 partnerId = 123;
        uint256 amount = 75 ether;
        
        vm.startPrank(user1);
        feeToken.approve(address(distributor), amount);
        
        vm.expectEmit(true, true, true, true);
        emit FeesDeposited(partnerId, address(feeToken), amount, user1);
        
        distributor.depositFees(partnerId, address(feeToken), amount);
        
        assertEq(distributor.getPartnerFees(partnerId, address(feeToken)), amount);
        
        vm.stopPrank();
    }
    
    function testRollEpoch() public {
        uint256 totalVotingPower = 1000 ether;
        
        // Setup total voting power
        mockVeDRAGON.setTotalVotingPower(totalVotingPower);
        
        // Move time forward past epoch end
        vm.warp(distributor.epochEndTime(1) + 1);
        
        vm.expectEmit(true, true, false, true);
        emit EpochRolled(2, distributor.epochEndTime(1), distributor.epochEndTime(1) + 7 days);
        
        distributor.rollEpoch();
        
        assertEq(distributor.currentEpoch(), 2);
        assertEq(distributor.epochTotalSupply(1), totalVotingPower);
    }
    
    function testGetClaimable() public {
        uint256 userVotingPower = 300 ether;
        uint256 totalVotingPower = 1000 ether;
        uint256 epochFees = 100 ether;
        
        // Setup epoch 1 with fees
        vm.startPrank(user1);
        feeToken.approve(address(distributor), epochFees);
        distributor.distributeGeneralFees(address(feeToken), epochFees);
        vm.stopPrank();
        
        // Setup voting power
        mockVeDRAGON.setTotalVotingPower(totalVotingPower);
        mockVeDRAGON.setVotingPowerAt(user1, distributor.epochEndTime(1), userVotingPower);
        
        // Move to next epoch
        vm.warp(distributor.epochEndTime(1) + 1);
        distributor.rollEpoch();
        
        uint256 expectedClaimable = (epochFees * userVotingPower) / totalVotingPower;
        uint256 actualClaimable = distributor.getClaimable(user1, 1, address(feeToken));
        
        assertEq(actualClaimable, expectedClaimable);
    }
    
    function testClaimFees() public {
        uint256 userVotingPower = 300 ether;
        uint256 totalVotingPower = 1000 ether;
        uint256 epochFees = 100 ether;
        
        // Setup epoch 1 with fees
        vm.startPrank(user1);
        feeToken.approve(address(distributor), epochFees);
        distributor.distributeGeneralFees(address(feeToken), epochFees);
        vm.stopPrank();
        
        // Setup voting power
        mockVeDRAGON.setTotalVotingPower(totalVotingPower);
        mockVeDRAGON.setVotingPowerAt(user1, distributor.epochEndTime(1), userVotingPower);
        
        // Move to next epoch
        vm.warp(distributor.epochEndTime(1) + 1);
        distributor.rollEpoch();
        
        uint256 expectedClaimable = (epochFees * userVotingPower) / totalVotingPower;
        uint256 balanceBefore = feeToken.balanceOf(user1);
        
        vm.expectEmit(true, true, true, true);
        emit FeesClaimed(user1, 1, address(feeToken), expectedClaimable);
        
        vm.prank(user1);
        distributor.claimFees(1, address(feeToken));
        
        assertEq(feeToken.balanceOf(user1), balanceBefore + expectedClaimable);
        assertTrue(distributor.hasUserClaimed(user1, 1, address(feeToken)));
        assertEq(distributor.getUserTotalClaimed(user1, address(feeToken)), expectedClaimable);
    }
    
    function testClaimFeesNative() public {
        uint256 userVotingPower = 500 ether;
        uint256 totalVotingPower = 1000 ether;
        uint256 epochFees = 10 ether;
        
        // Fund distributor with native tokens
        vm.deal(address(distributor), epochFees);
        distributor.distributeGeneralFees(address(0), epochFees);
        
        // Setup voting power
        mockVeDRAGON.setTotalVotingPower(totalVotingPower);
        mockVeDRAGON.setVotingPowerAt(user1, distributor.epochEndTime(1), userVotingPower);
        
        // Move to next epoch
        vm.warp(distributor.epochEndTime(1) + 1);
        distributor.rollEpoch();
        
        uint256 expectedClaimable = (epochFees * userVotingPower) / totalVotingPower;
        uint256 balanceBefore = user1.balance;
        
        vm.prank(user1);
        distributor.claimFees(1, address(0));
        
        assertTrue(user1.balance >= balanceBefore + expectedClaimable - 0.01 ether); // Account for gas
    }
    
    function testClaimMultiple() public {
        uint256 userVotingPower = 400 ether;
        uint256 totalVotingPower = 1000 ether;
        uint256 epochFees = 100 ether;
        
        // Setup multiple epochs and tokens
        vm.startPrank(user1);
        
        // Epoch 1 - feeToken
        feeToken.approve(address(distributor), epochFees);
        distributor.distributeGeneralFees(address(feeToken), epochFees);
        
        // Epoch 1 - rewardToken  
        rewardToken.approve(address(distributor), epochFees);
        distributor.distributeGeneralFees(address(rewardToken), epochFees);
        
        vm.stopPrank();
        
        // Setup voting power
        mockVeDRAGON.setTotalVotingPower(totalVotingPower);
        mockVeDRAGON.setVotingPowerAt(user1, distributor.epochEndTime(1), userVotingPower);
        
        // Move to next epoch
        vm.warp(distributor.epochEndTime(1) + 1);
        distributor.rollEpoch();
        
        uint256[] memory epochs = new uint256[](1);
        epochs[0] = 1;
        
        address[] memory tokens = new address[](2);
        tokens[0] = address(feeToken);
        tokens[1] = address(rewardToken);
        
        uint256 feeBalanceBefore = feeToken.balanceOf(user1);
        uint256 rewardBalanceBefore = rewardToken.balanceOf(user1);
        
        vm.prank(user1);
        distributor.claimMultiple(epochs, tokens);
        
        uint256 expectedClaimable = (epochFees * userVotingPower) / totalVotingPower;
        
        assertEq(feeToken.balanceOf(user1), feeBalanceBefore + expectedClaimable);
        assertEq(rewardToken.balanceOf(user1), rewardBalanceBefore + expectedClaimable);
    }
    
    function testClaimFeesInvalidEpoch() public {
        vm.startPrank(user1);
        
        // Current epoch
        vm.expectRevert(); // InvalidEpoch()
        distributor.claimFees(1, address(feeToken));
        
        // Future epoch
        vm.expectRevert(); // InvalidEpoch()
        distributor.claimFees(999, address(feeToken));
        
        vm.stopPrank();
    }
    
    function testClaimFeesNothingToClaim() public {
        // Move to next epoch with no fees
        vm.warp(distributor.epochEndTime(1) + 1);
        distributor.rollEpoch();
        
        vm.startPrank(user1);
        vm.expectRevert(); // NothingToClaim()
        distributor.claimFees(1, address(feeToken));
        vm.stopPrank();
    }
    
    function testOnlyOwnerFunctions() public {
        vm.startPrank(user1);
        
        vm.expectRevert(); // Ownable: caller is not the owner
        distributor.setRewardToken(address(rewardToken));
        
        vm.expectRevert(); // Ownable: caller is not the owner
        distributor.setWrappedToken(address(0x123));
        
        vm.expectRevert(); // Ownable: caller is not the owner
        distributor.setEpochDuration(14 days);
        
        vm.expectRevert(); // Ownable: caller is not the owner
        distributor.setVeDRAGONAddress(address(0x456));
        
        vm.expectRevert(); // Ownable: caller is not the owner
        distributor.setWrappedNativeToken(address(0x789));
        
        vm.stopPrank();
    }
    
    function testGetClaimableRewards() public {
        // Test with no rewards
        uint256 claimable = distributor.getClaimableRewards(user1);
        assertEq(claimable, 0);
        
        // TODO: Add more comprehensive test when epoch system is fully integrated with rewards
    }
    
    function testCheckFeeMStatus() public view {
        // Should not revert and return default value
        bool status = distributor.checkFeeMStatus();
        assertEq(status, false); // Default return value
    }
    
    function testSetVeDRAGONAddress() public {
        address newAddress = address(0x987);
        
        vm.expectEmit(true, true, false, true);
        emit VeDRAGONAddressUpdated(address(mockVeDRAGON), newAddress);
        
        vm.prank(owner);
        distributor.setVeDRAGONAddress(newAddress);
        
        // Note: Since veDRAGON is immutable, this is just for interface compliance
    }
    
    function testReceiveFees() public {
        uint256 amount = 60 ether;
        
        vm.startPrank(user1);
        feeToken.approve(address(distributor), amount);
        
        vm.expectEmit(true, true, false, true);
        emit FeesReceived(1, address(feeToken), amount);
        
        distributor.receiveFees(address(feeToken), amount);
        
        assertEq(distributor.getEpochFees(1, address(feeToken)), amount);
        
        vm.stopPrank();
    }
}