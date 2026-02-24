// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title IKarmaTreasury
 * @notice Treasury interface for reading raised amount (e.g. PaymentTreasury).
 * @dev Used by KARMA to determine how many tokens can be claimed via claimTokens().
 */
interface IKarmaTreasury {
    /**
     * @notice Returns the total raised amount (e.g. confirmed payments, normalized).
     * @return The total raised amount as a uint256 value.
     */
    function getRaisedAmount() external view returns (uint256);
}
