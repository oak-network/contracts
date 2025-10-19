// NOTE: This is an edited version of OpenZeppelin's Counters library (removed in v5.x).
// Source: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.4.1/contracts/utils/Counters.sol
// Reason: Used for backwards-compatible counter functionality in v5-based projects.

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

// The updates in this version are to ensure compatibility with Solidity v0.8.20 and to be consistent in style of other contracts used in this repository.

pragma solidity ^0.8.22;

library Counters {
    /**
     * @dev Error thrown when attempting to decrement a counter with value 0.
     */
    error CounterDecrementOverflow();

    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        if (value == 0) {
            revert CounterDecrementOverflow();
        }
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}
