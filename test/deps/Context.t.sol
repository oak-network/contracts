// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

contract MockContext is Context {
    function msgSender() external view returns (address) {
        return _msgSender();
    }

    function msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}

contract MockContextCaller {
    function callSender(MockContext context) public view returns (address) {
        return context.msgSender();
    }

    // function callData(MockContext context) public view returns (bytes calldata){
    //     return context.msgData();
    // }
}

contract ContextTest is Test {
    MockContext context;
    MockContextCaller contextCaller;

    function setUp() public {
        context = new MockContext();
        contextCaller = new MockContextCaller();
    }

    function test_megSender() external {
        // returns the transaction sender when called from an EOA
        address addressOfEOA = address(0x12);
        vm.prank(addressOfEOA);
        assertEq(context.msgSender(), addressOfEOA);

        // returns the transaction sender when from test contract
        assertEq(context.msgSender(), address(this));
    }
}
