// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ICampaignPaymentTreasury} from "../interfaces/ICampaignPaymentTreasury.sol";
import {CampaignAccessChecker} from "./CampaignAccessChecker.sol";
import {PausableCancellable} from "./PausableCancellable.sol";
import {DataRegistryKeys} from "../constants/DataRegistryKeys.sol";

abstract contract BasePaymentTreasury is 
    Initializable,
    ICampaignPaymentTreasury,
    CampaignAccessChecker,
    PausableCancellable,
    ReentrancyGuard
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
    mapping(bytes32 => uint256) internal s_paymentIdToTokenId; // Track NFT token ID for each payment (0 means no NFT)
    
    /**
     * @dev Stores information about a payment in the treasury.
     * @param buyerAddress The address of the buyer who made the payment.
     * @param buyerId The ID of the buyer.
     * @param itemId The identifier of the item being purchased.
     * @param amount The amount to be paid for the item (in token's native decimals).
     * @param expiration The timestamp after which the payment expires.
     * @param isConfirmed Boolean indicating whether the payment has been confirmed.
     * @param isCryptoPayment Boolean indicating whether the payment is made using direct crypto payment.
     * @param lineItemCount The number of line items associated with this payment.
     */
    struct PaymentInfo {
        address buyerAddress;
        bytes32 buyerId;
        bytes32 itemId;
        uint256 amount;
        uint256 expiration;
        bool isConfirmed;
        bool isCryptoPayment;
        uint256 lineItemCount;
    }

    mapping (bytes32 => PaymentInfo) internal s_payment;
    
    // Combined line items with their configuration snapshots per payment ID
    mapping (bytes32 => ICampaignPaymentTreasury.PaymentLineItem[]) internal s_paymentLineItems; // paymentId => array of stored line items
    
    // External fees per payment ID
    mapping (bytes32 => ICampaignPaymentTreasury.ExternalFees[]) internal s_paymentExternalFees; // paymentId => array of external fees
    
    // Multi-token balances (all in token's native decimals)
    mapping(address => uint256) internal s_pendingPaymentPerToken; // Pending payment amounts per token
    mapping(address => uint256) internal s_confirmedPaymentPerToken; // Confirmed payment amounts per token (decreases on refunds)
    mapping(address => uint256) internal s_lifetimeConfirmedPaymentPerToken; // Lifetime confirmed payment amounts per token (never decreases)
    mapping(address => uint256) internal s_availableConfirmedPerToken; // Available confirmed amounts per token
    
    // Tracking for non-goal line items (countTowardsGoal = False) per token
    mapping(address => uint256) internal s_nonGoalLineItemPendingPerToken; // Pending non-goal line items per token
    mapping(address => uint256) internal s_nonGoalLineItemConfirmedPerToken; // Confirmed non-goal line items per token
    mapping(address => uint256) internal s_nonGoalLineItemClaimablePerToken; // Claimable non-goal line items per token (after fees)
    mapping(address => uint256) internal s_refundableNonGoalLineItemPerToken; // Refundable non-goal line items per token (after fees)

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
     * @dev Emitted when non-goal line items are claimed by the platform admin.
     * @param token The token that was claimed.
     * @param amount The amount claimed.
     * @param platformAdmin The address of the platform admin who claimed.
     */
    event NonGoalLineItemsClaimed(address indexed token, uint256 amount, address indexed platformAdmin);

    /**
     * @dev Emitted when expired funds are claimed by the platform and protocol admins.
     * @param token The token that was claimed.
     * @param platformAmount The amount sent to the platform admin.
     * @param protocolAmount The amount sent to the protocol admin.
     */
    event ExpiredFundsClaimed(address indexed token, uint256 platformAmount, uint256 protocolAmount);

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

    /**
     * @dev Throws an error indicating that the payment expiration exceeds the maximum allowed expiration time.
     * @param expiration The requested expiration timestamp.
     * @param maxExpiration The maximum allowed expiration timestamp.
     */
    error PaymentTreasuryExpirationExceedsMax(uint256 expiration, uint256 maxExpiration);

    /**
     * @dev Throws when attempting to claim expired funds before the claim window opens.
     * @param claimableAt The timestamp when the claim window opens.
     */
    error PaymentTreasuryClaimWindowNotReached(uint256 claimableAt);

    /**
     * @dev Throws when there are no funds available to claim.
     */
    error PaymentTreasuryNoFundsToClaim();

    /**
     * @dev Retrieves the max expiration duration configured for the current platform or globally.
     * @return hasLimit Indicates whether a max expiration duration is configured.
     * @return duration The max expiration duration in seconds.
     */
    function _getMaxExpirationDuration() internal view returns (bool hasLimit, uint256 duration) {
        bytes32 platformScopedKey = DataRegistryKeys.scopedToPlatform(
            DataRegistryKeys.MAX_PAYMENT_EXPIRATION,
            PLATFORM_HASH
        );

        // Prefer platform-specific value stored in GlobalParams via registry.
        bytes32 maxExpirationBytes = INFO.getDataFromRegistry(platformScopedKey);

        if (maxExpirationBytes == ZERO_BYTES) {
            maxExpirationBytes = INFO.getDataFromRegistry(DataRegistryKeys.MAX_PAYMENT_EXPIRATION);
        }

        if (maxExpirationBytes == ZERO_BYTES) {
            return (false, 0);
        }

        duration = uint256(maxExpirationBytes);

        if (duration == 0) {
            return (false, 0);
        }

        hasLimit = true;
    }

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
     * @inheritdoc ICampaignPaymentTreasury
     */
    function getLifetimeRaisedAmount() external view returns (uint256) {
        address[] memory acceptedTokens = INFO.getAcceptedTokens();
        uint256 totalNormalized = 0;
        
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            address token = acceptedTokens[i];
            uint256 amount = s_lifetimeConfirmedPaymentPerToken[token];
            if (amount > 0) {
                totalNormalized += _normalizeAmount(token, amount);
            }
        }
        
        return totalNormalized;
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function getRefundedAmount() external view returns (uint256) {
        address[] memory acceptedTokens = INFO.getAcceptedTokens();
        uint256 totalNormalized = 0;
        
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            address token = acceptedTokens[i];
            uint256 lifetimeAmount = s_lifetimeConfirmedPaymentPerToken[token];
            uint256 currentAmount = s_confirmedPaymentPerToken[token];
            uint256 refundedAmount = lifetimeAmount - currentAmount;
            if (refundedAmount > 0) {
                totalNormalized += _normalizeAmount(token, refundedAmount);
            }
        }
        
        return totalNormalized;
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function getExpectedAmount() external view returns (uint256) {
        address[] memory acceptedTokens = INFO.getAcceptedTokens();
        uint256 totalNormalized = 0;
        
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            address token = acceptedTokens[i];
            uint256 amount = s_pendingPaymentPerToken[token];
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
     * @dev Struct to hold line item calculation totals to reduce stack depth.
     */
    struct LineItemTotals {
        uint256 totalGoalLineItemAmount;
        uint256 totalProtocolFeeFromLineItems;
        uint256 totalNonGoalClaimableAmount;
        uint256 totalNonGoalRefundableAmount;
        uint256 totalInstantTransferAmountForCheck;
        uint256 totalInstantTransferAmount;
    }

    /**
     * @dev Validates, stores, and tracks line items in a single loop for gas efficiency.
     * @param paymentId The payment ID to store line items for.
     * @param lineItems Array of line items to validate, store, and track.
     * @param paymentToken The token used for the payment.
     */
    function _validateStoreAndTrackLineItems(
        bytes32 paymentId,
        ICampaignPaymentTreasury.LineItem[] calldata lineItems,
        address paymentToken
    ) internal {
        for (uint256 i = 0; i < lineItems.length; i++) {
            ICampaignPaymentTreasury.LineItem calldata item = lineItems[i];
            
            // Validate line item
            if (item.typeId == ZERO_BYTES || item.amount == 0) {
                revert PaymentTreasuryInvalidInput();
            }
            
            // Get line item type configuration (single call per item)
            (
                bool exists,
                string memory label,
                bool countsTowardGoal,
                bool applyProtocolFee,
                bool canRefund,
                bool instantTransfer
            ) = INFO.getLineItemType(PLATFORM_HASH, item.typeId);
            
            if (!exists) {
                revert PaymentTreasuryInvalidInput();
            }
            
            // Store line item with configuration snapshot
            s_paymentLineItems[paymentId].push(ICampaignPaymentTreasury.PaymentLineItem({
                typeId: item.typeId,
                amount: item.amount,
                label: label,
                countsTowardGoal: countsTowardGoal,
                applyProtocolFee: applyProtocolFee,
                canRefund: canRefund,
                instantTransfer: instantTransfer
            }));
            
            // Track pending amounts based on whether it counts toward goal
            if (countsTowardGoal) {
                s_pendingPaymentPerToken[paymentToken] += item.amount;
            } else {
                s_nonGoalLineItemPendingPerToken[paymentToken] += item.amount;
            }
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
        uint256 expiration,
        ICampaignPaymentTreasury.LineItem[] calldata lineItems,
        ICampaignPaymentTreasury.ExternalFees[] calldata externalFees
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

        // Validate expiration does not exceed maximum allowed expiration time (platform-specific or global)
        (bool hasMaxExpiration, uint256 maxExpirationDuration) = _getMaxExpirationDuration();
        if (hasMaxExpiration) {
            uint256 maxAllowedExpiration = block.timestamp + maxExpirationDuration;
            if (expiration > maxAllowedExpiration) {
                revert PaymentTreasuryExpirationExceedsMax(expiration, maxAllowedExpiration);
            }
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
            isCryptoPayment: false,
            lineItemCount: lineItems.length
        });

        // Validate, store, and track line items
        _validateStoreAndTrackLineItems(paymentId, lineItems, paymentToken);

        // Store external fees
        ICampaignPaymentTreasury.ExternalFees[] storage storedExternalFees = s_paymentExternalFees[paymentId];
        for (uint256 i = 0; i < externalFees.length; ) {
            storedExternalFees.push(externalFees[i]);
            unchecked {
                ++i;
            }
        }

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
        uint256[] calldata expirations,
        ICampaignPaymentTreasury.LineItem[][] calldata lineItemsArray,
        ICampaignPaymentTreasury.ExternalFees[][] calldata externalFeesArray
    ) public override virtual onlyPlatformAdmin(PLATFORM_HASH) whenCampaignNotPaused whenCampaignNotCancelled {
        
        // Validate array lengths are consistent
        uint256 length = paymentIds.length;
        if (length == 0 || 
            length != buyerIds.length || 
            length != itemIds.length || 
            length != paymentTokens.length ||
            length != amounts.length || 
            length != expirations.length ||
            length != lineItemsArray.length ||
            length != externalFeesArray.length) {
            revert PaymentTreasuryInvalidInput();
        }

        // Get max expiration duration once outside the loop for efficiency (platform-specific or global)
        (bool hasMaxExpiration, uint256 maxExpirationDuration) = _getMaxExpirationDuration();
        uint256 maxAllowedExpiration = 0;
        if (hasMaxExpiration) {
            maxAllowedExpiration = block.timestamp + maxExpirationDuration;
        }

        // Process each payment in the batch
        for (uint256 i = 0; i < length;) {
            bytes32 paymentId = paymentIds[i];
            bytes32 buyerId = buyerIds[i];
            bytes32 itemId = itemIds[i];
            address paymentToken = paymentTokens[i];
            uint256 amount = amounts[i];
            uint256 expiration = expirations[i];
            ICampaignPaymentTreasury.LineItem[] calldata lineItems = lineItemsArray[i];

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

            // Validate expiration does not exceed maximum allowed expiration time
            if (hasMaxExpiration && expiration > maxAllowedExpiration) {
                revert PaymentTreasuryExpirationExceedsMax(expiration, maxAllowedExpiration);
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
                isCryptoPayment: false,
                lineItemCount: lineItems.length
            });

            // Validate, store, and track line items in a single loop
            _validateStoreAndTrackLineItems(paymentId, lineItems, paymentToken);

            // Store external fees
            ICampaignPaymentTreasury.ExternalFees[] calldata externalFees = externalFeesArray[i];
            ICampaignPaymentTreasury.ExternalFees[] storage storedExternalFees = s_paymentExternalFees[paymentId];
            for (uint256 j = 0; j < externalFees.length; ) {
                storedExternalFees.push(externalFees[j]);
                unchecked {
                    ++j;
                }
            }

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
        uint256 amount,
        ICampaignPaymentTreasury.LineItem[] calldata lineItems,
        ICampaignPaymentTreasury.ExternalFees[] calldata externalFees
    ) public override virtual nonReentrant whenCampaignNotPaused whenCampaignNotCancelled {
        
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

        // Validate, calculate total, store, and process line items
        uint256 totalAmount = amount;
        address platformAdmin = INFO.getPlatformAdminAddress(PLATFORM_HASH);
        uint256 protocolFeePercent = INFO.getProtocolFeePercent();
        uint256 totalInstantTransferAmount = 0;

        for (uint256 i = 0; i < lineItems.length; i++) {
            ICampaignPaymentTreasury.LineItem calldata item = lineItems[i];
            
            // Validate line item
            if (item.typeId == ZERO_BYTES || item.amount == 0) {
                revert PaymentTreasuryInvalidInput();
            }
            
            // Get line item type configuration (single call per item)
            (
                bool exists,
                string memory label,
                bool countsTowardGoal,
                bool applyProtocolFee,
                bool canRefund,
                bool instantTransfer
            ) = INFO.getLineItemType(PLATFORM_HASH, item.typeId);
            
            if (!exists) {
                revert PaymentTreasuryInvalidInput();
            }
            
            // Accumulate total amount
            totalAmount += item.amount;
            
            // Store line item with configuration snapshot
            s_paymentLineItems[paymentId].push(ICampaignPaymentTreasury.PaymentLineItem({
                typeId: item.typeId,
                amount: item.amount,
                label: label,
                countsTowardGoal: countsTowardGoal,
                applyProtocolFee: applyProtocolFee,
                canRefund: canRefund,
                instantTransfer: instantTransfer
            }));
            
            // Process line items immediately since crypto payment is confirmed
            if (countsTowardGoal) {
                // Line items that count toward goal use existing tracking variables
                s_confirmedPaymentPerToken[paymentToken] += item.amount;
                s_lifetimeConfirmedPaymentPerToken[paymentToken] += item.amount;
                s_availableConfirmedPerToken[paymentToken] += item.amount;
            } else {
                // Apply protocol fee if applicable
                uint256 feeAmount = 0;
                if (applyProtocolFee) {
                    uint256 protocolFee = (item.amount * protocolFeePercent) / PERCENT_DIVIDER;
                    feeAmount += protocolFee;
                    s_protocolFeePerToken[paymentToken] += protocolFee;
                }
                uint256 netAmount = item.amount - feeAmount;
                
                if (instantTransfer) {
                    // Accumulate for batch transfer after loop
                    totalInstantTransferAmount += netAmount;
                } else {
                    // Track outstanding non-goal balances using net amounts (after fees)
                    s_nonGoalLineItemConfirmedPerToken[paymentToken] += netAmount;
                    
                    if (canRefund) {
                        s_refundableNonGoalLineItemPerToken[paymentToken] += netAmount;
                    } else {
                        s_nonGoalLineItemClaimablePerToken[paymentToken] += netAmount;
                    }
                }
            }
        }

        // Store external fees
        ICampaignPaymentTreasury.ExternalFees[] storage storedExternalFees = s_paymentExternalFees[paymentId];
        for (uint256 i = 0; i < externalFees.length; ) {
            storedExternalFees.push(externalFees[i]);
            unchecked {
                ++i;
            }
        }

        IERC20(paymentToken).safeTransferFrom(buyerAddress, address(this), totalAmount);

        s_payment[paymentId] = PaymentInfo({
            buyerId: ZERO_BYTES,
            buyerAddress: buyerAddress,
            itemId: itemId,
            amount: amount, // Amount in token's native decimals
            expiration: 0, 
            isConfirmed: true, 
            isCryptoPayment: true,
            lineItemCount: lineItems.length
        });

        s_paymentIdToToken[paymentId] = paymentToken;
        s_confirmedPaymentPerToken[paymentToken] += amount;
        s_lifetimeConfirmedPaymentPerToken[paymentToken] += amount;
        s_availableConfirmedPerToken[paymentToken] += amount;

        // Perform single batch transfer if there are any instant transfer amounts
        if (totalInstantTransferAmount > 0) {
            IERC20(paymentToken).safeTransfer(platformAdmin, totalInstantTransferAmount);
        }
        // Mint NFT for crypto payment
        uint256 tokenId = INFO.mintNFTForPledge(
            buyerAddress,
            itemId, // Using itemId as the reward identifier
            paymentToken,
            amount,
            0, // shippingFee (0 for payment treasuries)
            0  // tipAmount (0 for payment treasuries)
        );
        s_paymentIdToTokenId[paymentId] = tokenId;

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
        ICampaignPaymentTreasury.PaymentLineItem[] storage lineItems = s_paymentLineItems[paymentId];

        // Remove pending tracking for line items using snapshot from payment creation
        // This prevents issues if line item type configuration changed after payment creation
        for (uint256 i = 0; i < lineItems.length; i++) {
            // Use snapshot instead of current configuration to ensure consistency
            if (lineItems[i].countsTowardGoal) {
                s_pendingPaymentPerToken[paymentToken] -= lineItems[i].amount;
            } else {
                s_nonGoalLineItemPendingPerToken[paymentToken] -= lineItems[i].amount;
            }
        }

        delete s_payment[paymentId];
        delete s_paymentIdToToken[paymentId];
        delete s_paymentLineItems[paymentId];
        delete s_paymentExternalFees[paymentId];

        s_pendingPaymentPerToken[paymentToken] -= amount;

        emit PaymentCancelled(paymentId);
    }

    /**
     * @dev Calculates line item totals for balance checking and state updates.
     * @param lineItems Array of line items to process.
     * @param protocolFeePercent Protocol fee percentage.
     * @return totals Struct containing all calculated totals.
     */
    function _calculateLineItemTotals(
        ICampaignPaymentTreasury.PaymentLineItem[] storage lineItems,
        uint256 protocolFeePercent
    ) internal view returns (LineItemTotals memory totals) {
        for (uint256 i = 0; i < lineItems.length; i++) {
            ICampaignPaymentTreasury.PaymentLineItem memory item = lineItems[i];
            
            bool countsTowardGoal = item.countsTowardGoal;
            bool applyProtocolFee = item.applyProtocolFee;
            bool instantTransfer = item.instantTransfer;

            if (countsTowardGoal) {
                totals.totalGoalLineItemAmount += item.amount;
            } else {
                uint256 feeAmount = 0;
                if (applyProtocolFee) {
                    uint256 protocolFee = (item.amount * protocolFeePercent) / PERCENT_DIVIDER;
                    totals.totalProtocolFeeFromLineItems += protocolFee;
                    feeAmount += protocolFee;
                }
                
                uint256 netAmount = item.amount - feeAmount;
                
                if (instantTransfer) {
                    totals.totalInstantTransferAmountForCheck += netAmount;
                } else if (item.canRefund) {
                    totals.totalNonGoalRefundableAmount += netAmount;
                } else {
                    totals.totalNonGoalClaimableAmount += netAmount;
                }
            }
        }
    }

    /**
     * @dev Checks if there's sufficient balance for payment confirmation.
     * @param paymentToken The token address.
     * @param paymentAmount The base payment amount.
     * @param totals Line item totals struct.
     */
    function _checkBalanceForConfirmation(
        address paymentToken,
        uint256 paymentAmount,
        LineItemTotals memory totals
    ) internal view {
        uint256 actualBalance = IERC20(paymentToken).balanceOf(address(this));
        uint256 currentlyCommitted = s_availableConfirmedPerToken[paymentToken] + 
                                      s_protocolFeePerToken[paymentToken] + 
                                      s_platformFeePerToken[paymentToken] +
                                      s_nonGoalLineItemClaimablePerToken[paymentToken] +
                                      s_refundableNonGoalLineItemPerToken[paymentToken];
        
        uint256 newCommitted = currentlyCommitted + 
                               paymentAmount + 
                               totals.totalGoalLineItemAmount + 
                               totals.totalProtocolFeeFromLineItems + 
                               totals.totalNonGoalClaimableAmount +
                               totals.totalNonGoalRefundableAmount;
        
        if (newCommitted + totals.totalInstantTransferAmountForCheck > actualBalance) {
            revert PaymentTreasuryInsufficientBalance(
                newCommitted + totals.totalInstantTransferAmountForCheck,
                actualBalance
            );
        }
    }

    /**
     * @dev Updates state for line items during payment confirmation.
     * @param paymentToken The token address.
     * @param lineItems Array of line items to process.
     * @param protocolFeePercent Protocol fee percentage.
     * @return totalInstantTransferAmount Total amount to transfer instantly.
     */
    function _updateLineItemsForConfirmation(
        address paymentToken,
        ICampaignPaymentTreasury.PaymentLineItem[] storage lineItems,
        uint256 protocolFeePercent
    ) internal returns (uint256 totalInstantTransferAmount) {
        for (uint256 i = 0; i < lineItems.length; i++) {
            ICampaignPaymentTreasury.PaymentLineItem memory item = lineItems[i];
            
            bool countsTowardGoal = item.countsTowardGoal;
            bool applyProtocolFee = item.applyProtocolFee;
            bool canRefund = item.canRefund;
            bool instantTransfer = item.instantTransfer;

            if (countsTowardGoal) {
                s_pendingPaymentPerToken[paymentToken] -= item.amount;
                s_confirmedPaymentPerToken[paymentToken] += item.amount;
                s_lifetimeConfirmedPaymentPerToken[paymentToken] += item.amount;
                s_availableConfirmedPerToken[paymentToken] += item.amount;
            } else {
                s_nonGoalLineItemPendingPerToken[paymentToken] -= item.amount;
                
                uint256 feeAmount = 0;
                if (applyProtocolFee) {
                    uint256 protocolFee = (item.amount * protocolFeePercent) / PERCENT_DIVIDER;
                    feeAmount += protocolFee;
                    s_protocolFeePerToken[paymentToken] += protocolFee;
                }
                
                uint256 netAmount = item.amount - feeAmount;
                
                if (instantTransfer) {
                    totalInstantTransferAmount += netAmount;
                    // Instant transfer items are not tracked in s_nonGoalLineItemConfirmedPerToken
                } else {
                    // Track outstanding non-goal balances using net amounts (after fees)
                    s_nonGoalLineItemConfirmedPerToken[paymentToken] += netAmount;
                    
                    if (canRefund) {
                        s_refundableNonGoalLineItemPerToken[paymentToken] += netAmount;
                    } else {
                        s_nonGoalLineItemClaimablePerToken[paymentToken] += netAmount;
                    }
                }
            }
        }
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function confirmPayment(
        bytes32 paymentId,
        address buyerAddress
    ) public override virtual nonReentrant onlyPlatformAdmin(PLATFORM_HASH) whenCampaignNotPaused whenCampaignNotCancelled {
        _validatePaymentForAction(paymentId);
    
        address paymentToken = s_paymentIdToToken[paymentId];
        uint256 paymentAmount = s_payment[paymentId].amount;
        ICampaignPaymentTreasury.PaymentLineItem[] storage lineItems = s_paymentLineItems[paymentId];
        
        uint256 protocolFeePercent = INFO.getProtocolFeePercent();
        LineItemTotals memory totals = _calculateLineItemTotals(lineItems, protocolFeePercent);
        
        _checkBalanceForConfirmation(paymentToken, paymentAmount, totals);
        
        totals.totalInstantTransferAmount = _updateLineItemsForConfirmation(
            paymentToken,
            lineItems,
            protocolFeePercent
        );
        
        s_payment[paymentId].isConfirmed = true;

        s_pendingPaymentPerToken[paymentToken] -= paymentAmount;
        s_confirmedPaymentPerToken[paymentToken] += paymentAmount;
        s_lifetimeConfirmedPaymentPerToken[paymentToken] += paymentAmount;
        s_availableConfirmedPerToken[paymentToken] += paymentAmount;
        
        if (totals.totalInstantTransferAmount > 0) {
            address platformAdmin = INFO.getPlatformAdminAddress(PLATFORM_HASH);
            IERC20(paymentToken).safeTransfer(platformAdmin, totals.totalInstantTransferAmount);
        }
        
        if (buyerAddress != address(0)) {
            s_payment[paymentId].buyerAddress = buyerAddress;
            bytes32 itemId = s_payment[paymentId].itemId;
            uint256 tokenId = INFO.mintNFTForPledge(
                buyerAddress,
                itemId,
                paymentToken,
                paymentAmount,
                0,
                0
            );
            s_paymentIdToTokenId[paymentId] = tokenId;
        }
        
        emit PaymentConfirmed(paymentId);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function confirmPaymentBatch(
        bytes32[] calldata paymentIds,
        address[] calldata buyerAddresses
    ) public override virtual nonReentrant onlyPlatformAdmin(PLATFORM_HASH) whenCampaignNotPaused whenCampaignNotCancelled {
        
        // Validate array lengths must match
        if (buyerAddresses.length != paymentIds.length) {
            revert PaymentTreasuryInvalidInput();
        }
        
        bytes32 currentPaymentId;
        address currentToken;
        
        uint256 protocolFeePercent = INFO.getProtocolFeePercent();
        address platformAdmin = INFO.getPlatformAdminAddress(PLATFORM_HASH);
        
        for(uint256 i = 0; i < paymentIds.length;){
            currentPaymentId = paymentIds[i];
            
            _validatePaymentForAction(currentPaymentId);
            
            currentToken = s_paymentIdToToken[currentPaymentId];
            uint256 amount = s_payment[currentPaymentId].amount;
            ICampaignPaymentTreasury.PaymentLineItem[] storage lineItems = s_paymentLineItems[currentPaymentId];
            
            LineItemTotals memory totals = _calculateLineItemTotals(lineItems, protocolFeePercent);
            _checkBalanceForConfirmation(currentToken, amount, totals);
            
            totals.totalInstantTransferAmount = _updateLineItemsForConfirmation(
                currentToken,
                lineItems,
                protocolFeePercent
            );
            
            s_payment[currentPaymentId].isConfirmed = true;
            
            s_pendingPaymentPerToken[currentToken] -= amount;
            s_confirmedPaymentPerToken[currentToken] += amount;
            s_lifetimeConfirmedPaymentPerToken[currentToken] += amount;
            s_availableConfirmedPerToken[currentToken] += amount;
            
            if (totals.totalInstantTransferAmount > 0) {
                IERC20(currentToken).safeTransfer(platformAdmin, totals.totalInstantTransferAmount);
            }

            if (buyerAddresses[i] != address(0)) {
                address buyerAddress = buyerAddresses[i];
                s_payment[currentPaymentId].buyerAddress = buyerAddress;
                bytes32 itemId = s_payment[currentPaymentId].itemId;
                uint256 tokenId = INFO.mintNFTForPledge(
                    buyerAddress,
                    itemId,
                    currentToken,
                    amount,
                    0,
                    0
                );
                s_paymentIdToTokenId[currentPaymentId] = tokenId;
            }

            unchecked {
                ++i;
            }
        }
        
        emit PaymentBatchConfirmed(paymentIds);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     * @dev For non-NFT payments only. Verifies that no NFT exists for this payment.
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
        uint256 tokenId = s_paymentIdToTokenId[paymentId];

        if (payment.buyerId == ZERO_BYTES) {
            revert PaymentTreasuryPaymentNotExist(paymentId);
        }
        if(!payment.isConfirmed){
            revert PaymentTreasuryPaymentNotConfirmed(paymentId);
        }
        if (amountToRefund == 0 || availablePaymentAmount < amountToRefund) {
            revert PaymentTreasuryPaymentNotClaimable(paymentId);
        }
        // This function is for non-NFT payments only
        if (tokenId != 0) {
            revert PaymentTreasuryCryptoPayment(paymentId);
        }

        // Use snapshots of line item type configuration from payment creation time
        // This prevents issues if line item type configuration changed after payment creation/confirmation
        ICampaignPaymentTreasury.PaymentLineItem[] storage lineItems = s_paymentLineItems[paymentId];
        uint256 protocolFeePercent = INFO.getProtocolFeePercent();
        
        // Calculate total line item refund amount using snapshots
        uint256 totalGoalLineItemRefundAmount = 0;
        uint256 totalNonGoalLineItemRefundAmount = 0;
        
        for (uint256 i = 0; i < lineItems.length; i++) {
            ICampaignPaymentTreasury.PaymentLineItem memory item = lineItems[i];
            
            // Use snapshot flags instead of current configuration
            if (!item.canRefund) {
                continue; // Skip non-refundable line items (based on snapshot at creation time)
            }
            
            if (item.countsTowardGoal) {
                // Goal line items: full amount is refundable from goal tracking
                totalGoalLineItemRefundAmount += item.amount;
            } else {
                // Non-goal line items: handle fees and instant transfers
                // For instant transfer items, the net amount was already sent to platform admin - don't refund
                // For non-instant items, only refund the net amount (after fees), not the fees themselves
                if (item.instantTransfer) {
                    // Skip instant transfer items - they were already sent to platform admin
                    continue;
                }
                
                uint256 feeAmount = 0;
                if (item.applyProtocolFee) {
                    feeAmount = (item.amount * protocolFeePercent) / PERCENT_DIVIDER;
                }
                uint256 netAmount = item.amount - feeAmount;
                
                // Only refund the net amount (fees are not refundable)
                totalNonGoalLineItemRefundAmount += netAmount;
            }
        }

        // Check that we have enough available balance for the total refund (BEFORE modifying state)
        // Goal line items are in availableConfirmedPerToken, non-goal items need separate check
        uint256 totalRefundAmount = amountToRefund + totalGoalLineItemRefundAmount + totalNonGoalLineItemRefundAmount;
        
        // For goal line items and base payment, check availableConfirmedPerToken
        if (availablePaymentAmount < (amountToRefund + totalGoalLineItemRefundAmount)) {
            revert PaymentTreasuryPaymentNotClaimable(paymentId);
        }
        
        // For non-goal line items, check that we have enough claimable balance
        // (only non-instant transfer items are refundable, and only their net amounts after fees)
        if (totalNonGoalLineItemRefundAmount > 0) {
            uint256 availableRefundable = s_refundableNonGoalLineItemPerToken[paymentToken];
            if (availableRefundable < totalNonGoalLineItemRefundAmount) {
                revert PaymentTreasuryPaymentNotClaimable(paymentId);
            }
        }
        
        // Check that contract has enough actual balance to perform the transfer
        uint256 contractBalance = IERC20(paymentToken).balanceOf(address(this));
        if (contractBalance < totalRefundAmount) {
            revert PaymentTreasuryPaymentNotClaimable(paymentId);
        }

        // Update state: remove tracking for refundable line items using snapshots
        for (uint256 i = 0; i < lineItems.length; i++) {
            ICampaignPaymentTreasury.PaymentLineItem memory item = lineItems[i];
            
            // Use snapshot flags instead of current configuration
            if (!item.canRefund) {
                continue; // Skip non-refundable line items (based on snapshot at creation time)
            }
            
            if (item.countsTowardGoal) {
                // Goal line items: remove from goal tracking
                s_confirmedPaymentPerToken[paymentToken] -= item.amount;
                s_availableConfirmedPerToken[paymentToken] -= item.amount;
            } else {
                // Non-goal line items: remove from non-goal tracking
                // Note: instantTransfer items are skipped in the refund calculation above
                if (item.instantTransfer) {
                    // Instant transfer items were already sent to platform admin; nothing tracked
                    continue;
                }
                
                // Calculate fees and net amount using snapshot
                uint256 feeAmount = 0;
                if (item.applyProtocolFee) {
                    feeAmount = (item.amount * protocolFeePercent) / PERCENT_DIVIDER;
                    // Fees are NOT refunded - they remain in the protocol fee pool
                }
                
                uint256 netAmount = item.amount - feeAmount;
                
                // Remove net amount from outstanding non-goal tracking
                s_nonGoalLineItemConfirmedPerToken[paymentToken] -= netAmount;
                
                // Remove from refundable tracking (only net amount is refundable)
                s_refundableNonGoalLineItemPerToken[paymentToken] -= netAmount;
            }
        }

        delete s_payment[paymentId];
        delete s_paymentIdToToken[paymentId];
        delete s_paymentLineItems[paymentId];
        delete s_paymentExternalFees[paymentId];

        s_confirmedPaymentPerToken[paymentToken] -= amountToRefund;
        s_availableConfirmedPerToken[paymentToken] -= amountToRefund;

        IERC20(paymentToken).safeTransfer(refundAddress, totalRefundAmount);
        emit RefundClaimed(paymentId, totalRefundAmount, refundAddress);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     * @dev For NFT payments only. Requires an NFT exists and burns it. Refund is sent to current NFT owner.
     */
    function claimRefund(
        bytes32 paymentId
    ) public override virtual whenCampaignNotPaused whenCampaignNotCancelled
    {
        PaymentInfo memory payment = s_payment[paymentId];
        address paymentToken = s_paymentIdToToken[paymentId];
        address buyerAddress = payment.buyerAddress;
        uint256 amountToRefund = payment.amount;
        uint256 availablePaymentAmount = s_availableConfirmedPerToken[paymentToken];
        uint256 tokenId = s_paymentIdToTokenId[paymentId];

        if (buyerAddress == address(0)) {
            revert PaymentTreasuryPaymentNotExist(paymentId);
        }
        if (amountToRefund == 0 || availablePaymentAmount < amountToRefund) {
            revert PaymentTreasuryPaymentNotClaimable(paymentId);
        }
        // This function is for NFT payments only - NFT must exist
        if (tokenId == 0) {
            revert PaymentTreasuryPaymentNotClaimable(paymentId);
        }

        // Get NFT owner before burning
        address nftOwner = INFO.ownerOf(tokenId);

        // Use snapshots of line item type configuration from payment creation time
        // This prevents issues if line item type configuration changed after payment creation/confirmation
        ICampaignPaymentTreasury.PaymentLineItem[] storage lineItems = s_paymentLineItems[paymentId];
        uint256 protocolFeePercent = INFO.getProtocolFeePercent();
        
        // Calculate total line item refund amount using snapshots
        uint256 totalGoalLineItemRefundAmount = 0;
        uint256 totalNonGoalLineItemRefundAmount = 0;
        
        for (uint256 i = 0; i < lineItems.length; i++) {
            ICampaignPaymentTreasury.PaymentLineItem memory item = lineItems[i];
            
            // Use snapshot flags instead of current configuration
            if (!item.canRefund) {
                continue; // Skip non-refundable line items (based on snapshot at creation time)
            }
            
            if (item.countsTowardGoal) {
                // Goal line items: full amount is refundable from goal tracking
                totalGoalLineItemRefundAmount += item.amount;
            } else {
                // Non-goal line items: handle fees and instant transfers
                // For instant transfer items, the net amount was already sent to platform admin - don't refund
                // For non-instant items, only refund the net amount (after fees), not the fees themselves
                if (item.instantTransfer) {
                    // Skip instant transfer items - they were already sent to platform admin
                    continue;
                }
                
                uint256 feeAmount = 0;
                if (item.applyProtocolFee) {
                    feeAmount = (item.amount * protocolFeePercent) / PERCENT_DIVIDER;
                }
                uint256 netAmount = item.amount - feeAmount;
                
                // Only refund the net amount (fees are not refundable)
                totalNonGoalLineItemRefundAmount += netAmount;
            }
        }

        // Check that we have enough available balance for the total refund (BEFORE modifying state)
        // Goal line items are in availableConfirmedPerToken, non-goal items need separate check
        uint256 totalRefundAmount = amountToRefund + totalGoalLineItemRefundAmount + totalNonGoalLineItemRefundAmount;
        
        // For goal line items and base payment, check availableConfirmedPerToken
        if (availablePaymentAmount < (amountToRefund + totalGoalLineItemRefundAmount)) {
            revert PaymentTreasuryPaymentNotClaimable(paymentId);
        }
        
        // For non-goal line items, check that we have enough claimable balance
        // (only non-instant transfer items are refundable, and only their net amounts after fees)
        if (totalNonGoalLineItemRefundAmount > 0) {
            uint256 availableRefundable = s_refundableNonGoalLineItemPerToken[paymentToken];
            if (availableRefundable < totalNonGoalLineItemRefundAmount) {
                revert PaymentTreasuryPaymentNotClaimable(paymentId);
            }
        }
        
        // Check that contract has enough actual balance to perform the transfer
        uint256 contractBalance = IERC20(paymentToken).balanceOf(address(this));
        if (contractBalance < totalRefundAmount) {
            revert PaymentTreasuryPaymentNotClaimable(paymentId);
        }

        // Update state: remove tracking for refundable line items using snapshots
        for (uint256 i = 0; i < lineItems.length; i++) {
            ICampaignPaymentTreasury.PaymentLineItem memory item = lineItems[i];
            
            // Use snapshot flags instead of current configuration
            if (!item.canRefund) {
                continue; // Skip non-refundable line items (based on snapshot at creation time)
            }
            
            if (item.countsTowardGoal) {
                // Goal line items: remove from goal tracking
                s_confirmedPaymentPerToken[paymentToken] -= item.amount;
                s_availableConfirmedPerToken[paymentToken] -= item.amount;
            } else {
                // Non-goal line items: remove from non-goal tracking
                // Note: instantTransfer items are skipped in the refund calculation above
                if (item.instantTransfer) {
                    // Instant transfer items were already sent to platform admin; nothing tracked
                    continue;
                }
                
                // Calculate fees and net amount using snapshot
                uint256 feeAmount = 0;
                if (item.applyProtocolFee) {
                    feeAmount = (item.amount * protocolFeePercent) / PERCENT_DIVIDER;
                    // Fees are NOT refunded - they remain in the protocol fee pool
                }
                
                uint256 netAmount = item.amount - feeAmount;
                
                // Remove net amount from outstanding non-goal tracking
                s_nonGoalLineItemConfirmedPerToken[paymentToken] -= netAmount;
                
                // Remove from refundable tracking (only net amount is refundable)
                s_refundableNonGoalLineItemPerToken[paymentToken] -= netAmount;
            }
        }

        delete s_payment[paymentId];
        delete s_paymentIdToToken[paymentId];
        delete s_paymentLineItems[paymentId];
        delete s_paymentExternalFees[paymentId];
        delete s_paymentIdToTokenId[paymentId];

        s_confirmedPaymentPerToken[paymentToken] -= amountToRefund;
        s_availableConfirmedPerToken[paymentToken] -= amountToRefund;

        // Burn NFT (requires treasury approval from owner)
        INFO.burn(tokenId);

        IERC20(paymentToken).safeTransfer(nftOwner, totalRefundAmount);
        emit RefundClaimed(paymentId, totalRefundAmount, nftOwner);
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
     * @notice Allows platform admin to claim non-goal line items that are available for claiming.
     * @param token The token address to claim.
     */
    function claimNonGoalLineItems(address token)
        public
        virtual
        onlyPlatformAdmin(PLATFORM_HASH)
        whenCampaignNotPaused
        whenCampaignNotCancelled
    {
        if (!INFO.isTokenAccepted(token)) {
            revert PaymentTreasuryTokenNotAccepted(token);
        }

        uint256 claimableAmount = s_nonGoalLineItemClaimablePerToken[token];
        if (claimableAmount == 0) {
            revert PaymentTreasuryInvalidInput();
        }

        s_nonGoalLineItemClaimablePerToken[token] = 0;
        uint256 currentNonGoalConfirmed = s_nonGoalLineItemConfirmedPerToken[token];
        s_nonGoalLineItemConfirmedPerToken[token] = currentNonGoalConfirmed > claimableAmount
            ? currentNonGoalConfirmed - claimableAmount
            : 0;
        address platformAdmin = INFO.getPlatformAdminAddress(PLATFORM_HASH);
        
        IERC20(token).safeTransfer(platformAdmin, claimableAmount);
        
        emit NonGoalLineItemsClaimed(token, claimableAmount, platformAdmin);
    }

    /**
     * @notice Allows the platform admin to claim all remaining funds once the claim window has opened.
     */
    function claimExpiredFunds()
        public
        virtual
        onlyPlatformAdmin(PLATFORM_HASH)
        whenCampaignNotPaused
        whenCampaignNotCancelled
    {
        uint256 claimDelay = INFO.getPlatformClaimDelay(PLATFORM_HASH);
        uint256 claimableAt = INFO.getDeadline();
        claimableAt += claimDelay;

        if (block.timestamp < claimableAt) {
            revert PaymentTreasuryClaimWindowNotReached(claimableAt);
        }

        address[] memory acceptedTokens = INFO.getAcceptedTokens();
        address platformAdmin = INFO.getPlatformAdminAddress(PLATFORM_HASH);
        address protocolAdmin = INFO.getProtocolAdminAddress();

        bool claimedAny;

        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            address token = acceptedTokens[i];

            uint256 availableConfirmed = s_availableConfirmedPerToken[token];
            uint256 claimableAmount = s_nonGoalLineItemClaimablePerToken[token];
            uint256 refundableAmount = s_refundableNonGoalLineItemPerToken[token];
            uint256 platformFeeAmount = s_platformFeePerToken[token];
            uint256 protocolFeeAmount = s_protocolFeePerToken[token];

            uint256 platformAmount = availableConfirmed + claimableAmount + refundableAmount + platformFeeAmount;
            uint256 protocolAmount = protocolFeeAmount;

            if (platformAmount == 0 && protocolAmount == 0) {
                continue;
            }

            if (availableConfirmed > 0) {
                uint256 currentConfirmed = s_confirmedPaymentPerToken[token];
                s_confirmedPaymentPerToken[token] = currentConfirmed > availableConfirmed
                    ? currentConfirmed - availableConfirmed
                    : 0;
                s_availableConfirmedPerToken[token] = 0;
            }

            if (claimableAmount > 0 || refundableAmount > 0) {
                uint256 reduction = claimableAmount + refundableAmount;
                uint256 currentNonGoalConfirmed = s_nonGoalLineItemConfirmedPerToken[token];
                s_nonGoalLineItemConfirmedPerToken[token] = currentNonGoalConfirmed > reduction
                    ? currentNonGoalConfirmed - reduction
                    : 0;
                s_nonGoalLineItemClaimablePerToken[token] = 0;
                s_refundableNonGoalLineItemPerToken[token] = 0;
            }

            if (platformFeeAmount > 0) {
                s_platformFeePerToken[token] = 0;
            }

            if (protocolFeeAmount > 0) {
                s_protocolFeePerToken[token] = 0;
            }

            // transfer funds after state has been cleared
            if (platformAmount > 0) {
                IERC20(token).safeTransfer(platformAdmin, platformAmount);
                claimedAny = true;
            }

            if (protocolAmount > 0) {
                IERC20(token).safeTransfer(protocolAdmin, protocolAmount);
                claimedAny = true;
            }

            emit ExpiredFundsClaimed(token, platformAmount, protocolAmount);
        }

        if (!claimedAny) {
            revert PaymentTreasuryNoFundsToClaim();
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
     * @notice Returns true if the treasury has been cancelled.
     * @return True if cancelled, false otherwise.
     */
    function cancelled() public view virtual override(ICampaignPaymentTreasury, PausableCancellable) returns (bool) {
        return super.cancelled();
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
     * @inheritdoc ICampaignPaymentTreasury
     */
    function getPaymentData(bytes32 paymentId) public view override returns (ICampaignPaymentTreasury.PaymentData memory) {
        PaymentInfo memory payment = s_payment[paymentId];
        address paymentToken = s_paymentIdToToken[paymentId];
        ICampaignPaymentTreasury.PaymentLineItem[] storage lineItemsStorage = s_paymentLineItems[paymentId];
        ICampaignPaymentTreasury.ExternalFees[] storage externalFeesStorage = s_paymentExternalFees[paymentId];

        // Copy line items from storage to memory (required: cannot directly assign storage array to memory array)
        ICampaignPaymentTreasury.PaymentLineItem[] memory lineItems = new ICampaignPaymentTreasury.PaymentLineItem[](lineItemsStorage.length);
        for (uint256 i = 0; i < lineItemsStorage.length; i++) {
            lineItems[i] = lineItemsStorage[i];
        }

        // Copy external fees from storage to memory (same reason as line items)
        ICampaignPaymentTreasury.ExternalFees[] memory externalFees = new ICampaignPaymentTreasury.ExternalFees[](externalFeesStorage.length);
        for (uint256 i = 0; i < externalFeesStorage.length; i++) {
            externalFees[i] = externalFeesStorage[i];
        }

        return ICampaignPaymentTreasury.PaymentData({
            buyerAddress: payment.buyerAddress,
            buyerId: payment.buyerId,
            itemId: payment.itemId,
            amount: payment.amount,
            expiration: payment.expiration,
            isConfirmed: payment.isConfirmed,
            isCryptoPayment: payment.isCryptoPayment,
            lineItemCount: payment.lineItemCount,
            paymentToken: paymentToken,
            lineItems: lineItems,
            externalFees: externalFees
        });
    }

    /**
     * @dev Internal function to check the success condition for fee disbursement.
     * @return Whether the success condition is met.
     */
    function _checkSuccessCondition() internal view virtual returns (bool);
}