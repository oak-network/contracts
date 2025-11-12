# AdminAccessCheckerStorage
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/e5024d64e3fbbb8a9ba5520b2280c0e3ebc75174/src/storage/AdminAccessCheckerStorage.sol)

Storage contract for AdminAccessChecker using ERC-7201 namespaced storage

This contract contains the storage layout and accessor functions for AdminAccessChecker


## State Variables
### ADMIN_ACCESS_CHECKER_STORAGE_LOCATION

```solidity
bytes32 private constant ADMIN_ACCESS_CHECKER_STORAGE_LOCATION =
    0x7c2f08fa04c2c7c7ab255a45dbf913d4c236b91c59858917e818398e997f8800
```


## Functions
### _getAdminAccessCheckerStorage


```solidity
function _getAdminAccessCheckerStorage() internal pure returns (Storage storage $);
```

## Structs
### Storage
**Note:**
storage-location: erc7201:ccprotocol.storage.AdminAccessChecker


```solidity
struct Storage {
    IGlobalParams globalParams;
}
```

