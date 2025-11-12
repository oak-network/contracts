# IReward
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/e5024d64e3fbbb8a9ba5520b2280c0e3ebc75174/src/interfaces/IReward.sol)

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

