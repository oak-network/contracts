# TimestampChecker
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts/blob/b6945e2b533f7d9aacb156ae915f6d1bb6b199de/src/utils/TimestampChecker.sol)

A contract that provides timestamp-related checks for contract functions.


## Functions
### currentTimeIsGreater

Modifier that checks if the current timestamp is greater than a specified time.


```solidity
modifier currentTimeIsGreater(uint256 inputTime);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`inputTime`|`uint256`|The timestamp being checked against.|


### currentTimeIsLess

Modifier that checks if the current timestamp is less than a specified time.


```solidity
modifier currentTimeIsLess(uint256 inputTime);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`inputTime`|`uint256`|The timestamp being checked against.|


### currentTimeIsWithinRange

Modifier that checks if the current timestamp is within a specified time range.


```solidity
modifier currentTimeIsWithinRange(uint256 initialTime, uint256 finalTime);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`initialTime`|`uint256`|The initial timestamp of the range.|
|`finalTime`|`uint256`|The final timestamp of the range.|


### _revertIfCurrentTimeIsNotLess

*Internal function to revert if the current timestamp is less than or equal a specified time.*


```solidity
function _revertIfCurrentTimeIsNotLess(uint256 inputTime) internal view virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`inputTime`|`uint256`|The timestamp being checked against.|


### _revertIfCurrentTimeIsNotGreater

*Internal function to revert if the current timestamp is not greater than or equal a specified time.*


```solidity
function _revertIfCurrentTimeIsNotGreater(uint256 inputTime) internal view virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`inputTime`|`uint256`|The timestamp being checked against.|


### _revertIfCurrentTimeIsNotWithinRange

*Internal function to revert if the current timestamp is not within a specified time range.*


```solidity
function _revertIfCurrentTimeIsNotWithinRange(uint256 initialTime, uint256 finalTime) internal view virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`initialTime`|`uint256`|The initial timestamp of the range.|
|`finalTime`|`uint256`|The final timestamp of the range.|


## Errors
### CurrentTimeIsGreater
*Error: The current timestamp is greater than the specified input time.*


```solidity
error CurrentTimeIsGreater(uint256 inputTime, uint256 currentTime);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`inputTime`|`uint256`|The timestamp being checked against.|
|`currentTime`|`uint256`|The current block timestamp.|

### CurrentTimeIsLess
*Error: The current timestamp is less than the specified input time.*


```solidity
error CurrentTimeIsLess(uint256 inputTime, uint256 currentTime);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`inputTime`|`uint256`|The timestamp being checked against.|
|`currentTime`|`uint256`|The current block timestamp.|

### CurrentTimeIsNotWithinRange
*Error: The current timestamp is not within the specified range.*


```solidity
error CurrentTimeIsNotWithinRange(uint256 initialTime, uint256 finalTime);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`initialTime`|`uint256`|The initial timestamp of the range.|
|`finalTime`|`uint256`|The final timestamp of the range.|

