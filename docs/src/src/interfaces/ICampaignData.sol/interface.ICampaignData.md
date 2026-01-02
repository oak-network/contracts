# ICampaignData
[Git Source](https://github.com/oak-network/contracts/blob/0ce055a8ba31ca09404e9d09ecd2549534cbec61/src/interfaces/ICampaignData.sol)

An interface for managing campaign data in a CCP.


## Structs
### CampaignData
Struct to represent campaign data, including launch time, deadline, goal amount, and currency.


```solidity
struct CampaignData {
    uint256 launchTime; // Timestamp when the campaign is launched.
    uint256 deadline; // Timestamp or block number when the campaign ends.
    uint256 goalAmount; // Funding goal amount that the campaign aims to achieve.
    bytes32 currency; // Currency identifier for the campaign (e.g., bytes32("USD")).
}
```

