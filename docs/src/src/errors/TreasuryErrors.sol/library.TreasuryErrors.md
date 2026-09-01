# TreasuryErrors
[Git Source](https://github.com/oak-network/contracts/blob/6c7f67f5ed14ef0f4f9444b95ac6770ae2af756a/src/errors/TreasuryErrors.sol)

**Title:**
TreasuryErrors

Shared error-code enums for all treasury contracts


## Enums
### InvalidInput
Codes for `InvalidInput` errors (input-validation failures).


```solidity
enum InvalidInput {
    INVALID_LINE_ITEM,
    LINE_ITEM_TYPE_NOT_FOUND,
    EMPTY_SIGNATURE,
    INVALID_BUYER,
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
    ZERO_AMOUNT
}
```

### NotClaimable
Codes for `NotClaimable` errors (refund / claim-check failures).


```solidity
enum NotClaimable {
    ZERO_REFUND_AMOUNT,
    INSUFFICIENT_LIQUIDITY,
    ZERO_REFUND_ADDRESS,
    NOT_NFT_PAYMENT,
    INSUFFICIENT_GOAL_LIQUIDITY,
    INSUFFICIENT_NON_GOAL_LIQUIDITY,
    INSUFFICIENT_CONTRACT_BALANCE,
    CAMPAIGN_SUCCESSFUL,
    INVALID_REFUND_PERIOD
}
```

