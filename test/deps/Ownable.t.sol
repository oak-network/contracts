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

    function test_Owner() external {
        assertEq(ownable.owner(), address(this));
    }

    function test_CheckOwner() external {
        ownable.checkOwner();
        vm.prank(address(0x1));
        vm.expectRevert("Ownable: caller is not the owner");
        ownable.checkOwner();
    }

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    function test_EventOwnershipTransferred() external {
        assertEq(address(this), ownable.owner());

        vm.expectEmit(true, true, false, false, address(ownable));
        emit OwnershipTransferred(address(this), address(0x2));
        ownable.transferOwnership(address(0x2));

        assertEq(address(0x2), ownable.owner());

        vm.expectEmit(true, true, false, false, address(ownable));
        emit OwnershipTransferred(address(0x2), address(0x3));
        ownable.transferOwnershipExternal(address(0x3));
    }

    function test_TransferOwnership() external {
        assertEq(address(this), ownable.owner());

        vm.expectRevert("Ownable: new owner is the zero address");
        ownable.transferOwnership(address(0));

        ownable.transferOwnership(address(0x2));
        assertEq(address(0x2), ownable.owner());
    }

    function test_TransferOwnershipExternal() external {
        assertEq(address(this), ownable.owner());
        ownable.transferOwnershipExternal(address(0x2));
        assertEq(address(0x2), ownable.owner());
    }

    function test_RenounceOwnership() external {
        assertEq(address(this), ownable.owner());
        ownable.renounceOwnership();
        assertEq(ownable.owner(), address(0));
    }
}
