# ICampaignData
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/7ac353e6507e46c7ee7bc7cb49a3fb20dfde2b56/src/interfaces/ICampaignData.sol)

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

