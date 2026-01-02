# Counters
[Git Source](https://github.com/oak-network/contracts/blob/0ce055a8ba31ca09404e9d09ecd2549534cbec61/src/utils/Counters.sol)


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
Error thrown when attempting to decrement a counter with value 0.


```solidity
error CounterDecrementOverflow();
```

## Structs
### Counter

```solidity
struct Counter {
    // This variable should never be directly accessed by users of the library: interactions must be restricted to
    // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
    // this feature: see https://github.com/ethereum/solidity/issues/4637
    uint256 _value; // default: 0
}
```

