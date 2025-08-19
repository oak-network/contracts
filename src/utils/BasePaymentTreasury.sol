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
    uint256 internal s_platformFee;
    uint256 internal s_protocolFee;
    /**
     * @dev Stores information about a payment in the treasury.
     * @param buyerAddress The address of the buyer who made the payment.
     * @param buyerId The ID of the buyer.
     * @param itemId The identifier of the item being purchased.
     * @param amount The amount to be paid for the item.
     * @param expiration The timestamp after which the payment expires.
     * @param isConfirmed Boolean indicating whether the payment has been confirmed.
     * @param isCryptoPayment Boolean indicating whether the payment is made using direct crypto payment.
     */
    struct PaymentInfo {
        address buyerAddress;
        bytes32 buyerId;
        bytes32 itemId;
        uint256 amount;
        uint256 expiration;
        bool isConfirmed;
        bool isCryptoPayment;
    }

    mapping (bytes32 => PaymentInfo) internal s_payment;
    uint256 internal s_pendingPaymentAmount;
    uint256 internal s_confirmedPaymentAmount;
    uint256 internal s_availableConfirmedPaymentAmount;

    /**
     * @dev Emitted when a new payment is created.
     * @param buyerAddress The address of the buyer making the payment.
     * @param paymentId The unique identifier of the payment.
     * @param buyerId The id of the buyer.
     * @param itemId The identifier of the item being purchased.
     * @param amount The amount to be paid for the item.
     * @param expiration The timestamp after which the payment expires.
     * @param isCryptoPayment Boolean indicating whether the payment is made using direct crypto payment.
     */
    event PaymentCreated(
        address buyerAddress,
        bytes32 indexed paymentId,
        bytes32 buyerId,
        bytes32 indexed itemId,
        uint256 amount,
        uint256 expiration,
        bool isCryptoPayment
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
     * @dev Emitted when a withdrawal is successfully processed along with the applied fee.
     * @param to The recipient address receiving the funds.
     * @param amount The total amount withdrawn (excluding fee).
     * @param fee The fee amount deducted from the withdrawal.
     */
    event WithdrawalWithFeeSuccessful(address indexed to, uint256 amount, uint256 fee);

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

    /**
     * @dev This error is thrown when an operation is attempted on a crypto payment that is only valid for non-crypto payments.
     * @param paymentId The unique identifier of the payment that caused the error.
     */
    error PaymentTreasuryCryptoPayment(bytes32 paymentId);

    /**
     * @notice Emitted when the fee exceeds the requested withdrawal amount.
     *
     * @param withdrawalAmount The amount requested for withdrawal.
     * @param fee The calculated fee, which is greater than the withdrawal amount.
     */
    error PaymentTreasuryInsufficientFundsForFee(uint256 withdrawalAmount, uint256 fee);

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
     * @notice Ensures that the caller is either the payment's buyer or the platform admin.
     * @param paymentId The unique identifier of the payment to validate access for.
     */
    modifier onlyBuyerOrPlatformAdmin(bytes32 paymentId) {
        PaymentInfo memory payment = s_payment[paymentId];
        address buyerAddress = payment.buyerAddress;

        if (
            msg.sender != buyerAddress &&
            msg.sender != INFO.getPlatformAdminAddress(PLATFORM_HASH)
        ) {
            revert PaymentTreasuryPaymentNotClaimable(paymentId);
        }
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
        bytes32 buyerId,
        bytes32 itemId,
        uint256 amount,
        uint256 expiration
    ) public override virtual onlyPlatformAdmin(PLATFORM_HASH) whenCampaignNotPaused whenCampaignNotCancelled {

        if(buyerId == ZERO_BYTES ||
           amount == 0 || 
           expiration <= block.timestamp ||
           paymentId == ZERO_BYTES ||
           itemId == ZERO_BYTES
        ){
            revert PaymentTreasuryInvalidInput();
        }

        if(s_payment[paymentId].buyerId != ZERO_BYTES || s_payment[paymentId].buyerAddress != address(0)){
            revert PaymentTreasuryPaymentAlreadyExist(paymentId);
        }

        s_payment[paymentId] = PaymentInfo({
            buyerId: buyerId,
            buyerAddress: address(0),
            itemId: itemId,
            amount: amount,
            expiration: expiration,
            isConfirmed: false,
            isCryptoPayment: false
        });

        s_pendingPaymentAmount += amount;

        emit PaymentCreated(
            address(0),
            paymentId,
            buyerId,
            itemId,
            amount,
            expiration,
            false
        );

    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function processCryptoPayment(
        bytes32 paymentId,
        bytes32 itemId,
        address buyerAddress,
        uint256 amount
    ) public override virtual whenCampaignNotPaused whenCampaignNotCancelled {
        
        if(buyerAddress == address(0) ||
           amount == 0 || 
           paymentId == ZERO_BYTES ||
           itemId == ZERO_BYTES
        ){
            revert PaymentTreasuryInvalidInput();
        }

        if(s_payment[paymentId].buyerAddress != address(0) || s_payment[paymentId].buyerId != ZERO_BYTES){
            revert PaymentTreasuryPaymentAlreadyExist(paymentId);
        }

        TOKEN.safeTransferFrom(buyerAddress, address(this), amount);

        s_payment[paymentId] = PaymentInfo({
            buyerId: ZERO_BYTES,
            buyerAddress: buyerAddress,
            itemId: itemId,
            amount: amount,
            expiration: 0, 
            isConfirmed: true, 
            isCryptoPayment: true
        });

        s_confirmedPaymentAmount += amount;
        s_availableConfirmedPaymentAmount += amount;

        emit PaymentCreated(
            buyerAddress,
            paymentId,
            ZERO_BYTES,
            itemId,
            amount,
            0,
            true
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

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function claimRefund(
        bytes32 paymentId, 
        address refundAddress
    ) public override virtual onlyPlatformAdmin(PLATFORM_HASH) whenCampaignNotPaused whenCampaignNotCancelled
    {
        if(refundAddress == address(0)){
            revert PaymentTreasuryInvalidInput();
        }
        PaymentInfo memory payment = s_payment[paymentId];
        uint256 amountToRefund = payment.amount;
        uint256 availablePaymentAmount = s_availableConfirmedPaymentAmount;

        if (payment.buyerId == ZERO_BYTES) {
            revert PaymentTreasuryPaymentNotExist(paymentId);
        }
        if(!payment.isConfirmed){
            revert PaymentTreasuryPaymentNotConfirmed(paymentId);
        }
        if (amountToRefund == 0 || availablePaymentAmount < amountToRefund) {
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
    function claimRefund(
        bytes32 paymentId
    ) public override virtual onlyBuyerOrPlatformAdmin(paymentId) whenCampaignNotPaused whenCampaignNotCancelled
    {
        PaymentInfo memory payment = s_payment[paymentId];
        address buyerAddress = payment.buyerAddress;
        uint256 amountToRefund = payment.amount;
        uint256 availablePaymentAmount = s_availableConfirmedPaymentAmount;

        if (buyerAddress == address(0)) {
            revert PaymentTreasuryPaymentNotExist(paymentId);
        }
        if (amountToRefund == 0 || availablePaymentAmount < amountToRefund) {
            revert PaymentTreasuryPaymentNotClaimable(paymentId);
        }

        delete s_payment[paymentId];

        s_confirmedPaymentAmount -= amountToRefund;
        s_availableConfirmedPaymentAmount -= amountToRefund;

        TOKEN.safeTransfer(buyerAddress, amountToRefund);
        emit RefundClaimed(paymentId, amountToRefund, buyerAddress);
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
        uint256 protocolShare = s_protocolFee;
        uint256 platformShare = s_platformFee;
        (s_protocolFee, s_platformFee) = (0, 0);
        
        TOKEN.safeTransfer(INFO.getProtocolAdminAddress(), protocolShare);
        
        TOKEN.safeTransfer(
            INFO.getPlatformAdminAddress(PLATFORM_HASH),
            platformShare
        );
        
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
        if (!_checkSuccessCondition()) {
            revert PaymentTreasurySuccessConditionNotFulfilled();
        }

        address recipient = INFO.owner();
        uint256 balance = s_availableConfirmedPaymentAmount;
        if (balance == 0) {
            revert PaymentTreasuryAlreadyWithdrawn();
        }

        // Calculate fees
        uint256 protocolShare = (balance * INFO.getProtocolFeePercent()) / PERCENT_DIVIDER;
        uint256 platformShare = (balance * INFO.getPlatformFeePercent(PLATFORM_HASH)) / PERCENT_DIVIDER;

        s_protocolFee += protocolShare;
        s_platformFee += platformShare;

        uint256 totalFee = protocolShare + platformShare;

        if(balance < totalFee) {
            revert PaymentTreasuryInsufficientFundsForFee(balance, totalFee);
        }
        uint256 withdrawalAmount = balance - totalFee;
        
        // Reset balance
        s_availableConfirmedPaymentAmount = 0;

        TOKEN.safeTransfer(recipient, withdrawalAmount);

        emit WithdrawalWithFeeSuccessful(recipient, withdrawalAmount, totalFee);
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
     * - The payment is a crypto payment
     * @param paymentId The unique identifier of the payment to validate.
     */
    function _validatePaymentForAction(bytes32 paymentId) internal view {
        PaymentInfo memory payment = s_payment[paymentId];

        if (payment.buyerId == ZERO_BYTES) {
            revert PaymentTreasuryPaymentNotExist(paymentId);
        }

        if (payment.isConfirmed) {
            revert PaymentTreasuryPaymentAlreadyConfirmed(paymentId);
        }

        if (payment.expiration <= block.timestamp) {
            revert PaymentTreasuryPaymentAlreadyExpired(paymentId);
        }

        if (payment.isCryptoPayment) {
            revert PaymentTreasuryCryptoPayment(paymentId);
        }
    }

    /**
     * @dev Internal function to check the success condition for fee disbursement.
     * @return Whether the success condition is met.
     */
    function _checkSuccessCondition() internal view virtual returns (bool);

}