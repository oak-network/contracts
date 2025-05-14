# ICampaignData
[Git Source](https://github.com/ccprotocol/reference-client-sc/blob/32b7b1617200d0c6f3248845ef972180411f1f65/src/interfaces/ICampaignData.sol)

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

