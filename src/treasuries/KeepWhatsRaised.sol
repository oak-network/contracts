// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

import {Counters} from "../utils/Counters.sol";
import {TimestampChecker} from "../utils/TimestampChecker.sol";
import {BaseTreasury} from "../utils/BaseTreasury.sol";
import {ICampaignTreasury} from "../interfaces/ICampaignTreasury.sol";
import {IReward} from "../interfaces/IReward.sol";
import {ICampaignData} from "../interfaces/ICampaignData.sol";

/**
 * @title KeepWhatsRaised
 * @notice A contract that keeps all the funds raised, regardless of the success condition.
 */
contract KeepWhatsRaised is
    IReward,
    BaseTreasury,
    TimestampChecker,
    ERC721Burnable,
    ICampaignData
{
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
    /// Tracks whether a pledge with a specific ID has already been processed
    mapping(bytes32 => bool) public s_processedPledges;
    /// Mapping to store payment gateway fees by unique pledge ID
    mapping(bytes32 => uint256) public s_paymentGatewayFees;
    /// Mapping that stores fee values indexed by their corresponding fee keys.
    mapping(bytes32 => uint256) private s_feeValues;

    // Counters for token IDs and rewards
    Counters.Counter private s_tokenIdCounter;
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

        /// @dev Time delay (in timestamp) enforced before a withdrawal can be completed.
        uint256 withdrawalDelay;

        /// @dev Time delay (in timestamp) before a refund becomes claimable or processed.
        uint256 refundDelay;

        /// @dev Duration (in timestamp) for which config changes are locked to prevent immediate updates.
        uint256 configLockPeriod;

        /// @dev True if the creator is Colombian, false otherwise.
        bool isColombianCreator;
    }

    string private s_name;
    string private s_symbol;
    uint256 private s_tip;
    uint256 private s_platformFee;
    uint256 private s_protocolFee;
    uint256 private s_availablePledgedAmount;
    uint256 private s_cancellationTime;
    bool private s_isWithdrawalApproved;
    bool private s_tipClaimed;
    bool private s_fundClaimed;
    FeeKeys private s_feeKeys;
    Config private s_config;
    CampaignData private s_campaignData;

    /**
     * @dev Emitted when a backer makes a pledge.
     * @param backer The address of the backer making the pledge.
     * @param reward The name of the reward.
     * @param pledgeAmount The amount pledged.
     * @param tip An optional tip can be added during the process.
     * @param tokenId The ID of the token representing the pledge.
     * @param rewards An array of reward names.
     */
    event Receipt(
        address indexed backer,
        bytes32 indexed reward,
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
    event TreasuryConfigured(
        Config config,
        CampaignData campaignData,
        FeeKeys feeKeys,
        FeeValues feeValues
    );

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
     * @dev Emitted when an unauthorized action is attempted.
     */
    error KeepWhatsRaisedUnAuthorized();

    /**
     * @dev Emitted when an invalid input is detected.
     */
    error KeepWhatsRaisedInvalidInput();

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
    error KeepWhatsRaisedInsufficientFundsForWithdrawalAndFee(uint256 availableAmount, uint256 withdrawalAmount, uint256 fee);

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
     * @dev Emitted when a token or pledge is not eligible for claiming (e.g., claim period not reached or not valid).
     * @param tokenId The ID of the token that was attempted to be claimed.
     */
    error KeepWhatsRaisedNotClaimable(uint256 tokenId);

    /**
     * @dev Emitted when an admin attempts to claim funds that are not yet claimable according to the rules.
     */
    error KeepWhatsRaisedNotClaimableAdmin();
    
    /**
     * @dev Emitted when a configuration change is attempted during the lock period.
     */
    error KeepWhatsRaisedConfigLocked();

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
        if(!s_isWithdrawalApproved){
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
        if(block.timestamp > s_campaignData.deadline - s_config.configLockPeriod){
            revert KeepWhatsRaisedConfigLocked();
        }
        _;
    }

    /// @notice Restricts access to only the platform admin or the campaign owner.
    /// @dev Checks if `msg.sender` is either the platform admin (via `INFO.getPlatformAdminAddress`)
    ///      or the campaign owner (via `INFO.owner()`). Reverts with `KeepWhatsRaisedUnAuthorized` if not authorized.
    modifier onlyPlatformAdminOrCampaignOwner() {
        if (
            msg.sender != INFO.getPlatformAdminAddress(PLATFORM_HASH) &&
            msg.sender != INFO.owner()
        ) {
            revert KeepWhatsRaisedUnAuthorized();
        }
        _;
    }

    /**
     * @dev Constructor for the KeepWhatsRaised contract.
     */
    constructor() ERC721("", "") {}

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

    function name() public view override returns (string memory) {
        return s_name;
    }

    function symbol() public view override returns (string memory) {
        return s_symbol;
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
    function getReward(
        bytes32 rewardName
    ) external view returns (Reward memory reward) {
        if (s_reward[rewardName].rewardValue == 0) {
            revert KeepWhatsRaisedInvalidInput();
        }
        return s_reward[rewardName];
    }

    /**
     * @inheritdoc ICampaignTreasury
     */
    function getRaisedAmount() external view override returns (uint256) {
        return s_pledgedAmount;
    }

    /**
     * @notice Retrieves the currently available raised amount in the treasury.
     * @return The current available raised amount as a uint256 value.
     */
    function getAvailableRaisedAmount() external view returns (uint256) {
        return s_availablePledgedAmount;
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
     * @param {bytes32} feeKey - The unique identifier key used to reference a specific fee type.
     * 
     * @return {uint256} The fee value corresponding to the provided fee key. 
     */
    function getFeeValue(bytes32 feeKey) public view returns (uint256) {
        return s_feeValues[feeKey];
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
        if(s_isWithdrawalApproved){
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
        if (
            campaignData.launchTime < block.timestamp ||
            campaignData.deadline <= campaignData.launchTime
        ) {
            revert KeepWhatsRaisedInvalidInput();
        }
        if(
            feeKeys.grossPercentageFeeKeys.length != feeValues.grossPercentageFeeValues.length
        ) {
            revert KeepWhatsRaisedInvalidInput();
        }
        
        s_config = config;
        s_feeKeys = feeKeys;
        s_campaignData = campaignData;

        s_feeValues[feeKeys.flatFeeKey] = feeValues.flatFeeValue;
        s_feeValues[feeKeys.cumulativeFlatFeeKey] = feeValues.cumulativeFlatFeeValue;
        
        for (uint256 i = 0; i < feeKeys.grossPercentageFeeKeys.length; i++) {
            s_feeValues[feeKeys.grossPercentageFeeKeys[i]] = feeValues.grossPercentageFeeValues[i];
        }

        emit TreasuryConfigured(
            config,
            campaignData,
            feeKeys,
            feeValues
        );
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
    function updateDeadline(
        uint256 deadline
    )
        external
        onlyPlatformAdminOrCampaignOwner
        onlyBeforeConfigLock
        whenNotPaused
        whenNotCancelled
    {
        if (deadline <= getLaunchTime() || deadline <= block.timestamp) {
            revert KeepWhatsRaisedInvalidInput();
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
    function updateGoalAmount(
        uint256 goalAmount
    )
        external
        onlyPlatformAdminOrCampaignOwner
        onlyBeforeConfigLock
        whenNotPaused
        whenNotCancelled
    {
        if (goalAmount == 0) {
            revert KeepWhatsRaisedInvalidInput();
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
    function addRewards(
        bytes32[] calldata rewardNames,
        Reward[] calldata rewards
    )
        external
        onlyCampaignOwner
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
        if (rewardNames.length != rewards.length) {
            revert KeepWhatsRaisedInvalidInput();
        }

        for (uint256 i = 0; i < rewardNames.length; i++) {
            bytes32 rewardName = rewardNames[i];
            Reward calldata reward = rewards[i];

            // Reward name must not be zero bytes and reward value must be non-zero
            if (rewardName == ZERO_BYTES || reward.rewardValue == 0) {
                revert KeepWhatsRaisedInvalidInput();
            }

            // If there are any items, their arrays must match in length
            if (
                (reward.itemId.length != reward.itemValue.length) ||
                (reward.itemId.length != reward.itemQuantity.length)
            ) {
                revert KeepWhatsRaisedInvalidInput();
            }

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
    function removeReward(
        bytes32 rewardName
    )
        external
        onlyCampaignOwner
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
        if (s_reward[rewardName].rewardValue == 0) {
            revert KeepWhatsRaisedInvalidInput();
        }
        delete s_reward[rewardName];
        s_rewardCounter.decrement();
        emit RewardRemoved(rewardName);
    }

    /**
     * @notice Sets the payment gateway fee and executes a pledge in a single transaction.
     * @param pledgeId The unique identifier of the pledge.
     * @param backer The address of the backer making the pledge.
     * @param pledgeAmount The amount of the pledge.
     * @param tip An optional tip can be added during the process.
     * @param fee The payment gateway fee to associate with this pledge.
     * @param reward An array of reward names.
     * @param isPledgeForAReward A boolean indicating whether this pledge is for a reward or without..
     */
    function setFeeAndPledge(
        bytes32 pledgeId,
        address backer,
        uint256 pledgeAmount,
        uint256 tip,
        uint256 fee,
        bytes32[] calldata reward,
        bool isPledgeForAReward
    ) 
        external 
        onlyPlatformAdmin(PLATFORM_HASH)
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
        //Set Payment Gateway Fee
        setPaymentGatewayFee(pledgeId, fee);

        if(isPledgeForAReward){
            _pledgeForAReward(pledgeId, backer, tip, reward, msg.sender); // Pass admin as token source
        }else {
            _pledgeWithoutAReward(pledgeId, backer, pledgeAmount, tip, msg.sender); // Pass admin as token source
        }
    }

    /**
     * @notice Allows a backer to pledge for a reward.
     * @dev The first element of the `reward` array must be a reward tier and the other elements can be either reward tiers or non-reward tiers.
     *      The non-reward tiers cannot be pledged for without a reward.
     * @param pledgeId The unique identifier of the pledge.
     * @param backer The address of the backer making the pledge.
     * @param tip An optional tip can be added during the process.
     * @param reward An array of reward names.
     */
    function pledgeForAReward(
        bytes32 pledgeId,
        address backer,
        uint256 tip,
        bytes32[] calldata reward
    )
        public
        currentTimeIsWithinRange(getLaunchTime(), getDeadline())
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
        _pledgeForAReward(pledgeId, backer, tip, reward, backer); // Pass backer as token source for direct calls
    }

    /**
     * @notice Internal function that allows a backer to pledge for a reward with tokens transferred from a specified source.
     * @dev The first element of the `reward` array must be a reward tier and the other elements can be either reward tiers or non-reward tiers.
     *      The non-reward tiers cannot be pledged for without a reward.
     *      This function is called internally by both public pledgeForAReward (with backer as token source) and 
     *      setFeeAndPledge (with admin as token source).
     * @param pledgeId The unique identifier of the pledge.
     * @param backer The address of the backer making the pledge (receives the NFT).
     * @param tip An optional tip can be added during the process.
     * @param reward An array of reward names.
     * @param tokenSource The address from which tokens will be transferred (either backer for direct calls or admin for setFeeAndPledge calls).
     */
    function _pledgeForAReward(
        bytes32 pledgeId,
        address backer,
        uint256 tip,
        bytes32[] calldata reward,
        address tokenSource
    )
        internal
        currentTimeIsWithinRange(getLaunchTime(), getDeadline())
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
        bytes32 internalPledgeId = keccak256(abi.encodePacked(pledgeId, msg.sender));

        if(s_processedPledges[internalPledgeId]){
            revert KeepWhatsRaisedPledgeAlreadyProcessed(internalPledgeId);
        }
        s_processedPledges[internalPledgeId] = true;

        uint256 tokenId = s_tokenIdCounter.current();
        uint256 rewardLen = reward.length;
        Reward memory tempReward = s_reward[reward[0]];
        if (
            backer == address(0) ||
            rewardLen > s_rewardCounter.current() ||
            reward[0] == ZERO_BYTES ||
            !tempReward.isRewardTier
        ) {
            revert KeepWhatsRaisedInvalidInput();
        }
        uint256 pledgeAmount = tempReward.rewardValue;
        for (uint256 i = 1; i < rewardLen; i++) {
            if (reward[i] == ZERO_BYTES) {
                revert KeepWhatsRaisedInvalidInput();
            }
            tempReward = s_reward[reward[i]];
            if (tempReward.rewardValue == 0) {
                revert KeepWhatsRaisedInvalidInput();
            }
            pledgeAmount += tempReward.rewardValue;
        }
        _pledge(pledgeId, backer, reward[0], pledgeAmount, tip, tokenId, reward, tokenSource);
    }

    /**
     * @notice Allows a backer to pledge without selecting a reward.
     * @param pledgeId The unique identifier of the pledge.
     * @param backer The address of the backer making the pledge.
     * @param pledgeAmount The amount of the pledge.
     * @param tip An optional tip can be added during the process.
     */
    function pledgeWithoutAReward(
        bytes32 pledgeId,
        address backer,
        uint256 pledgeAmount,
        uint256 tip
    )
        public
        currentTimeIsWithinRange(getLaunchTime(), getDeadline())
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
        _pledgeWithoutAReward(pledgeId, backer, pledgeAmount, tip, backer); // Pass backer as token source for direct calls
    }

    /**
     * @notice Internal function that allows a backer to pledge without selecting a reward with tokens transferred from a specified source.
     * @dev This function is called internally by both public pledgeWithoutAReward (with backer as token source) and 
     *      setFeeAndPledge (with admin as token source).
     * @param pledgeId The unique identifier of the pledge.
     * @param backer The address of the backer making the pledge (receives the NFT).
     * @param pledgeAmount The amount of the pledge.
     * @param tip An optional tip can be added during the process.
     * @param tokenSource The address from which tokens will be transferred (either backer for direct calls or admin for setFeeAndPledge calls).
     */
    function _pledgeWithoutAReward(
        bytes32 pledgeId,
        address backer,
        uint256 pledgeAmount,
        uint256 tip,
        address tokenSource
    )
        internal
        currentTimeIsWithinRange(getLaunchTime(), getDeadline())
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
        bytes32 internalPledgeId = keccak256(abi.encodePacked(pledgeId, msg.sender));

        if(s_processedPledges[internalPledgeId]){
            revert KeepWhatsRaisedPledgeAlreadyProcessed(internalPledgeId);
        }
        s_processedPledges[internalPledgeId] = true;

        uint256 tokenId = s_tokenIdCounter.current();
        bytes32[] memory emptyByteArray = new bytes32[](0);

        _pledge(pledgeId, backer, ZERO_BYTES, pledgeAmount, tip, tokenId, emptyByteArray, tokenSource);
    }

    /**
     * @inheritdoc ICampaignTreasury
     */
    function withdraw() public view override whenNotPaused whenNotCancelled {
        revert KeepWhatsRaisedDisabled();
    }

    /**
     * @dev Allows the campaign owner or platform admin to withdraw funds, applying required fees and taxes.
     *
     * @param amount The withdrawal amount (ignored for final withdrawals).
     *
     * Requirements:
     * - Caller must be authorized.
     * - Withdrawals must be enabled, not paused, and within the allowed time.
     * - For partial withdrawals:
     *   - `amount` > 0 and `amount + fees` ≤ available balance.
     * - For final withdrawals:
     *   - Available balance > 0 and fees ≤ available balance.
     *
     * Effects:
     * - Deducts fees (flat, cumulative, and Colombian tax if applicable).
     * - Updates available balance.
     * - Transfers net funds to the recipient.
     *
     * Reverts:
     * - If insufficient funds or invalid input.
     *
     * Emits:
     * - `WithdrawalWithFeeSuccessful`.
     */
    function withdraw(
        uint256 amount
    ) 
        public
        onlyPlatformAdminOrCampaignOwner
        currentTimeIsLess(getDeadline() + s_config.withdrawalDelay)
        whenNotPaused
        whenNotCancelled
        withdrawalEnabled
    {
        uint256 flatFee = getFeeValue(s_feeKeys.flatFeeKey);
        uint256 cumulativeFee = getFeeValue(s_feeKeys.cumulativeFlatFeeKey);
        uint256 currentTime = block.timestamp;
        uint256 withdrawalAmount = s_availablePledgedAmount;
        uint256 totalFee = 0;
        address recipient = INFO.owner();
        bool isFinalWithdrawal = (currentTime > getDeadline());

        //Main Fees
        if(isFinalWithdrawal){
            if(withdrawalAmount == 0){
                revert KeepWhatsRaisedAlreadyWithdrawn();
            }
            if(withdrawalAmount < s_config.minimumWithdrawalForFeeExemption){
                 s_platformFee += flatFee;
                 totalFee += flatFee;
            }

        }else {
            withdrawalAmount = amount;
            if(withdrawalAmount == 0){
                revert KeepWhatsRaisedInvalidInput();
            }
            if(withdrawalAmount > s_availablePledgedAmount){
                revert KeepWhatsRaisedInsufficientFundsForWithdrawalAndFee(s_availablePledgedAmount, withdrawalAmount, totalFee); 
            }

            if(withdrawalAmount < s_config.minimumWithdrawalForFeeExemption){
                 s_platformFee += cumulativeFee;
                 totalFee += cumulativeFee;
            }else {
                s_platformFee += flatFee;
                totalFee += flatFee;
            }
        }

        uint256 availableBeforeTax = withdrawalAmount; //The tax implemented is on the withdrawal amount

        // Colombian creator tax
        if (s_config.isColombianCreator) {
            // Formula: (availableBeforeTax * 0.004) / 1.004 ≈ ((availableBeforeTax * 40) / 10040)
            uint256 scaled = availableBeforeTax * PERCENT_DIVIDER;
            uint256 numerator = scaled * 40;
            uint256 denominator = 10040;
            uint256 columbianCreatorTax = numerator / (denominator * PERCENT_DIVIDER);

            s_platformFee += columbianCreatorTax;
            totalFee += columbianCreatorTax;
        }

        if(isFinalWithdrawal) {
            if(withdrawalAmount < totalFee) {
                revert KeepWhatsRaisedInsufficientFundsForFee(withdrawalAmount, totalFee);
            }
            
            s_availablePledgedAmount = 0;
            TOKEN.safeTransfer(recipient, withdrawalAmount - totalFee);
        } else {
            if(s_availablePledgedAmount < (withdrawalAmount + totalFee)) {
                revert KeepWhatsRaisedInsufficientFundsForWithdrawalAndFee(s_availablePledgedAmount, withdrawalAmount, totalFee);
            }
            
            s_availablePledgedAmount -= (withdrawalAmount + totalFee);
            TOKEN.safeTransfer(recipient, withdrawalAmount);
        }

        emit WithdrawalWithFeeSuccessful(recipient, isFinalWithdrawal ? withdrawalAmount - totalFee : withdrawalAmount, totalFee);
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
    function claimRefund(
        uint256 tokenId
    )
        external
        currentTimeIsGreater(getLaunchTime())
        whenCampaignNotPaused
        whenNotPaused
    {
        if (!_checkRefundPeriodStatus(false)) {
            revert KeepWhatsRaisedNotClaimable(tokenId);
        }

        uint256 amountToRefund = s_tokenToPledgedAmount[tokenId];
        uint256 availablePledgedAmount = s_availablePledgedAmount;
        uint256 paymentFee = s_tokenToPaymentFee[tokenId];
        uint256 netRefundAmount = amountToRefund - paymentFee;

        if (netRefundAmount == 0 || availablePledgedAmount < netRefundAmount) {
            revert KeepWhatsRaisedNotClaimable(tokenId);
        }
        s_tokenToPledgedAmount[tokenId] = 0;
        s_pledgedAmount -= amountToRefund;
        s_availablePledgedAmount -= netRefundAmount;
        s_tokenToPaymentFee[tokenId] = 0;

        burn(tokenId);
        TOKEN.safeTransfer(msg.sender, netRefundAmount);
        emit RefundClaimed(tokenId, netRefundAmount, msg.sender);
    }

    /**
     * @dev Disburses all accumulated fees to the appropriate fee collector or treasury.
     * 
     * Requirements:
     * - Only callable when fees are available.
     */
    function disburseFees()
        public
        override
        whenNotPaused
        whenNotCancelled
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
     * @dev Allows an authorized claimer to collect tips contributed during the campaign.
     * 
     * Requirements:
     * - Caller must be authorized to claim tips.
     * - Tip amount must be non-zero.
     */
    function claimTip()
        external
        onlyPlatformAdmin(PLATFORM_HASH)
        whenCampaignNotPaused
        whenNotPaused
    {
        if(s_cancellationTime == 0 && block.timestamp <= getDeadline()){
            revert KeepWhatsRaisedNotClaimableAdmin();
        }

        if(s_tipClaimed){
            revert KeepWhatsRaisedAlreadyClaimed();
        }

        address platformAdmin = INFO.getPlatformAdminAddress(PLATFORM_HASH);
        uint256 tip = s_tip;
        s_tip = 0;
        s_tipClaimed = true;

        TOKEN.safeTransfer(
            platformAdmin,
            tip
        );

        emit TipClaimed(tip, platformAdmin);
    }

    /**
    * @dev Allows the platform admin to claim the remaining funds from a campaign.
    *
    * Requirements:
    * - Claim period must have started and funds must be available.
    * - Cannot be previously claimed.
    */
    function claimFund()
        external
        onlyPlatformAdmin(PLATFORM_HASH)
        whenCampaignNotPaused
        whenNotPaused
    {
        bool isCancelled = s_cancellationTime > 0;
        uint256 cancelLimit = s_cancellationTime + s_config.refundDelay;
        uint256 deadlineLimit = getDeadline() + s_config.withdrawalDelay;

        if ((isCancelled && block.timestamp <= cancelLimit) || (!isCancelled && block.timestamp <= deadlineLimit)) {
            revert KeepWhatsRaisedNotClaimableAdmin();
        }

        if(s_fundClaimed){
            revert KeepWhatsRaisedAlreadyClaimed();
        }

        address platformAdmin = INFO.getPlatformAdminAddress(PLATFORM_HASH);
        uint256 amountToClaim = s_availablePledgedAmount;
        s_availablePledgedAmount = 0;
        s_fundClaimed = true;

        TOKEN.safeTransfer(
            platformAdmin,
            amountToClaim
        );

        emit FundClaimed(amountToClaim, platformAdmin);
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
    function _checkSuccessCondition()
        internal
        view
        virtual
        override
        returns (bool)
    {
        return true;
    }

    function _pledge(
        bytes32 pledgeId,
        address backer,
        bytes32 reward,
        uint256 pledgeAmount,
        uint256 tip,
        uint256 tokenId,
        bytes32[] memory rewards,
        address tokenSource
    ) private {
        uint256 totalAmount = pledgeAmount + tip;
        
        // Transfer tokens from tokenSource (either admin or backer)
        TOKEN.safeTransferFrom(tokenSource, address(this), totalAmount);
        
        s_tokenIdCounter.increment();
        s_tokenToPledgedAmount[tokenId] = pledgeAmount;
        s_tokenToTippedAmount[tokenId] = tip;
        s_pledgedAmount += pledgeAmount;
        s_tip += tip;

        //Fee Calculation
        pledgeAmount = _calculateNetAvailable(pledgeId, tokenId, pledgeAmount);
        s_availablePledgedAmount += pledgeAmount;

        _safeMint(backer, tokenId, abi.encodePacked(backer, reward));
        emit Receipt(
            backer,
            reward,
            pledgeAmount,
            tip,
            tokenId,
            rewards
        );
    }

    /**
     * @notice Calculates the net amount available from a pledge after deducting 
     *         all applicable fees.
     *
     * @dev The function performs the following:
     *      - Applies all configured gross percentage-based fees
     *      - Applies payment gateway fee for the given pledge
     *      - Applies protocol fee based on protocol configuration
     *      - Accumulates total platform and protocol fees
     *      - Records the total deducted fee for the token
     *
     * @param pledgeId The unique identifier of the pledge
     * @param tokenId The token ID representing the pledge
     * @param pledgeAmount The original pledged amount before deductions
     *
     * @return The net available amount after all fees are deducted
     */
    function _calculateNetAvailable(bytes32 pledgeId, uint256 tokenId, uint256 pledgeAmount) internal returns (uint256) {
        uint256 totalFee = 0;

        // Gross Percentage Fee Calculation
        uint256 len = s_feeKeys.grossPercentageFeeKeys.length;
        for (uint256 i = 0; i < len; i++) {
            uint256 fee = (pledgeAmount * getFeeValue(s_feeKeys.grossPercentageFeeKeys[i]))
                        / PERCENT_DIVIDER;
            s_platformFee += fee;
            totalFee += fee;
        }

        //Payment Gateway Fee Calculation
        uint256 paymentGatewayFee = getPaymentGatewayFee(pledgeId);
        s_platformFee += paymentGatewayFee;
        totalFee += paymentGatewayFee;

        //Protocol Fee Calculation
        uint256 protocolFee = (pledgeAmount * INFO.getProtocolFeePercent()) /
            PERCENT_DIVIDER;
        s_protocolFee += protocolFee;
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

    // The following functions are overrides required by Solidity.
    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
