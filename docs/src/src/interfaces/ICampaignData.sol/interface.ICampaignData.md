# ICampaignData
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts/blob/b6945e2b533f7d9aacb156ae915f6d1bb6b199de/src/interfaces/ICampaignData.sol)

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

