// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {ICampaignPaymentTreasury} from "../interfaces/ICampaignPaymentTreasury.sol";
import {CampaignAccessChecker} from "./CampaignAccessChecker.sol";
import {PausableCancellable} from "./PausableCancellable.sol";

abstract contract BasePaymentTreasury is 
    Initializable,
    ICampaignPaymentTreasury,
    CampaignAccessChecker,
    PausableCancellable
{
    using SafeERC20 for IERC20;

    bytes32 internal constant ZERO_BYTES =
        0x0000000000000000000000000000000000000000000000000000000000000000;
    uint256 internal constant PERCENT_DIVIDER = 10000;

    bytes32 internal PLATFORM_HASH;
    uint256 internal PLATFORM_FEE_PERCENT;
    IERC20 internal TOKEN;
    bool internal s_feesDisbursed;

    struct PaymentInfo {
        address buyerAddress;
        bytes32 itemId;
        uint256 amount;
        uint256 expiration;
        bool isConfirmed;
    }

    mapping (bytes32 => PaymentInfo) internal s_payment;
    uint256 internal s_pendingPaymentAmount;
    uint256 internal s_confirmedPaymentAmount;
    uint256 internal s_availableConfirmedPaymentAmount;

    /**
     * @dev Emitted when a new payment is created.
     * @param paymentId The unique identifier of the payment.
     * @param buyerAddress The address of the buyer who initiated the payment.
     * @param itemId The identifier of the item being purchased.
     * @param amount The amount to be paid for the item.
     * @param expiration The timestamp after which the payment expires.
     */
    event PaymentCreated(
        bytes32 indexed paymentId,
        address indexed buyerAddress,
        bytes32 indexed itemId,
        uint256 amount,
        uint256 expiration
    );

    /**
     * @dev Emitted when a payment is cancelled and removed from the treasury.
     * @param paymentId The unique identifier of the cancelled payment.
     */
    event PaymentCancelled(
        bytes32 indexed paymentId
    );

    /**
     * @dev Emitted when a payment is confirmed.
     * @param paymentId The unique identifier of the cancelled payment.
     */
    event PaymentConfirmed(
        bytes32 indexed paymentId
    );

    /**
     * @dev Emitted when multiple payments are confirmed in a single batch operation.
     * @param paymentIds An array of unique identifiers for the confirmed payments.
     */
    event PaymentBatchConfirmed(
        bytes32[] paymentIds
    );

    /**
     * @notice Emitted when fees are successfully disbursed.
     * @param protocolShare The amount of fees sent to the protocol.
     * @param platformShare The amount of fees sent to the platform.
     */
    event FeesDisbursed(uint256 protocolShare, uint256 platformShare);

    /**
     * @notice Emitted when a withdrawal is successful.
     * @param to The recipient of the withdrawal.
     * @param amount The amount withdrawn.
     */
    event WithdrawalSuccessful(address indexed to, uint256 amount);

    /**
     * @dev Emitted when a refund is claimed.
     * @param paymentId The unique identifier of the cancelled payment.
     * @param refundAmount The refund amount claimed.
     * @param claimer The address of the claimer.
     */
    event RefundClaimed(bytes32 indexed paymentId, uint256 refundAmount, address indexed claimer);

    /**
     * @dev Reverts when one or more provided inputs to the payment treasury are invalid.
     */
    error PaymentTreasuryInvalidInput();

    /**
     * @dev Throws an error indicating that the payment id is already exist.
     */
    error PaymentTreasuryPaymentAlreadyExist(bytes32 paymentId);

    /**
     * @dev Throws an error indicating that the payment id is already confirmed.
     */
    error PaymentTreasuryPaymentAlreadyConfirmed(bytes32 paymentId);

    /**
     * @dev Throws an error indicating that the payment id is already expired.
     */
    error PaymentTreasuryPaymentAlreadyExpired(bytes32 paymentId);

    /**
     * @dev Throws an error indicating that the payment id is not exist.
     */
    error PaymentTreasuryPaymentNotExist(bytes32 paymentId);

    /**
     * @dev Throws an error indicating that the campaign is paused.
     */
    error PaymentTreasuryCampaignInfoIsPaused();

    /**
     * @dev Throws an error indicating that the success condition was not fulfilled.
     */
    error PaymentTreasurySuccessConditionNotFulfilled();

    /**
     * @dev Throws an error indicating that fees have not been disbursed.
     */
    error PaymentTreasuryFeeNotDisbursed();

    /**
     * @dev Throws an error indicating that the payment id is not confirmed.
     */
    error PaymentTreasuryPaymentNotConfirmed(bytes32 paymentId);

    /**
     * @dev Emitted when claiming an unclaimable refund.
     * @param paymentId The unique identifier of the refundable payment.
     */
    error PaymentTreasuryPaymentNotClaimable(bytes32 paymentId);

    /**
     * @dev Emitted when an attempt is made to withdraw funds from the treasury but the payment has already been withdrawn.
     */
    error PaymentTreasuryAlreadyWithdrawn();

    function __BaseContract_init(
        bytes32 platformHash,
        address infoAddress
    ) internal {
        __CampaignAccessChecker_init(infoAddress);
        PLATFORM_HASH = platformHash;
        TOKEN = IERC20(INFO.getTokenAddress());
        PLATFORM_FEE_PERCENT = INFO.getPlatformFeePercent(platformHash);
    }

    /**
     * @dev Modifier that checks if the campaign is not paused.
     */
    modifier whenCampaignNotPaused() {
        _revertIfCampaignPaused();
        _;
    }

    modifier whenCampaignNotCancelled() {
        _revertIfCampaignCancelled();
        _;
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function getplatformHash() external view override returns (bytes32) {
        return PLATFORM_HASH;
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function getplatformFeePercent() external view override returns (uint256) {
        return PLATFORM_FEE_PERCENT;
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function getRaisedAmount() public view override virtual returns (uint256) {
        return s_confirmedPaymentAmount;
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function getAvailableRaisedAmount() external view returns (uint256) {
        return s_availableConfirmedPaymentAmount;
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function createPayment(
        bytes32 paymentId,
        address buyerAddress,
        bytes32 itemId,
        uint256 amount,
        uint256 expiration
    ) public override virtual onlyPlatformAdmin(PLATFORM_HASH) whenCampaignNotPaused whenCampaignNotCancelled {

        if(buyerAddress == address(0) ||
           amount == 0 || 
           expiration <= block.timestamp ||
           paymentId == ZERO_BYTES ||
           itemId == ZERO_BYTES
        ){
            revert PaymentTreasuryInvalidInput();
        }

        if(s_payment[paymentId].buyerAddress != address(0)){
            revert PaymentTreasuryPaymentAlreadyExist(paymentId);
        }

        s_payment[paymentId] = PaymentInfo({
            buyerAddress: buyerAddress,
            itemId: itemId,
            amount: amount,
            expiration: expiration,
            isConfirmed: false
        });

        s_pendingPaymentAmount += amount;

        emit PaymentCreated(
            paymentId,
            buyerAddress,
            itemId,
            amount,
            expiration
        );

    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function cancelPayment(
        bytes32 paymentId
    ) public override virtual onlyPlatformAdmin(PLATFORM_HASH) whenCampaignNotPaused whenCampaignNotCancelled {

        _validatePaymentForAction(paymentId);

        uint256 amount = s_payment[paymentId].amount;

        delete s_payment[paymentId];

        s_pendingPaymentAmount -= amount;

        emit PaymentCancelled(paymentId);

    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function confirmPayment(
        bytes32 paymentId
    ) public override virtual onlyPlatformAdmin(PLATFORM_HASH) whenCampaignNotPaused whenCampaignNotCancelled {

        _validatePaymentForAction(paymentId);

        s_payment[paymentId].isConfirmed = true;

        uint256 amount = s_payment[paymentId].amount;

        s_pendingPaymentAmount -= amount;
        s_confirmedPaymentAmount += amount;
        s_availableConfirmedPaymentAmount += amount;

        emit PaymentConfirmed(paymentId);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function confirmPaymentBatch(
        bytes32[] calldata paymentIds
    ) public override virtual onlyPlatformAdmin(PLATFORM_HASH) whenCampaignNotPaused whenCampaignNotCancelled { 

        for(uint256 i = 0; i < paymentIds.length; i++){
            _validatePaymentForAction(paymentIds[i]);

            s_payment[paymentIds[i]].isConfirmed = true;

            uint256 amount = s_payment[paymentIds[i]].amount;

            s_pendingPaymentAmount -= amount;
            s_confirmedPaymentAmount += amount;
            s_availableConfirmedPaymentAmount += amount;
        }

        emit PaymentBatchConfirmed(paymentIds);

    }

    function claimRefund(
        bytes32 paymentId, 
        address refundAddress
    ) public override virtual onlyPlatformAdmin(PLATFORM_HASH) whenCampaignNotPaused whenCampaignNotCancelled
    {
        PaymentInfo memory payment = s_payment[paymentId];

        if (payment.buyerAddress == address(0)) {
            revert PaymentTreasuryPaymentNotExist(paymentId);
        }
        if(!payment.isConfirmed){
            revert PaymentTreasuryPaymentNotConfirmed(paymentId);
        }

        uint256 amountToRefund = payment.amount;
        if (amountToRefund == 0) {
            revert PaymentTreasuryPaymentNotClaimable(paymentId);
        }

        delete s_payment[paymentId];

        s_confirmedPaymentAmount -= amountToRefund;
        s_availableConfirmedPaymentAmount -= amountToRefund;

        TOKEN.safeTransfer(refundAddress, amountToRefund);
        emit RefundClaimed(paymentId, amountToRefund, refundAddress);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function disburseFees()
        public
        virtual
        override
        whenCampaignNotPaused
        whenCampaignNotCancelled
    {
        if (!_checkSuccessCondition()) {
            revert PaymentTreasurySuccessConditionNotFulfilled();
        }
        uint256 balance = s_availableConfirmedPaymentAmount;
        uint256 protocolShare = (balance * INFO.getProtocolFeePercent()) /
            PERCENT_DIVIDER;
        uint256 platformShare = (balance *
            INFO.getPlatformFeePercent(PLATFORM_HASH)) / PERCENT_DIVIDER;

        s_availableConfirmedPaymentAmount -= protocolShare;
        s_availableConfirmedPaymentAmount -= platformShare;

        TOKEN.safeTransfer(INFO.getProtocolAdminAddress(), protocolShare);

        TOKEN.safeTransfer(
            INFO.getPlatformAdminAddress(PLATFORM_HASH),
            platformShare
        );

        s_feesDisbursed = true;
        emit FeesDisbursed(protocolShare, platformShare);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function withdraw()
        public
        virtual
        override
        whenCampaignNotPaused
        whenCampaignNotCancelled
    {
        if (!s_feesDisbursed) {
            revert PaymentTreasuryFeeNotDisbursed();
        }
        uint256 balance = s_availableConfirmedPaymentAmount;
        if (balance == 0) {
            revert PaymentTreasuryAlreadyWithdrawn();
        }

        address recipient = INFO.owner();
        s_availableConfirmedPaymentAmount = 0;

        TOKEN.safeTransfer(recipient, balance);

        emit WithdrawalSuccessful(recipient, balance);
    }

    /**
     * @dev External function to pause the campaign.
     */
    function pauseTreasury(
        bytes32 message
    ) public virtual onlyPlatformAdmin(PLATFORM_HASH) {
        _pause(message);
    }

    /**
     * @dev External function to unpause the campaign.
     */
    function unpauseTreasury(
        bytes32 message
    ) public virtual onlyPlatformAdmin(PLATFORM_HASH) {
        _unpause(message);
    }

    /**
     * @dev External function to cancel the campaign.
     */
    function cancelTreasury(
        bytes32 message
    ) public virtual onlyPlatformAdmin(PLATFORM_HASH) {
        _cancel(message);
    }

    /**
     * @dev Internal function to check if the campaign is paused.
     * If the campaign is paused, it reverts with TreasuryCampaignInfoIsPaused error.
     */
    function _revertIfCampaignPaused() internal view {
        if (INFO.paused()) {
            revert PaymentTreasuryCampaignInfoIsPaused();
        }
    }

    function _revertIfCampaignCancelled() internal view {
        if (INFO.cancelled()) {
            revert PaymentTreasuryCampaignInfoIsPaused();
        }
    }

    /**
     * @dev Validates the given payment ID to ensure it is eligible for further action.
     * Reverts if:
     * - The payment does not exist.
     * - The payment has already been confirmed.
     * - The payment has already expired.
     * @param paymentId The unique identifier of the payment to validate.
     */
    function _validatePaymentForAction(bytes32 paymentId) internal view {
        PaymentInfo memory payment = s_payment[paymentId];

        if (payment.buyerAddress == address(0)) {
            revert PaymentTreasuryPaymentNotExist(paymentId);
        }

        if (payment.isConfirmed) {
            revert PaymentTreasuryPaymentAlreadyConfirmed(paymentId);
        }

        if (payment.expiration <= block.timestamp) {
            revert PaymentTreasuryPaymentAlreadyExpired(paymentId);
        }
    }

    /**
     * @dev Internal function to check the success condition for fee disbursement.
     * @return Whether the success condition is met.
     */
    function _checkSuccessCondition() internal view virtual returns (bool);

}