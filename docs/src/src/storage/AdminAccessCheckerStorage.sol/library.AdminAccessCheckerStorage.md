# AdminAccessCheckerStorage
[Git Source](https://github.com/oak-network/contracts/blob/6c7f67f5ed14ef0f4f9444b95ac6770ae2af756a/src/storage/AdminAccessCheckerStorage.sol)

**Title:**
AdminAccessCheckerStorage

Storage contract for AdminAccessChecker using ERC-7201 namespaced storage

This contract contains the storage layout and accessor functions for AdminAccessChecker


## Constants
### ADMIN_ACCESS_CHECKER_STORAGE_LOCATION

```solidity
bytes32 private constant ADMIN_ACCESS_CHECKER_STORAGE_LOCATION =
    0x7608703513d219ecdd1e84aa0951e3c83cfe601f872259e1340c97792f4b8200
```


## Functions
### _getAdminAccessCheckerStorage


```solidity
function _getAdminAccessCheckerStorage() internal pure returns (Storage storage $);
```

## Structs
### Storage
**Note:**
storage-location: erc7201:oaknetwork.storage.AdminAccessChecker


```solidity
struct Storage {
    IGlobalParams globalParams;
}
```

