# ICampaignData
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/7ba93df0a979ce4ef420098855e6b4bfadbb6ecd/src/interfaces/ICampaignData.sol)

An interface for managing campaign data in a CCP.


## Structs
### CampaignData
*Struct to represent campaign data, including launch time, deadline, and goal amount.*


```solidity
struct CampaignData {
    uint256 launchTime;
    uint256 deadline;
    uint256 goalAmount;
}
```

