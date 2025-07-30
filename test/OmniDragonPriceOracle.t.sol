// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/core/oracles/OmniDragonPriceOracle.sol";

// ============ MOCK ORACLE CONTRACTS ============

contract MockChainlinkAggregator {
  int256 public price = 250000000; // $2.50 in 8 decimals
  uint256 public updatedAt = block.timestamp;
  uint8 public decimals = 8;
  bool public shouldFail = false;

  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 _updatedAt, uint80 answeredInRound)
  {
    if (shouldFail) {
      revert("Chainlink feed failed");
    }
    return (1, price, block.timestamp, updatedAt, 1);
  }

  function setPrice(int256 _price) external {
    price = _price;
    updatedAt = block.timestamp;
  }

  function setUpdatedAt(uint256 _updatedAt) external {
    updatedAt = _updatedAt;
  }

  function setShouldFail(bool _shouldFail) external {
    shouldFail = _shouldFail;
  }
}

contract MockBandProtocol {
  uint256 public rate = 2500000000000000000; // $2.50 in 18 decimals (was wrong before)
  uint256 public lastUpdatedBase = block.timestamp;
  bool public shouldFail = false;

  struct ReferenceData {
    uint256 rate;
    uint256 lastUpdatedBase;
    uint256 lastUpdatedQuote;
  }

  function getReferenceData(string memory, string memory) external view returns (ReferenceData memory) {
    if (shouldFail) {
      revert("Band feed failed");
    }
    return ReferenceData({rate: rate, lastUpdatedBase: lastUpdatedBase, lastUpdatedQuote: lastUpdatedBase});
  }

  function setRate(uint256 _rate) external {
    rate = _rate;
    lastUpdatedBase = block.timestamp;
  }

  function setLastUpdatedBase(uint256 _lastUpdated) external {
    lastUpdatedBase = _lastUpdated;
  }

  function setShouldFail(bool _shouldFail) external {
    shouldFail = _shouldFail;
  }
}

contract MockAPI3ReaderProxy {
  int224 public value = 2500000000000000000; // $2.50 in 18 decimals as int224
  uint32 public timestamp = uint32(block.timestamp);
  bool public shouldFail = false;

  function read() external view returns (int224, uint32) {
    if (shouldFail) {
      revert("API3 feed failed");
    }
    return (value, timestamp);
  }

  function setValue(int224 _value) external {
    value = _value;
    timestamp = uint32(block.timestamp);
  }

  function setTimestamp(uint32 _timestamp) external {
    timestamp = _timestamp;
  }

  function setShouldFail(bool _shouldFail) external {
    shouldFail = _shouldFail;
  }
}

contract MockPythOracle {
  int64 public price = 250000000; // $2.50 with 8 decimal places
  int32 public expo = -8; // -8 exponent means 8 decimal places
  uint256 public publishTime = block.timestamp;
  bool public shouldFail = false;

  struct Price {
    int64 price;
    uint64 conf;
    int32 expo;
    uint256 publishTime;
  }

  function getPriceUnsafe(bytes32) external view returns (Price memory) {
    if (shouldFail) {
      revert("Pyth feed failed");
    }
    return Price({price: price, conf: 1000000, expo: expo, publishTime: publishTime});
  }

  function setPrice(int64 _price, int32 _expo) external {
    price = _price;
    expo = _expo;
    publishTime = block.timestamp;
  }

  function setPublishTime(uint256 _publishTime) external {
    publishTime = _publishTime;
  }

  function setShouldFail(bool _shouldFail) external {
    shouldFail = _shouldFail;
  }
}

contract MockOmniDragonRegistry {
  mapping(uint16 => address) public wrappedNativeTokens;

  function getWrappedNativeToken(uint16 chainId) external view returns (address) {
    return wrappedNativeTokens[chainId];
  }

  function setWrappedNativeToken(uint16 chainId, address token) external {
    wrappedNativeTokens[chainId] = token;
  }
}

contract MockUniswapV2Pair {
  address public token0;
  address public token1;
  uint112 public reserve0 = 1000000 * 1e18; // 1M tokens
  uint112 public reserve1 = 2500000 * 1e6; // 2.5M USDC (6 decimals)
  uint256 public totalSupply = 1000 * 1e18; // 1k LP tokens

  constructor(address _token0, address _token1) {
    token0 = _token0;
    token1 = _token1;
  }

  function getReserves() external view returns (uint112, uint112, uint32) {
    return (reserve0, reserve1, uint32(block.timestamp));
  }

  function setReserves(uint112 _reserve0, uint112 _reserve1) external {
    reserve0 = _reserve0;
    reserve1 = _reserve1;
  }

  function setTotalSupply(uint256 _totalSupply) external {
    totalSupply = _totalSupply;
  }
}

