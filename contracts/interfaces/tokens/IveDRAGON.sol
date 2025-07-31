// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IveDRAGON
 * @dev Interface for vote-escrowed DRAGON token
 *
 * Provides voting power tracking and delegation functionality
 * Core component of the OmniDragon governance system
 * https://x.com/sonicreddragon
 * https://t.me/sonicreddragon
 */
interface IveDRAGON {
  /**
   * @notice Get the total voting power across all users
   * @return The total voting power
   */
  function getTotalVotingPower() external view returns (uint256);

  /**
   * @notice Get a user's voting power at a specific timestamp
   * @param user The user address
   * @param timestamp The timestamp to check voting power at
   * @return The user's voting power at the given timestamp
   */
  function getVotingPowerAt(address user, uint256 timestamp) external view returns (uint256);

  /**
   * @notice Get a user's current voting power
   * @param user The user address
   * @return The user's current voting power
   */
  function getVotingPower(address user) external view returns (uint256);

  /**
   * @notice Lock DRAGON tokens to get veDRAGON voting power
   * @param amount The amount of DRAGON tokens to lock
   * @param lockDuration The duration to lock tokens (in seconds)
   */
  function lock(uint256 amount, uint256 lockDuration) external;

  /**
   * @notice Extend the lock duration for existing veDRAGON
   * @param newLockDuration The new lock duration (must be longer than current)
   */
  function extendLock(uint256 newLockDuration) external;

  /**
   * @notice Increase the amount of locked DRAGON tokens
   * @param amount Additional amount of DRAGON tokens to lock
   */
  function increaseLock(uint256 amount) external;

  /**
   * @notice Withdraw unlocked DRAGON tokens (after lock period expires)
   */
  function withdraw() external;

  /**
   * @notice Get lock information for a user
   * @param user The user address
   * @return amount The amount of locked DRAGON tokens
   * @return unlockTime The timestamp when tokens can be withdrawn
   */
  function getLockInfo(address user) external view returns (uint256 amount, uint256 unlockTime);

  /**
   * @notice Check if a user's lock has expired
   * @param user The user address
   * @return True if the lock has expired
   */
  function isLockExpired(address user) external view returns (bool);
}