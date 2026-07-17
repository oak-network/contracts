# IReward
[Git Source](https://github.com/oak-network/contracts/blob/6c7f67f5ed14ef0f4f9444b95ac6770ae2af756a/src/interfaces/IReward.sol)

**Title:**
IReward

An interface for managing rewards in a campaign.


## Structs
### Reward

```solidity
struct Reward {
    uint256 rewardValue;
    bool isRewardTier;
    bool canBeAddOn;
    bytes32[] itemId;
    uint256[] itemValue;
    uint256[] itemQuantity;
}
```

