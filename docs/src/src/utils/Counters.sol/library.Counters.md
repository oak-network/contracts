# Counters
[Git Source](https://github.com/oak-network/ccprotocol-contracts-internal/blob/be3636c015d0f78c20f6d8f0de7b678aaf6d8428/src/utils/Counters.sol)


## Functions
### current


```solidity
function current(Counter storage counter) internal view returns (uint256);
```

### increment


```solidity
function increment(Counter storage counter) internal;
```

### decrement


```solidity
function decrement(Counter storage counter) internal;
```

### reset


```solidity
function reset(Counter storage counter) internal;
```

## Errors
### CounterDecrementOverflow
*Error thrown when attempting to decrement a counter with value 0.*


```solidity
error CounterDecrementOverflow();
```

## Structs
### Counter

```solidity
struct Counter {
    uint256 _value;
}
```