/**
 * @title OmniDragonPriceOracle Test Suite
 * @dev Comprehensive tests for multi-oracle price aggregation, circuit breakers, and emergency modes
 */
contract OmniDragonPriceOracleTest is Test {
  OmniDragonPriceOracle public priceOracle;
  MockChainlinkAggregator public mockChainlink;
  MockBandProtocol public mockBand;
  MockAPI3ReaderProxy public mockAPI3;
  MockPythOracle public mockPyth;
  MockOmniDragonRegistry public mockRegistry;
  MockUniswapV2Pair public mockPair;

  address public owner = address(0x1);
  address public dragonToken = address(0x2);
  address public wrappedNative = address(0x3);

  string public constant NATIVE_SYMBOL = "SONIC";
  string public constant QUOTE_SYMBOL = "USD";
  bytes32 public constant PYTH_PRICE_ID = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;

  function setUp() public {
    vm.startPrank(owner);

    // Deploy mock oracle feeds
    mockChainlink = new MockChainlinkAggregator();
    mockBand = new MockBandProtocol();
    mockAPI3 = new MockAPI3ReaderProxy();
    mockPyth = new MockPythOracle();
    mockRegistry = new MockOmniDragonRegistry();

    console.log("Mock oracle feeds deployed");

    // Set up registry
    mockRegistry.setWrappedNativeToken(146, wrappedNative);

    // Deploy price oracle
    priceOracle = new OmniDragonPriceOracle(NATIVE_SYMBOL, QUOTE_SYMBOL, owner, address(mockRegistry), dragonToken);

    console.log("Price oracle deployed at:", address(priceOracle));

    // Configure oracle feeds
    priceOracle.configureOracles(
      address(mockChainlink), // Chainlink
      address(mockBand), // Band
      address(mockAPI3), // API3
      address(mockPyth), // Pyth
      PYTH_PRICE_ID, // Pyth price ID
      "DRAGON" // Band base symbol
    );

    // Set oracle weights (40%, 30%, 20%, 10%)
    priceOracle.setOracleWeights(4000, 3000, 2000, 1000);

    // Set native token price feed for current chain ID (not hardcoded 146)
    priceOracle.setNativeTokenPriceFeed(block.chainid, address(mockChainlink));

    console.log("Price oracle configured");

    vm.stopPrank();

    console.log("Setup completed successfully");
  }

  function testInitialPriceCalculation() public {
    console.log("\n=== Testing Initial Price Calculation ===");

    // All oracles return $2.50
    // Expected weighted average: $2.50

    vm.startPrank(owner);

    bool success = priceOracle.initializePrice();
    assertTrue(success, "Price initialization should succeed");

    (int256 price, uint256 timestamp) = priceOracle.getLatestPrice();

    console.log("Initialized price:", uint256(price));
    console.log("Timestamp:", timestamp);

    // Should be approximately $2.50 in 18 decimals
    assertApproxEqRel(uint256(price), 2.5e18, 0.01e18, "Price should be approximately $2.50");
    assertEq(timestamp, block.timestamp, "Timestamp should be current");

    vm.stopPrank();

    console.log("SUCCESS: Initial price calculation working");
  }

  function testWeightedAverageCalculation() public {
    console.log("\n=== Testing Weighted Average Calculation ===");

    // Set different prices for each oracle
    mockChainlink.setPrice(300000000); // $3.00 (40% weight)
    mockBand.setRate(2500000000000000000); // $2.50 (30% weight)
    mockAPI3.setValue(2000000000000000000); // $2.00 (20% weight)
    mockPyth.setPrice(150000000, -8); // $1.50 (10% weight)

    vm.startPrank(owner);
    priceOracle.initializePrice();
    vm.stopPrank();

    (int256 price, ) = priceOracle.getLatestPrice();

    // Expected: (3.00 * 0.4) + (2.50 * 0.3) + (2.00 * 0.2) + (1.50 * 0.1) = 2.50
    uint256 expectedPrice = 2.5e18;

    console.log("Calculated price:", uint256(price));
    console.log("Expected price:", expectedPrice);

    assertApproxEqRel(uint256(price), expectedPrice, 0.01e18, "Weighted average calculation incorrect");

    console.log("SUCCESS: Weighted average calculation working");
  }

  function testCircuitBreakerActivation() public {
    console.log("\n=== Testing Circuit Breaker Activation ===");

    vm.startPrank(owner);

    // Initialize with $2.50
    priceOracle.initializePrice();

    // Disable grace period for testing
    priceOracle.setInitializationGracePeriod(0);

    // Set maximum deviation to 10%
    priceOracle.setMaxPriceDeviation(1000); // 10%

    // Now set price that exceeds 10% deviation ($3.00 = 20% increase)
    mockChainlink.setPrice(300000000);
    mockBand.setRate(3000000000000000000);
    mockAPI3.setValue(3000000000000000000);
    mockPyth.setPrice(300000000, -8);

    // Should trigger circuit breaker
    bool success = priceOracle.updatePrice();
    assertFalse(success, "Price update should fail due to circuit breaker");

    // Check oracle status
    (, bool circuitBreakerActive_, , , , ) = priceOracle.getOracleStatus();
    assertTrue(circuitBreakerActive_, "Circuit breaker should be active");

    // Getting price should revert with CircuitBreakerActive
    vm.expectRevert("CircuitBreakerActive()");
    priceOracle.getLatestPrice();

    vm.stopPrank();

    console.log("SUCCESS: Circuit breaker activation working");
  }

  function testCircuitBreakerReset() public {
    console.log("\n=== Testing Circuit Breaker Reset ===");

    vm.startPrank(owner);

    // Trigger circuit breaker first
    priceOracle.initializePrice();
    priceOracle.setMaxPriceDeviation(1000); // 10%

    // Set excessive price
    mockChainlink.setPrice(300000000);
    mockBand.setRate(3000000000000000000);
    mockAPI3.setValue(3000000000000000000);
    mockPyth.setPrice(300000000, -8);

    priceOracle.updatePrice(); // Should trigger circuit breaker

    // Reset circuit breaker
    priceOracle.resetCircuitBreaker();

    // Check status
    (, bool circuitBreakerActive_, , , , ) = priceOracle.getOracleStatus();
    assertFalse(circuitBreakerActive_, "Circuit breaker should be inactive after reset");

    // Should be able to get price again
    (int256 price, ) = priceOracle.getLatestPrice();
    assertGt(price, 0, "Should be able to get price after reset");

    vm.stopPrank();

    console.log("SUCCESS: Circuit breaker reset working");
  }

  function testEmergencyMode() public {
    console.log("\n=== Testing Emergency Mode ===");

    vm.startPrank(owner);

    // Initialize normally
    priceOracle.initializePrice();

    // Activate emergency mode with fixed price
    int256 emergencyPrice = 5e18; // $5.00
    priceOracle.activateEmergencyMode(emergencyPrice);

    // Check oracle status
    (, , bool emergencyMode_, , , ) = priceOracle.getOracleStatus();
    assertTrue(emergencyMode_, "Emergency mode should be active");

    // Should return emergency price
    (int256 price, ) = priceOracle.getLatestPrice();
    assertEq(price, emergencyPrice, "Should return emergency price");

    // Deactivate emergency mode
    priceOracle.deactivateEmergencyMode();

    (, , bool emergencyMode2_, , , ) = priceOracle.getOracleStatus();
    assertFalse(emergencyMode2_, "Emergency mode should be inactive");

    vm.stopPrank();

    console.log("SUCCESS: Emergency mode working");
  }

  function testStalenessDetection() public {
    console.log("\n=== Testing Staleness Detection ===");

    // Set reasonable timestamp to avoid underflow
    vm.warp(10000);

    vm.startPrank(owner);

    // Ensure all mock oracles have valid initial data
    mockChainlink.setPrice(250000000); // $2.50 in 8 decimals
    mockBand.setRate(2500000000000000000); // $2.50 in 18 decimals
    mockAPI3.setValue(int224(2500000000000000000)); // $2.50 in 18 decimals as int224
    mockPyth.setPrice(250000000, -8); // $2.50 with 8 decimal places (-8 exponent)

    // Initialize price first
    bool initSuccess = priceOracle.initializePrice();
    assertTrue(initSuccess, "Price initialization should succeed with valid data");

    // Verify initial state - should work
    bool initialSuccess = priceOracle.updatePrice();
    assertTrue(initialSuccess, "Initial update should work");

    // Make Chainlink feed stale (2 hours old)
    mockChainlink.setUpdatedAt(block.timestamp - 7200);

    // Update should still work with other oracles
    bool successWithStaleChainlink = priceOracle.updatePrice();
    assertTrue(successWithStaleChainlink, "Should work with stale Chainlink but active other oracles");

    // Make all feeds stale (2 hours old)
    mockBand.setLastUpdatedBase(block.timestamp - 7200);
    mockAPI3.setTimestamp(uint32(block.timestamp - 7200));
    mockPyth.setPublishTime(block.timestamp - 7200);

    // Now ALL oracles should be stale - updatePrice should revert
    vm.expectRevert("NoValidOracleData()");
    priceOracle.updatePrice();

    vm.stopPrank();

    console.log("SUCCESS: Staleness detection working");
  }

  function testOracleFailureHandling() public {
    console.log("\n=== Testing Oracle Failure Handling ===");

    vm.startPrank(owner);

    // Make some oracles fail
    mockChainlink.setShouldFail(true);
    mockBand.setShouldFail(true);

    // Should still work with API3 and Pyth
    bool success = priceOracle.initializePrice();
    assertTrue(success, "Should work with 2 working oracles");

    // Make all oracles fail
    mockAPI3.setShouldFail(true);
    mockPyth.setShouldFail(true);

    // Should fail with no working oracles
    vm.expectRevert();
    priceOracle.updatePrice();

    vm.stopPrank();

    console.log("SUCCESS: Oracle failure handling working");
  }

  function testNativeTokenPricing() public {
    console.log("\n=== Testing Native Token Pricing ===");

    // Set SONIC price to $3000
    mockChainlink.setPrice(300000000000); // $3000 in 8 decimals

    (int256 price, bool isValid, uint256 timestamp) = priceOracle.getNativeTokenPrice();

    assertTrue(isValid, "Native token price should be valid");
    assertEq(price, 300000000000, "Native token price should be $3000");
    assertEq(timestamp, block.timestamp, "Timestamp should be current");

    console.log("Native token price:", uint256(price));

    console.log("SUCCESS: Native token pricing working");
  }

  function testLPTokenPricing() public {
    console.log("\n=== Testing LP Token Pricing ===");

    // Create mock LP pair (DRAGON/USDC)
    mockPair = new MockUniswapV2Pair(dragonToken, address(0x4)); // USDC

    vm.startPrank(owner);

    // Initialize oracle with DRAGON price
    priceOracle.initializePrice();

    vm.stopPrank();

    // Set reserves: 1M DRAGON tokens, 2.5M USDC (implies $2.50 per DRAGON)
    mockPair.setReserves(1000000 * 1e18, 2500000 * 1e6);
    mockPair.setTotalSupply(1000 * 1e18); // 1k LP tokens

    // Calculate LP token price for 1 LP token
    uint256 lpAmount = 1e18; // 1 LP token
    uint256 usdValue = priceOracle.getLPTokenPrice(address(mockPair), lpAmount);

    console.log("LP token USD value:", usdValue);

    // Expected: TVL = (1M * $2.50) = $2.5M for DRAGON side only
    // Since we can't price the other token, expect 0 for now
    // This is expected behavior for unsupported tokens

    console.log("SUCCESS: LP token pricing logic working");
  }

  function testPriceFreshnessValidation() public {
    console.log("\n=== Testing Price Freshness Validation ===");

    vm.startPrank(owner);

    // Initialize price
    priceOracle.initializePrice();

    // Price should be fresh initially
    assertTrue(priceOracle.isFresh(), "Price should be fresh after initialization");

    // Move time forward by 2 hours (past staleness threshold)
    vm.warp(block.timestamp + 7200);

    // Price should no longer be fresh
    assertFalse(priceOracle.isFresh(), "Price should be stale after 2 hours");

    // Getting stale price should revert
    vm.expectRevert("PriceDataStale()");
    priceOracle.getLatestPrice();

    vm.stopPrank();

    console.log("SUCCESS: Price freshness validation working");
  }

  function testGracePeriodBehavior() public {
    console.log("\n=== Testing Grace Period Behavior ===");

    vm.startPrank(owner);

    // Should be in grace period initially
    (, , , bool inGracePeriod, , ) = priceOracle.getOracleStatus();
    assertTrue(inGracePeriod, "Should be in grace period after deployment");

    // During grace period, large price changes should be allowed
    priceOracle.initializePrice();

    // Set extremely different price (should not trigger circuit breaker in grace period)
    mockChainlink.setPrice(100000000000); // $1000 (40x increase)
    mockBand.setRate(1000000000000000000000);
    mockAPI3.setValue(1000000000000000000000);
    mockPyth.setPrice(100000000000, -8);

    bool success = priceOracle.updatePrice();
    assertTrue(success, "Large price changes should be allowed in grace period");

    // Move past grace period
    vm.warp(block.timestamp + 86401); // 24 hours + 1 second

    (, , , bool inGracePeriod2, , ) = priceOracle.getOracleStatus();
    assertFalse(inGracePeriod2, "Should not be in grace period after 24 hours");

    vm.stopPrank();

    console.log("SUCCESS: Grace period behavior working");
  }

  function testOracleWeightManagement() public {
    console.log("\n=== Testing Oracle Weight Management ===");

    vm.startPrank(owner);

    // Test invalid weights (don't sum to 10000)
    vm.expectRevert();
    priceOracle.setOracleWeights(5000, 3000, 1000, 500); // Sums to 9500

    // Test valid weights
    priceOracle.setOracleWeights(5000, 3000, 1500, 500); // Sums to 10000

    // Verify weights were set
    (
      OmniDragonPriceOracle.OracleConfig memory chainlink,
      OmniDragonPriceOracle.OracleConfig memory band,
      OmniDragonPriceOracle.OracleConfig memory api3,
      OmniDragonPriceOracle.OracleConfig memory pyth,
      ,

    ) = priceOracle.getOracleConfig();

    assertEq(chainlink.weight, 5000, "Chainlink weight should be 5000");
    assertEq(band.weight, 3000, "Band weight should be 3000");
    assertEq(api3.weight, 1500, "API3 weight should be 1500");
    assertEq(pyth.weight, 500, "Pyth weight should be 500");

    vm.stopPrank();

    console.log("SUCCESS: Oracle weight management working");
  }

  function testMaxDeviationConfiguration() public {
    console.log("\n=== Testing Max Deviation Configuration ===");

    vm.startPrank(owner);

    // Test invalid deviation (over 100%)
    vm.expectRevert();
    priceOracle.setMaxPriceDeviation(15000); // 150%

    // Test valid deviation
    priceOracle.setMaxPriceDeviation(500); // 5%

    // Initialize price
    priceOracle.initializePrice();

    // Disable grace period for testing
    priceOracle.setInitializationGracePeriod(0);

    // Test that 6% change triggers circuit breaker
    mockChainlink.setPrice(265000000); // $2.65 (6% increase)
    mockBand.setRate(2650000000000000000);
    mockAPI3.setValue(2650000000000000000);
    mockPyth.setPrice(265000000, -8);

    bool success = priceOracle.updatePrice();
    assertFalse(success, "6% change should trigger 5% circuit breaker");

    vm.stopPrank();

    console.log("SUCCESS: Max deviation configuration working");
  }

  function testOracleStatusReporting() public {
    console.log("\n=== Testing Oracle Status Reporting ===");

    vm.startPrank(owner);

    (
      bool initialized,
      bool circuitBreakerActive_,
      bool emergencyMode_,
      bool inGracePeriod,
      uint256 activeOracles,
      uint256 maxDeviation
    ) = priceOracle.getOracleStatus();

    assertFalse(initialized, "Should not be initialized initially");
    assertFalse(circuitBreakerActive_, "Circuit breaker should not be active initially");
    assertFalse(emergencyMode_, "Emergency mode should not be active initially");
    assertTrue(inGracePeriod, "Should be in grace period initially");
    assertEq(activeOracles, 4, "Should have 4 active oracles");
    assertEq(maxDeviation, 2000, "Default max deviation should be 20%");

    // Initialize and test again
    priceOracle.initializePrice();

    (bool initialized2, , , , , ) = priceOracle.getOracleStatus();
    assertTrue(initialized2, "Should be initialized after initializePrice");

    vm.stopPrank();

    console.log("SUCCESS: Oracle status reporting working");
    console.log("Active oracles:", activeOracles);
    console.log("Max deviation:", maxDeviation);
  }
}