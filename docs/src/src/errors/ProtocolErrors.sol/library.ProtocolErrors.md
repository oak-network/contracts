# ProtocolErrors
[Git Source](https://github.com/oak-network/contracts/blob/6c7f67f5ed14ef0f4f9444b95ac6770ae2af756a/src/errors/ProtocolErrors.sol)

**Title:**
ProtocolErrors

Shared error-code enums for GlobalParams, CampaignInfo, and CampaignInfoFactory invalid-input reverts.


## Enums
### GlobalParamsInvalidInput
Codes for `GlobalParamsInvalidInput` (input-validation failures).


```solidity
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
```

### CampaignInfoInvalidInput
Codes for `CampaignInfoInvalidInput` (input-validation failures).


```solidity
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
```

### CampaignInfoFactoryInvalidInput
Codes for `CampaignInfoFactoryInvalidInput` (input-validation failures).


```solidity
enum CampaignInfoFactoryInvalidInput {
    ZERO_CREATOR,
    PLATFORM_DATA_LENGTH_MISMATCH,
    LAUNCH_TIME_TOO_SOON,
    DEADLINE_TOO_SOON,
    INVALID_PLATFORM_DATA_KEY,
    ZERO_PLATFORM_DATA_VALUE,
    ZERO_IMPLEMENTATION
}
```

