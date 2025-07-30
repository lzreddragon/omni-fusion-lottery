// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MessagingReceipt, MessagingFee} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

/**
 * @title IChainlinkVRFIntegratorV2_5
 * @author 0xakita.eth
 * @notice Interface for cross-chain Chainlink VRF integration via LayerZero
 * @dev Enables secure cross-chain randomness for lottery systems
 */
interface IChainlinkVRFIntegratorV2_5 {
    /**
     * @notice Request random words via cross-chain VRF
     * @param destinationChainId The chain ID where VRF should be executed
     * @return receipt Messaging receipt from LayerZero
     * @return sequence Sequence number for tracking the request
     */
    function requestRandomWordsSimple(uint32 destinationChainId) external returns (
        MessagingReceipt memory receipt,
        uint64 sequence
    );
    
    /**
     * @notice Set authorization for a caller
     * @param caller Address to authorize
     * @param authorized Whether the caller is authorized
     */
    function setAuthorizedCaller(address caller, bool authorized) external;
    
    /**
     * @notice Check if a caller is authorized
     * @param caller Address to check
     * @return Whether the caller is authorized
     */
    function authorizedCallers(address caller) external view returns (bool);
    
    /**
     * @notice Get the messaging fee for a cross-chain VRF request
     * @param destinationChainId The destination chain ID
     * @return fee The messaging fee structure
     */
    function quote(uint32 destinationChainId) external view returns (MessagingFee memory fee);
}