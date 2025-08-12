# ICampaignData
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/56580a82da87af15808145e03ffc25bd15b6454b/src/interfaces/ICampaignData.sol)

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

