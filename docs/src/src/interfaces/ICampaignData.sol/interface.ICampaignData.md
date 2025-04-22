# ICampaignData
[Git Source](https://github.com/ccprotocol/reference-client-sc/blob/13d9d746c7f79b76f03c178fe64b679ba803191a/src/interfaces/ICampaignData.sol)

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

