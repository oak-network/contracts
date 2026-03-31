// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title TreasuryErrors
 * @notice Shared error-code enums for all treasury contracts
 */
library TreasuryErrors {
    /// @notice Codes for `InvalidInput` errors (input-validation failures).
    enum InvalidInput {
        INVALID_LINE_ITEM,
        LINE_ITEM_TYPE_NOT_FOUND,
        EMPTY_SIGNATURE,
        INVALID_BACKER,
        CONFIRM_BATCH_LENGTH_MISMATCH,
        ZERO_REFUND_ADDRESS,
        ZERO_CLAIMABLE_AMOUNT,
        REWARD_NOT_FOUND,
        REWARD_LENGTH_MISMATCH,
        INVALID_PLEDGE_INPUT,
        ZERO_REWARD_NAME,
        FEE_LENGTH_MISMATCH,
        INVALID_DEADLINE,
        ZERO_GOAL_AMOUNT,
        INVALID_REWARD_INPUT,
        ZERO_TOKEN_SOURCE,
        ZERO_AMOUNT,
        INSUFFICIENT_RECEIVED
    }

    /// @notice Codes for `NotClaimable` errors (refund / claim-check failures).
    enum NotClaimable {
        REFUND_ZERO_AMOUNT,
        INSUFFICIENT_LIQUIDITY,
        REFUND_ZERO_ADDRESS,
        NOT_NFT_PAYMENT,
        INSUFFICIENT_GOAL_LIQUIDITY,
        INSUFFICIENT_NON_GOAL_LIQUIDITY,
        INSUFFICIENT_CONTRACT_BALANCE,
        CAMPAIGN_SUCCESSFUL,
        INVALID_REFUND_PERIOD
    }
}
