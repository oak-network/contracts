// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

contract MockPausable is Pausable {
    bool public drasticMeasureTaken;
    uint256 public count;

    constructor() {
        drasticMeasureTaken = false;
        count = 0;
    }

    function normalProcess() external whenNotPaused {
        count++;
    }

    function drasticMeasure() external whenPaused {
        drasticMeasureTaken = true;
    }

    function pause() external {
        _pause();
    }

    function unpause() external {
        _unpause();
    }
}

contract PausableTest is Test {
    MockPausable pausable;

    function setUp() external {
        pausable = new MockPausable();
    }

    event Paused(address account);

    function test_pause() external {
        address alice = address(1234);
        vm.prank(alice);
        vm.expectEmit(true, false, false, false);
        emit Paused(alice);
        pausable.pause();
    }
}
