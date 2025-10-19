// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title TimestampChecker
 * @notice A contract that provides timestamp-related checks for contract functions.
 */
abstract contract TimestampChecker {
    /**
     * @dev Error: The current timestamp is greater than the specified input time.
     * @param inputTime The timestamp being checked against.
     * @param currentTime The current block timestamp.
     */
    error CurrentTimeIsGreater(uint256 inputTime, uint256 currentTime);

    /**
     * @dev Error: The current timestamp is less than the specified input time.
     * @param inputTime The timestamp being checked against.
     * @param currentTime The current block timestamp.
     */
    error CurrentTimeIsLess(uint256 inputTime, uint256 currentTime);

    /**
     * @dev Error: The current timestamp is not within the specified range.
     * @param initialTime The initial timestamp of the range.
     * @param finalTime The final timestamp of the range.
     */
    error CurrentTimeIsNotWithinRange(uint256 initialTime, uint256 finalTime);

    /**
     * @notice Modifier that checks if the current timestamp is greater than a specified time.
     * @param inputTime The timestamp being checked against.
     */
    modifier currentTimeIsGreater(uint256 inputTime) {
        _revertIfCurrentTimeIsNotGreater(inputTime);
        _;
    }

    /**
     * @notice Modifier that checks if the current timestamp is less than a specified time.
     * @param inputTime The timestamp being checked against.
     */
    modifier currentTimeIsLess(uint256 inputTime) {
        _revertIfCurrentTimeIsNotLess(inputTime);
        _;
    }

    /**
     * @notice Modifier that checks if the current timestamp is within a specified time range.
     * @param initialTime The initial timestamp of the range.
     * @param finalTime The final timestamp of the range.
     */
    modifier currentTimeIsWithinRange(uint256 initialTime, uint256 finalTime) {
        _revertIfCurrentTimeIsNotWithinRange(initialTime, finalTime);
        _;
    }

    /**
     * @dev Internal function to revert if the current timestamp is less than or equal a specified time.
     * @param inputTime The timestamp being checked against.
     */
    function _revertIfCurrentTimeIsNotLess(
        uint256 inputTime
    ) internal view virtual {
        uint256 currentTime = block.timestamp;
        if (currentTime >= inputTime) {
            revert CurrentTimeIsGreater(inputTime, currentTime);
        }
    }

    /**
     * @dev Internal function to revert if the current timestamp is not greater than or equal a specified time.
     * @param inputTime The timestamp being checked against.
     */
    function _revertIfCurrentTimeIsNotGreater(
        uint256 inputTime
    ) internal view virtual {
        uint256 currentTime = block.timestamp;
        if (currentTime <= inputTime) {
            revert CurrentTimeIsLess(inputTime, currentTime);
        }
    }

    /**
     * @dev Internal function to revert if the current timestamp is not within a specified time range.
     * @param initialTime The initial timestamp of the range.
     * @param finalTime The final timestamp of the range.
     */
    function _revertIfCurrentTimeIsNotWithinRange(
        uint256 initialTime,
        uint256 finalTime
    ) internal view virtual {
        uint256 currentTime = block.timestamp;
        if (currentTime < initialTime || currentTime > finalTime) {
            revert CurrentTimeIsNotWithinRange(initialTime, finalTime);
        }
    }
}
