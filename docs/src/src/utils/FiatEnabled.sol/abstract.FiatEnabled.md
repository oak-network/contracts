# FiatEnabled
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/08a57a0930f80d6f45ee44fa43ce6ad3e6c3c5c5/src/utils/FiatEnabled.sol)

A contract that provides functionality for tracking and managing fiat transactions.
This contract allows tracking the amount of fiat raised, individual fiat transactions, and the state of fiat fee disbursement.


## State Variables
### s_fiatRaisedAmount

```solidity
uint256 internal s_fiatRaisedAmount;
```


### s_fiatFeeIsDisbursed

```solidity
bool internal s_fiatFeeIsDisbursed;
```


### s_fiatAmountById

```solidity
mapping(bytes32 => uint256) internal s_fiatAmountById;
```


## Functions
### getFiatRaisedAmount

Get the total amount of fiat raised.


```solidity
function getFiatRaisedAmount() public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total fiat raised amount.|


### getFiatTransactionAmount

Get the amount of a specific fiat transaction.


```solidity
function getFiatTransactionAmount(bytes32 fiatTransactionId) external view returns (uint256 amount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fiatTransactionId`|`bytes32`|The unique identifier of the fiat transaction.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of the specified fiat transaction.|


### checkIfFiatFeeDisbursed

Check if the fiat fee has been disbursed.


```solidity
function checkIfFiatFeeDisbursed() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the fiat fee has been disbursed; otherwise, false.|


### _updateFiatTransaction

Update the details of a fiat transaction.


```solidity
function _updateFiatTransaction(bytes32 fiatTransactionId, uint256 fiatTransactionAmount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fiatTransactionId`|`bytes32`|The unique identifier of the fiat transaction.|
|`fiatTransactionAmount`|`uint256`|The amount of the fiat transaction.|


### _updateFiatFeeDisbursementState

*Update the state of fiat fee disbursement.*


```solidity
function _updateFiatFeeDisbursementState(bool isDisbursed, uint256 protocolFeeAmount, uint256 platformFeeAmount)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`isDisbursed`|`bool`|True if the fiat fee is disbursed; otherwise, false.|
|`protocolFeeAmount`|`uint256`|The protocol fee amount.|
|`platformFeeAmount`|`uint256`|The platform fee amount.|


## Events
### FiatTransactionUpdated
Emitted when a fiat transaction is updated.


```solidity
event FiatTransactionUpdated(bytes32 indexed fiatTransactionId, uint256 fiatTransactionAmount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fiatTransactionId`|`bytes32`|The unique identifier of the fiat transaction.|
|`fiatTransactionAmount`|`uint256`|The updated amount of the fiat transaction.|

### FiatFeeDisbusementStateUpdated
Emitted when the state of fiat fee disbursement is updated.


```solidity
event FiatFeeDisbusementStateUpdated(bool isDisbursed, uint256 protocolFeeAmount, uint256 platformFeeAmount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`isDisbursed`|`bool`|True if the fiat fee is disbursed; otherwise, false.|
|`protocolFeeAmount`|`uint256`|The protocol fee amount.|
|`platformFeeAmount`|`uint256`|The platform fee amount.|

## Errors
### FiatEnabledAlreadySet
*Throws an error indicating that the fiat enabled functionality is already set.*


```solidity
error FiatEnabledAlreadySet();
```

### FiatEnabledDisallowedState
*Throws an error indicating that the fiat enabled functionality is in an invalid state.*


```solidity
error FiatEnabledDisallowedState();
```

### FiatEnabledInvalidTransaction
*Throws an error indicating that the fiat transaction is invalid.*


```solidity
error FiatEnabledInvalidTransaction();
```

