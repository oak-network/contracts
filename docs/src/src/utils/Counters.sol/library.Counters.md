# Counters
[Git Source](https://github.com/ccprotocol/reference-client-sc/blob/13d9d746c7f79b76f03c178fe64b679ba803191a/src/utils/Counters.sol)

**Author:**
Matt Condon (@shrugs)

*Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
of elements in a mapping, issuing ERC721 ids, or counting request ids.
Include with `using Counters for Counters.Counter;`*


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

## Structs
### Counter

```solidity
struct Counter {
    uint256 _value;
}
```

