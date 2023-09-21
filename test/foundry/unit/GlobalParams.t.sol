// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Base_Test} from "../Base.t.sol";

contract GlobalParams_Test is Base_Test {

    function test_GetProtocolAdminAddress() external {
        address returnProtocolAdminAddress = globalParams
            .getProtocolAdminAddress();
        assertEq(users.protocolAdminAddress, returnProtocolAdminAddress);
    }

    function test_GetTokenAddress() external {
        address tokenAddress = globalParams.getTokenAddress();
        assertEq(address(testUSD), tokenAddress);
    }

    function test_GetProtocolFeePercent() external {
        uint256 returnProtocolFeePercent = globalParams.getProtocolFeePercent();
        assertEq(protocolFeePercent, returnProtocolFeePercent);
    }
}
