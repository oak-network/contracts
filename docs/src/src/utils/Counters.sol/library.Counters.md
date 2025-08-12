# Counters
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/56580a82da87af15808145e03ffc25bd15b6454b/src/utils/Counters.sol)


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

