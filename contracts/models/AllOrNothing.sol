// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../Interface/ICampaignTreasury.sol";
import "../Interface/ICampaignInfo.sol";

contract AllOrNothing is ICampaignTreasury, ERC721Burnable {
    using Counters for Counters.Counter;

    address public immutable registry;
    address public immutable info;
    bytes32 public immutable platform;
    uint256 constant percentDivider = 10000; // @audit-issue unused `percentDivider` variable
    uint256 public pledgedAmount; // @audit-issue `pledgedAmount` never initialized
    uint256 public platformFeePercent;
    uint256 public raisedBalance;
    uint256 public preLaunchPledge = 1 ether; //@audit-info Is the `preLaunchPledge` value always same? It can be used as a constant variable for gas optimization
    mapping(uint256 => uint256) tokenToPledgeAmount;

    event receipt(
        address indexed backer,
        bytes32 indexed reward,
        uint256 pledgeAmount,
        uint256 tokenId,
        bool isPreLaunchPledge,
        bytes32[] rewards
    );

    Counters.Counter private _tokenIdCounter;

    struct Item {
        string description; //@audit-info if `description` can be at most 32-bytes long use bytes32 instead for gas optimization
    }

    struct Reward {
        uint256 rewardValue;
        bool isRewardTier;
        string rewardDescription;
        bytes32[] itemId;
        mapping(bytes32 => uint256) itemQuantity; //@audit-info why `itemQuantity` is a mapping not an array?
    }

    // address token;
    mapping(bytes32 => Item) items;
    mapping(bytes32 => Reward) rewards;

    constructor(
        address _registry,
        address _info,
        bytes32 _platform
    ) ERC721("CampaignNFT", "CNFT") {
        //@audit-issue lacks zero address validation check
        registry = _registry;
        info = _info;
        platform = _platform;
    }

    function addItem(bytes32 item, string calldata description) external {
        items[item].description = description;
    }

    function addReward(
        bytes32 name,
        uint256 rewardValue,
        bool isRewardTier,
        bytes32[] memory itemIds,
        uint256[] memory itemQuantity
    ) external {
        //@audit-issue lacks `itemIds` and `itemQuantity` length check

        Reward storage reward = rewards[name]; //@audit-issue shadow local variable. Already ERC721 has `name` variable. Please use different name.
        reward.rewardValue = rewardValue;
        reward.isRewardTier = isRewardTier;
        reward.itemId = itemIds;
        uint256 len = itemQuantity.length;
        for (uint256 i = 0; i < len; i++) { //@audit-issue this for loop can be avoided
            reward.itemQuantity[itemIds[i]] = itemQuantity[i];
        }
    }

    // @audit Reentrancy Guard issue
    function pledge(
        address backer,
        bytes32[] calldata reward,
        uint256 amount
    ) external {
        // @audit-issue lacks parameter filtering like zero address checking, amount checking
        uint256 tokenId = _tokenIdCounter.current();
        ICampaignInfo campaign = ICampaignInfo(info);
        address token = campaign.token();
        uint256 pledgeAmount = 0;
        bool isPreLaunchPledge;
        bool success;
        require(block.timestamp <= campaign.deadline(), "AllOrNothing: Deadline reached");
        if (block.timestamp > campaign.launchTime()) {
            if (reward[0] != 0x00) {
                // uint256 value = rewards[reward[0]].rewardValue;
                bool isRewardTier = rewards[reward[0]].isRewardTier;
                require(isRewardTier == true); // @audit-issue Remove the boolean equality check and add an Error message e.g. require(isRewardTier, "Message")
                uint256 rewardLen = reward.length;
                uint256 totalValue;
                for (uint256 i = 0; i < rewardLen; i++) {
                    totalValue += rewards[reward[i]].rewardValue;
                }
                pledgeAmount = totalValue;
                _tokenIdCounter.increment();
                tokenToPledgeAmount[tokenId] = totalValue;
                success = IERC20(token).transferFrom(backer, address(this), totalValue);
                require(success);
                _safeMint(
                    backer,
                    tokenId
                    // ,
                    // abi.encodePacked(backer, " ", reward[0])
                );
            } else {
                pledgeAmount = amount;
                success = IERC20(token).transferFrom(backer, address(this), amount);
                require(success);
            }
        } else {
            isPreLaunchPledge = true;
            pledgeAmount = preLaunchPledge;
            _tokenIdCounter.increment();
            success = IERC20(token).transferFrom(backer, address(this), preLaunchPledge);
            require(success);
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
        require(block.timestamp >= campaign.deadline());//@audit-info Add an Error Message
        uint256 balance = currentBalance();
        require(balance >= campaign.goal() / campaign.platforms().length); //@audit-info Add an Error Message
        IERC20(campaign.token()).transfer(campaign.creator(), balance);
    }

    function claimRefund(uint256 tokenId) external {
        uint256 amount = tokenToPledgeAmount[tokenId];
        address token = ICampaignInfo(info).token();
        require(amount != 0, "AllOrNothing: PreLaunch pledge"); // @audit-issue use `>` symbol for Gas Optimization
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
