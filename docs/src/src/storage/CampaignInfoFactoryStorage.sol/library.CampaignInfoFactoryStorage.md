# CampaignInfoFactoryStorage
[Git Source](https://github.com/oak-network/ccprotocol-contracts-internal/blob/be3636c015d0f78c20f6d8f0de7b678aaf6d8428/src/storage/CampaignInfoFactoryStorage.sol)

Storage contract for CampaignInfoFactory using ERC-7201 namespaced storage

*This contract contains the storage layout and accessor functions for CampaignInfoFactory*


## State Variables
### CAMPAIGN_INFO_FACTORY_STORAGE_LOCATION

```solidity
bytes32 private constant CAMPAIGN_INFO_FACTORY_STORAGE_LOCATION =
    0x2857858a392b093e1f8b3f368c2276ce911f27cef445605a2932ebe945968d00;
```


## Functions
### _getCampaignInfoFactoryStorage


```solidity
function _getCampaignInfoFactoryStorage() internal pure returns (Storage storage $);
```

## Structs
### Storage
**Note:**
storage-location: erc7201:ccprotocol.storage.CampaignInfoFactory


```solidity
struct Storage {
    IGlobalParams globalParams;
    address treasuryFactoryAddress;
    address implementation;
    mapping(address => bool) isValidCampaignInfo;
    mapping(bytes32 => address) identifierToCampaignInfo;
}
```

