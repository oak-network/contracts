// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./AllOrNothing.sol";

/**
 * @title KeepWhatsRaised
 * @notice A contract that keeps all the funds raised, regardless of the success condition.
 * @dev This contract inherits from the `AllOrNothing` contract and overrides the `_checkSuccessCondition` function to always return true.
 */
contract KeepWhatsRaised is AllOrNothing {
    /**
     * @dev Initializes the KeepWhatsRaised contract.
     * @param platformBytes The unique identifier of the platform.
     * @param infoAddress The address of the associated campaign information contract.
     */
    constructor(
        bytes32 platformBytes,
        address infoAddress
    ) AllOrNothing(platformBytes, infoAddress) {}

    /**
     * @dev Overrides the success condition check to always return true.
     * @return Always returns true to keep all funds raised.
     */
    function _checkSuccessCondition() internal pure override returns (bool) {
        return true;
    }
}
