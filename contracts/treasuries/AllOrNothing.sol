// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../utils/TimestampChecker.sol";
import "../utils/BasicTreasury.sol";
import "../utils/FiatEnabled.sol";

contract AllOrNothing is
    BasicTreasury,
    TimestampChecker,
    FiatEnabled,
    ERC721Burnable
{
    using Counters for Counters.Counter;

    struct Reward {
        uint256 rewardValue;
        bool isRewardTier;
        bytes32[] itemId;
        uint256[] itemValue;
        uint256[] itemQuantity;
    }

    uint256 private constant PRELAUNCH_PLEDGE = 1 ether;

    mapping(uint256 => uint256) private s_tokenToPledgedAmount;
    mapping(bytes32 => Reward) private s_reward;

    Counters.Counter private s_tokenIdCounter;
    Counters.Counter private s_rewardCounter;

    event Receipt(
        address indexed backer,
        bytes32 indexed reward,
        uint256 pledgeAmount,
        uint256 tokenId,
        bool isPreLaunchPledge,
        bytes32[] rewards
    );

    error AllOrNothingUnAuthorized();
    error AllOrNothingInvalidInput();
    error AllOrNothingTransferFailed();
    error AllOrNothingNotSuccessful();
    error AllOrNothingFeeNotDisbursed();
    error AllOrNothingNotClaimable(uint256 tokenId);

    constructor(
        bytes32 platformBytes,
        address infoAddress,
        address tokenAddress,
        uint256 platformFeePercent
    )
        ERC721("", "")
        BasicTreasury(
            platformBytes,
            platformFeePercent,
            infoAddress,
            tokenAddress
        )
    {
        s_tokenIdCounter.increment();
    }

    modifier onlyPlatformAdmin() {
        _checkIfPlatformAdmin();
        _;
    }

    modifier onlyOwner() {
        _checkIfCampaignOwner();
        _;
    }

    function getReward(
        bytes32 rewardName
    ) external view returns (Reward memory) {
        if (s_reward[rewardName].rewardValue == 0) {
            revert AllOrNothingInvalidInput();
        }
        return s_reward[rewardName];
    }

    function addReward(
        bytes32 rewardName,
        Reward calldata reward
    ) external onlyOwner {
        Reward storage tempReward = s_reward[rewardName];
        if (
            tempReward.rewardValue != 0 &&
            tempReward.itemId.length > 0 &&
            tempReward.itemId.length == tempReward.itemValue.length &&
            tempReward.itemId.length == tempReward.itemQuantity.length
        ) {
            s_reward[rewardName] = reward;
            s_rewardCounter.increment();
        } else {
            revert AllOrNothingInvalidInput();
        }
    }

    function removeReward(bytes32 rewardName) external onlyOwner {
        if (s_reward[rewardName].rewardValue == 0) {
            revert AllOrNothingInvalidInput();
        }
        delete s_reward[rewardName];
        s_rewardCounter.decrement();
    }

    function getRaisedAmount() external view override returns (uint256) {
        return s_fiatRaisedAmount + s_pledgedAmountInCrypto;
    }

    function updateFiatPledge(
        bytes32 fiatPledgeId,
        uint256 fiatPledgeAmount
    ) external onlyPlatformAdmin {
        _updateFiatTransaction(fiatPledgeId, fiatPledgeAmount);
    }

    function updateFiatFeeDisbursementState(
        bool isDisbursed,
        uint256 protocolFeeAmount,
        uint256 platformFeeAmount
    ) external onlyPlatformAdmin {
        _updateFiatFeeDisbusementState(
            isDisbursed,
            protocolFeeAmount,
            platformFeeAmount
        );
    }

    function pledgeOnPreLaunch(
        address backer
    ) external currentTimeIsLess(INFO.getLaunchTime()) {
        uint256 prelaunchPledgeAmount = PRELAUNCH_PLEDGE;
        bool success = TOKEN.transferFrom(
            backer,
            address(this),
            prelaunchPledgeAmount
        );
        if (!success) {
            revert AllOrNothingTransferFailed();
        }
        uint256 tokenId = s_tokenIdCounter.current();
        s_tokenIdCounter.increment();
        _safeMint(
            backer,
            tokenId,
            abi.encodePacked(backer, " PreLaunchPledge")
        );
        s_pledgedAmountInCrypto += prelaunchPledgeAmount;
        bytes32[] memory emptyByteArray = new bytes32[](0);
        emit Receipt(
            backer,
            ZERO_BYTES,
            prelaunchPledgeAmount,
            tokenId,
            true,
            emptyByteArray
        );
    }

    function pledgeForAReward(
        address backer,
        bytes32[] calldata reward
    )
        external
        currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
    {
        uint256 tokenId = s_tokenIdCounter.current();
        bool success;
        uint256 rewardLen = reward.length;
        Reward storage tempReward = s_reward[reward[0]];
        if (
            backer == address(0) ||
            rewardLen > s_rewardCounter.current() ||
            reward[0] == ZERO_BYTES ||
            !tempReward.isRewardTier
        ) {
            revert AllOrNothingInvalidInput();
        }
        uint256 pledgeAmount = tempReward.rewardValue;
        for (uint256 i = 1; i < rewardLen; i++) {
            if (reward[i] == ZERO_BYTES) {
                revert AllOrNothingInvalidInput();
            }
            pledgeAmount += s_reward[reward[i]].rewardValue;
        }
        success = TOKEN.transferFrom(backer, address(this), pledgeAmount);
        if (success) {
            s_tokenIdCounter.increment();
            _safeMint(
                backer,
                tokenId,
                abi.encodePacked(backer, " ", reward[0])
            );
            s_tokenToPledgedAmount[tokenId] = pledgeAmount;
            s_pledgedAmountInCrypto += pledgeAmount;
            emit Receipt(
                backer,
                reward[0],
                pledgeAmount,
                tokenId,
                false,
                reward
            );
        } else {
            revert AllOrNothingTransferFailed();
        }
    }

    function pledgeWithoutAReward(
        address backer,
        uint256 pledgeAmount
    )
        external
        currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
    {
        bool success = TOKEN.transferFrom(backer, address(this), pledgeAmount);
        if (success) {
            s_pledgedAmountInCrypto += pledgeAmount;
            bytes32[] memory emptyByteArray = new bytes32[](0);
            emit Receipt(
                backer,
                ZERO_BYTES,
                pledgeAmount,
                0,
                false,
                emptyByteArray
            );
        } else {
            revert AllOrNothingTransferFailed();
        }
    }

    function claimRefund(
        uint256 tokenId
    )
        external
        currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
    {
        uint256 amount = s_tokenToPledgedAmount[tokenId];
        if (amount == 0) {
            revert AllOrNothingNotClaimable(tokenId);
        }
        s_tokenToPledgedAmount[tokenId] = 0;
        burn(tokenId);
        bool success = TOKEN.transfer(_msgSender(), amount);
        if (!success) {
            revert AllOrNothingTransferFailed();
        }
    }

    function _checkIfPlatformAdmin() internal view {
        if (msg.sender != INFO.getPlatformAdminAddress(PLATFORM_BYTES)) {
            revert AllOrNothingUnAuthorized();
        }
    }

    function _checkSuccessCondition()
        internal
        view
        virtual
        override
        returns (bool)
    {
        return INFO.getTotalRaisedAmount() > INFO.getGoalAmount();
    }

    function _checkIfCampaignOwner() private view returns (bool) {
        if (INFO.owner() == msg.sender) {
            return true;
        } else {
            revert AllOrNothingUnAuthorized();
        }
    }

    // The following functions are overrides required by Solidity.
    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
