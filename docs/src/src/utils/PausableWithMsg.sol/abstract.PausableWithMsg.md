# PausableWithMsg
[Git Source](https://github.com/ccprotocol/campaign-utils-contracts-aggregator/blob/79d78188e565502f83e2c0309c9a4ea3b35cee91/src/utils/PausableWithMsg.sol)


## State Variables
### _paused

```solidity
bool private _paused;
```


## Functions
### constructor

*Initializes the contract in unpaused state.*


```solidity
constructor();
```

### whenNotPaused

*Modifier to make a function callable only when the contract is not paused.
Requirements:
- The contract must not be paused.*


```solidity
modifier whenNotPaused();
```

### whenPaused

*Modifier to make a function callable only when the contract is paused.
Requirements:
- The contract must be paused.*


```solidity
modifier whenPaused();
```

### paused

*Returns true if the contract is paused, and false otherwise.*


```solidity
function paused() public view virtual returns (bool);
```

### _requireNotPaused

*Throws if the contract is paused.*


```solidity
function _requireNotPaused() internal view virtual;
```

### _requirePaused

*Throws if the contract is not paused.*


```solidity
function _requirePaused() internal view virtual;
```

### _pause

*Triggers stopped state.
Requirements:
- The contract must not be paused.*


```solidity
function _pause(bytes32 message) internal virtual whenNotPaused;
```

### _unpause

*Returns to normal state.
Requirements:
- The contract must be paused.*


```solidity
function _unpause(bytes32 message) internal virtual whenPaused;
```

## Events
### Paused
*Emitted when the pause is triggered by `account`.*


```solidity
event Paused(address account, bytes32 message);
```

### Unpaused
*Emitted when the pause is lifted by `account`.*


```solidity
event Unpaused(address account, bytes32 message);
```

