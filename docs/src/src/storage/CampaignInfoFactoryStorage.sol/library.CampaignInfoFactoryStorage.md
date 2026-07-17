# CampaignInfoFactoryStorage
[Git Source](https://github.com/oak-network/contracts/blob/6c7f67f5ed14ef0f4f9444b95ac6770ae2af756a/src/storage/CampaignInfoFactoryStorage.sol)

**Title:**
CampaignInfoFactoryStorage

Storage contract for CampaignInfoFactory using ERC-7201 namespaced storage

This contract contains the storage layout and accessor functions for CampaignInfoFactory


## Constants
### CAMPAIGN_INFO_FACTORY_STORAGE_LOCATION

```solidity
bytes32 private constant CAMPAIGN_INFO_FACTORY_STORAGE_LOCATION =
    0x6dcebba7d782f7ff546a8ee2af2a142213ed91f5c14e411be41cf3be65358c00
```


## Functions
### _getCampaignInfoFactoryStorage


```solidity
function _getCampaignInfoFactoryStorage() internal pure returns (Storage storage $);
```

## Structs
### Storage
**Note:**
storage-location: erc7201:oaknetwork.storage.CampaignInfoFactory


```solidity
struct Storage {
    IGlobalParams globalParams;
    address treasuryFactoryAddress;
    address implementation;
    mapping(address => bool) isValidCampaignInfo;
    mapping(bytes32 => address) identifierToCampaignInfo;
}
```

