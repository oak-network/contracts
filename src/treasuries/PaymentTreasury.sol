// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

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
     * @dev Constructor for the PaymentTreasury contract.
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
    function createPayment(
        bytes32 paymentId,
        bytes32 buyerId,
        bytes32 itemId,
        address paymentToken,
        uint256 amount,
        uint256 expiration
    ) public override whenNotPaused whenNotCancelled {
        super.createPayment(paymentId, buyerId, itemId, paymentToken, amount, expiration);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function processCryptoPayment(
        bytes32 paymentId,
        bytes32 itemId,
        address buyerAddress,
        address paymentToken,
        uint256 amount
    ) public override whenNotPaused whenNotCancelled {
        super.processCryptoPayment(paymentId, itemId, buyerAddress, paymentToken, amount);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function cancelPayment(
        bytes32 paymentId
    ) public override whenNotPaused whenNotCancelled {
        super.cancelPayment(paymentId);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function confirmPayment(
        bytes32 paymentId
    ) public override whenNotPaused whenNotCancelled {
        super.confirmPayment(paymentId);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function confirmPaymentBatch(
        bytes32[] calldata paymentIds
    ) public override whenNotPaused whenNotCancelled {
        super.confirmPaymentBatch(paymentIds);
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
    function claimRefund(
        bytes32 paymentId
    ) public override whenNotPaused whenNotCancelled {
        super.claimRefund(paymentId);
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
            _msgSender() != INFO.getPlatformAdminAddress(PLATFORM_HASH) &&
            _msgSender() != INFO.owner()
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