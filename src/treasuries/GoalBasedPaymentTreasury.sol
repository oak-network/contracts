// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {BasePaymentTreasury} from "../utils/BasePaymentTreasury.sol";
import {ICampaignPaymentTreasury} from "../interfaces/ICampaignPaymentTreasury.sol";
import {TimestampChecker} from "../utils/TimestampChecker.sol";

/**
 * @title GoalBasedPaymentTreasury
 * @notice A payment treasury with goal-based success conditions.
 */
contract GoalBasedPaymentTreasury is BasePaymentTreasury, TimestampChecker {

    /**
     * @dev Emitted when the goal has not been met for operations requiring success.
     */
    error GoalBasedPaymentTreasuryGoalNotMet();

    /**
     * @dev Emitted when attempting to refund after goal has been met.
     */
    error GoalBasedPaymentTreasuryNotRefundable();

    /**
     * @dev Emitted when an unauthorized action is attempted.
     */
    error GoalBasedPaymentTreasuryUnauthorized();

    /**
     * @dev Constructor for the GoalBasedPaymentTreasury contract.
     */
    constructor() {}

    /**
     * @notice Initializes the GoalBasedPaymentTreasury contract.
     * @param _platformHash The platform hash identifier.
     * @param _infoAddress The address of the CampaignInfo contract.
     * @param _trustedForwarder The address of the trusted forwarder for meta-transactions.
     */
    function initialize(bytes32 _platformHash, address _infoAddress, address _trustedForwarder) external initializer {
        __BaseContract_init(_platformHash, _infoAddress, _trustedForwarder);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     * @dev Create operations are only allowed during launchTime → deadline.
     */
    function createPayment(
        bytes32 paymentId,
        bytes32 buyerId,
        bytes32 itemId,
        address paymentToken,
        uint256 amount,
        uint256 expiration,
        ICampaignPaymentTreasury.LineItem[] calldata lineItems,
        ICampaignPaymentTreasury.ExternalFees[] calldata externalFees
    )
        public
        override
        currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
        whenNotPaused
        whenNotCancelled
    {
        super.createPayment(paymentId, buyerId, itemId, paymentToken, amount, expiration, lineItems, externalFees);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     * @dev Create operations are only allowed during launchTime → deadline.
     */
    function createPaymentBatch(
        bytes32[] calldata paymentIds,
        bytes32[] calldata buyerIds,
        bytes32[] calldata itemIds,
        address[] calldata paymentTokens,
        uint256[] calldata amounts,
        uint256[] calldata expirations,
        ICampaignPaymentTreasury.LineItem[][] calldata lineItemsArray,
        ICampaignPaymentTreasury.ExternalFees[][] calldata externalFeesArray
    )
        public
        override
        currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
        whenNotPaused
        whenNotCancelled
    {
        super.createPaymentBatch(
            paymentIds, buyerIds, itemIds, paymentTokens, amounts, expirations, lineItemsArray, externalFeesArray
        );
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     * @dev Create operations are only allowed during launchTime → deadline.
     */
    function processCryptoPayment(
        bytes32 paymentId,
        bytes32 itemId,
        address buyerAddress,
        address paymentToken,
        uint256 amount,
        ICampaignPaymentTreasury.LineItem[] calldata lineItems,
        ICampaignPaymentTreasury.ExternalFees[] calldata externalFees
    )
        public
        override
        currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
        whenNotPaused
        whenNotCancelled
    {
        super.processCryptoPayment(paymentId, itemId, buyerAddress, paymentToken, amount, lineItems, externalFees);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     * @dev Confirm operations are allowed during launchTime → deadline + buffer.
     */
    function confirmPayment(bytes32 paymentId, address buyerAddress)
        public
        override
        currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline() + INFO.getBufferTime())
        whenNotPaused
        whenNotCancelled
    {
        super.confirmPayment(paymentId, buyerAddress);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     * @dev Confirm operations are allowed during launchTime → deadline + buffer.
     */
    function confirmPaymentBatch(bytes32[] calldata paymentIds, address[] calldata buyerAddresses)
        public
        override
        currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline() + INFO.getBufferTime())
        whenNotPaused
        whenNotCancelled
    {
        super.confirmPaymentBatch(paymentIds, buyerAddresses);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     * @dev Cancel operations are allowed during launchTime → deadline + buffer.
     */
    function cancelPayment(bytes32 paymentId)
        public
        override
        currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline() + INFO.getBufferTime())
        whenNotPaused
        whenNotCancelled
    {
        super.cancelPayment(paymentId);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     * @dev Refunds are allowed after launchTime, but blocked after deadline if goal is met.
     */
    function claimRefund(bytes32 paymentId, address refundAddress)
        public
        override
        currentTimeIsGreater(INFO.getLaunchTime())
        whenNotPaused
        whenNotCancelled
    {
        // Optimistic Lock: Block refunds if the campaign is projected to succeed (Confirmed + Pending >= Goal).
        // This prevents a "bank run" during the settlement buffer while pending payments are confirmed.
        // If pending payments fail and the total drops below the goal after buffer has elapsed, refunds will unlock.
        if (block.timestamp >= INFO.getDeadline() && getGoalProgress() >= INFO.getGoalAmount()) {
            revert GoalBasedPaymentTreasuryNotRefundable();
        }
        super.claimRefund(paymentId, refundAddress);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     * @dev Refunds are allowed after launchTime, but blocked after deadline if goal is met.
     */
    function claimRefund(bytes32 paymentId)
        public
        override
        currentTimeIsGreater(INFO.getLaunchTime())
        whenNotPaused
        whenNotCancelled
    {
        // Optimistic Lock: Block refunds if the campaign is projected to succeed (Confirmed + Pending >= Goal).
        // This prevents a "bank run" during the settlement buffer while pending payments are confirmed.
        // If pending payments fail and the total drops below the goal after buffer has elapsed, refunds will unlock.
        if (block.timestamp >= INFO.getDeadline() && getGoalProgress() >= INFO.getGoalAmount()) {
            revert GoalBasedPaymentTreasuryNotRefundable();
        }
        super.claimRefund(paymentId);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     * @dev Claiming expired funds is allowed after launchTime.
     */
    function claimExpiredFunds()
        public
        override
        currentTimeIsGreater(INFO.getLaunchTime())
        whenNotPaused
    {
        super.claimExpiredFunds();
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     * @dev Fee disbursement is only allowed after deadline and requires goal to be met.
     */
    function disburseFees()
        public
        override
        currentTimeIsGreater(INFO.getDeadline())
        whenNotPaused
    {
        if (!_checkSuccessCondition()) {
            revert GoalBasedPaymentTreasuryGoalNotMet();
        }
        super.disburseFees();
    }

    /**
     * @inheritdoc BasePaymentTreasury
     * @dev Claiming non-goal line items is allowed after launchTime.
     */
    function claimNonGoalLineItems(address token)
        public
        override
        currentTimeIsGreater(INFO.getLaunchTime())
        whenNotPaused
    {
        super.claimNonGoalLineItems(token);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     * @dev Withdrawal is only allowed after deadline.
     *      Success condition is checked in the base implementation.
     */
    function withdraw()
        public
        override
        currentTimeIsGreater(INFO.getDeadline())
        whenNotPaused
        whenNotCancelled
    {
        super.withdraw();
    }

    /**
     * @inheritdoc BasePaymentTreasury
     * @dev This function is overridden to allow the platform admin and the campaign owner to cancel a treasury.
     */
    function cancelTreasury(bytes32 message) public override {
        if (_msgSender() != INFO.getPlatformAdminAddress(PLATFORM_HASH) && _msgSender() != INFO.owner()) {
            revert GoalBasedPaymentTreasuryUnauthorized();
        }
        _cancel(message);
    }

    /**
     * @notice Returns goal progress - time-aware for consistency.
     * @return The current goal progress amount (normalized to 18 decimals).
     */
    function getGoalProgress() public view returns (uint256) {
        if (block.timestamp > INFO.getDeadline() + INFO.getBufferTime()) {
            // After settlement period: only confirmed matters
            return getRaisedAmount();
        }
        // During campaign/buffer: optimistic view (pending + confirmed)
        return getRaisedAmount() + getExpectedAmount();
    }

    /**
     * @inheritdoc BasePaymentTreasury
     * @dev Success condition: confirmed raised amount >= goal amount.
     */
    function _checkSuccessCondition() internal view virtual override returns (bool) {
        return getRaisedAmount() >= INFO.getGoalAmount();
    }
}

