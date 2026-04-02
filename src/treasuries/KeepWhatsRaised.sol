// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Counters} from "../utils/Counters.sol";
import {TimestampChecker} from "../utils/TimestampChecker.sol";
import {BaseTreasury} from "../utils/BaseTreasury.sol";
import {ICampaignTreasury} from "../interfaces/ICampaignTreasury.sol";
import {ICampaignInfo} from "../interfaces/ICampaignInfo.sol";
import {IReward} from "../interfaces/IReward.sol";
import {ICampaignData} from "../interfaces/ICampaignData.sol";
import {IPermit2, ISignatureTransfer, PermitData} from "../interfaces/IPermit2.sol";
import {TreasuryErrors} from "../errors/TreasuryErrors.sol";

/**
 * @title KeepWhatsRaised
 * @notice A contract that keeps all the funds raised, regardless of the success condition.
 */
contract KeepWhatsRaised is IReward, BaseTreasury, TimestampChecker, ICampaignData {
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    // Mapping to store the pledged amount per token ID
    mapping(uint256 => uint256) private s_tokenToPledgedAmount;
    // Mapping to store the tipped amount per token ID
    mapping(uint256 => uint256) private s_tokenToTippedAmount;
    // Mapping to store the payment fee per token ID
    mapping(uint256 => uint256) private s_tokenToPaymentFee;
    // Mapping to store reward details by name
    mapping(bytes32 => Reward) private s_reward;
    /// Tracks whether an external pledge ID has already been processed.
    mapping(bytes32 => bool) public s_processedPledges;
    /// Mapping to store payment gateway fees by unique pledge ID
    mapping(bytes32 => uint256) public s_paymentGatewayFees;
    /// Flat fee values (token amounts, 18 decimals). Units are unambiguous.
    uint256 private s_flatFeeValue;
    uint256 private s_cumulativeFlatFeeValue;
    /// Gross percentage fee values (basis points, 0 to PERCENT_DIVIDER - 1). Stored in same order as s_feeKeys.grossPercentageFeeKeys.
    uint256[] private s_grossPercentageFeeValues;

    // Multi-token support
    mapping(uint256 => address) private s_tokenIdToPledgeToken; // Token used for each pledge
    mapping(address => uint256) private s_protocolFeePerToken; // Protocol fees per token
    mapping(address => uint256) private s_platformFeePerToken; // Platform fees per token
    mapping(address => uint256) private s_tipPerToken; // Tips per token
    mapping(address => uint256) private s_availablePerToken; // Available amount per token

    // Counter for reward tiers
    Counters.Counter private s_rewardCounter;

    /**
     * @dev Represents keys used to reference different fee configurations.
     * These keys are typically used to look up fee values stored in `s_platformData`.
     */
    struct FeeKeys {
        /// @dev Key for a flat fee applied to an operation.
        bytes32 flatFeeKey;
        /// @dev Key for a cumulative flat fee, potentially across multiple actions.
        bytes32 cumulativeFlatFeeKey;
        /// @dev Keys for gross percentage-based fees (calculated before deductions).
        bytes32[] grossPercentageFeeKeys;
    }

    /**
     * @dev Represents the complete fee structure values for treasury operations.
     * These values correspond to the fees that will be applied to transactions
     * and are typically retrieved using keys from `FeeKeys` struct.
     */
    struct FeeValues {
        /// @dev Value for a flat fee applied to an operation.
        uint256 flatFeeValue;
        /// @dev Value for a cumulative flat fee, potentially across multiple actions.
        uint256 cumulativeFlatFeeValue;
        /// @dev Values for gross percentage-based fees (calculated before deductions).
        uint256[] grossPercentageFeeValues;
    }
    /**
     * @dev System configuration parameters related to withdrawal and refund behavior.
     */

    struct Config {
        /// @dev The minimum withdrawal amount required to qualify for fee exemption.
        uint256 minimumWithdrawalForFeeExemption;
        /// @dev Time delay (in timestamp) after the campaign deadline until which the campaign owner may withdraw.
        ///      Withdrawal is allowed only while current time is less than deadline + withdrawalDelay.
        ///      After deadline + withdrawalDelay, the withdrawal function is no longer callable.
        uint256 withdrawalDelay;
        /// @dev Time delay (in timestamp) before a refund becomes claimable or processed.
        uint256 refundDelay;
        /// @dev Duration (in timestamp) for which config changes are locked to prevent immediate updates.
        uint256 configLockPeriod;
        /// @dev True if the creator is Colombian, false otherwise.
        bool isColombianCreator;
    }

    uint256 private s_cancellationTime;
    bool private s_isWithdrawalApproved;
    bool private s_tipClaimed;
    bool private s_fundClaimed;
    bool private s_configured;
    FeeKeys private s_feeKeys;
    Config private s_config;
    CampaignData private s_campaignData;

    // ---------------------------------------------------------------------------
    // Permit2 witness types for direct user pledge functions
    // (setFeeAndPledge is admin-only and uses standard ERC20 transferFrom)
    // ---------------------------------------------------------------------------
    // pledgeForAReward witness – binds pledgeId, backer, reward array, and tip
    bytes32 internal constant KWR_PLEDGE_FOR_REWARD_WITNESS_TYPEHASH = keccak256(
        "KWRPledgeForRewardWitness(bytes32 pledgeId,address backer,bytes32 rewardsHash,uint256 tip)"
    );
    string internal constant KWR_PLEDGE_FOR_REWARD_WITNESS_TYPE_STRING =
        "KWRPledgeForRewardWitness witness)KWRPledgeForRewardWitness(bytes32 pledgeId,address backer,bytes32 rewardsHash,uint256 tip)TokenPermissions(address token,uint256 amount)";

    // pledgeWithoutAReward witness – binds pledgeId, backer, pledgeAmount, and tip
    bytes32 internal constant KWR_PLEDGE_WITHOUT_REWARD_WITNESS_TYPEHASH = keccak256(
        "KWRPledgeWithoutRewardWitness(bytes32 pledgeId,address backer,uint256 pledgeAmount,uint256 tip)"
    );
    string internal constant KWR_PLEDGE_WITHOUT_REWARD_WITNESS_TYPE_STRING =
        "KWRPledgeWithoutRewardWitness witness)KWRPledgeWithoutRewardWitness(bytes32 pledgeId,address backer,uint256 pledgeAmount,uint256 tip)TokenPermissions(address token,uint256 amount)";


    /**
     * @dev Emitted when a backer makes a pledge.
     * @param backer The address of the backer making the pledge.
     * @param pledgeToken The token used for the pledge.
     * @param reward The name of the reward.
     * @param pledgeAmount The amount pledged.
     * @param tip An optional tip can be added during the process.
     * @param tokenId The ID of the token representing the pledge.
     * @param rewards An array of reward names.
     */
    event Receipt(
        address indexed backer,
        address indexed pledgeToken,
        bytes32 reward,
        uint256 pledgeAmount,
        uint256 tip,
        uint256 tokenId,
        bytes32[] rewards
    );

    /**
     * @dev Emitted when rewards are added to the campaign.
     * @param rewardNames The names of the rewards.
     * @param rewards The details of the rewards.
     */
    event RewardsAdded(bytes32[] rewardNames, Reward[] rewards);

    /**
     * @dev Emitted when a reward is removed from the campaign.
     * @param rewardName The name of the reward.
     */
    event RewardRemoved(bytes32 indexed rewardName);

    /// @dev Emitted when withdrawal functionality has been approved by the platform admin.
    event WithdrawalApproved();

    /**
     * @dev Emitted when the treasury configuration is updated.
     * @param config The updated configuration parameters (e.g., delays, exemptions).
     * @param campaignData The campaign-related data associated with the treasury setup.
     * @param feeKeys The set of keys used to determine applicable fees.
     * @param feeValues The fee values corresponding to the fee keys.
     */
    event TreasuryConfigured(Config config, CampaignData campaignData, FeeKeys feeKeys, FeeValues feeValues);

    /**
     * @dev Emitted when a withdrawal is successfully processed along with the applied fee.
     * @param to The recipient address receiving the funds.
     * @param amount The total amount withdrawn (excluding fee).
     * @param fee The fee amount deducted from the withdrawal.
     */
    event WithdrawalWithFeeSuccessful(address indexed to, uint256 amount, uint256 fee);

    /**
     * @dev Emitted when a tip is claimed from the contract.
     * @param amount The amount of tip claimed.
     * @param claimer The address that claimed the tip.
     */
    event TipClaimed(uint256 amount, address indexed claimer);

    /**
     * @dev Emitted when campaign or user's remaining funds are successfully claimed by the platform admin.
     * @param amount The amount of funds claimed.
     * @param claimer The address that claimed the funds.
     */
    event FundClaimed(uint256 amount, address indexed claimer);

    /**
     * @dev Emitted when a refund is claimed.
     * @param tokenId The ID of the token representing the pledge.
     * @param refundAmount The refund amount claimed.
     * @param claimer The address of the claimer.
     */
    event RefundClaimed(uint256 indexed tokenId, uint256 refundAmount, address indexed claimer);

    /**
     * @dev Emitted when the deadline of the campaign is updated.
     * @param newDeadline The new deadline.
     */
    event KeepWhatsRaisedDeadlineUpdated(uint256 newDeadline);

    /**
     * @dev Emitted when the goal amount for a campaign is updated.
     * @param newGoalAmount The new goal amount set for the campaign.
     */
    event KeepWhatsRaisedGoalAmountUpdated(uint256 newGoalAmount);

    /**
     * @dev Emitted when a gateway fee is set for a specific pledge.
     * @param pledgeId The unique identifier of the pledge.
     * @param fee The amount of the payment gateway fee set.
     */
    event KeepWhatsRaisedPaymentGatewayFeeSet(bytes32 indexed pledgeId, uint256 fee);

    /**
     * @dev Emitted when a tip is forwarded directly to the platform admin
     *      during a setFeeAndPledge call, instead of being stored in the treasury.
     * @param pledgeId The unique identifier of the pledge this tip is linked to.
     * @param backer The address of the backer who contributed the tip.
     * @param pledgeToken The token used for the tip.
     * @param amount The tip amount forwarded.
     */
    event TipForwarded(bytes32 indexed pledgeId, address indexed backer, address indexed pledgeToken, uint256 amount);

    /**
     * @dev Emitted when an unauthorized action is attempted.
     */
    error KeepWhatsRaisedUnAuthorized();

    /**
     * @dev Emitted when an invalid input is detected.
     * @param code Error code defined in {TreasuryErrors.InvalidInput}.
     */
    error KeepWhatsRaisedInvalidInput(TreasuryErrors.InvalidInput code);

    /// @dev Emitted when fee keys are not unique (duplicate or overlap between flat and percentage keys).
    error KeepWhatsRaisedDuplicateFeeKey();

    /// @dev Emitted when a percentage fee value is >= PERCENT_DIVIDER (100%).
    error KeepWhatsRaisedPercentageFeeExceedsMax();

    /// @dev Emitted when the sum of gross percentage fees is >= PERCENT_DIVIDER (100%).
    error KeepWhatsRaisedAggregatePercentageExceedsMax();

    /// @dev Reverts when campaign launch time is in the past.
    error KeepWhatsRaisedLaunchTimeInPast();
    /// @dev Reverts when campaign deadline is not after launch time.
    error KeepWhatsRaisedDeadlineNotAfterLaunch();
    /// @dev Reverts when reward name is zero bytes.
    error KeepWhatsRaisedZeroRewardName();
    /// @dev Reverts when reward value is zero.
    error KeepWhatsRaisedZeroRewardValue();
    /// @dev Reverts when reward item arrays have mismatched lengths.
    error KeepWhatsRaisedRewardItemArrayLengthMismatch();
    /// @dev Reverts when backer address is zero.
    error KeepWhatsRaisedZeroBacker();
    /// @dev Reverts when reward selection length exceeds number of rewards.
    error KeepWhatsRaisedRewardSelectionLengthMismatch();
    /// @dev Reverts when first reward is not a reward tier.
    error KeepWhatsRaisedFirstRewardNotTier();
    /// @dev Reverts when refund amount is zero.
    error KeepWhatsRaisedRefundAmountZero();
    /// @dev Reverts when insufficient available balance for refund.
    error KeepWhatsRaisedInsufficientAvailableForRefund(uint256 tokenId);
    /// @dev Reverts when claimFund is called before refund delay (cancelled) or withdrawal delay (not cancelled).
    error KeepWhatsRaisedClaimFundWindowNotReached();

    /**
     * @dev Emitted when a token is not accepted for the campaign.
     */
    error KeepWhatsRaisedTokenNotAccepted(address token);

    /**
     * @dev Emitted when a `Reward` already exists for given input.
     */
    error KeepWhatsRaisedRewardExists();

    /**
     * @dev Emitted when anyone called a disabled function.
     */
    error KeepWhatsRaisedDisabled();

    /**
     * @dev Emitted when any functionality is already enabled and cannot be re-enabled.
     */
    error KeepWhatsRaisedAlreadyEnabled();

    /**
     * @dev Emitted when a withdrawal attempt exceeds the available funds after accounting for the fee.
     * @param availableAmount The maximum amount that can be withdrawn.
     * @param withdrawalAmount The attempted withdrawal amount.
     * @param fee The fee that would be applied to the withdrawal.
     */
    error KeepWhatsRaisedInsufficientFundsForWithdrawalAndFee(
        uint256 availableAmount, uint256 withdrawalAmount, uint256 fee
    );

    /**
     * @notice Emitted when the fee exceeds the requested withdrawal amount.
     *
     * @param withdrawalAmount The amount requested for withdrawal.
     * @param fee The calculated fee, which is greater than the withdrawal amount.
     */
    error KeepWhatsRaisedInsufficientFundsForFee(uint256 withdrawalAmount, uint256 fee);

    /**
     * @dev Emitted when a withdrawal has already been made and cannot be repeated.
     */
    error KeepWhatsRaisedAlreadyWithdrawn();

    /**
     * @dev Emitted when funds or rewards have already been claimed for the given context.
     */
    error KeepWhatsRaisedAlreadyClaimed();

    /**
     * @dev Emitted when an operation is attempted after the platform admin has already claimed the treasury funds.
     */
    error KeepWhatsRaisedFundAlreadyClaimed();

    /**
     * @dev Emitted when a token or pledge is not eligible for claiming (e.g., claim period not reached or not valid).
     * @param tokenId The ID of the token that was attempted to be claimed.
     * @param code Error code defined in {TreasuryErrors.NotClaimable}.
     */
    error KeepWhatsRaisedNotClaimable(uint256 tokenId, TreasuryErrors.NotClaimable code);

    /**
     * @dev Emitted when an admin attempts to claim funds that are not yet claimable according to the rules.
     */
    error KeepWhatsRaisedNotClaimableAdmin();

    /**
     * @dev Emitted when a configuration change is attempted during the lock period.
     */
    error KeepWhatsRaisedConfigLocked();
    /**
     * @dev Thrown when configureTreasury is called after the treasury has already been configured.
     */
    error KeepWhatsRaisedAlreadyConfigured();

    /**
     * @dev Reverts when withdrawalDelay is less than refundDelay, which would allow claimFund
     *      to be callable before the refund window ends (refund window: (deadline, deadline + refundDelay]).
     * @param withdrawalDelay The configured withdrawal delay.
     * @param refundDelay The configured refund delay.
     */
    error KeepWhatsRaisedWithdrawalBeforeRefundEnd(uint256 withdrawalDelay, uint256 refundDelay);

    /**
     * @dev Emitted when a disbursement is attempted before the refund period has ended.
     */
    error KeepWhatsRaisedDisbursementBlocked();

    /**
     * @dev Emitted when a pledge is submitted using a pledgeId that has already been processed.
     * @param pledgeId The unique identifier of the pledge that was already used.
     */
    error KeepWhatsRaisedPledgeAlreadyProcessed(bytes32 pledgeId);

    /**
     * @dev Ensures that withdrawals are currently enabled.
     * Reverts with `KeepWhatsRaisedDisabled` if the withdrawal approval flag is not set.
     */
    modifier withdrawalEnabled() {
        if (!s_isWithdrawalApproved) {
            revert KeepWhatsRaisedDisabled();
        }
        _;
    }

    /**
     * @dev Restricts execution to only occur before the configuration lock period.
     * Reverts with `KeepWhatsRaisedConfigLocked` if called too close to or after the campaign deadline.
     * The lock period is defined as the duration before the deadline during which configuration changes are not allowed.
     */
    modifier onlyBeforeConfigLock() {
        if (block.timestamp > s_campaignData.deadline - s_config.configLockPeriod) {
            revert KeepWhatsRaisedConfigLocked();
        }
        _;
    }

    /// @notice Restricts access to only the platform admin or the campaign owner.
    /// @dev Checks if `_msgSender()` is either the platform admin (via `INFO.getPlatformAdminAddress`)
    ///      or the campaign owner (via `INFO.owner()`). Reverts with `KeepWhatsRaisedUnAuthorized` if not authorized.
    modifier onlyPlatformAdminOrCampaignOwner() {
        if (_msgSender() != INFO.getPlatformAdminAddress(PLATFORM_HASH) && _msgSender() != INFO.owner()) {
            revert KeepWhatsRaisedUnAuthorized();
        }
        _;
    }

    /**
     * @dev Constructor for the KeepWhatsRaised contract.
     */
    constructor() {}

    function initialize(bytes32 _platformHash, address _infoAddress) external initializer {
        __BaseContract_init(_platformHash, _infoAddress);
    }

    /**
     * @notice Retrieves the withdrawal approval status.
     */
    function getWithdrawalApprovalStatus() public view returns (bool) {
        return s_isWithdrawalApproved;
    }

    /**
     * @notice Retrieves the details of a reward.
     * @param rewardName The name of the reward.
     * @return reward The details of the reward as a `Reward` struct.
     */
    function getReward(bytes32 rewardName) external view returns (Reward memory reward) {
        if (s_reward[rewardName].rewardValue == 0) {
            revert KeepWhatsRaisedInvalidInput(TreasuryErrors.InvalidInput.REWARD_NOT_FOUND);
        }
        return s_reward[rewardName];
    }

    /**
     * @inheritdoc ICampaignTreasury
     * @return amount Total raised amount across all tokens, normalized to 18 decimals.
     */
    function getRaisedAmount() external view override returns (uint256 amount) {
        address[] memory acceptedTokens = INFO.getAcceptedTokens();

        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            address token = acceptedTokens[i];
            uint256 tokenAmount = s_tokenRaisedAmounts[token];
            if (tokenAmount > 0) {
                amount += _normalizeAmount(token, tokenAmount);
            }
        }

        return amount;
    }

    /**
     * @inheritdoc ICampaignTreasury
     * @return amount Lifetime total raised amount across all tokens, normalized to 18 decimals.
     */
    function getLifetimeRaisedAmount() external view override returns (uint256 amount) {
        address[] memory acceptedTokens = INFO.getAcceptedTokens();

        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            address token = acceptedTokens[i];
            uint256 tokenAmount = s_tokenLifetimeRaisedAmounts[token];
            if (tokenAmount > 0) {
                amount += _normalizeAmount(token, tokenAmount);
            }
        }

        return amount;
    }

    /**
     * @inheritdoc ICampaignTreasury
     * @return amount Total refunded amount across all tokens, normalized to 18 decimals.
     */
    function getRefundedAmount() external view override returns (uint256 amount) {
        address[] memory acceptedTokens = INFO.getAcceptedTokens();

        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            address token = acceptedTokens[i];
            uint256 refundedAmount = s_tokenLifetimeRaisedAmounts[token] - s_tokenRaisedAmounts[token];
            if (refundedAmount > 0) {
                amount += _normalizeAmount(token, refundedAmount);
            }
        }

        return amount;
    }

    /**
     * @notice Retrieves the currently available raised amount in the treasury.
     * @return amount Available raised amount across all tokens, normalized to 18 decimals.
     */
    function getAvailableRaisedAmount() external view returns (uint256 amount) {
        address[] memory acceptedTokens = INFO.getAcceptedTokens();

        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            address token = acceptedTokens[i];
            uint256 tokenAmount = s_availablePerToken[token];
            if (tokenAmount > 0) {
                amount += _normalizeAmount(token, tokenAmount);
            }
        }

        return amount;
    }

    /**
     * @notice Retrieves the campaign's launch time.
     * @return The timestamp when the campaign was launched.
     */
    function getLaunchTime() public view returns (uint256) {
        return s_campaignData.launchTime;
    }

    /**
     * @notice Retrieves the campaign's deadline.
     * @return The timestamp when the campaign ends.
     */
    function getDeadline() public view returns (uint256) {
        return s_campaignData.deadline;
    }

    /**
     * @notice Retrieves the campaign's funding goal amount.
     * @return The funding goal amount of the campaign.
     */
    function getGoalAmount() external view returns (uint256) {
        return s_campaignData.goalAmount;
    }

    /**
     * @notice Retrieves the payment gateway fee for a given pledge ID.
     * @param pledgeId The unique identifier of the pledge.
     * @return The fixed gateway fee amount associated with the pledge ID.
     */
    function getPaymentGatewayFee(bytes32 pledgeId) public view returns (uint256) {
        return s_paymentGatewayFees[pledgeId];
    }

    /**
     * @dev Retrieves the fee value associated with a specific fee key from storage.
     *      Flat fee keys return token amounts (18 decimals); percentage keys return basis points.
     * @param feeKey The unique identifier key used to reference a specific fee type.
     * @return The fee value corresponding to the provided fee key (0 if key is unknown).
     */
    function getFeeValue(bytes32 feeKey) public view returns (uint256) {
        if (feeKey == s_feeKeys.flatFeeKey) return s_flatFeeValue;
        if (feeKey == s_feeKeys.cumulativeFlatFeeKey) return s_cumulativeFlatFeeValue;
        for (uint256 i = 0; i < s_feeKeys.grossPercentageFeeKeys.length; i++) {
            if (s_feeKeys.grossPercentageFeeKeys[i] == feeKey) {
                return s_grossPercentageFeeValues[i];
            }
        }
        return 0;
    }

    /**
     * @notice Sets the fixed payment gateway fee for a specific pledge.
     * @param pledgeId The unique identifier of the pledge.
     * @param fee The gateway fee amount to be associated with the given pledge ID.
     */
    function setPaymentGatewayFee(bytes32 pledgeId, uint256 fee)
        public
        onlyPlatformAdmin(PLATFORM_HASH)
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
        s_paymentGatewayFees[pledgeId] = fee;

        emit KeepWhatsRaisedPaymentGatewayFeeSet(pledgeId, fee);
    }

    /**
     * @notice Approves the withdrawal of the treasury by the platform admin.
     */
    function approveWithdrawal()
        external
        onlyPlatformAdmin(PLATFORM_HASH)
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
        if (s_isWithdrawalApproved) {
            revert KeepWhatsRaisedAlreadyEnabled();
        }

        s_isWithdrawalApproved = true;

        emit WithdrawalApproved();
    }

    /**
     * @dev Configures the treasury for a campaign by setting the system parameters,
     *      campaign-specific data, and fee configuration keys.
     *
     * @param config The configuration settings including withdrawal delay, refund delay,
     *               fee exemption threshold, and configuration lock period.
     *               Must satisfy withdrawalDelay >= refundDelay so claimFund is only callable after the refund window ends.
     * @param campaignData The campaign-related metadata such as deadlines and funding goals.
     * @param feeKeys The set of keys used to reference applicable flat and percentage-based fees.
     * @param feeValues The fee values corresponding to the fee keys.
     */
    function configureTreasury(
        Config memory config,
        CampaignData memory campaignData,
        FeeKeys memory feeKeys,
        FeeValues memory feeValues
    )
        external
        onlyPlatformAdmin(PLATFORM_HASH)
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
        if (campaignData.launchTime < block.timestamp) revert KeepWhatsRaisedLaunchTimeInPast();
        if (campaignData.deadline <= campaignData.launchTime) revert KeepWhatsRaisedDeadlineNotAfterLaunch();
        if (s_configured) {
            revert KeepWhatsRaisedAlreadyConfigured();
        }
        if (feeKeys.grossPercentageFeeKeys.length != feeValues.grossPercentageFeeValues.length) {
            revert KeepWhatsRaisedInvalidInput(TreasuryErrors.InvalidInput.FEE_LENGTH_MISMATCH);
        }
        if (config.withdrawalDelay < config.refundDelay) {
            revert KeepWhatsRaisedWithdrawalBeforeRefundEnd(config.withdrawalDelay, config.refundDelay);
        }

        // Enforce key uniqueness: flat keys must differ and must not appear in percentage keys
        if (feeKeys.flatFeeKey == feeKeys.cumulativeFlatFeeKey) {
            revert KeepWhatsRaisedDuplicateFeeKey();
        }
        for (uint256 i = 0; i < feeKeys.grossPercentageFeeKeys.length; i++) {
            bytes32 k = feeKeys.grossPercentageFeeKeys[i];
            if (k == feeKeys.flatFeeKey || k == feeKeys.cumulativeFlatFeeKey) {
                revert KeepWhatsRaisedDuplicateFeeKey();
            }
            for (uint256 j = i + 1; j < feeKeys.grossPercentageFeeKeys.length; j++) {
                if (feeKeys.grossPercentageFeeKeys[j] == k) {
                    revert KeepWhatsRaisedDuplicateFeeKey();
                }
            }
        }

        // Per-fee and aggregate percentage bounds (each and total must be < PERCENT_DIVIDER)
        uint256 aggregatePercent = 0;
        for (uint256 i = 0; i < feeValues.grossPercentageFeeValues.length; i++) {
            uint256 v = feeValues.grossPercentageFeeValues[i];
            if (v >= PERCENT_DIVIDER) {
                revert KeepWhatsRaisedPercentageFeeExceedsMax();
            }
            aggregatePercent += v;
        }
        if (aggregatePercent >= PERCENT_DIVIDER) {
            revert KeepWhatsRaisedAggregatePercentageExceedsMax();
        }

        s_configured = true;
        s_config = config;
        s_feeKeys = feeKeys;
        s_campaignData = campaignData;

        s_flatFeeValue = feeValues.flatFeeValue;
        s_cumulativeFlatFeeValue = feeValues.cumulativeFlatFeeValue;
        s_grossPercentageFeeValues = feeValues.grossPercentageFeeValues;

        emit TreasuryConfigured(config, campaignData, feeKeys, feeValues);
    }

    /**
     * @dev Updates the campaign's deadline.
     *
     * @param deadline The new deadline timestamp for the campaign.
     *
     * Requirements:
     * - Must be called before the configuration lock period (see `onlyBeforeConfigLock`).
     * - The new deadline must be a future timestamp.
     */
    function updateDeadline(uint256 deadline)
        external
        onlyPlatformAdminOrCampaignOwner
        onlyBeforeConfigLock
        whenNotPaused
        whenNotCancelled
    {
        if (deadline <= getLaunchTime() || deadline <= block.timestamp) {
            revert KeepWhatsRaisedInvalidInput(TreasuryErrors.InvalidInput.INVALID_DEADLINE);
        }

        s_campaignData.deadline = deadline;
        emit KeepWhatsRaisedDeadlineUpdated(deadline);
    }

    /**
     * @dev Updates the funding goal amount for the campaign.
     *
     * @param goalAmount The new goal amount.
     *
     * Requirements:
     * - Must be called before the configuration lock period (see `onlyBeforeConfigLock`).
     */
    function updateGoalAmount(uint256 goalAmount)
        external
        onlyPlatformAdminOrCampaignOwner
        onlyBeforeConfigLock
        whenNotPaused
        whenNotCancelled
    {
        if (goalAmount == 0) {
            revert KeepWhatsRaisedInvalidInput(TreasuryErrors.InvalidInput.ZERO_GOAL_AMOUNT);
        }
        s_campaignData.goalAmount = goalAmount;
        emit KeepWhatsRaisedGoalAmountUpdated(goalAmount);
    }

    /**
     * @notice Adds multiple rewards in a batch.
     * @dev This function allows for both reward tiers and non-reward tiers.
     *      For both types, rewards must have non-zero value.
     *      If items are specified (non-empty arrays), the itemId, itemValue, and itemQuantity arrays must match in length.
     *      Empty arrays are allowed for both reward tiers and non-reward tiers.
     * @param rewardNames An array of reward names.
     * @param rewards An array of `Reward` structs containing reward details.
     */
    function addRewards(bytes32[] calldata rewardNames, Reward[] calldata rewards)
        external
        onlyCampaignOwner
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
        if (rewardNames.length != rewards.length) {
            revert KeepWhatsRaisedInvalidInput(TreasuryErrors.InvalidInput.REWARD_LENGTH_MISMATCH);
        }

        for (uint256 i = 0; i < rewardNames.length; i++) {
            bytes32 rewardName = rewardNames[i];
            Reward calldata reward = rewards[i];

            // Reward name must not be zero bytes and reward value must be non-zero
            if (rewardName == ZERO_BYTES) revert KeepWhatsRaisedZeroRewardName();
            if (reward.rewardValue == 0) revert KeepWhatsRaisedZeroRewardValue();

            // If there are any items, their arrays must match in length
            if (reward.itemId.length != reward.itemValue.length) revert KeepWhatsRaisedRewardItemArrayLengthMismatch();
            if (reward.itemId.length != reward.itemQuantity.length) revert KeepWhatsRaisedRewardItemArrayLengthMismatch();

            // Check for duplicate reward
            if (s_reward[rewardName].rewardValue != 0) {
                revert KeepWhatsRaisedRewardExists();
            }

            s_reward[rewardName] = reward;
            s_rewardCounter.increment();
        }
        emit RewardsAdded(rewardNames, rewards);
    }

    /**
     * @notice Removes a reward from the campaign.
     * @param rewardName The name of the reward.
     */
    function removeReward(bytes32 rewardName)
        external
        onlyCampaignOwner
        currentTimeIsLess(getLaunchTime())
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
        if (s_reward[rewardName].rewardValue == 0) {
            revert KeepWhatsRaisedInvalidInput(TreasuryErrors.InvalidInput.REWARD_NOT_FOUND);
        }
        delete s_reward[rewardName];
        s_rewardCounter.decrement();
        emit RewardRemoved(rewardName);
    }

    /**
     * @notice Sets the payment gateway fee and executes a pledge in a single transaction.
     *         When tip > 0, the tip is forwarded directly to the platform admin within this
     *         transaction and never enters the treasury balance.
     * @param pledgeId The unique identifier of the pledge.
     * @param backer The address of the backer making the pledge.
     * @param pledgeAmount The amount of the pledge.
     * @param tip The tip amount to forward to the platform admin (0 if no tip).
     * @param fee The payment gateway fee to associate with this pledge.
     * @param reward An array of reward names.
     * @param isPledgeForAReward A boolean indicating whether this pledge is for a reward or without.
     */
    function setFeeAndPledge(
        bytes32 pledgeId,
        address backer,
        address pledgeToken,
        uint256 pledgeAmount,
        uint256 tip,
        uint256 fee,
        bytes32[] calldata reward,
        bool isPledgeForAReward
    )
        external
        nonReentrant
        onlyPlatformAdmin(PLATFORM_HASH)
        currentTimeIsWithinRange(getLaunchTime(), getDeadline())
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
        setPaymentGatewayFee(pledgeId, fee);

        if (tip > 0) {
            address platformAdmin = INFO.getPlatformAdminAddress(PLATFORM_HASH);
            IERC20(pledgeToken).safeTransferFrom(_msgSender(), platformAdmin, tip);
            emit TipForwarded(pledgeId, backer, pledgeToken, tip);
        }

        PermitData memory emptyPermitData = PermitData({nonce: 0, deadline: 0, signature: ""});

        if (isPledgeForAReward) {
            _pledgeForAReward(pledgeId, backer, pledgeToken, 0, reward, _msgSender(), false, emptyPermitData);
        } else {
            _pledgeWithoutAReward(pledgeId, backer, pledgeToken, pledgeAmount, 0, _msgSender(), false, emptyPermitData);
        }
    }

    /**
     * @notice Allows a backer to pledge for a reward using a Permit2 signature.
     * @dev Tokens are transferred from `backer` via Permit2 `permitWitnessTransferFrom`.
     *      The permit's witness commits to `pledgeId`, `backer`, the reward array hash, and
     *      `tip`, so the caller cannot tamper with those parameters after the backer has signed.
     * @param pledgeId The unique identifier of the pledge.
     * @param backer The address of the backer making the pledge (must be the permit signer).
     * @param pledgeToken The token to use for the pledge.
     * @param tip An optional tip can be added during the process.
     * @param reward An array of reward names.
     * @param permitData Permit2 permit data (nonce, deadline, signature) signed by `backer`.
     */
    function pledgeForAReward(
        bytes32 pledgeId,
        address backer,
        address pledgeToken,
        uint256 tip,
        bytes32[] calldata reward,
        PermitData calldata permitData
    )
        public
        nonReentrant
        currentTimeIsWithinRange(getLaunchTime(), getDeadline())
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
        if (permitData.signature.length == 0) {
            revert KeepWhatsRaisedInvalidInput(TreasuryErrors.InvalidInput.EMPTY_SIGNATURE);
        }

        _pledgeForAReward(pledgeId, backer, pledgeToken, tip, reward, address(0), true, permitData);
    }

    /**
     * @notice Internal function that allows a backer to pledge for a reward.
     * @dev Called by both the public `pledgeForAReward` (Permit2 transfer) and
     *      `setFeeAndPledge` (admin ERC20 transfer).
     * @param pledgeId The unique identifier of the pledge.
     * @param backer The address of the backer making the pledge (receives the NFT).
     * @param pledgeToken The token to use for the pledge.
     * @param tip An optional tip can be added during the process.
     * @param reward An array of reward names.
     * @param tokenSource Token source address for the admin (ERC20) path.
     * @param usePermit2 Whether to transfer tokens via Permit2 or direct ERC20 transfer.
     * @param permitData Permit2 data for the direct user path.
     */
    function _pledgeForAReward(
        bytes32 pledgeId,
        address backer,
        address pledgeToken,
        uint256 tip,
        bytes32[] memory reward,
        address tokenSource,
        bool usePermit2,
        PermitData memory permitData
    ) internal {
        bytes32 internalPledgeId = pledgeId;

        if (s_processedPledges[internalPledgeId]) {
            revert KeepWhatsRaisedPledgeAlreadyProcessed(internalPledgeId);
        }
        s_processedPledges[internalPledgeId] = true;

        uint256 rewardLen = reward.length;
        Reward memory tempReward = s_reward[reward[0]];
        if (backer == address(0)) revert KeepWhatsRaisedZeroBacker();
        if (rewardLen > s_rewardCounter.current()) revert KeepWhatsRaisedRewardSelectionLengthMismatch();
        if (reward[0] == ZERO_BYTES) revert KeepWhatsRaisedInvalidInput(TreasuryErrors.InvalidInput.INVALID_REWARD_INPUT);
        if (!tempReward.isRewardTier) revert KeepWhatsRaisedFirstRewardNotTier();

        uint256 pledgeAmount = tempReward.rewardValue;
        for (uint256 i = 1; i < rewardLen; i++) {
            if (reward[i] == ZERO_BYTES) {
                revert KeepWhatsRaisedInvalidInput(TreasuryErrors.InvalidInput.ZERO_REWARD_NAME);
            }
            tempReward = s_reward[reward[i]];
            if (tempReward.rewardValue == 0 || !tempReward.canBeAddOn) {
                revert KeepWhatsRaisedInvalidInput(TreasuryErrors.InvalidInput.REWARD_NOT_FOUND);
            }
            pledgeAmount += tempReward.rewardValue;
        }
        _pledge(
            pledgeId,
            backer,
            pledgeToken,
            reward[0],
            pledgeAmount,
            tip,
            reward,
            tokenSource,
            usePermit2,
            permitData
        );
    }

    /**
     * @notice Allows a backer to pledge without selecting a reward using a Permit2 signature.
     * @dev Tokens are transferred from `backer` via Permit2 `permitWitnessTransferFrom`.
     *      The permit's witness commits to `pledgeId`, `backer`, `pledgeAmount`, and `tip`.
     * @param pledgeId The unique identifier of the pledge.
     * @param backer The address of the backer making the pledge (must be the permit signer).
     * @param pledgeToken The token to use for the pledge.
     * @param pledgeAmount The amount of the pledge (in token's native decimals).
     * @param tip An optional tip (in token's native decimals).
     * @param permitData Permit2 permit data (nonce, deadline, signature) signed by `backer`.
     */
    function pledgeWithoutAReward(
        bytes32 pledgeId,
        address backer,
        address pledgeToken,
        uint256 pledgeAmount,
        uint256 tip,
        PermitData calldata permitData
    )
        public
        nonReentrant
        currentTimeIsWithinRange(getLaunchTime(), getDeadline())
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
        if (permitData.signature.length == 0) {
            revert KeepWhatsRaisedInvalidInput(TreasuryErrors.InvalidInput.EMPTY_SIGNATURE);
        }

        _pledgeWithoutAReward(pledgeId, backer, pledgeToken, pledgeAmount, tip, address(0), true, permitData);
    }

    /**
     * @notice Internal function that allows a backer to pledge without a reward.
     * @dev Called by both the public `pledgeWithoutAReward` (Permit2 transfer) and
     *      `setFeeAndPledge` (admin ERC20 transfer).
     * @param pledgeId The unique identifier of the pledge.
     * @param backer The address of the backer making the pledge (receives the NFT).
     * @param pledgeToken The token to use for the pledge.
     * @param pledgeAmount The amount of the pledge.
     * @param tip An optional tip.
     * @param tokenSource Token source address for the admin (ERC20) path.
     * @param usePermit2 Whether to transfer tokens via Permit2 or direct ERC20 transfer.
     * @param permitData Permit2 data for the direct user path.
     */
    function _pledgeWithoutAReward(
        bytes32 pledgeId,
        address backer,
        address pledgeToken,
        uint256 pledgeAmount,
        uint256 tip,
        address tokenSource,
        bool usePermit2,
        PermitData memory permitData
    ) internal {
        bytes32 internalPledgeId = pledgeId;

        if (s_processedPledges[internalPledgeId]) {
            revert KeepWhatsRaisedPledgeAlreadyProcessed(internalPledgeId);
        }
        s_processedPledges[internalPledgeId] = true;

        bytes32[] memory emptyByteArray = new bytes32[](0);

        _pledge(
            pledgeId,
            backer,
            pledgeToken,
            ZERO_BYTES,
            pledgeAmount,
            tip,
            emptyByteArray,
            tokenSource,
            usePermit2,
            permitData
        );
    }

    /**
     * @inheritdoc ICampaignTreasury
     */
    function withdraw() public view override whenCampaignNotPaused whenCampaignNotCancelled whenNotPaused whenNotCancelled {
        revert KeepWhatsRaisedDisabled();
    }

    /**
     * @dev Computes Colombian creator tax with a single accounting model to avoid double-counting.
     * - Partial withdrawal: `amount` is NET (what the creator receives). Tax is additive (fee on top).
     *   Formula: tax = ceil(net * 40 / 10000). Rounded up per Colombian Peso precision requirements.
     * - Final withdrawal: `amount` is GROSS (full remaining balance). Tax is deducted from it.
     *   Formula: tax = ceil(gross * 40 / 10040) (tax-inclusive rate). Rounded up per Colombian Peso.
     * @param amount The net amount (partial) or gross amount (final) in token units.
     * @param isFromGross True for final withdrawal (amount = full balance), false for partial (amount = net to creator).
     * @return Tax amount in token units (rounded up).
     */
    function _colombianCreatorTax(uint256 amount, bool isFromGross) internal pure returns (uint256) {
        if (amount == 0) return 0;
        if (isFromGross) {
            // Gross-including-tax: tax = ceil(gross * 40 / 10040)
            return (amount * 40 + 10040 - 1) / 10040;
        } else {
            // Net amount (additive tax): tax = ceil(net * 40 / 10000)
            return (amount * 40 + 10000 - 1) / 10000;
        }
    }

    /**
     * @dev Allows the campaign owner or platform admin to withdraw funds, applying required fees and taxes.
     *
     * Accounting model (per product requirement):
     * - Partial withdrawal: Creator receives the full requested amount; fees (including Colombian tax) are additive
     *   (deducted from the pool in addition). So: pool -= amount + totalFee, creator gets amount (net).
     * - Final withdrawal: Fees (including Colombian tax) are cut from the remaining balance; creator receives
     *   the remainder. So: pool -= withdrawalAmount, creator gets withdrawalAmount - totalFee (net).
     *
     * @param token The token to withdraw.
     * @param amount The withdrawal amount (ignored for final withdrawals). For partial, this is the NET amount
     *               to transfer to the creator; fees are additive.
     *
     * Requirements:
     * - Caller must be authorized.
     * - Withdrawals must be enabled, not paused, and within the withdrawal window (current time < deadline + withdrawalDelay).
     * - Token must be accepted for the campaign.
     * - For partial withdrawals:
     *   - `amount` > 0 and `amount + fees` ≤ available balance.
     * - For final withdrawals:
     *   - Available balance > 0 and fees ≤ available balance.
     *
     * Effects:
     * - Deducts fees (flat, cumulative, and Colombian tax if applicable).
     * - Updates available balance per token.
     * - Transfers net funds to the recipient.
     *
     * Reverts:
     * - If insufficient funds or invalid input.
     *
     * Emits:
     * - `WithdrawalWithFeeSuccessful`.
     */
    function withdraw(address token, uint256 amount)
        public
        onlyPlatformAdminOrCampaignOwner
        currentTimeIsLess(getDeadline() + s_config.withdrawalDelay)
        whenCampaignNotPaused
        whenCampaignNotCancelled
        whenNotPaused
        whenNotCancelled
        withdrawalEnabled
    {
        if (s_fundClaimed) {
            revert KeepWhatsRaisedFundAlreadyClaimed();
        }
        if (!INFO.isTokenAccepted(token)) {
            revert KeepWhatsRaisedTokenNotAccepted(token);
        }

        // Fee config values are in 18 decimals, denormalize for comparison/calculation
        uint256 flatFee = _denormalizeAmount(token, getFeeValue(s_feeKeys.flatFeeKey));
        uint256 cumulativeFee = _denormalizeAmount(token, getFeeValue(s_feeKeys.cumulativeFlatFeeKey));
        uint256 minimumWithdrawalForFeeExemption = _denormalizeAmount(token, s_config.minimumWithdrawalForFeeExemption);

        uint256 currentTime = block.timestamp;
        uint256 available = s_availablePerToken[token];
        uint256 withdrawalAmount;
        uint256 totalFee = 0;
        address recipient = INFO.owner();
        bool isFinalWithdrawal = (currentTime > getDeadline());

        //Main Fees
        if (isFinalWithdrawal) {
            if (available == 0) {
                revert KeepWhatsRaisedAlreadyWithdrawn();
            }
            withdrawalAmount = available;
            if (withdrawalAmount < minimumWithdrawalForFeeExemption) {
                s_platformFeePerToken[token] += flatFee;
                totalFee += flatFee;
            }
        } else {
            if (amount == 0) {
                revert KeepWhatsRaisedInvalidInput(TreasuryErrors.InvalidInput.ZERO_AMOUNT);
            }
            if (amount > available) {
                revert KeepWhatsRaisedInsufficientFundsForWithdrawalAndFee(
                    available, amount, totalFee
                );
            }
            withdrawalAmount = amount;

            if (withdrawalAmount < minimumWithdrawalForFeeExemption) {
                s_platformFeePerToken[token] += cumulativeFee;
                totalFee += cumulativeFee;
            } else {
                s_platformFeePerToken[token] += flatFee;
                totalFee += flatFee;
            }
        }

        // Colombian creator tax: single accounting model to avoid double-counting.
        // Partial: withdrawalAmount = NET (amount to creator); tax is additive (fee on top), formula from net.
        // Final: withdrawalAmount = GROSS (full balance); tax is deducted from it, formula from gross. Rounded up to next unit (e.g. Peso).
        if (s_config.isColombianCreator) {
            uint256 columbianCreatorTax = _colombianCreatorTax(withdrawalAmount, isFinalWithdrawal);
            s_platformFeePerToken[token] += columbianCreatorTax;
            totalFee += columbianCreatorTax;
        }

        if (isFinalWithdrawal) {
            if (withdrawalAmount < totalFee) {
                revert KeepWhatsRaisedInsufficientFundsForFee(withdrawalAmount, totalFee);
            }

            s_availablePerToken[token] = 0;
            IERC20(token).safeTransfer(recipient, withdrawalAmount - totalFee);
        } else {
            if (available < (withdrawalAmount + totalFee)) {
                revert KeepWhatsRaisedInsufficientFundsForWithdrawalAndFee(
                    available, withdrawalAmount, totalFee
                );
            }

            s_availablePerToken[token] -= (withdrawalAmount + totalFee);
            IERC20(token).safeTransfer(recipient, withdrawalAmount);
        }

        emit WithdrawalWithFeeSuccessful(
            recipient, isFinalWithdrawal ? withdrawalAmount - totalFee : withdrawalAmount, totalFee
        );
    }

    /**
     * @dev Allows a backer to claim a refund associated with a specific pledge (token ID).
     *
     * @param tokenId The ID of the token representing the backer's pledge.
     *
     * Requirements:
     * - Refund delay must have passed.
     * - The token must be eligible for a refund and not previously claimed.
     */
    function claimRefund(uint256 tokenId)
        external
        currentTimeIsGreater(getLaunchTime())
        whenCampaignNotPaused
        whenNotPaused
    {
        if (s_fundClaimed) {
            revert KeepWhatsRaisedFundAlreadyClaimed();
        }
        if (!_checkRefundPeriodStatus(false)) {
            revert KeepWhatsRaisedNotClaimable(tokenId, TreasuryErrors.NotClaimable.INVALID_REFUND_PERIOD);
        }

        // Get NFT owner before burning
        address nftOwner = INFO.ownerOf(tokenId);

        address pledgeToken = s_tokenIdToPledgeToken[tokenId];
        uint256 amountToRefund = s_tokenToPledgedAmount[tokenId];
        uint256 paymentFee = s_tokenToPaymentFee[tokenId];
        uint256 netRefundAmount = amountToRefund - paymentFee;

        if (netRefundAmount == 0) revert KeepWhatsRaisedRefundAmountZero();
        if (s_availablePerToken[pledgeToken] < netRefundAmount) revert KeepWhatsRaisedInsufficientAvailableForRefund(tokenId);

        s_tokenToPledgedAmount[tokenId] = 0;
        s_tokenRaisedAmounts[pledgeToken] -= amountToRefund;
        s_availablePerToken[pledgeToken] -= netRefundAmount;
        s_tokenToPaymentFee[tokenId] = 0;

        // Burn the NFT (requires treasury approval from owner)
        INFO.burn(tokenId);

        IERC20(pledgeToken).safeTransfer(nftOwner, netRefundAmount);
        emit RefundClaimed(tokenId, netRefundAmount, nftOwner);
    }

    /**
     * @dev Disburses all accumulated fees to the appropriate fee collector or treasury.
     *      Callable before or after cancellation so that accrued fees are never trapped.
     *
     * Requirements:
     * - Only callable when fees are available.
     */
    function disburseFees() public override whenCampaignNotPaused whenNotPaused {
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
     * @dev Allows an authorized claimer to collect tips contributed during the campaign.
     *
     * Requirements:
     * - Caller must be authorized to claim tips.
     * - Tip amount must be non-zero.
     */
    function claimTip() external onlyPlatformAdmin(PLATFORM_HASH) whenCampaignNotPaused whenNotPaused {
        if (s_cancellationTime == 0 && block.timestamp <= getDeadline()) {
            revert KeepWhatsRaisedNotClaimableAdmin();
        }

        if (s_tipClaimed) {
            revert KeepWhatsRaisedAlreadyClaimed();
        }

        address platformAdmin = INFO.getPlatformAdminAddress(PLATFORM_HASH);
        address[] memory acceptedTokens = INFO.getAcceptedTokens();
        s_tipClaimed = true;

        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            address token = acceptedTokens[i];
            uint256 tip = s_tipPerToken[token];

            if (tip > 0) {
                s_tipPerToken[token] = 0;
                IERC20(token).safeTransfer(platformAdmin, tip);
                emit TipClaimed(tip, platformAdmin);
            }
        }
    }

    /**
     * @dev Allows the platform admin to claim the remaining funds from a campaign.
     *
     * Requirements:
     * - Claim period must have started and funds must be available.
     * - Cannot be previously claimed.
     */
    function claimFund() external onlyPlatformAdmin(PLATFORM_HASH) whenCampaignNotPaused whenNotPaused {
        bool isCancelled = s_cancellationTime > 0;
        uint256 cancelLimit = s_cancellationTime + s_config.refundDelay;
        uint256 deadlineLimit = getDeadline() + s_config.withdrawalDelay;

        if (isCancelled && block.timestamp <= cancelLimit) revert KeepWhatsRaisedClaimFundWindowNotReached();
        if (!isCancelled && block.timestamp <= deadlineLimit) revert KeepWhatsRaisedClaimFundWindowNotReached();

        if (s_fundClaimed) {
            revert KeepWhatsRaisedAlreadyClaimed();
        }

        address platformAdmin = INFO.getPlatformAdminAddress(PLATFORM_HASH);
        address[] memory acceptedTokens = INFO.getAcceptedTokens();
        s_fundClaimed = true;

        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            address token = acceptedTokens[i];
            uint256 amountToClaim = s_availablePerToken[token];

            if (amountToClaim > 0) {
                s_availablePerToken[token] = 0;
                IERC20(token).safeTransfer(platformAdmin, amountToClaim);
                emit FundClaimed(amountToClaim, platformAdmin);
            }
        }
    }

    /**
     * @inheritdoc BaseTreasury
     * @dev This function is overridden to allow the platform admin and the campaign owner to cancel a treasury.
     */
    function cancelTreasury(bytes32 message) public override onlyPlatformAdminOrCampaignOwner {
        s_cancellationTime = block.timestamp;
        _cancel(message);
    }

    /**
     * @inheritdoc BaseTreasury
     */
    function _checkSuccessCondition() internal view virtual override returns (bool) {
        return true;
    }

    /**
     * @dev Processes a pledge: transfers tokens, mints NFT, and updates state.
     * @dev Mints a pledge NFT via `_safeMint`; reverts if `backer` is a contract that does not implement `IERC721Receiver`.
     * @param pledgeId Unique identifier for the pledge.
     * @param backer Recipient of the pledge NFT.
     * @param pledgeToken Token used for the pledge.
     * @param reward First reward tier (ZERO_BYTES for non-reward pledges).
     * @param pledgeAmount Pledge amount in the token's native decimals (must be denormalized by caller).
     * @param tip Tip amount in the token's native decimals.
     * @param rewards Full reward selection (for event).
     * @param tokenSource Address from which tokens are transferred.
     */
    function _pledge(
        bytes32 pledgeId,
        address backer,
        address pledgeToken,
        bytes32 reward,
        uint256 pledgeAmount,
        uint256 tip,
        bytes32[] memory rewards,
        address tokenSource,
        bool usePermit2,
        PermitData memory permitData
    ) private {
        if (!INFO.isTokenAccepted(pledgeToken)) {
            revert KeepWhatsRaisedTokenNotAccepted(pledgeToken);
        }
        if (tokenSource == address(this) || backer == address(this)) {
            revert KeepWhatsRaisedInvalidInput(TreasuryErrors.InvalidInput.INVALID_BACKER);
        }
        if (usePermit2 && permitData.signature.length == 0) {
            revert KeepWhatsRaisedInvalidInput(TreasuryErrors.InvalidInput.EMPTY_SIGNATURE);
        }
        if (!usePermit2 && tokenSource == address(0)) {
            revert KeepWhatsRaisedInvalidInput(TreasuryErrors.InvalidInput.ZERO_TOKEN_SOURCE);
        }

        uint256 pledgeAmountInTokenDecimals;
        if (reward != ZERO_BYTES) {
            pledgeAmountInTokenDecimals = _denormalizeAmount(pledgeToken, pledgeAmount);
        } else {
            pledgeAmountInTokenDecimals = pledgeAmount;
        }

        uint256 totalAmount = pledgeAmountInTokenDecimals + tip;
        uint256 actualPledgeAmount;

        if (usePermit2) {
            bytes32 witness;
            string memory witnessTypeString;

            if (reward != ZERO_BYTES) {
                bytes32 rewardsHash = keccak256(abi.encodePacked(rewards));
                witness = keccak256(
                    abi.encode(KWR_PLEDGE_FOR_REWARD_WITNESS_TYPEHASH, pledgeId, backer, rewardsHash, tip)
                );
                witnessTypeString = KWR_PLEDGE_FOR_REWARD_WITNESS_TYPE_STRING;
            } else {
                witness = keccak256(
                    abi.encode(
                        KWR_PLEDGE_WITHOUT_REWARD_WITNESS_TYPEHASH,
                        pledgeId,
                        backer,
                        pledgeAmountInTokenDecimals,
                        tip
                    )
                );
                witnessTypeString = KWR_PLEDGE_WITHOUT_REWARD_WITNESS_TYPE_STRING;
            }

            IPermit2(INFO.getPermit2Address()).permitWitnessTransferFrom(
                ISignatureTransfer.PermitTransferFrom({
                    permitted: ISignatureTransfer.TokenPermissions({token: pledgeToken, amount: totalAmount}),
                    nonce: permitData.nonce,
                    deadline: permitData.deadline
                }),
                ISignatureTransfer.SignatureTransferDetails({to: address(this), requestedAmount: totalAmount}),
                backer,
                witness,
                witnessTypeString,
                permitData.signature
            );
            actualPledgeAmount = pledgeAmountInTokenDecimals;
        } else {
            IERC20(pledgeToken).safeTransferFrom(tokenSource, address(this), totalAmount);
            actualPledgeAmount = pledgeAmountInTokenDecimals;
        }

        uint256 tokenId = INFO.mintNFTForPledge(backer, reward, pledgeToken, actualPledgeAmount, 0, tip);

        s_tokenToPledgedAmount[tokenId] = actualPledgeAmount;
        s_tokenToTippedAmount[tokenId] = tip;
        s_tokenIdToPledgeToken[tokenId] = pledgeToken;
        s_tipPerToken[pledgeToken] += tip;
        s_tokenRaisedAmounts[pledgeToken] += actualPledgeAmount;
        s_tokenLifetimeRaisedAmounts[pledgeToken] += actualPledgeAmount;

        uint256 netAvailable = _calculateNetAvailable(pledgeId, pledgeToken, tokenId, actualPledgeAmount);
        s_availablePerToken[pledgeToken] += netAvailable;

        emit Receipt(backer, pledgeToken, reward, pledgeAmount, tip, tokenId, rewards);
    }

    /**
     * @notice Calculates the net amount available from a pledge after deducting
     *         all applicable fees.
     *
     * @dev The function performs the following:
     *      - Applies all configured gross percentage-based fees
     *      - Applies payment gateway fee for the given pledge
     *      - Applies protocol fee based on protocol configuration
     *      - Accumulates total platform and protocol fees per token
     *      - Records the total deducted fee for the token
     *
     * @param pledgeId The unique identifier of the pledge
     * @param pledgeToken The token used for the pledge
     * @param tokenId The token ID representing the pledge
     * @param pledgeAmount The original pledged amount before deductions
     *
     * @return The net available amount after all fees are deducted
     */
    function _calculateNetAvailable(bytes32 pledgeId, address pledgeToken, uint256 tokenId, uint256 pledgeAmount)
        internal
        returns (uint256)
    {
        uint256 totalFee = 0;

        // Gross Percentage Fee Calculation
        uint256 len = s_feeKeys.grossPercentageFeeKeys.length;
        for (uint256 i = 0; i < len; i++) {
            uint256 fee = (pledgeAmount * s_grossPercentageFeeValues[i]) / PERCENT_DIVIDER;
            s_platformFeePerToken[pledgeToken] += fee;
            totalFee += fee;
        }

        // Payment Gateway Fee Calculation - MUST DENORMALIZE
        uint256 paymentGatewayFeeNormalized = getPaymentGatewayFee(pledgeId);
        uint256 paymentGatewayFee = _denormalizeAmount(pledgeToken, paymentGatewayFeeNormalized);
        s_platformFeePerToken[pledgeToken] += paymentGatewayFee;
        totalFee += paymentGatewayFee;

        // Protocol Fee Calculation (correct as-is)
        uint256 protocolFee = (pledgeAmount * INFO.getProtocolFeePercent()) / PERCENT_DIVIDER;
        s_protocolFeePerToken[pledgeToken] += protocolFee;
        totalFee += protocolFee;

        s_tokenToPaymentFee[tokenId] = totalFee;

        return pledgeAmount - totalFee;
    }

    /**
     * @dev Checks the refund period status based on campaign state
     * @param checkIfOver If true, returns whether refund period is over; if false, returns whether currently within refund period
     * @return bool Status based on checkIfOver parameter
     *
     * @notice Refund period logic:
     *         - If campaign is cancelled: refund period is active until s_cancellationTime + s_config.refundDelay
     *         - If campaign is not cancelled: refund period is active until deadline + s_config.refundDelay
     *         - Before deadline (non-cancelled): not in refund period
     *
     * @dev This function handles both cancelled and non-cancelled campaign scenarios
     */
    function _checkRefundPeriodStatus(bool checkIfOver) internal view returns (bool) {
        uint256 deadline = getDeadline();
        bool isCancelled = s_cancellationTime > 0;

        bool refundPeriodOver;

        if (isCancelled) {
            // If cancelled, refund period ends after s_config.refundDelay from cancellation time
            refundPeriodOver = block.timestamp > s_cancellationTime + s_config.refundDelay;
        } else {
            // If not cancelled, refund period ends after s_config.refundDelay from deadline
            refundPeriodOver = block.timestamp > deadline + s_config.refundDelay;
        }

        if (checkIfOver) {
            return refundPeriodOver;
        } else {
            // For non-cancelled campaigns, also check if we're after deadline
            if (!isCancelled) {
                return block.timestamp > deadline && !refundPeriodOver;
            }
            return !refundPeriodOver;
        }
    }
}
