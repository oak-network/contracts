// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract OwnableContract is Ownable {
    function checkOwner() external view {
        _checkOwner();
    }

    function transferOwnershipExternal(address newOwner) external {
        _transferOwnership(newOwner);
    }
}

contract OwnableTest is Test {
    OwnableContract ownable;

    function setUp() public {
        ownable = new OwnableContract();
    }

    function test_Owner() external virtual {
        assertEq(ownable.owner(), address(this));
    }
}
