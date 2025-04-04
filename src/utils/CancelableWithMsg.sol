// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

abstract contract CancelableWithMsg {
    /**
     * @dev Emitted when the cancel is triggered by `account`.
     */
    event Canceled(address account, bytes32 message);

    bool private _canceled;

    /**
     * @dev Initializes the contract in un-canceled state.
     */
    constructor() {
        _canceled = false;
    }


    /**
     * @dev Throws if the contract is canceled.
     * 
     * Requirements:
     * 
     * - The contract must not be canceled.
     */
    modifier whenNotCanceled() {
        _requireNotCanceled();
        _;
    }

    /**
     * @dev Throws if the contract is canceled.
     * 
     * Requirements:
     * 
     * - The contract must be canceled.
     */
    modifier whenCanceled() {
        _requireCanceled();
        _;
    }

    /**
     * @dev Returns true if the contract is canceled, and false otherwise.
     */
    function canceled() public view virtual returns (bool) {
        return _canceled;
    }

    /**
     * @dev Throws if the contract is canceled.
     */
    function _requireNotCanceled() internal view virtual {
        require(!canceled(), "Cancelable: canceled");
    }

    /**
     * @dev Throws if the contract is not canceled.
     */
    function _requireCanceled() internal view virtual {
        require(canceled(), "Cancelable: not canceled");
    }

    /**
     * @dev Triggers the canceled state.
     * 
     * Requirements:
     * 
     * - The contract must not be canceled.
     */
    function _cancel(bytes32 message) internal virtual whenNotCanceled {
        _canceled = true;
        emit Canceled(msg.sender, message);
    }

}
