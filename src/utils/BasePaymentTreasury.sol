// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
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
    uint256 internal constant STANDARD_DECIMALS = 18;

    bytes32 internal PLATFORM_HASH;
    uint256 internal PLATFORM_FEE_PERCENT;
    
    // Multi-token support
    mapping(bytes32 => address) internal s_paymentIdToToken; // Track token used for each payment
    mapping(address => uint256) internal s_platformFeePerToken; // Platform fees per token
    mapping(address => uint256) internal s_protocolFeePerToken; // Protocol fees per token
    
    /**
     * @dev Stores information about a payment in the treasury.
     * @param buyerAddress The address of the buyer who made the payment.
     * @param buyerId The ID of the buyer.
     * @param itemId The identifier of the item being purchased.
     * @param amount The amount to be paid for the item (in token's native decimals).
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
    
    // Multi-token balances (all in token's native decimals)
    mapping(address => uint256) internal s_pendingPaymentPerToken; // Pending payment amounts per token
    mapping(address => uint256) internal s_confirmedPaymentPerToken; // Confirmed payment amounts per token
    mapping(address => uint256) internal s_availableConfirmedPerToken; // Available confirmed amounts per token

    /**
     * @dev Emitted when a new payment is created.
     * @param buyerAddress The address of the buyer making the payment.
     * @param paymentId The unique identifier of the payment.
     * @param buyerId The id of the buyer.
     * @param itemId The identifier of the item being purchased.
     * @param paymentToken The token used for the payment.
     * @param amount The amount to be paid for the item (in token's native decimals).
     * @param expiration The timestamp after which the payment expires.
     * @param isCryptoPayment Boolean indicating whether the payment is made using direct crypto payment.
     */
    event PaymentCreated(
        address buyerAddress,
        bytes32 indexed paymentId,
        bytes32 buyerId,
        bytes32 indexed itemId,
        address indexed paymentToken,
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
     * @dev Emitted when multiple payments are created in a single batch operation.
     * @param paymentIds An array of unique identifiers for the created payments.
     */
    event PaymentBatchCreated(
        bytes32[] paymentIds
    );

    /**
     * @notice Emitted when fees are successfully disbursed.
     * @param token The token in which fees were disbursed.
     * @param protocolShare The amount of fees sent to the protocol.
     * @param platformShare The amount of fees sent to the platform.
     */
    event FeesDisbursed(address indexed token, uint256 protocolShare, uint256 platformShare);

    /**
     * @dev Emitted when a withdrawal is successfully processed along with the applied fee.
     * @param token The token that was withdrawn.
     * @param to The recipient address receiving the funds.
     * @param amount The total amount withdrawn (excluding fee).
     * @param fee The fee amount deducted from the withdrawal.
     */
    event WithdrawalWithFeeSuccessful(address indexed token, address indexed to, uint256 amount, uint256 fee);

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
     * @dev Throws an error indicating that the payment id already exists.
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
     * @dev Throws an error indicating that the payment id does not exist.
     */
    error PaymentTreasuryPaymentNotExist(bytes32 paymentId);

    /**
     * @dev Throws an error indicating that the campaign is paused.
     */
    error PaymentTreasuryCampaignInfoIsPaused();

    /**
     * @dev Emitted when a token is not accepted for the campaign.
     */
    error PaymentTreasuryTokenNotAccepted(address token);

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

    /**
     * @dev Emitted when there are insufficient unallocated tokens for a payment confirmation.
     */
    error PaymentTreasuryInsufficientBalance(uint256 required, uint256 available);

    function __BaseContract_init(
        bytes32 platformHash,
        address infoAddress
    ) internal {
        __CampaignAccessChecker_init(infoAddress);
        PLATFORM_HASH = platformHash;
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
            _msgSender() != buyerAddress &&
            _msgSender() != INFO.getPlatformAdminAddress(PLATFORM_HASH)
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
        address[] memory acceptedTokens = INFO.getAcceptedTokens();
        uint256 totalNormalized = 0;
        
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            address token = acceptedTokens[i];
            uint256 amount = s_confirmedPaymentPerToken[token];
            if (amount > 0) {
                totalNormalized += _normalizeAmount(token, amount);
            }
        }
        
        return totalNormalized;
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function getAvailableRaisedAmount() external view returns (uint256) {
        address[] memory acceptedTokens = INFO.getAcceptedTokens();
        uint256 totalNormalized = 0;
        
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            address token = acceptedTokens[i];
            uint256 amount = s_availableConfirmedPerToken[token];
            if (amount > 0) {
                totalNormalized += _normalizeAmount(token, amount);
            }
        }
        
        return totalNormalized;
    }
    
    /**
     * @dev Normalizes token amounts to 18 decimals for consistent comparisons.
     * @param token The token address.
     * @param amount The amount to normalize.
     * @return The normalized amount (scaled to 18 decimals).
     */
    function _normalizeAmount(
        address token,
        uint256 amount
    ) internal view returns (uint256) {
        uint8 decimals = IERC20Metadata(token).decimals();
        
        if (decimals == STANDARD_DECIMALS) {
            return amount;
        } else if (decimals < STANDARD_DECIMALS) {
            return amount * (10 ** (STANDARD_DECIMALS - decimals));
        } else {
            return amount / (10 ** (decimals - STANDARD_DECIMALS));
        }
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
    ) public override virtual onlyPlatformAdmin(PLATFORM_HASH) whenCampaignNotPaused whenCampaignNotCancelled {

        if(buyerId == ZERO_BYTES ||
           amount == 0 || 
           expiration <= block.timestamp ||
           paymentId == ZERO_BYTES ||
           itemId == ZERO_BYTES ||
           paymentToken == address(0)
        ){
            revert PaymentTreasuryInvalidInput();
        }

        // Validate token is accepted
        if (!INFO.isTokenAccepted(paymentToken)) {
            revert PaymentTreasuryTokenNotAccepted(paymentToken);
        }

        if(s_payment[paymentId].buyerId != ZERO_BYTES || s_payment[paymentId].buyerAddress != address(0)){
            revert PaymentTreasuryPaymentAlreadyExist(paymentId);
        }

        s_payment[paymentId] = PaymentInfo({
            buyerId: buyerId,
            buyerAddress: address(0),
            itemId: itemId,
            amount: amount, // Amount in token's native decimals
            expiration: expiration,
            isConfirmed: false,
            isCryptoPayment: false
        });

        s_paymentIdToToken[paymentId] = paymentToken;
        s_pendingPaymentPerToken[paymentToken] += amount;

        emit PaymentCreated(
            address(0),
            paymentId,
            buyerId,
            itemId,
            paymentToken,
            amount,
            expiration,
            false
        );
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
    ) public override virtual onlyPlatformAdmin(PLATFORM_HASH) whenCampaignNotPaused whenCampaignNotCancelled {
        
        // Validate array lengths are consistent
        uint256 length = paymentIds.length;
        if (length == 0 || 
            length != buyerIds.length || 
            length != itemIds.length || 
            length != paymentTokens.length ||
            length != amounts.length || 
            length != expirations.length) {
            revert PaymentTreasuryInvalidInput();
        }

        // Process each payment in the batch
        for (uint256 i = 0; i < length;) {
            bytes32 paymentId = paymentIds[i];
            bytes32 buyerId = buyerIds[i];
            bytes32 itemId = itemIds[i];
            address paymentToken = paymentTokens[i];
            uint256 amount = amounts[i];
            uint256 expiration = expirations[i];

            // Validate individual payment parameters
            if(buyerId == ZERO_BYTES ||
               amount == 0 || 
               expiration <= block.timestamp ||
               paymentId == ZERO_BYTES ||
               itemId == ZERO_BYTES ||
               paymentToken == address(0)
            ){
                revert PaymentTreasuryInvalidInput();
            }

            // Validate token is accepted
            if (!INFO.isTokenAccepted(paymentToken)) {
                revert PaymentTreasuryTokenNotAccepted(paymentToken);
            }

            // Check if payment already exists
            if(s_payment[paymentId].buyerId != ZERO_BYTES || s_payment[paymentId].buyerAddress != address(0)){
                revert PaymentTreasuryPaymentAlreadyExist(paymentId);
            }

            // Create the payment
            s_payment[paymentId] = PaymentInfo({
                buyerId: buyerId,
                buyerAddress: address(0),
                itemId: itemId,
                amount: amount, // Amount in token's native decimals
                expiration: expiration,
                isConfirmed: false,
                isCryptoPayment: false
            });

            s_paymentIdToToken[paymentId] = paymentToken;
            s_pendingPaymentPerToken[paymentToken] += amount;

            emit PaymentCreated(
                address(0),
                paymentId,
                buyerId,
                itemId,
                paymentToken,
                amount,
                expiration,
                false
            );

            unchecked {
                ++i;
            }
        }

        emit PaymentBatchCreated(paymentIds);
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
    ) public override virtual whenCampaignNotPaused whenCampaignNotCancelled {
        
        if(buyerAddress == address(0) ||
           amount == 0 || 
           paymentId == ZERO_BYTES ||
           itemId == ZERO_BYTES ||
           paymentToken == address(0)
        ){
            revert PaymentTreasuryInvalidInput();
        }

        // Validate token is accepted
        if (!INFO.isTokenAccepted(paymentToken)) {
            revert PaymentTreasuryTokenNotAccepted(paymentToken);
        }

        if(s_payment[paymentId].buyerAddress != address(0) || s_payment[paymentId].buyerId != ZERO_BYTES){
            revert PaymentTreasuryPaymentAlreadyExist(paymentId);
        }

        IERC20(paymentToken).safeTransferFrom(buyerAddress, address(this), amount);

        s_payment[paymentId] = PaymentInfo({
            buyerId: ZERO_BYTES,
            buyerAddress: buyerAddress,
            itemId: itemId,
            amount: amount, // Amount in token's native decimals
            expiration: 0, 
            isConfirmed: true, 
            isCryptoPayment: true
        });

        s_paymentIdToToken[paymentId] = paymentToken;
        s_confirmedPaymentPerToken[paymentToken] += amount;
        s_availableConfirmedPerToken[paymentToken] += amount;

        emit PaymentCreated(
            buyerAddress,
            paymentId,
            ZERO_BYTES,
            itemId,
            paymentToken,
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

        address paymentToken = s_paymentIdToToken[paymentId];
        uint256 amount = s_payment[paymentId].amount;

        delete s_payment[paymentId];
        delete s_paymentIdToToken[paymentId];

        s_pendingPaymentPerToken[paymentToken] -= amount;

        emit PaymentCancelled(paymentId);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function confirmPayment(
        bytes32 paymentId
    ) public override virtual onlyPlatformAdmin(PLATFORM_HASH) whenCampaignNotPaused whenCampaignNotCancelled {
        _validatePaymentForAction(paymentId);
    
        address paymentToken = s_paymentIdToToken[paymentId];
        uint256 paymentAmount = s_payment[paymentId].amount;
        
        // Check that we have enough unallocated tokens for this payment
        uint256 actualBalance = IERC20(paymentToken).balanceOf(address(this));
        uint256 currentlyCommitted = s_availableConfirmedPerToken[paymentToken] + 
                                      s_protocolFeePerToken[paymentToken] + 
                                      s_platformFeePerToken[paymentToken];
        
        if (currentlyCommitted + paymentAmount > actualBalance) {
            revert PaymentTreasuryInsufficientBalance(
                currentlyCommitted + paymentAmount,
                actualBalance
            );
        }
        
        s_payment[paymentId].isConfirmed = true;
 
        s_pendingPaymentPerToken[paymentToken] -= paymentAmount;
        s_confirmedPaymentPerToken[paymentToken] += paymentAmount;
        s_availableConfirmedPerToken[paymentToken] += paymentAmount;
        
        emit PaymentConfirmed(paymentId);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function confirmPaymentBatch(
        bytes32[] calldata paymentIds
    ) public override virtual onlyPlatformAdmin(PLATFORM_HASH) whenCampaignNotPaused whenCampaignNotCancelled {
        
        bytes32 currentPaymentId;
        address currentToken;
        
        for(uint256 i = 0; i < paymentIds.length;){
            currentPaymentId = paymentIds[i];
            
            _validatePaymentForAction(currentPaymentId);
            
            currentToken = s_paymentIdToToken[currentPaymentId];
            uint256 amount = s_payment[currentPaymentId].amount;
            uint256 actualBalance = IERC20(currentToken).balanceOf(address(this));
            
            // Check if this confirmation would exceed balance
            uint256 currentlyCommitted = s_availableConfirmedPerToken[currentToken] + 
                                          s_protocolFeePerToken[currentToken] + 
                                          s_platformFeePerToken[currentToken];
            
            if (currentlyCommitted + amount > actualBalance) {
                revert PaymentTreasuryInsufficientBalance(
                    currentlyCommitted + amount,
                    actualBalance
                );
            }
            
            s_payment[currentPaymentId].isConfirmed = true;
            s_pendingPaymentPerToken[currentToken] -= amount;
            s_confirmedPaymentPerToken[currentToken] += amount;
            s_availableConfirmedPerToken[currentToken] += amount;

            unchecked {
                ++i;
            }
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
        address paymentToken = s_paymentIdToToken[paymentId];
        uint256 amountToRefund = payment.amount;
        uint256 availablePaymentAmount = s_availableConfirmedPerToken[paymentToken];

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
        delete s_paymentIdToToken[paymentId];

        s_confirmedPaymentPerToken[paymentToken] -= amountToRefund;
        s_availableConfirmedPerToken[paymentToken] -= amountToRefund;

        IERC20(paymentToken).safeTransfer(refundAddress, amountToRefund);
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
        address paymentToken = s_paymentIdToToken[paymentId];
        address buyerAddress = payment.buyerAddress;
        uint256 amountToRefund = payment.amount;
        uint256 availablePaymentAmount = s_availableConfirmedPerToken[paymentToken];

        if (buyerAddress == address(0)) {
            revert PaymentTreasuryPaymentNotExist(paymentId);
        }
        if (amountToRefund == 0 || availablePaymentAmount < amountToRefund) {
            revert PaymentTreasuryPaymentNotClaimable(paymentId);
        }

        delete s_payment[paymentId];
        delete s_paymentIdToToken[paymentId];

        s_confirmedPaymentPerToken[paymentToken] -= amountToRefund;
        s_availableConfirmedPerToken[paymentToken] -= amountToRefund;

        IERC20(paymentToken).safeTransfer(buyerAddress, amountToRefund);
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
        address[] memory acceptedTokens = INFO.getAcceptedTokens();
        address protocolAdmin = INFO.getProtocolAdminAddress();
        address platformAdmin = INFO.getPlatformAdminAddress(PLATFORM_HASH);
        
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            address token = acceptedTokens[i];
            uint256 protocolShare = s_protocolFeePerToken[token];
            uint256 platformShare = s_platformFeePerToken[token];
            
            if (protocolShare > 0 || platformShare > 0) {
                s_protocolFeePerToken[token] = 0;
                s_platformFeePerToken[token] = 0;
                
                if (protocolShare > 0) {
                    IERC20(token).safeTransfer(protocolAdmin, protocolShare);
                }
                
                if (platformShare > 0) {
                    IERC20(token).safeTransfer(platformAdmin, platformShare);
                }
                
                emit FeesDisbursed(token, protocolShare, platformShare);
            }
        }
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
        address[] memory acceptedTokens = INFO.getAcceptedTokens();
        uint256 protocolFeePercent = INFO.getProtocolFeePercent();
        uint256 platformFeePercent = INFO.getPlatformFeePercent(PLATFORM_HASH);
        
        bool hasWithdrawn = false;
        
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            address token = acceptedTokens[i];
            uint256 balance = s_availableConfirmedPerToken[token];
            
            if (balance > 0) {
                hasWithdrawn = true;
                
                // Calculate fees
                uint256 protocolShare = (balance * protocolFeePercent) / PERCENT_DIVIDER;
                uint256 platformShare = (balance * platformFeePercent) / PERCENT_DIVIDER;

                s_protocolFeePerToken[token] += protocolShare;
                s_platformFeePerToken[token] += platformShare;

                uint256 totalFee = protocolShare + platformShare;

                if(balance < totalFee) {
                    revert PaymentTreasuryInsufficientFundsForFee(balance, totalFee);
                }
                uint256 withdrawalAmount = balance - totalFee;
                
                // Reset balance
                s_availableConfirmedPerToken[token] = 0;

                IERC20(token).safeTransfer(recipient, withdrawalAmount);

                emit WithdrawalWithFeeSuccessful(token, recipient, withdrawalAmount, totalFee);
            }
        }
        
        if (!hasWithdrawn) {
            revert PaymentTreasuryAlreadyWithdrawn();
        }
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
     * If the campaign is paused, it reverts with PaymentTreasuryCampaignInfoIsPaused error.
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