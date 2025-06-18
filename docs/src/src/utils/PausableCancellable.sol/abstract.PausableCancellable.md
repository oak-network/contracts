# PausableCancellable
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/7ba93df0a979ce4ef420098855e6b4bfadbb6ecd/src/utils/PausableCancellable.sol)

Abstract contract providing pause and cancel state management with events and modifiers


## State Variables
### _paused

```solidity
bool private _paused;
```


### _cancelled

```solidity
bool private _cancelled;
```


## Functions
### whenNotPaused

Modifier to allow function only when not paused


```solidity
modifier whenNotPaused();
```

### whenPaused

Modifier to allow function only when paused


```solidity
modifier whenPaused();
```

### whenNotCancelled

Modifier to allow function only when not cancelled


```solidity
modifier whenNotCancelled();
```

### whenCancelled

Modifier to allow function only when cancelled


```solidity
modifier whenCancelled();
```

### paused

Returns true if the contract is currently paused


```solidity
function paused() public view virtual returns (bool);
```

### cancelled

Returns true if the contract has been cancelled


```solidity
function cancelled() public view virtual returns (bool);
```

### _pause

Pauses the contract

*Can only pause if not already paused or cancelled*


```solidity
function _pause(bytes32 reason) internal virtual whenNotPaused whenNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`reason`|`bytes32`|A short reason for pausing|


### _unpause

Unpauses the contract

*Can only unpause if currently paused*


```solidity
function _unpause(bytes32 reason) internal virtual whenPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`reason`|`bytes32`|A short reason for unpausing|


### _cancel

Cancels the contract permanently

*Auto-unpauses if paused, and cannot be undone*


```solidity
function _cancel(bytes32 reason) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`reason`|`bytes32`|A short reason for cancellation|


## Events
### Paused
Emitted when contract is paused


```solidity
event Paused(address indexed account, bytes32 reason);
```

### Unpaused
Emitted when contract is unpaused


```solidity
event Unpaused(address indexed account, bytes32 reason);
```

### Cancelled
Emitted when contract is cancelled


```solidity
event Cancelled(address indexed account, bytes32 reason);
```

## Errors
### PausedError
*Reverts if contract is paused*


```solidity
error PausedError();
```

### NotPausedError
*Reverts if contract is not paused*


```solidity
error NotPausedError();
```

### CancelledError
*Reverts if contract is cancelled*


```solidity
error CancelledError();
```

### NotCancelledError
*Reverts if contract is not cancelled*


```solidity
error NotCancelledError();
```

### CannotCancel
*Reverts if contract is already cancelled*


```solidity
error CannotCancel();
```

