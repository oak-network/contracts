// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Base_Test} from "../Base.t.sol";

/// @notice Test contract for GlobalParams contract.
contract GlobalParams_Test is Base_Test {

    /// @dev Test GetProtocolAdminAddress function.
    function test_GetProtocolAdminAddress() external {
        address returnProtocolAdminAddress = globalParams
            .getProtocolAdminAddress();
        assertEq(users.protocolAdminAddress, returnProtocolAdminAddress);
    }

    /// @dev Test GetTokenAddress function.
    function test_GetTokenAddress() external {
        address tokenAddress = globalParams.getTokenAddress();
        assertEq(address(testUSD), tokenAddress);
    }

    /// @dev Test GetProtocolFeePercent function.
    function test_GetProtocolFeePercent() external {
        uint256 returnProtocolFeePercent = globalParams.getProtocolFeePercent();
        assertEq(PROTOCOL_FEE_PERCENT, returnProtocolFeePercent);
    }
}
