# IReward
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts/blob/b6945e2b533f7d9aacb156ae915f6d1bb6b199de/src/interfaces/IReward.sol)

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

