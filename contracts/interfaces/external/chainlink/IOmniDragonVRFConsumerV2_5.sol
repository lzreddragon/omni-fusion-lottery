// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IOmniDragonVRFConsumerV2_5
 * @author 0xakita.eth
 * @notice Interface for local Chainlink VRF consumer
 * @dev Handles direct VRF requests on the local chain
 */
interface IOmniDragonVRFConsumerV2_5 {
    /**
     * @notice Request random words from local Chainlink VRF
     * @return requestId The VRF request ID
     */
    function requestRandomWordsLocal() external returns (uint256 requestId);
    
    /**
     * @notice Set local caller authorization
     * @param caller Address to authorize
     * @param authorized Whether the caller is authorized
     */
    function setLocalCallerAuthorization(address caller, bool authorized) external;
    
    /**
     * @notice Check if a caller is authorized for local requests
     * @param caller Address to check
     * @return Whether the caller is authorized
     */
    function localAuthorizedCallers(address caller) external view returns (bool);
    
    /**
     * @notice Get the fee for a local VRF request
     * @return fee The fee in native tokens
     */
    function getRequestFee() external view returns (uint256 fee);
}