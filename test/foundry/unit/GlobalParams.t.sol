// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {GlobalParams} from "src/GlobalParams.sol";
import {Defaults} from "../Base.t.sol";
import {TestToken} from "../../mocks/TestToken.sol";

contract GlobalParams_UnitTest is Test, Defaults{
    GlobalParams internal globalParams;
    TestToken internal token;

    address internal admin = address(0xA11CE);
    uint256 internal protocolFee = 300; // 3%

    function setUp() public {
        token = new TestToken(tokenName, tokenSymbol);
        globalParams = new GlobalParams(admin, address(token), protocolFee);
    }

    function testInitialValues() public {
        assertEq(globalParams.getProtocolAdminAddress(), admin);
        assertEq(globalParams.getTokenAddress(), address(token));
        assertEq(globalParams.getProtocolFeePercent(), protocolFee);
    }

    function testSetProtocolAdmin() public {
        address newAdmin = address(0xBEEF);
        vm.prank(admin);
        globalParams.updateProtocolAdminAddress(newAdmin);
        assertEq(globalParams.getProtocolAdminAddress(), newAdmin);
    }

    function testSetAcceptedToken() public {
        address newToken = address(0xDEAD);
        vm.prank(admin);
        globalParams.updateTokenAddress(newToken);
        assertEq(globalParams.getTokenAddress(), newToken);
    }

    function testSetProtocolFeePercent() public {
        vm.prank(admin);
        globalParams.updateProtocolFeePercent(500); // 5%
        assertEq(globalParams.getProtocolFeePercent(), 500);
    }

    function testUnauthorizedSettersRevert() public {
        vm.expectRevert();
        globalParams.updateProtocolFeePercent(1000);

        vm.expectRevert();
        globalParams.updateTokenAddress(address(0xBEEF));
    }
}
