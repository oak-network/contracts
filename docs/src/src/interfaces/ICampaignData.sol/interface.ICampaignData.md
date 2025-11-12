# ICampaignData
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/fbdbad195ebe6c636608bb8168723963b1f37dd9/src/interfaces/ICampaignData.sol)

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

