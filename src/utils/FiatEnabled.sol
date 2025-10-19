// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title FiatEnabled
 * @notice A contract that provides functionality for tracking and managing fiat transactions.
 * This contract allows tracking the amount of fiat raised, individual fiat transactions, and the state of fiat fee disbursement.
 */
abstract contract FiatEnabled {
    uint256 internal s_fiatRaisedAmount;
    bool internal s_fiatFeeIsDisbursed;
    mapping(bytes32 => uint256) internal s_fiatAmountById;

    /**
     * @notice Emitted when a fiat transaction is updated.
     * @param fiatTransactionId The unique identifier of the fiat transaction.
     * @param fiatTransactionAmount The updated amount of the fiat transaction.
     */
    event FiatTransactionUpdated(
        bytes32 indexed fiatTransactionId,
        uint256 fiatTransactionAmount
    );

    /**
     * @notice Emitted when the state of fiat fee disbursement is updated.
     * @param isDisbursed True if the fiat fee is disbursed; otherwise, false.
     * @param protocolFeeAmount The protocol fee amount.
     * @param platformFeeAmount The platform fee amount.
     */
    event FiatFeeDisbusementStateUpdated(
        bool isDisbursed,
        uint256 protocolFeeAmount,
        uint256 platformFeeAmount
    );

    /**
     * @dev Throws an error indicating that the fiat enabled functionality is already set.
     */
    error FiatEnabledAlreadySet();
    /**
     * @dev Throws an error indicating that the fiat enabled functionality is in an invalid state.
     */
    error FiatEnabledDisallowedState();
    /**
     * @dev Throws an error indicating that the fiat transaction is invalid.
     */
    error FiatEnabledInvalidTransaction();

    /**
     * @notice Get the total amount of fiat raised.
     * @return The total fiat raised amount.
     */
    function getFiatRaisedAmount() public view returns (uint256) {
        return s_fiatRaisedAmount;
    }

    /**
     * @notice Get the amount of a specific fiat transaction.
     * @param fiatTransactionId The unique identifier of the fiat transaction.
     * @return amount The amount of the specified fiat transaction.
     */
    function getFiatTransactionAmount(
        bytes32 fiatTransactionId
    ) external view returns (uint256 amount) {
        amount = s_fiatAmountById[fiatTransactionId];
        if (amount == 0) {
            revert FiatEnabledInvalidTransaction();
        }
    }

    /**
     * @notice Check if the fiat fee has been disbursed.
     * @return True if the fiat fee has been disbursed; otherwise, false.
     */
    function checkIfFiatFeeDisbursed() external view returns (bool) {
        return s_fiatFeeIsDisbursed;
    }

    /**
     * @notice Update the details of a fiat transaction.
     * @param fiatTransactionId The unique identifier of the fiat transaction.
     * @param fiatTransactionAmount The amount of the fiat transaction.
     */
    function _updateFiatTransaction(
        bytes32 fiatTransactionId,
        uint256 fiatTransactionAmount
    ) internal {
        s_fiatAmountById[fiatTransactionId] = fiatTransactionAmount;
        s_fiatRaisedAmount += fiatTransactionAmount;
        emit FiatTransactionUpdated(fiatTransactionId, fiatTransactionAmount);
    }

    /**
     * @dev Update the state of fiat fee disbursement.
     * @param isDisbursed True if the fiat fee is disbursed; otherwise, false.
     * @param protocolFeeAmount The protocol fee amount.
     * @param platformFeeAmount The platform fee amount.
     */
    function _updateFiatFeeDisbursementState(
        bool isDisbursed,
        uint256 protocolFeeAmount,
        uint256 platformFeeAmount
    ) internal {
        if (s_fiatFeeIsDisbursed == true) {
            revert FiatEnabledAlreadySet();
        }
        if (!isDisbursed) {
            revert FiatEnabledDisallowedState();
        }
        s_fiatFeeIsDisbursed = true;
        emit FiatFeeDisbusementStateUpdated(
            isDisbursed,
            protocolFeeAmount,
            platformFeeAmount
        );
    }
}
