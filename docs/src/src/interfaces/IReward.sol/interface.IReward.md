# IReward
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/fbdbad195ebe6c636608bb8168723963b1f37dd9/src/interfaces/IReward.sol)

An interface for managing rewards in a campaign.


## Structs
### Reward

```solidity
struct Reward {
    uint256 rewardValue;
    bool isRewardTier;
    bytes32[] itemId;
    uint256[] itemValue;
    uint256[] itemQuantity;
}
```

