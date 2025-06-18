# IReward
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/7ba93df0a979ce4ef420098855e6b4bfadbb6ecd/src/interfaces/IReward.sol)

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

