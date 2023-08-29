// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../Interface/ICampaignTreasury.sol";
import "../Interface/ICampaignInfo.sol";

contract AllOrNothing is ICampaignTreasury, ERC721Burnable {
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

    event receipt(
        address indexed backer,
        bytes32 indexed reward,
        uint256 pledgeAmount,
        uint256 tokenId,
        bool isPreLaunchPledge,
        bytes32[] rewards
    );

    error AllOrNothingUnAuthorized();

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

    function pledge(
        address backer,
        uint256 amount,
        bytes32[] calldata reward
    ) external {
        uint256 tokenId = _tokenIdCounter.current();
        ICampaignInfo campaign = ICampaignInfo(info);
        address token = campaign.token();
        uint256 pledgeAmount = 0;
        bool isPreLaunchPledge;
        bool success;
        require(
            block.timestamp <= campaign.deadline(),
            "AllOrNothing: Deadline reached"
        );
        if (block.timestamp > campaign.launchTime()) {
            if (reward[0] != 0x00) {
                // uint256 value = rewards[reward[0]].rewardValue;
                bool isRewardTier = rewards[reward[0]].isRewardTier;
                require(isRewardTier == true);
                uint256 rewardLen = reward.length;
                uint256 totalValue;
                for (uint256 i = 0; i < rewardLen; i++) {
                    totalValue += rewards[reward[i]].rewardValue;
                }
                success = IERC20(token).transferFrom(
                    backer,
                    address(this),
                    totalValue
                );
                require(success);
                pledgeAmount = totalValue;
                _tokenIdCounter.increment();
                _safeMint(
                    backer,
                    tokenId
                    // ,
                    // abi.encodePacked(backer, " ", reward[0])
                );
                tokenToPledgeAmount[tokenId] = totalValue;
            } else {
                success = IERC20(token).transferFrom(
                    backer,
                    address(this),
                    amount
                );
                require(success);
                pledgeAmount = amount;
            }
        } else {
            isPreLaunchPledge = true;
            success = IERC20(token).transferFrom(
                backer,
                address(this),
                preLaunchPledge
            );
            require(success);
            pledgeAmount = preLaunchPledge;
            _tokenIdCounter.increment();
            _safeMint(
                backer,
                tokenId
                // ,
                // abi.encodePacked(backer, " PreLaunchPledge")
            );
        }
        raisedBalance += pledgeAmount;
        emit receipt(
            backer,
            reward[0],
            pledgeAmount,
            tokenId,
            isPreLaunchPledge,
            reward
        );
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
