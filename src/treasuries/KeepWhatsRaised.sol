// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

import "../utils/Counters.sol";
import "../utils/TimestampChecker.sol";
import "../utils/BaseTreasury.sol";
import "../interfaces/IReward.sol";

/**
 * @title KeepWhatsRaised
 * @notice A contract that keeps all the funds raised, regardless of the success condition.
 */
abstract contract KeepWhatsRaised is
    IReward,
    BaseTreasury,
    TimestampChecker,
    ERC721Burnable
{
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    // Mapping to store the total collected amount (pledged amount and tip amount) per token ID
    mapping(uint256 => uint256) private s_tokenToTotalCollectedAmount;
    // Mapping to store the pledged amount per token ID
    mapping(uint256 => uint256) private s_tokenToPledgedAmount;
    // Mapping to store the tipped amount per token ID
    mapping(uint256 => uint256) private s_tokenToTippedAmount;
    // Mapping to store reward details by name
    mapping(bytes32 => Reward) private s_reward;

    // Counters for token IDs and rewards
    Counters.Counter private s_tokenIdCounter;
    Counters.Counter private s_rewardCounter;
    struct FeeKeys {
        bytes32 flatFeeKey;
        bytes32 cumulativeFlatFeeKey;
        bytes32[] grossPercentageFeeKeys;
        bytes32[] netPercentageFeeKeys;
    }
    struct Config {
        uint256 minimumWithdrawalForFeeExemption;
        uint256 withdrawalDelay;
    }

    string private s_name;
    string private s_symbol;
    uint256 private s_tip;
    uint256 private s_platformFee;
    uint256 private s_protocolFee;
    uint256 private s_availablePledgedAmount;
    bool private s_isWithdrawalApproved;
    bool private s_tipDisbursed;
    FeeKeys private s_feeKeys;
    Config private s_config;

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

    event WithdrawalApproved();

    event ConfigAndFeeKeysSet(
        Config s_config,
        FeeKeys s_feeKeys
    );

    event WithdrawalWithFeeSuccessful(address to, uint256 amount, uint256 fee);

    event TipClaimed(uint256 amount, address claimer);

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

    error KeepWhatsRaisedAlreadyEnabled();

    error KeepWhatsRaisedInvalidKey();

    error KeepWhatsRaisedWithdrawalOverload(uint256 availableAmount, uint256 withdrawalAmount, uint256 fee);

    error KeepWhatsRaisedAlreadyWithdrawn();

    error KeepWhatsRaisedAlreadyDisbursed();

    modifier withdrawalEnabled() {
        if(!s_isWithdrawalApproved){
            revert KeepWhatsRaisedDisabled();
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

    function setConfigsAndFeeKeys(
        Config memory config,
        FeeKeys memory feeKeys
    ) 
        external 
        onlyPlatformAdmin(PLATFORM_HASH)
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
        s_config = config;
        s_feeKeys = feeKeys;

        emit ConfigAndFeeKeysSet(
            config,
            feeKeys
        );
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
     * @notice Allows a backer to pledge for a reward.
     * @dev The first element of the `reward` array must be a reward tier and the other elements can be either reward tiers or non-reward tiers.
     *      The non-reward tiers cannot be pledged for without a reward.
     * @param backer The address of the backer making the pledge.
     * @param tip An optional tip can be added during the process.
     * @param reward An array of reward names.
     */
    function pledgeForAReward(
        address backer,
        uint256 tip,
        bytes32[] calldata reward
    )
        external
        currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
        uint256 tokenId = s_tokenIdCounter.current();
        uint256 rewardLen = reward.length;
        Reward storage tempReward = s_reward[reward[0]];
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
            pledgeAmount += s_reward[reward[i]].rewardValue;
        }
        _pledge(backer, reward[0], pledgeAmount, tip, tokenId, reward);
    }

    /**
     * @notice Allows a backer to pledge without selecting a reward.
     * @param backer The address of the backer making the pledge.
     * @param pledgeAmount The amount of the pledge.
     * @param tip An optional tip can be added during the process.
     */
    function pledgeWithoutAReward(
        address backer,
        uint256 pledgeAmount,
        uint256 tip
    )
        external
        currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
        uint256 tokenId = s_tokenIdCounter.current();
        bytes32[] memory emptyByteArray = new bytes32[](0);

        _pledge(backer, ZERO_BYTES, pledgeAmount, tip, tokenId, emptyByteArray);
    }

    /**
     * @inheritdoc ICampaignTreasury
     */
    function withdraw() public view override whenNotPaused whenNotCancelled {
        revert KeepWhatsRaisedDisabled();
    }

    function withdraw(
        uint256 amount
    ) 
        public
        currentTimeIsLess(INFO.getDeadline() + s_config.withdrawalDelay)
        whenNotPaused
        whenNotCancelled
        withdrawalEnabled
    {
        uint256 flatFee = uint256(INFO.getPlatformData(s_feeKeys.flatFeeKey));
        uint256 cumulativeFee = uint256(INFO.getPlatformData(s_feeKeys.cumulativeFlatFeeKey));
        uint256 currentTime = block.timestamp;
        uint256 withdrawalAmount = s_availablePledgedAmount;
        uint256 totalFee = 0;
        address recipient = INFO.owner();

        //Main Fees
        if(currentTime > INFO.getDeadline()){
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
                revert KeepWhatsRaisedWithdrawalOverload(s_availablePledgedAmount, withdrawalAmount, totalFee); 
            }

            if(withdrawalAmount < s_config.minimumWithdrawalForFeeExemption){
                 s_platformFee += cumulativeFee;
                 totalFee += cumulativeFee;
            }else {
                s_platformFee += flatFee;
                totalFee += flatFee;
            }
        }

        //Other Fees
        uint256 fee = (s_availablePledgedAmount * INFO.getProtocolFeePercent()) /
            PERCENT_DIVIDER;
        s_protocolFee += fee;
        totalFee += fee;

        //Gross Percentage Fee Calculation
        uint256 len = s_feeKeys.grossPercentageFeeKeys.length;
        for(uint256 i = 0; i < len; i++){
            fee = (s_availablePledgedAmount * uint256(s_feeKeys.grossPercentageFeeKeys[i])) /
                PERCENT_DIVIDER;
            s_platformFee += fee;
            totalFee += fee;
        }

        //Net Percentage Fee Calculation
        if(totalFee > withdrawalAmount){
            revert KeepWhatsRaisedWithdrawalOverload(s_availablePledgedAmount, withdrawalAmount, totalFee);
        }
        uint256 availableBeforeNet = withdrawalAmount - totalFee;
        len = s_feeKeys.netPercentageFeeKeys.length;
        for(uint256 i = 0; i < len; i++){
            fee = (availableBeforeNet * uint256(s_feeKeys.netPercentageFeeKeys[i])) /
                PERCENT_DIVIDER;
            s_platformFee += fee;
            totalFee += fee;
        }

        if(totalFee > withdrawalAmount){
            revert KeepWhatsRaisedWithdrawalOverload(s_availablePledgedAmount, withdrawalAmount, totalFee);
        }

        s_availablePledgedAmount -= withdrawalAmount;
        withdrawalAmount -= totalFee;

        TOKEN.safeTransfer(recipient, withdrawalAmount);

        emit WithdrawalWithFeeSuccessful(recipient, withdrawalAmount, totalFee);
    }

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

    function claimTip()
        external
        onlyPlatformAdmin(PLATFORM_HASH)
        currentTimeIsGreater(INFO.getDeadline())
        whenCampaignNotPaused
        whenNotPaused
    {
        if(s_tipDisbursed){
            revert KeepWhatsRaisedAlreadyDisbursed();
        }

        address platformAdmin = INFO.getPlatformAdminAddress(PLATFORM_HASH);
        uint256 tip = s_tip;
        s_tip = 0;
        s_tipDisbursed = true;

        TOKEN.safeTransfer(
            platformAdmin,
            tip
        );

        emit TipClaimed(tip, platformAdmin);
    }

    /**
     * @inheritdoc BaseTreasury
     * @dev This function is overridden to allow the platform admin and the campaign owner to cancel a treasury.
     */
    function cancelTreasury(bytes32 message) public override {
        if (
            msg.sender != INFO.getPlatformAdminAddress(PLATFORM_HASH) &&
            msg.sender != INFO.owner()
        ) {
            revert KeepWhatsRaisedUnAuthorized();
        }
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
        return INFO.getTotalRaisedAmount() >= INFO.getGoalAmount();
    }

    function _pledge(
        address backer,
        bytes32 reward,
        uint256 pledgeAmount,
        uint256 tip,
        uint256 tokenId,
        bytes32[] memory rewards
    ) private {
        uint256 totalAmount = pledgeAmount + tip;
        TOKEN.safeTransferFrom(backer, address(this), totalAmount);
        s_tokenIdCounter.increment();
        _safeMint(backer, tokenId, abi.encodePacked(backer, reward));
        s_tokenToPledgedAmount[tokenId] = pledgeAmount;
        s_tokenToTotalCollectedAmount[tokenId] = totalAmount;
        s_tokenToTippedAmount[tokenId] = tip;
        s_pledgedAmount += pledgeAmount;
        s_availablePledgedAmount += pledgeAmount;
        s_tip += tip;
        emit Receipt(
            backer,
            reward,
            pledgeAmount,
            tip,
            tokenId,
            rewards
        );
    }

    // The following functions are overrides required by Solidity.
    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
