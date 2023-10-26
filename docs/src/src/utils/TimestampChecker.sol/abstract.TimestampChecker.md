# TimestampChecker
[Git Source](https://github.com/ccprotocol/campaign-utils-contracts-aggregator/blob/79d78188e565502f83e2c0309c9a4ea3b35cee91/src/utils/TimestampChecker.sol)

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


### _checkIfCurrentTimeIsGreater

*Internal function to check if the current timestamp is greater than a specified time.*


```solidity
function _checkIfCurrentTimeIsGreater(uint256 inputTime) internal view virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`inputTime`|`uint256`|The timestamp being checked against.|


### _checkIfCurrentTimeIsLess

*Internal function to check if the current timestamp is less than a specified time.*


```solidity
function _checkIfCurrentTimeIsLess(uint256 inputTime) internal view virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`inputTime`|`uint256`|The timestamp being checked against.|


### _checkIfCurrentTimeIsWithinRange

*Internal function to check if the current timestamp is within a specified time range.*


```solidity
function _checkIfCurrentTimeIsWithinRange(uint256 initialTime, uint256 finalTime) internal view virtual;
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

### CurrentTimeIsLess
*Error: The current timestamp is less than the specified input time.*


```solidity
error CurrentTimeIsLess(uint256 inputTime, uint256 currentTime);
```

### CurrentTimeIsNotWithinRange
*Error: The current timestamp is not within the specified range.*


```solidity
error CurrentTimeIsNotWithinRange(uint256 initialTime, uint256 finalTime);
```

