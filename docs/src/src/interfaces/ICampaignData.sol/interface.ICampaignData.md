# ICampaignData
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/08a57a0930f80d6f45ee44fa43ce6ad3e6c3c5c5/src/interfaces/ICampaignData.sol)

An interface for managing campaign data in a CCP.


## Structs
### CampaignData
*Struct to represent campaign data, including launch time, deadline, goal amount, and currency.*


```solidity
struct CampaignData {
    uint256 launchTime;
    uint256 deadline;
    uint256 goalAmount;
    bytes32 currency;
}
```

