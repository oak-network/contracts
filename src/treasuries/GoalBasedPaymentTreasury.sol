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
     * @notice Initializes the GoalBasedPaymentTreasury contract.
     * @param _platformHash The platform hash identifier.
     * @param _infoAddress The address of the CampaignInfo contract.
     * @param _trustedForwarder The address of the trusted forwarder for meta-transactions.
     */
    function initialize(bytes32 _platformHash, address _infoAddress, address _trustedForwarder) external initializer {
        __BaseContract_init(_platformHash, _infoAddress, _trustedForwarder);
    }

    /**
     * @dev Internal function to check if current time is within launchTime → deadline range.
     */
    function _checkCreateTimeRange() internal view {
        _revertIfCurrentTimeIsNotWithinRange(INFO.getLaunchTime(), INFO.getDeadline());
    }

    /**
     * @dev Internal function to check if current time is within launchTime → deadline + buffer range.
     */
    function _checkConfirmTimeRange() internal view {
        _revertIfCurrentTimeIsNotWithinRange(INFO.getLaunchTime(), INFO.getDeadline() + INFO.getBufferTime());
    }

    /**
     * @dev Internal function to check if current time is greater than launchTime.
     */
    function _checkAfterLaunch() internal view {
        _revertIfCurrentTimeIsNotGreater(INFO.getLaunchTime());
    }

    /**
     * @dev Internal function to check if current time is greater than deadline.
     */
    function _checkAfterDeadline() internal view {
        _revertIfCurrentTimeIsNotGreater(INFO.getDeadline());
    }

    /**
     * @dev Internal function to check optimistic lock for refunds.
     * Blocks refunds if the campaign is projected to succeed (Confirmed + Pending >= Goal).
     */
    function _checkRefundAllowed() internal view {
        if (block.timestamp >= INFO.getDeadline()) {
            uint256 progress = block.timestamp > INFO.getDeadline() + INFO.getBufferTime()
                ? getRaisedAmount()
                : getRaisedAmount() + getExpectedAmount();
            if (progress >= INFO.getGoalAmount()) {
                revert GoalBasedPaymentTreasuryNotRefundable();
            }
        }
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
    ) public override whenNotPaused whenNotCancelled {
        _checkCreateTimeRange();
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
    ) public override whenNotPaused whenNotCancelled {
        _checkCreateTimeRange();
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
    ) public override whenNotPaused whenNotCancelled {
        _checkCreateTimeRange();
        super.processCryptoPayment(paymentId, itemId, buyerAddress, paymentToken, amount, lineItems, externalFees);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     * @dev Confirm operations are allowed during launchTime → deadline + buffer.
     */
    function confirmPayment(bytes32 paymentId, address buyerAddress)
        public
        override
        whenNotPaused
        whenNotCancelled
    {
        _checkConfirmTimeRange();
        super.confirmPayment(paymentId, buyerAddress);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     * @dev Confirm operations are allowed during launchTime → deadline + buffer.
     */
    function confirmPaymentBatch(bytes32[] calldata paymentIds, address[] calldata buyerAddresses)
        public
        override
        whenNotPaused
        whenNotCancelled
    {
        _checkConfirmTimeRange();
        super.confirmPaymentBatch(paymentIds, buyerAddresses);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     * @dev Cancel operations are allowed during launchTime → deadline + buffer.
     */
    function cancelPayment(bytes32 paymentId)
        public
        override
        whenNotPaused
        whenNotCancelled
    {
        _checkConfirmTimeRange();
        super.cancelPayment(paymentId);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     * @dev Refunds are allowed after launchTime, but blocked after deadline if goal is met.
     */
    function claimRefund(bytes32 paymentId, address refundAddress)
        public
        override
        whenNotPaused
        whenNotCancelled
    {
        _checkAfterLaunch();
        _checkRefundAllowed();
        super.claimRefund(paymentId, refundAddress);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     * @dev Refunds are allowed after launchTime, but blocked after deadline if goal is met.
     */
    function claimRefund(bytes32 paymentId)
        public
        override
        whenNotPaused
        whenNotCancelled
    {
        _checkAfterLaunch();
        _checkRefundAllowed();
        super.claimRefund(paymentId);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     * @dev Claiming expired funds is allowed after launchTime.
     */
    function claimExpiredFunds() public override whenNotPaused {
        _checkAfterLaunch();
        super.claimExpiredFunds();
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     * @dev Fee disbursement is only allowed after deadline and requires goal to be met.
     */
    function disburseFees() public override whenNotPaused {
        _checkAfterDeadline();
        if (!_checkSuccessCondition()) {
            revert GoalBasedPaymentTreasuryGoalNotMet();
        }
        super.disburseFees();
    }

    /**
     * @inheritdoc BasePaymentTreasury
     * @dev Claiming non-goal line items is allowed after launchTime.
     */
    function claimNonGoalLineItems(address token) public override whenNotPaused {
        _checkAfterLaunch();
        super.claimNonGoalLineItems(token);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     * @dev Withdrawal is only allowed after deadline.
     *      Success condition is checked in the base implementation.
     */
    function withdraw() public override whenNotPaused whenNotCancelled {
        _checkAfterDeadline();
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
     * @inheritdoc BasePaymentTreasury
     * @dev Success condition: confirmed raised amount >= goal amount.
     */
    function _checkSuccessCondition() internal view virtual override returns (bool) {
        return getRaisedAmount() >= INFO.getGoalAmount();
    }
}

