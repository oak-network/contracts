// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./AllOrNothing.sol";

contract KeepWhatsRaised is AllOrNothing {
    constructor(
        bytes32 platformBytes,
        address infoAddress,
        address tokenAddress,
        uint256 platformFeePercent
    )
        AllOrNothing(
            platformBytes,
            infoAddress,
            tokenAddress,
            platformFeePercent
        )
    {}

    function _checkSuccessCondition()
        internal
        pure
        override
        returns (bool)
    {
        return true;
    }
}
