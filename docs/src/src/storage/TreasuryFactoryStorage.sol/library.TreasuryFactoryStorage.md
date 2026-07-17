# TreasuryFactoryStorage
[Git Source](https://github.com/oak-network/contracts/blob/6c7f67f5ed14ef0f4f9444b95ac6770ae2af756a/src/storage/TreasuryFactoryStorage.sol)

**Title:**
TreasuryFactoryStorage

Storage contract for TreasuryFactory using ERC-7201 namespaced storage

This contract contains the storage layout and accessor functions for TreasuryFactory


## Constants
### TREASURY_FACTORY_STORAGE_LOCATION

```solidity
bytes32 private constant TREASURY_FACTORY_STORAGE_LOCATION =
    0xac5f58af051caf3154d38fdfab53396f7d32e9ef6bb41b866435ed38c5426600
```


## Functions
### _getTreasuryFactoryStorage


```solidity
function _getTreasuryFactoryStorage() internal pure returns (Storage storage $);
```

## Structs
### Storage
**Note:**
storage-location: erc7201:oaknetwork.storage.TreasuryFactory


```solidity
struct Storage {
    mapping(bytes32 => mapping(uint256 => address)) implementationMap;
    mapping(address => bool) approvedImplementations;
    address campaignInfoFactory;
}
```

