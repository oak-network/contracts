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
}
