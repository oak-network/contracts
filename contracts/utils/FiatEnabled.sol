// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

abstract contract FiatEnabled {
    uint256 internal s_fiatRaisedAmount;
    bool internal s_fiatFeeIsDisbursed;
    mapping(bytes32 => uint256) internal s_fiatAmountById;

    error FiatEnabledAlreadySet();
    error FiatEnabledDisallowedState();

    function _updateFiatPledge(
        bytes32 fiatPledgeId,
        uint256 fiatPledgeAmount
    ) internal {
        s_fiatAmountById[fiatPledgeId] = fiatPledgeAmount;
        s_fiatRaisedAmount += fiatPledgeAmount;
    }

    function _updateFiatFeeDisbusementState(bool isDisbursed) internal {
        if (s_fiatFeeIsDisbursed == true) {
            revert FiatEnabledAlreadySet();
        }
        if (isDisbursed) {
            s_fiatFeeIsDisbursed = true;
        }
        else {
            revert FiatEnabledDisallowedState();
        }
    }
}
