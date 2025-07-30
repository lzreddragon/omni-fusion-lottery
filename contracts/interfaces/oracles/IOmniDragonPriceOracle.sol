// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IOmniDragonPriceOracle
 * @author 0xakita.eth
 * @notice Interface for Dragon ecosystem price oracle
 * @dev Provides secure price feeds for DRAGON token and native tokens
 */
interface IOmniDragonPriceOracle {
    /**
     * @notice Get aggregated DRAGON token price in USD
     * @return price Price in USD with 8 decimal places
     * @return success Whether the price fetch was successful
     * @return timestamp When the price was last updated
     */
    function getAggregatedPrice() external view returns (
        int256 price,
        bool success,
        uint256 timestamp
    );
    
    /**
     * @notice Get native token price in USD (ETH, SONIC, AVAX, etc.)
     * @return price Price in USD with 8 decimal places
     * @return success Whether the price fetch was successful
     * @return timestamp When the price was last updated
     */
    function getNativeTokenPrice() external view returns (
        int256 price,
        bool success,
        uint256 timestamp
    );
    
    /**
     * @notice Get price for a specific token
     * @param token Token address to get price for
     * @return price Price in USD with 8 decimal places
     * @return success Whether the price fetch was successful
     * @return timestamp When the price was last updated
     */
    function getTokenPrice(address token) external view returns (
        int256 price,
        bool success,
        uint256 timestamp
    );
    
    /**
     * @notice Check if oracle is healthy and providing fresh data
     * @return healthy Whether the oracle is functioning properly
     */
    function isOracleHealthy() external view returns (bool healthy);
    
    /**
     * @notice Get the maximum age for price data before it's considered stale
     * @return maxAge Maximum age in seconds
     */
    function getMaxPriceAge() external view returns (uint256 maxAge);
    
    /**
     * @notice Get the number of price sources being aggregated
     * @return count Number of active price sources
     */
    function getPriceSourceCount() external view returns (uint256 count);
    
    /**
     * @notice Get deviation threshold for price updates
     * @return threshold Deviation threshold in basis points
     */
    function getDeviationThreshold() external view returns (uint256 threshold);
}