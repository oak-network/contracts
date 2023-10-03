// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

contract MockContext is Context {
    function msgSender() external view returns (address) {
        return _msgSender();
    }

    event Data(bytes data, uint256 integerValue, string stringValue);

    function msgData(uint256 integerValue, string memory stringValue) public {
        emit Data(_msgData(), integerValue, stringValue);
    }
}

contract ContextTest is Test {
    MockContext context;

    function setUp() public {
        context = new MockContext();
    }

    function test_msgSender() external {
        // returns the transaction sender when called from an EOA
        address addressOfEOA = address(0x12);
        vm.prank(addressOfEOA);
        assertEq(context.msgSender(), addressOfEOA);

        // returns the transaction sender when called from test contract
        assertEq(context.msgSender(), address(this));
    }

    event Data(bytes data, uint256 integerValue, string stringValue);

    function test_msgData() external {
        uint256 integerValue = 1234;
        string memory stringValue = "Context Test";
        bytes memory callData;
        callData = abi.encode(integerValue, stringValue);
        // vm.expectEmit(true, true, true, false, address(this));
        vm.expectEmit(false, true, true, false);
        emit Data(callData, integerValue, stringValue);
        context.msgData(integerValue, stringValue);
    }
}
