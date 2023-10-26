// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

abstract contract PausableWithMsg {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account, bytes32 message);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account, bytes32 message);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause(bytes32 message) internal virtual whenNotPaused {
        _paused = true;
        emit Paused(msg.sender, message);
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause(bytes32 message) internal virtual whenPaused {
        _paused = false;
        emit Unpaused(msg.sender, message);
    }
}
