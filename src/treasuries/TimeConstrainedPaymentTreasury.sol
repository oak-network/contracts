// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BasePaymentTreasury} from "../utils/BasePaymentTreasury.sol";
import {ICampaignPaymentTreasury} from "../interfaces/ICampaignPaymentTreasury.sol";
import {TimestampChecker} from "../utils/TimestampChecker.sol";

contract TimeConstrainedPaymentTreasury is
    BasePaymentTreasury,
    TimestampChecker
{
    using SafeERC20 for IERC20;

    /**
     * @dev Emitted when an unauthorized action is attempted.
     */
    error TimeConstrainedPaymentTreasuryUnAuthorized();

    /**
     * @dev Constructor for the TimeConstrainedPaymentTreasury contract.
     */
    constructor() {}

    function initialize(
        bytes32 _platformHash,
        address _infoAddress
    ) external initializer {
        __BaseContract_init(_platformHash, _infoAddress);
    }

    /**
     * @dev Internal function to check if current time is within the allowed range.
     */
    function _checkTimeWithinRange() internal view {
        uint256 launchTime = INFO.getLaunchTime();
        uint256 deadline = INFO.getDeadline();
        uint256 bufferTime = INFO.getBufferTime();
        _revertIfCurrentTimeIsNotWithinRange(launchTime, deadline + bufferTime);
    }

    /**
     * @dev Internal function to check if current time is greater than launch time.
     */
    function _checkTimeIsGreater() internal view {
        uint256 launchTime = INFO.getLaunchTime();
        _revertIfCurrentTimeIsNotGreater(launchTime);
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
    ) public override whenCampaignNotPaused whenCampaignNotCancelled {
        _checkTimeWithinRange();
        super.createPayment(paymentId, buyerId, itemId, paymentToken, amount, expiration);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function createPaymentBatch(
        bytes32[] calldata paymentIds,
        bytes32[] calldata buyerIds,
        bytes32[] calldata itemIds,
        address[] calldata paymentTokens,
        uint256[] calldata amounts,
        uint256[] calldata expirations
    ) public override whenCampaignNotPaused whenCampaignNotCancelled {
        _checkTimeWithinRange();
        super.createPaymentBatch(paymentIds, buyerIds, itemIds, paymentTokens, amounts, expirations);
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
    ) public override whenCampaignNotPaused whenCampaignNotCancelled {
        _checkTimeWithinRange();
        super.processCryptoPayment(paymentId, itemId, buyerAddress, paymentToken, amount);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function cancelPayment(
        bytes32 paymentId
    ) public override whenCampaignNotPaused whenCampaignNotCancelled {
        _checkTimeWithinRange();
        super.cancelPayment(paymentId);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function confirmPayment(
        bytes32 paymentId,
        address buyerAddress
    ) public override whenCampaignNotPaused whenCampaignNotCancelled {
        _checkTimeWithinRange();
        super.confirmPayment(paymentId, buyerAddress);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function confirmPaymentBatch(
        bytes32[] calldata paymentIds,
        address[] calldata buyerAddresses
    ) public override whenCampaignNotPaused whenCampaignNotCancelled {
        _checkTimeWithinRange();
        super.confirmPaymentBatch(paymentIds, buyerAddresses);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function claimRefund(
        bytes32 paymentId, 
        address refundAddress
    ) public override whenCampaignNotPaused whenCampaignNotCancelled {
        _checkTimeIsGreater();
        super.claimRefund(paymentId, refundAddress);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function claimRefund(
        bytes32 paymentId
    ) public override whenCampaignNotPaused whenCampaignNotCancelled {
        _checkTimeIsGreater();
        super.claimRefund(paymentId);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function disburseFees()
        public
        override
        whenCampaignNotPaused
        whenCampaignNotCancelled
    {
        _checkTimeIsGreater();
        super.disburseFees();
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function withdraw() public override whenCampaignNotPaused whenCampaignNotCancelled {
        _checkTimeIsGreater();
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
            revert TimeConstrainedPaymentTreasuryUnAuthorized();
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
