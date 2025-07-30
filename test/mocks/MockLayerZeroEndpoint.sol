// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockLayerZeroEndpoint
 * @dev Mock LayerZero endpoint for testing purposes
 */
contract MockLayerZeroEndpoint {
    mapping(address => address) public delegates;
    
    function setDelegate(address _delegate) external {
        delegates[msg.sender] = _delegate;
    }
    
    function quote(
        // MessagingParams calldata _params,
        bytes calldata, // _params placeholder
        address // _sender
    ) external pure returns (uint256 nativeFee, uint256 lzTokenFee) {
        return (0.001 ether, 0); // Mock fees
    }
    
    function send(
        bytes calldata, // _params placeholder  
        address // _refundAddress
    ) external payable returns (bytes32 guid, uint64 nonce, uint256 fee) {
        return (keccak256(abi.encodePacked(block.timestamp, msg.sender)), uint64(block.number), msg.value);
    }
}