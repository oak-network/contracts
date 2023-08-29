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

    uint256 private s_totalPledgedAmount;
    uint256 private s_pledgedAmountInCrypto;
    uint256 private s_pledgedAmountInFiat;

    mapping(uint256 => uint256) private s_tokenToPledgedAmount;
    mapping(bytes32 => Reward) private s_reward;
    mapping(bytes32 => uint256) private s_fiatPledge;

    Counters.Counter private s_tokenIdCounter;
    Counters.Counter private s_rewardCounter;

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
    error AllOrNothingTransferFromFailed();

    constructor(address info) ERC721("Xstarter", "XNFT") {
        CAMPAIGN_INFO = info;
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

    function pledgeForAReward(
        address backer,
        bytes32[] calldata reward
    )
        external
        currentTimeIsWithinRange(
            ICampaignInfo(CAMPAIGN_INFO).getLaunchTime(),
            ICampaignInfo(CAMPAIGN_INFO).getDeadline
        )
    {
        uint256 tokenId = s_tokenIdCounter.current();
        ICampaignInfo campaign = ICampaignInfo(CAMPAIGN_INFO);
        address token = campaign.getTokenAddress();
        bool success;
        uint256 rewardLen = reward.length;
        s_reward storage tempReward;
        if (
            backer == address(0) ||
            rewardLen != s_rewardCounter.current() ||
            reward[0] == 0x00 ||
            tempReward[reward[0]].isRewardTier
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
            _safeMint(backer, tokenId);
            s_tokenIdCounter[tokenId] = pledgeAmount;
        } else {
            revert AllOrNothingTransferFromFailed();
        }
    }
    
    function collect() external {
        ICampaignInfo campaign = ICampaignInfo(info);
        require(block.timestamp >= campaign.deadline());
        uint256 balance = currentBalance();
        require(balance >= campaign.goal() / campaign.platforms().length);
        IERC20(campaign.token()).transfer(campaign.creator(), balance);
    }

    function claimRefund(uint256 tokenId) external {
        uint256 amount = tokenToPledgeAmount[tokenId];
        address token = ICampaignInfo(info).token();
        require(amount != 0, "AllOrNothing: PreLaunch pledge");
        tokenToPledgeAmount[tokenId] = 0;
        burn(tokenId);
        bool success = IERC20(token).transfer(_msgSender(), amount);
        require(success);
    }

    // The following functions are overrides required by Solidity.
    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
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
}
