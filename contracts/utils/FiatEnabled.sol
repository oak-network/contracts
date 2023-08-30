// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

abstract contract FiatEnabled {
    uint256 internal s_fiatRaisedAmount;
    bool internal s_fiatFeeIsDisbursed;
    mapping(bytes32 => uint256) internal s_fiatAmountById;

    event FiatTransactionUpdated(
        bytes32 indexed fiatTransactionId,
        uint256 fiatTransactionAmount
    );

    event FiatFeeDisbusementStateUpdated(
        bool isDisbursed,
        uint256 protocolFeeAmount,
        uint256 platformFeeAmount
    );

    error FiatEnabledAlreadySet();
    error FiatEnabledDisallowedState();

    function _updateFiatTransaction(
        bytes32 fiatTransactionId,
        uint256 fiatTransactionAmount
    ) internal {
        s_fiatAmountById[fiatTransactionId] = fiatTransactionAmount;
        s_fiatRaisedAmount += fiatTransactionAmount;
        emit FiatTransactionUpdated(fiatTransactionId, fiatTransactionAmount);
    }

    function _updateFiatFeeDisbusementState(
        bool isDisbursed,
        uint256 protocolFeeAmount,
        uint256 platformFeeAmount
    ) internal {
        if (s_fiatFeeIsDisbursed == true) {
            revert FiatEnabledAlreadySet();
        }
        if (isDisbursed) {
            s_fiatFeeIsDisbursed = true;
            emit FiatFeeDisbusementStateUpdated(
                isDisbursed,
                protocolFeeAmount,
                platformFeeAmount
            );
        } else {
            revert FiatEnabledDisallowedState();
        }
    }
}
