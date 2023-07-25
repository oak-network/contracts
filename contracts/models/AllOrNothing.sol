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
    uint256 constant percentDivider = 10000;
    uint256 public pledgedAmount;
    uint256 public platformFeePercent;
    uint256 public raisedBalance;
    uint256 public preLaunchPledge = 1 ether;
    mapping (uint256 => uint256) tokenToPledgeAmount;

    event receipt(
        address indexed backer,
        bytes32 indexed reward,
        uint256 pledgeAmount,
        uint256 tokenId,
        bool isPreLaunchPledge
    );

    Counters.Counter private _tokenIdCounter;

    struct Item {
        string description;
    }

    struct Reward {
        uint256 rewardValue;
        string rewardDescription;
        bytes32[] itemId;
        mapping(bytes32 => uint256) itemQuantity;
    }

    address token;
    mapping(bytes32 => Item) items;
    mapping(bytes32 => Reward) rewards;

    constructor(
        address _registry,
        address _info,
        bytes32 _platform
    ) ERC721("CampaignNFT", "CNFT") {
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
        bytes32[] memory itemIds,
        uint256[] memory itemQuantity
    ) external {
        Reward storage reward = rewards[name];
        reward.rewardValue = rewardValue;
        reward.itemId = itemIds;
        uint256 len = itemQuantity.length;
        for (uint256 i = 0; i < len; i++) {
            reward.itemQuantity[itemIds[i]] = itemQuantity[i];
        }
    }

    function pledge(address backer, bytes32 reward, uint256 amount) public {
        uint256 tokenId = _tokenIdCounter.current();
        ICampaignInfo campaign = ICampaignInfo(info);
        uint256 launchTime = campaign.launchTime();
        uint256 deadline = campaign.deadline();
        uint256 pledgeAmount = 0;
        bool isPreLaunchPledge;
        require(block.timestamp <= deadline, "AllOrNothing: Deadline reached");
        if (block.timestamp > launchTime) {
            if (reward != 0x00) {
                uint256 value = rewards[reward].rewardValue;
                require(value != 0);
                IERC20(token).transferFrom(backer, address(this), value);
                pledgeAmount = value;
                _tokenIdCounter.increment();
                _safeMint(
                    backer,
                    tokenId,
                    abi.encodePacked(backer, " ", reward)
                );
                tokenToPledgeAmount[tokenId] = value;
            } else {
                IERC20(token).transferFrom(backer, address(this), amount);
                pledgeAmount = amount;
            }
        } else {
            isPreLaunchPledge = true;
            IERC20(token).transferFrom(backer, address(this), preLaunchPledge);
            _safeMint(
                backer,
                tokenId,
                abi.encodePacked(backer, " PreLaunchPledge")
            );
        }
        emit receipt(backer, reward, pledgeAmount, tokenId, isPreLaunchPledge);
    }

    function collect() public {
        ICampaignInfo campaign = ICampaignInfo(info);
        require(block.timestamp >= campaign.deadline());
        uint256 balance = currentBalance();
        require(balance >= campaign.goal() / campaign.platforms().length);
        IERC20(address(this)).transfer(campaign.creator(), balance);
    }

    function claimRefund(uint256 tokenId) external {
        uint256 amount = tokenToPledgeAmount[tokenId];
        require(ownerOf(tokenId) == msg.sender, "AllOrNothing: Not token owner");
        require(amount !=0, "AllOrNothing: PreLaunch pledge");
        tokenToPledgeAmount[tokenId] = 0;
        _burn(tokenId);
        IERC20(token).transfer(msg.sender, amount);
    }

    // function burn(uint256 tokenId) private override {
    //     _burn(tokenId);
    // }

    // The following functions are overrides required by Solidity.
    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function getplatformId() public view returns (bytes32) {
        return platform;
    }

    function getplatformFeePercent() public view returns (uint256) {
        return platformFeePercent;
    }

    function getplatformFee() public view returns (uint256) {
        return (pledgedAmount * platformFeePercent) / percentDivider;
    }

    function getTotalCollectableByCreator() public view returns (uint256) {
        return pledgedAmount - getplatformFee();
    }

    function getPledgedAmount() public view returns (uint256) {
        return pledgedAmount;
    }

    function pledgeInFiat(uint256 amount) external {
        pledgedAmount += amount;
    }

    function setplatformFeePercent(uint256 _platformFeePercent) external {
        platformFeePercent = _platformFeePercent;
    }

    // function raisedBalance() external view override returns (uint256) {}

    function currentBalance() public view override returns (uint256) {
        return IERC20(ICampaignInfo(info).token()).balanceOf(address(this));
    }
}
