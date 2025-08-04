// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BasePaymentTreasury} from "../utils/BasePaymentTreasury.sol";
import {ICampaignPaymentTreasury} from "../interfaces/ICampaignPaymentTreasury.sol";

contract PaymentTreasury is
    BasePaymentTreasury
{
    using SafeERC20 for IERC20;

    string private s_name;
    string private s_symbol;

    /**
     * @dev Emitted when an unauthorized action is attempted.
     */
    error PaymentTreasuryUnAuthorized();

    /**
     * @dev Emitted when `disburseFees` after fee is disbursed already.
     */
    error PaymentTreasuryFeeAlreadyDisbursed();

    /**
     * @dev Constructor for the AllOrNothing contract.
     */
    constructor() {}

    function initialize(
        bytes32 _platformHash,
        address _infoAddress,
        string calldata _name,
        string calldata _symbol
    ) external initializer {
        __BaseContract_init(_platformHash, _infoAddress);
        s_name = _name;
        s_symbol = _symbol;
    }

    function name() public view returns (string memory) {
        return s_name;
    }

    function symbol() public view returns (string memory) {
        return s_symbol;
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function claimRefund(
        bytes32 paymentId, 
        address refundAddress
    ) public override whenNotPaused whenNotCancelled {
        super.claimRefund(paymentId, refundAddress);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function disburseFees()
        public
        override
        whenNotPaused
        whenNotCancelled
    {
        if (s_feesDisbursed) {
            revert PaymentTreasuryFeeAlreadyDisbursed();
        }
        super.disburseFees();
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function withdraw() public override whenNotPaused whenNotCancelled {
        super.withdraw();
    }

    /**
     * @inheritdoc BasePaymentTreasury
     * @dev This function is overridden to allow the platform admin and the campaign owner to cancel a treasury.
     */
    function cancelTreasury(bytes32 message) public override {
        if (
            msg.sender != INFO.getPlatformAdminAddress(PLATFORM_HASH) &&
            msg.sender != INFO.owner()
        ) {
            revert PaymentTreasuryUnAuthorized();
        }
        _cancel(message);
    }

    /**
     * @inheritdoc BasePaymentTreasury
     */
    function _checkSuccessCondition()
        internal
        view
        virtual
        override
        returns (bool)
    {
        return true;
    }
}