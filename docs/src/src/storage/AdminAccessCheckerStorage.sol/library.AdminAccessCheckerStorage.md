# AdminAccessCheckerStorage
[Git Source](https://github.com/oak-network/contracts/blob/0ce055a8ba31ca09404e9d09ecd2549534cbec61/src/storage/AdminAccessCheckerStorage.sol)

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

