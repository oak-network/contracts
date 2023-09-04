// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./AllOrNothing.sol";

contract KeepWhatsRaised is AllOrNothing {
    constructor(
        bytes32 platformBytes,
        address infoAddress
    )
        AllOrNothing(
            platformBytes,
            infoAddress
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
