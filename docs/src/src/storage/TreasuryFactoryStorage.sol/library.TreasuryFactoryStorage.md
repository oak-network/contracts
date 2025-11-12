# TreasuryFactoryStorage
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/fbdbad195ebe6c636608bb8168723963b1f37dd9/src/storage/TreasuryFactoryStorage.sol)

Storage contract for TreasuryFactory using ERC-7201 namespaced storage

This contract contains the storage layout and accessor functions for TreasuryFactory


## State Variables
### TREASURY_FACTORY_STORAGE_LOCATION

```solidity
bytes32 private constant TREASURY_FACTORY_STORAGE_LOCATION =
    0x96b7de8c171ef460648aea35787d043e89feb6b6de2623a1e6f17a91b9c9e900
```


## Functions
### _getTreasuryFactoryStorage


```solidity
function _getTreasuryFactoryStorage() internal pure returns (Storage storage $);
```

## Structs
### Storage
**Note:**
storage-location: erc7201:ccprotocol.storage.TreasuryFactory


```solidity
struct Storage {
    mapping(bytes32 => mapping(uint256 => address)) implementationMap;
    mapping(address => bool) approvedImplementations;
}
```

