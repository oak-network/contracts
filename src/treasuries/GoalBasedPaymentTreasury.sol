// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {BasePaymentTreasury} from "../utils/BasePaymentTreasury.sol";
import {ICampaignPaymentTreasury} from "../interfaces/ICampaignPaymentTreasury.sol";

/**
 * @title GoalBasedPaymentTreasury
 * @notice A payment treasury with goal-based success conditions.
 */
contract GoalBasedPaymentTreasury is BasePaymentTreasury {
    error GoalBasedPaymentTreasuryInvalidTimestamp();

    /**
     * @notice Initializes the GoalBasedPaymentTreasury contract.
     * @param _platformHash The platform hash identifier.
     * @param _infoAddress The address of the CampaignInfo contract.
     * @param _trustedForwarder The address of the trusted forwarder for meta-transactions.
     */
    function initialize(bytes32 _platformHash, address _infoAddress, address _trustedForwarder) external initializer {
        __BaseContract_init(_platformHash, _infoAddress, _trustedForwarder);
    }

    function _revertIfCurrentTimeIsNotGreater(uint256 inputTime) private view {
        if (block.timestamp <= inputTime) {
            revert GoalBasedPaymentTreasuryInvalidTimestamp();
        }
    }

    function _revertIfCurrentTimeIsNotWithinRange(uint256 initialTime, uint256 finalTime) private view {
        uint256 currentTime = block.timestamp;
        if (currentTime < initialTime || currentTime > finalTime) {
            revert GoalBasedPaymentTreasuryInvalidTimestamp();
        }
    }

    /**
     * @dev Internal function to check if current time is within launchTime → deadline range.
     */
    function _checkCreateTimeRange() private view {
        _revertIfCurrentTimeIsNotWithinRange(INFO.getLaunchTime(), INFO.getDeadline());
    }

    /**
     * @dev Internal function to check if current time is within launchTime → deadline + buffer range.
     */
    function _checkConfirmTimeRange() private view {
        _revertIfCurrentTimeIsNotWithinRange(INFO.getLaunchTime(), INFO.getDeadline() + INFO.getBufferTime());
    }

    /**
     * @dev Internal function to check if current time is greater than launchTime.
     */
    function _checkAfterLaunch() private view {
        _revertIfCurrentTimeIsNotGreater(INFO.getLaunchTime());
    }
    
    /**
     * @dev Internal function to check if current time is greater than deadline.
     */
    function _checkAfterDeadline() private view {
        _revertIfCurrentTimeIsNotGreater(INFO.getDeadline());
    }

    /**
     * @dev Overflow-safe goal comparison for optimistic progress checks.
     */
    function _isGoalMetWithExpected(uint256 confirmed, uint256 expected, uint256 goal)
        private
        pure
        returns (bool)
    {
        if (confirmed >= goal) {
            return true;
        }
        uint256 remaining = goal - confirmed;
        return expected >= remaining;
    }

    /**
     * @dev Locks campaign success outcome after deadline using campaign-level optimistic totals.
     * The lock is shared across all treasuries through CampaignInfo.
     */
    function _lockGoalOutcomeIfNeeded() private {
        if (block.timestamp <= INFO.getDeadline()) {
            return;
        }

        (bool locked,,) = INFO.getGoalOutcomeLock();
        if (!locked) {
            INFO.lockGoalOutcome();
        }
    }

    /**
     * @dev Internal function to check refund eligibility with immutable post-deadline outcome.
     */
    function _checkRefundAllowed() private {
        _checkAfterLaunch();
        uint256 deadline = INFO.getDeadline();
        if (block.timestamp > deadline) {
            _lockGoalOutcomeIfNeeded();
            if (_checkSuccessCondition()) {
                revert PaymentTreasurySuccessConditionNotFulfilled();
            }
        } else if (block.timestamp == deadline) {
            // At exact deadline, keep optimistic protection (confirmed + pending).
            uint256 confirmed = INFO.getTotalRaisedAmount();
            uint256 expected = INFO.getTotalExpectedAmount();
            uint256 goalAmount = INFO.getGoalAmount();
            if (_isGoalMetWithExpected(confirmed, expected, goalAmount)) {
                revert PaymentTreasurySuccessConditionNotFulfilled();
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
        _lockGoalOutcomeIfNeeded();
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
        _lockGoalOutcomeIfNeeded();
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
        _lockGoalOutcomeIfNeeded();
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
    {
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
    {
        _checkRefundAllowed();
        super.claimRefund(paymentId);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     * @dev Claiming expired funds is allowed after launchTime.
     */
    function claimExpiredFunds() public override whenNotPaused {
        _checkAfterLaunch();
        _lockGoalOutcomeIfNeeded();
        super.claimExpiredFunds();
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     * @dev Fee disbursement is only allowed after deadline and requires goal to be met.
     */
    function disburseFees() public override whenNotPaused {
        _checkAfterDeadline();
        _lockGoalOutcomeIfNeeded();
        if (!_checkSuccessCondition()) {
            revert PaymentTreasurySuccessConditionNotFulfilled();
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
        _lockGoalOutcomeIfNeeded();
        super.withdraw();
    }

    /**
     * @inheritdoc BasePaymentTreasury
     * @dev This function is overridden to allow the platform admin and the campaign owner to cancel a treasury.
     */
    function cancelTreasury(bytes32 message) public override onlyPlatformAdminOrCampaignOwner {
        _cancel(message);
    }

    /**
     * @inheritdoc BasePaymentTreasury
     * @dev Before lock: uses confirmed raised amount only.
     *      After lock: uses immutable campaign-level goal outcome from CampaignInfo.
     */
    function _checkSuccessCondition() internal view virtual override returns (bool) {
        (bool locked, bool successful,) = INFO.getGoalOutcomeLock();
        if (locked) {
            return successful;
        }
        return INFO.getTotalRaisedAmount() >= INFO.getGoalAmount();
    }
}
