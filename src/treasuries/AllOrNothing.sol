// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Counters} from "../utils/Counters.sol";
import {TimestampChecker} from "../utils/TimestampChecker.sol";
import {ICampaignTreasury} from "../interfaces/ICampaignTreasury.sol";
import {ICampaignInfo} from "../interfaces/ICampaignInfo.sol";
import {BaseTreasury} from "../utils/BaseTreasury.sol";
import {IReward} from "../interfaces/IReward.sol";
import {IPermit2, ISignatureTransfer, PermitData} from "../interfaces/IPermit2.sol";
import {TreasuryErrors} from "../errors/TreasuryErrors.sol";

/**
 * @title AllOrNothing
 * @notice A contract for handling "all-or-nothing" crowdfunding campaigns. Funds are only claimable by the campaign owner if the funding goal is met by the deadline; otherwise, backers can claim refunds.
 */
contract AllOrNothing is IReward, BaseTreasury, TimestampChecker {
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    // Mapping to store the total collected amount (pledged amount and shipping fee) per token ID
    mapping(uint256 => uint256) private s_tokenToTotalCollectedAmount;
    // Mapping to store the pledged amount per token ID
    mapping(uint256 => uint256) private s_tokenToPledgedAmount;
    // Mapping to store reward details by name
    mapping(bytes32 => Reward) private s_reward;
    // Mapping to store the token used for each pledge
    mapping(uint256 => address) private s_tokenIdToPledgeToken;

    // Counter for reward tiers
    Counters.Counter private s_rewardCounter;

    // ---------------------------------------------------------------------------
    // Permit2 witness types for pledge functions
    // ---------------------------------------------------------------------------
    // pledgeForAReward witness – binds backer, reward array, and shipping fee
    bytes32 internal constant AON_PLEDGE_FOR_REWARD_WITNESS_TYPEHASH = keccak256(
        "PledgeForRewardWitness(address backer,bytes32 rewardsHash,uint256 shippingFee)"
    );
    string internal constant AON_PLEDGE_FOR_REWARD_WITNESS_TYPE_STRING =
        "PledgeForRewardWitness witness)PledgeForRewardWitness(address backer,bytes32 rewardsHash,uint256 shippingFee)TokenPermissions(address token,uint256 amount)";

    // pledgeWithoutAReward witness – binds backer and pledge amount
    bytes32 internal constant AON_PLEDGE_WITHOUT_REWARD_WITNESS_TYPEHASH =
        keccak256("PledgeWithoutRewardWitness(address backer,uint256 pledgeAmount)");
    string internal constant AON_PLEDGE_WITHOUT_REWARD_WITNESS_TYPE_STRING =
        "PledgeWithoutRewardWitness witness)PledgeWithoutRewardWitness(address backer,uint256 pledgeAmount)TokenPermissions(address token,uint256 amount)";


    /**
     * @dev Emitted when a backer makes a pledge.
     * @param backer The address of the backer making the pledge.
     * @param pledgeToken The token used for the pledge.
     * @param reward The name of the reward.
     * @param pledgeAmount The amount pledged.
     * @param tokenId The ID of the token representing the pledge.
     * @param rewards An array of reward names.
     */
    event Receipt(
        address indexed backer,
        address indexed pledgeToken,
        bytes32 reward,
        uint256 pledgeAmount,
        uint256 shippingFee,
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

    /**
     * @dev Emitted when a refund is claimed.
     * @param tokenId The ID of the token representing the pledge.
     * @param refundAmount The refund amount claimed.
     * @param claimer The address of the claimer.
     */
    event RefundClaimed(uint256 tokenId, uint256 refundAmount, address claimer);

    /**
     * @dev Emitted when an unauthorized action is attempted.
     */
    error AllOrNothingUnAuthorized();

    /**
     * @dev Emitted when an invalid input is detected.
     * @param code Error code defined in {TreasuryErrors.InvalidInput}.
     */
    error AllOrNothingInvalidInput(TreasuryErrors.InvalidInput code);

    /// @dev Reverts when reward name is zero bytes.
    error AllOrNothingZeroRewardName();
    /// @dev Reverts when reward value is zero.
    error AllOrNothingZeroRewardValue();
    /// @dev Reverts when reward item arrays have mismatched lengths.
    error AllOrNothingRewardItemArrayLengthMismatch();
    /// @dev Reverts when backer address is zero.
    error AllOrNothingZeroBacker();
    /// @dev Reverts when reward selection length exceeds number of rewards.
    error AllOrNothingRewardSelectionLengthMismatch();
    /// @dev Reverts when first reward is not a reward tier.
    error AllOrNothingFirstRewardNotTier();

    /**
     * @dev Emitted when a token transfer fails.
     */
    error AllOrNothingTransferFailed();

    /**
     * @dev Emitted when the campaign is not successful.
     */
    error AllOrNothingNotSuccessful();

    /**
     * @dev Emitted when fees are not disbursed.
     */
    error AllOrNothingFeeNotDisbursed();

    /**
     * @dev Emitted when a `Reward` already exists for given input.
     */
    error AllOrNothingRewardExists();

    /**
     * @dev Emitted when a token is not accepted for the campaign.
     */
    error AllOrNothingTokenNotAccepted(address token);

    /**
     * @dev Emitted when claiming an unclaimable refund.
     * @param tokenId The ID of the token representing the pledge.
     * @param code Error code defined in {TreasuryErrors.NotClaimable}.
     */
    error AllOrNothingNotClaimable(uint256 tokenId, TreasuryErrors.NotClaimable code);

    /**
     * @dev Constructor for the AllOrNothing contract.
     */
    constructor() {}

    function initialize(bytes32 _platformHash, address _infoAddress) external initializer {
        __BaseContract_init(_platformHash, _infoAddress);
    }

    /**
     * @notice Retrieves the details of a reward.
     * @param rewardName The name of the reward.
     * @return reward The details of the reward as a `Reward` struct.
     */
    function getReward(bytes32 rewardName) external view returns (Reward memory reward) {
        if (s_reward[rewardName].rewardValue == 0) {
            revert AllOrNothingInvalidInput(TreasuryErrors.InvalidInput.REWARD_NOT_FOUND);
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
            revert AllOrNothingInvalidInput(TreasuryErrors.InvalidInput.REWARD_LENGTH_MISMATCH);
        }

        for (uint256 i = 0; i < rewardNames.length; i++) {
            bytes32 rewardName = rewardNames[i];
            Reward calldata reward = rewards[i];

            if (rewardName == ZERO_BYTES) revert AllOrNothingZeroRewardName();
            if (reward.rewardValue == 0) revert AllOrNothingZeroRewardValue();

            // If there are any items, their arrays must match in length
            if (reward.itemId.length != reward.itemValue.length) revert AllOrNothingRewardItemArrayLengthMismatch();
            if (reward.itemId.length != reward.itemQuantity.length) revert AllOrNothingRewardItemArrayLengthMismatch();

            // Check for duplicate reward
            if (s_reward[rewardName].rewardValue != 0) {
                revert AllOrNothingRewardExists();
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
        currentTimeIsLess(INFO.getLaunchTime())
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
        if (s_reward[rewardName].rewardValue == 0) {
            revert AllOrNothingInvalidInput(TreasuryErrors.InvalidInput.REWARD_NOT_FOUND);
        }
        delete s_reward[rewardName];
        s_rewardCounter.decrement();
        emit RewardRemoved(rewardName);
    }

    /**
     * @notice Allows a backer to pledge for a reward using a Permit2 signature.
     * @dev Tokens are transferred from `backer` via Permit2 `permitWitnessTransferFrom`.
     *      The permit's witness commits to `backer`, the reward array hash, and `shippingFee`,
     *      so the caller cannot change those values after the backer has signed.
     * @param backer The address of the backer making the pledge (must be the permit signer).
     * @param pledgeToken The token address to use for the pledge.
     * @param shippingFee The shipping fee amount.
     * @param reward An array of reward names.
     * @param permitData Permit2 permit data (nonce, deadline, signature) signed by `backer`.
     */
    function pledgeForAReward(
        address backer,
        address pledgeToken,
        uint256 shippingFee,
        bytes32[] calldata reward,
        PermitData calldata permitData
    )
        external
        nonReentrant
        currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
        uint256 rewardLen = reward.length;
        Reward storage tempReward = s_reward[reward[0]];
        if (backer == address(0)) revert AllOrNothingZeroBacker();
        if (rewardLen > s_rewardCounter.current()) revert AllOrNothingRewardSelectionLengthMismatch();
        if (reward[0] == ZERO_BYTES) revert AllOrNothingInvalidInput(TreasuryErrors.InvalidInput.INVALID_PLEDGE_INPUT);
        if (!tempReward.isRewardTier) revert AllOrNothingFirstRewardNotTier();
        uint256 pledgeAmount = tempReward.rewardValue;
        for (uint256 i = 1; i < rewardLen; i++) {
            if (reward[i] == ZERO_BYTES) {
                revert AllOrNothingInvalidInput(TreasuryErrors.InvalidInput.ZERO_REWARD_NAME);
            }
            tempReward = s_reward[reward[i]];
            if (tempReward.rewardValue == 0 || !tempReward.canBeAddOn) {
                revert AllOrNothingInvalidInput(TreasuryErrors.InvalidInput.REWARD_NOT_FOUND);
            }
            pledgeAmount += tempReward.rewardValue;
        }
        _pledge(backer, pledgeToken, reward[0], pledgeAmount, shippingFee, reward, permitData);
    }

    /**
     * @notice Allows a backer to pledge without selecting a reward using a Permit2 signature.
     * @dev Tokens are transferred from `backer` via Permit2 `permitWitnessTransferFrom`.
     *      The permit's witness commits to `backer` and `pledgeAmount`.
     * @param backer The address of the backer making the pledge (must be the permit signer).
     * @param pledgeToken The token address to use for the pledge.
     * @param pledgeAmount The amount of the pledge (in token's native decimals).
     * @param permitData Permit2 permit data (nonce, deadline, signature) signed by `backer`.
     */
    function pledgeWithoutAReward(
        address backer,
        address pledgeToken,
        uint256 pledgeAmount,
        PermitData calldata permitData
    )
        external
        nonReentrant
        currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
        bytes32[] memory emptyByteArray = new bytes32[](0);

        _pledge(backer, pledgeToken, ZERO_BYTES, pledgeAmount, 0, emptyByteArray, permitData);
    }

    /**
     * @notice Allows a backer to claim a refund.
     * @param tokenId The ID of the token representing the pledge.
     */
    function claimRefund(uint256 tokenId)
        external
        currentTimeIsGreater(INFO.getLaunchTime())
        whenCampaignNotPaused
        whenNotPaused
    {
        if (block.timestamp >= INFO.getDeadline() && _checkSuccessCondition()) {
            revert AllOrNothingNotClaimable(tokenId, TreasuryErrors.NotClaimable.CAMPAIGN_SUCCESSFUL);
        }

        // Get NFT owner before burning
        address nftOwner = INFO.ownerOf(tokenId);

        uint256 amountToRefund = s_tokenToTotalCollectedAmount[tokenId];
        uint256 pledgedAmount = s_tokenToPledgedAmount[tokenId];
        address pledgeToken = s_tokenIdToPledgeToken[tokenId];

        if (amountToRefund == 0) {
            revert AllOrNothingNotClaimable(tokenId, TreasuryErrors.NotClaimable.REFUND_ZERO_AMOUNT);
        }

        s_tokenToTotalCollectedAmount[tokenId] = 0;
        s_tokenToPledgedAmount[tokenId] = 0;
        s_tokenRaisedAmounts[pledgeToken] -= pledgedAmount;
        delete s_tokenIdToPledgeToken[tokenId];

        // Burn the NFT (requires treasury approval from owner)
        INFO.burn(tokenId);

        IERC20(pledgeToken).safeTransfer(nftOwner, amountToRefund);
        emit RefundClaimed(tokenId, amountToRefund, nftOwner);
    }

    /**
     * @inheritdoc ICampaignTreasury
     */
    function disburseFees() public override currentTimeIsGreater(INFO.getDeadline()) whenNotPaused whenNotCancelled {
        super.disburseFees();
    }

    /**
     * @inheritdoc ICampaignTreasury
     */
    function withdraw() public override whenNotPaused whenNotCancelled {
        super.withdraw();
    }

    /**
     * @inheritdoc BaseTreasury
     * @dev This function is overridden to allow the platform admin and the campaign owner to cancel a treasury.
     */
    function cancelTreasury(bytes32 message) public override {
        if (_msgSender() != INFO.getPlatformAdminAddress(PLATFORM_HASH) && _msgSender() != INFO.owner()) {
            revert AllOrNothingUnAuthorized();
        }
        _cancel(message);
    }

    /**
     * @inheritdoc BaseTreasury
     */
    function _checkSuccessCondition() internal view virtual override returns (bool) {
        return INFO.getTotalRaisedAmount() >= INFO.getGoalAmount();
    }

    /**
     * @dev Processes a pledge: transfers tokens, mints NFT, and updates state.
     * @dev Mints a pledge NFT via `_safeMint`; reverts if `backer` is a contract that does not implement `IERC721Receiver`.
     * @param backer Recipient of the pledge NFT.
     * @param pledgeToken Token used for the pledge.
     * @param reward First reward tier (ZERO_BYTES for non-reward pledges).
     * @param pledgeAmount Pledge amount in the token's native decimals (must be denormalized by caller).
     * @param shippingFee Shipping fee in the token's native decimals (must be denormalized by caller; use 0 for non-reward).
     * @param rewards Full reward selection (for event).
     */
    function _pledge(
        address backer,
        address pledgeToken,
        bytes32 reward,
        uint256 pledgeAmount,
        uint256 shippingFee,
        bytes32[] memory rewards,
        PermitData calldata permitData
    ) private {
        if (!INFO.isTokenAccepted(pledgeToken)) {
            revert AllOrNothingTokenNotAccepted(pledgeToken);
        }
        if (backer == address(this)) {
            revert AllOrNothingInvalidInput(TreasuryErrors.InvalidInput.INVALID_BACKER);
        }
        if (permitData.signature.length == 0) {
            revert AllOrNothingInvalidInput(TreasuryErrors.InvalidInput.EMPTY_SIGNATURE);
        }

        uint256 pledgeAmountInTokenDecimals;
        uint256 shippingFeeInTokenDecimals;

        if (reward != ZERO_BYTES) {
            pledgeAmountInTokenDecimals = _denormalizeAmount(pledgeToken, pledgeAmount);
            shippingFeeInTokenDecimals = _denormalizeAmount(pledgeToken, shippingFee);
        } else {
            pledgeAmountInTokenDecimals = pledgeAmount;
            shippingFeeInTokenDecimals = shippingFee;
        }

        uint256 totalAmount = pledgeAmountInTokenDecimals + shippingFeeInTokenDecimals;

        bytes32 witness;
        string memory witnessTypeString;

        if (reward != ZERO_BYTES) {
            bytes32 rewardsHash = keccak256(abi.encodePacked(rewards));
            witness = keccak256(
                abi.encode(AON_PLEDGE_FOR_REWARD_WITNESS_TYPEHASH, backer, rewardsHash, shippingFee)
            );
            witnessTypeString = AON_PLEDGE_FOR_REWARD_WITNESS_TYPE_STRING;
        } else {
            witness =
                keccak256(abi.encode(AON_PLEDGE_WITHOUT_REWARD_WITNESS_TYPEHASH, backer, pledgeAmountInTokenDecimals));
            witnessTypeString = AON_PLEDGE_WITHOUT_REWARD_WITNESS_TYPE_STRING;
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

        uint256 tokenId = INFO.mintNFTForPledge(
            backer, reward, pledgeToken, pledgeAmountInTokenDecimals, shippingFeeInTokenDecimals, 0
        );

        s_tokenToPledgedAmount[tokenId] = pledgeAmountInTokenDecimals;
        s_tokenToTotalCollectedAmount[tokenId] = totalAmount;
        s_tokenIdToPledgeToken[tokenId] = pledgeToken;
        s_tokenRaisedAmounts[pledgeToken] += pledgeAmountInTokenDecimals;
        s_tokenLifetimeRaisedAmounts[pledgeToken] += pledgeAmountInTokenDecimals;

        emit Receipt(backer, pledgeToken, reward, pledgeAmount, shippingFee, tokenId, rewards);
    }
}
