// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title ProtocolErrors
 * @notice Shared error-code enums for GlobalParams, CampaignInfo, and CampaignInfoFactory invalid-input reverts.
 */
library ProtocolErrors {
    /// @notice Codes for `GlobalParamsInvalidInput` (input-validation failures).
    enum GlobalParamsInvalidInput {
        ZERO_TOKEN,
        ZERO_REGISTRY_KEY,
        ZERO_PLATFORM_HASH,
        ZERO_PLATFORM_DATA_KEY,
        ZERO_CURRENCY,
        ZERO_LINE_ITEM_TYPE_ID,
        LINE_ITEM_GOAL_APPLIES_PROTOCOL_FEE,
        LINE_ITEM_GOAL_NOT_REFUNDABLE,
        LINE_ITEM_GOAL_INSTANT_TRANSFER,
        LINE_ITEM_NON_GOAL_INSTANT_REFUNDABLE,
        ZERO_ADDRESS
    }

    /// @notice Codes for `CampaignInfoInvalidInput` (input-validation failures).
    enum CampaignInfoInvalidInput {
        DUPLICATE_ACCEPTED_TOKEN,
        PLATFORM_DATA_NOT_SET,
        INVALID_LAUNCH_TIME,
        INVALID_DEADLINE,
        ZERO_GOAL_AMOUNT,
        PLATFORM_SELECTION_UNCHANGED,
        PLATFORM_DATA_LENGTH_MISMATCH,
        INVALID_PLATFORM_DATA_KEY,
        ZERO_PLATFORM_DATA_VALUE
    }

    /// @notice Codes for `CampaignInfoFactoryInvalidInput` (input-validation failures).
    enum CampaignInfoFactoryInvalidInput {
        ZERO_CREATOR,
        PLATFORM_DATA_LENGTH_MISMATCH,
        LAUNCH_TIME_TOO_SOON,
        DEADLINE_TOO_SOON,
        INVALID_PLATFORM_DATA_KEY,
        ZERO_PLATFORM_DATA_VALUE,
        ZERO_IMPLEMENTATION
    }
}
