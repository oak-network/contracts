// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";

contract CountersTest is Test {
    using Counters for Counters.Counter;
    Counters.Counter _counter;

    function test_Current() external {
        assertEq(_counter.current(), 0);
    }

    function test_Increment() external {
        _counter.increment();
        assertEq(_counter.current(), 1);
        _counter.increment();
        assertEq(_counter.current(), 2);
    }

    function test_Decrement() external {
        assertEq(_counter.current(), 0);
        vm.expectRevert("Counter: decrement overflow");
        _counter.decrement();

        _counter.increment();
        assertEq(_counter.current(), 1);
        _counter.decrement();
        assertEq(_counter.current(), 0);
    }

    function test_Reset() external {
        _counter.increment();
        _counter.increment();
        _counter.increment();
        assertEq(_counter.current(), 3);

        _counter.reset();
        assertEq(_counter.current(), 0);
    }
}
