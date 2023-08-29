// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../interfaces/ICampaignTreasury.sol";
import "../interfaces/ICampaignInfo.sol";
import "../utils/TimestampChecker.sol";

contract AllOrNothing is ICampaignTreasury, ERC721Burnable, TimestampChecker {
    using Counters for Counters.Counter;

    struct Reward {
        uint256 rewardValue;
        bool isRewardTier;
        bytes32[] itemId;
        uint256[] itemValue;
        uint256[] itemQuantity;
    }

    /// Xstarter bytes
    bytes32 private constant PLATFORM_BYTES =
        0x5873746172746572000000000000000000000000000000000000000000000000;
    uint256 private constant PERCENT_DIVIDER = 10000;
    uint256 private constant PRELAUNCH_PLEDGE = 1 ether;
    uint256 private constant PLATFORM_FEE_PERCENT = 300;

    address private immutable CAMPAIGN_INFO;
    address private immutable TOKEN;

    uint256 private s_pledgedAmountInCrypto;
    uint256 private s_pledgedAmountInFiat;

    bool private s_cryptoFeeDisbursed;
    bool private s_fiatFeeDisbursed;

    mapping(uint256 => uint256) private s_tokenToPledgedAmount;
    mapping(bytes32 => Reward) private s_reward;
    mapping(bytes32 => uint256) private s_fiatPledge;

    Counters.Counter private s_tokenIdCounter;
    Counters.Counter private s_rewardCounter;

    ICampaignInfo s_info = ICampaignInfo(CAMPAIGN_INFO);

    event receipt(
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

    constructor(address info) ERC721("Xstarter", "XNFT") {
        CAMPAIGN_INFO = info;
        TOKEN = s_info.getTokenAddress();

        s_tokenIdCounter.increment();
    }

    modifier onlyPlatformAdmin() {
        _checkIfPlatformAdmin();
        _;
    }

    function _checkIfPlatformAdmin() internal view {
        if (
            msg.sender !=
            ICampaignInfo(CAMPAIGN_INFO).getPlatformAdminAddress(PLATFORM_BYTES)
        ) {
            revert AllOrNothingUnAuthorized();
        }
    }

    function addReward(bytes32 rewardName, Reward calldata reward) external {
        s_reward[rewardName] = reward;
    }

    function updateFiatPledge(
        bytes32 fiatPledgeId,
        uint256 fiatPledgeAmount
    ) external onlyPlatformAdmin {
        s_fiatPledge[fiatPledgeId] = fiatPledgeAmount;
    }

    function pledgeOnPreLaunch(
        address backer
    ) external currentTimeIsLess(s_info.getLaunchTime()) {
        uint256 prelaunchPledgeAmount = PRELAUNCH_PLEDGE;
        bool success = IERC20(ICampaignInfo(CAMPAIGN_INFO).getTokenAddress())
            .transferFrom(backer, address(this), prelaunchPledgeAmount);
        require(success);
        uint256 tokenId = s_tokenIdCounter.current();
        s_tokenIdCounter.increment();
        _safeMint(
            backer,
            tokenId,
            abi.encodePacked(backer, " PreLaunchPledge")
        );
        s_pledgedAmountInCrypto += prelaunchPledgeAmount;
        emit receipt(
            backer,
            0x00,
            prelaunchPledgeAmount,
            tokenId,
            true,
            [0x00]
        );
    }

    function pledgeForAReward(
        address backer,
        bytes32[] calldata reward
    )
        external
        currentTimeIsWithinRange(s_info.getLaunchTime(), s_info.getDeadline)
    {
        uint256 tokenId = s_tokenIdCounter.current();
        ICampaignInfo campaign = ICampaignInfo(CAMPAIGN_INFO);
        address token = campaign.getTokenAddress();
        bool success;
        uint256 rewardLen = reward.length;
        s_reward storage tempReward;
        if (
            backer == address(0) ||
            rewardLen > s_rewardCounter.current() ||
            reward[0] == 0x00 ||
            !tempReward[reward[0]].isRewardTier
        ) {
            revert AllOrNothingInvalidInput();
        }
        uint256 pledgeAmount = tempReward[reward[0]].rewardValue;
        for (uint256 i = 1; i < rewardLen; i++) {
            if (reward[i] == 0x00) {
                revert AllOrNothingInvalidInput();
            }
            pledgeAmount += tempReward[reward[i]].rewardValue;
        }
        success = IERC20(token).transferFrom(
            backer,
            address(this),
            pledgeAmount
        );
        if (success) {
            s_tokenIdCounter.increment();
            _safeMint(
                backer,
                tokenId,
                abi.encodePacked(backer, " ", reward[0])
            );
            s_tokenToPledgedAmount[tokenId] = pledgeAmount;
            s_tokenIdCounter[tokenId] = pledgeAmount;
            s_pledgedAmountInCrypto += pledgeAmount;
            emit receipt(
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
    ) external {
        bool success = IERC20(TOKEN).transferFrom(
            backer,
            address(this),
            pledgeAmount
        );
        if (success) {
            s_pledgedAmountInCrypto += pledgeAmount;
            emit receipt(backer, 0x00, pledgeAmount, 0, false, [0x00]);
        } else {
            revert AllOrNothingTransferFailed();
        }
    }

    function disburseFees() external currentTimeIsGreater(s_info.getDeadline()) { 
        uint256 balance = s_pledgedAmountInCrypto;
        if (s_info.getTotalRaisedAmount() > s_info.getGoalAmount()) {
            uint256 protocolShare = balance * s_info.getProtocolFeePercent() / PERCENT_DIVIDER;
            uint256 platformShare = balance * PLATFORM_FEE_PERCENT / PERCENT_DIVIDER;
            bool success = IERC20(TOKEN).transfer(s_info.getProtocolAdminAddress, protocolShare);
            if (!success) {
                revert AllOrNothingTransferFailed();
            }
            success = IERC20(TOKEN).transfer(s_info.getPlatformAdminAddress, platformShare);
            if (!success) {
                revert AllOrNothingTransferFailed();
            }
            s_cryptoFeeDisbursed = true;
        }
        else {
            revert AllOrNothingNotSuccessful();
        }
    }

    function withdrawCrptoPledgedAmount() external {
        if (s_cryptoFeeDisbursed) {
            uint256 balance = IERC20(TOKEN).balanceOf(address.this);
            IERC20(TOKEN).transfer(s_info.creator(), balance);
        }
        else {
            revert AllOrNothingFeeNotDisbursed();
        }
    }

    function claimRefund(uint256 tokenId) external CurrentTimeIsLess(s_info.getDeadline()) {
        uint256 amount = s_tokenToPledgedAmount[tokenId];
        if (amount == 0)
        require(amount != 0, "AllOrNothing: PreLaunch pledge");
        s_tokenToPledgedAmount[tokenId] = 0;
        burn(tokenId);
        bool success = IERC20(TOKEN).transfer(_msgSender(), amount);
        if (!success) {
            revert AllOrNothingTransferFailed();
        }
    }

    function getplatformId() external view returns (bytes32) {
        return platform;
    }

    function getplatformFeePercent() external view returns (uint256) {
        return platformFeePercent;
    }

    function getplatformFee() external view returns (uint256) {
        return (pledgedAmount * platformFeePercent) / percentDivider;
    }

    function setplatformFeePercent(uint256 _platformFeePercent) external {
        platformFeePercent = _platformFeePercent;
    }

    function currentBalance() public view override returns (uint256) {
        return IERC20(ICampaignInfo(info).token()).balanceOf(address(this));
    }

    // The following functions are overrides required by Solidity.
    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
