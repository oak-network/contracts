// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";

/// @title PausableCancellable
/// @notice Abstract contract providing pause and cancel state management with events and modifiers
abstract contract PausableCancellable is Context {
    bool private _paused;
    bool private _cancelled;

    /**
     * @notice Emitted when contract is paused
     */
    event Paused(address indexed account, bytes32 reason);

    /**
     * @notice Emitted when contract is unpaused
     */
    event Unpaused(address indexed account, bytes32 reason);

    /**
     * @notice Emitted when contract is cancelled
     */
    event Cancelled(address indexed account, bytes32 reason);

    /**
     * @dev Reverts if contract is paused
     */
    error PausedError();

    /**
     * @dev Reverts if contract is not paused
     */
    error NotPausedError();

    /**
     * @dev Reverts if contract is cancelled
     */
    error CancelledError();

    /**
     * @dev Reverts if contract is not cancelled
     */
    error NotCancelledError();

    /**
     * @dev Reverts if contract is already cancelled
     */
    error CannotCancel();

    /**
     * @notice Modifier to allow function only when not paused
     */
    modifier whenNotPaused() {
        if (_paused) revert PausedError();
        _;
    }

    /**
     * @notice Modifier to allow function only when paused
     */
    modifier whenPaused() {
        if (!_paused) revert NotPausedError();
        _;
    }

    /**
     * @notice Modifier to allow function only when not cancelled
     */
    modifier whenNotCancelled() {
        if (_cancelled) revert CancelledError();
        _;
    }

    /**
     * @notice Modifier to allow function only when cancelled
     */
    modifier whenCancelled() {
        if (!_cancelled) revert NotCancelledError();
        _;
    }

    /**
     * @notice Returns true if the contract is currently paused
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @notice Returns true if the contract has been cancelled
     */
    function cancelled() public view virtual returns (bool) {
        return _cancelled;
    }

    /**
     * @notice Pauses the contract
     * @param reason A short reason for pausing
     * @dev Can only pause if not already paused or cancelled
     */
    function _pause(
        bytes32 reason
    ) internal virtual whenNotPaused whenNotCancelled {
        _paused = true;
        emit Paused(_msgSender(), reason);
    }

    /**
     * @notice Unpauses the contract
     * @param reason A short reason for unpausing
     * @dev Can only unpause if currently paused
     */
    function _unpause(bytes32 reason) internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender(), reason);
    }

    /**
     * @notice Cancels the contract permanently
     * @param reason A short reason for cancellation
     * @dev Auto-unpauses if paused, and cannot be undone
     */
    function _cancel(bytes32 reason) internal virtual {
        if (_cancelled) revert CannotCancel();
        /// @dev keccak256 Hash of `Auto-unpaused during cancellation` is passed as a reason
        if (_paused) {
            _unpause(
                0x231da0eace2a459b43889b78bbd1fc88a89e3192ee6cbcda7015c539d577e2cd
            );
        }
        _cancelled = true;
        emit Cancelled(_msgSender(), reason);
    }
}
