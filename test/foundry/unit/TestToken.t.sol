// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {TestToken} from "../../mocks/TestToken.sol";
import {Defaults} from "../Base.t.sol";

contract TestToken_UnitTest is Test, Defaults {
    TestToken internal token;

    address internal user = address(0x1234);
    uint256 internal mintAmount = 1_000 * 1e18;

    function setUp() public {
        token = new TestToken(tokenName, tokenSymbol);
    }

    function testMintIncreasesBalance() public {
        token.mint(user, mintAmount);
        assertEq(token.balanceOf(user), mintAmount);
    }

    function testTransferWorks() public {
        address recipient = address(0x5678);
        token.mint(user, mintAmount);
        vm.prank(user);
        token.transfer(recipient, 200 * 1e18);
        assertEq(token.balanceOf(recipient), 200 * 1e18);
    }
}
