// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../Interface/ICampaignTreasury.sol";
import "../Interface/ICampaignInfo.sol";

contract PreOrder is ICampaignTreasury, ERC721Burnable {
    using Counters for Counters.Counter;

    address public immutable registry;
    address public immutable info;
    bytes32 public immutable platform;
    uint256 public immutable minimumPledgeCount;
    uint256 constant percentDivider = 10000;
    uint256 public pledgedAmount;
    uint256 public platformFeePercent;
    uint256 public raisedBalance;
    uint256 public pledgeCount;
    address constant platformAddress = 0x9Aee2Bb8906D3f3B1BB957765eb76a880bc47788;
    address constant protocolAddress = 0x9Aee2Bb8906D3f3B1BB957765eb76a880bc47788;
    mapping(uint256 => uint256) tokenToPledgeAmount;

    event receipt(
        address indexed backer,
        bytes32 indexed reward,
        uint256 pledgeAmount,
        uint256 tokenId
    );

    Counters.Counter private _tokenIdCounter;

    struct Reward {
        uint256 rewardValue;
        bytes32[] itemId;
        uint256[] itemValue;
        uint256[] itemQuantity;
    }
    mapping(bytes32 => Reward) rewards;

    constructor(
        address _registry,
        address _info,
        bytes32 _platform,
        uint256 _minimumPledgeCount
    ) ERC721("CampaignNFT", "CNFT") {
        registry = _registry;
        info = _info;
        platform = _platform;
        minimumPledgeCount = _minimumPledgeCount;
    }

    function getReward(
        bytes32 rewardName
    ) external view returns (Reward memory) {
        return rewards[rewardName];
    }

    function addReward(bytes32 rewardName, Reward calldata reward) external {
        rewards[rewardName] = reward;
    }

    function pledge(address backer, bytes32 rewardName) external {
        uint256 tokenId = _tokenIdCounter.current();
        ICampaignInfo campaign = ICampaignInfo(info);
        address token = campaign.token();
        require(
            block.timestamp <= campaign.deadline(),
            "AllOrNothing: Deadline reached"
        );

        uint256 rewardValue = rewards[rewardName].rewardValue;
        bool success = IERC20(token).transferFrom(
            backer,
            address(this),
            rewardValue
        );
        require(success);
        _tokenIdCounter.increment();
        _safeMint(
            backer,
            tokenId
            // ,
            // abi.encodePacked(backer, " ", reward[0])
        );
        raisedBalance += rewardValue;
        tokenToPledgeAmount[tokenId] = rewardValue;
        pledgeCount++;
        emit receipt(backer, rewardName, rewardValue, tokenId);
    }

    function collect() external {
        ICampaignInfo campaign = ICampaignInfo(info);
        address token = campaign.token();
        require(block.timestamp >= campaign.deadline(), "PreOrder: Deadline not reached");
        require(pledgeCount >= minimumPledgeCount, "PreOrder: Campaign not successful");
        uint256 balance = currentBalance();
        uint256 protocolShare = balance * 200 / percentDivider;
        uint256 platformShare = balance * 300 / percentDivider;
        bool success = IERC20(token).transfer(platformAddress, platformShare);
        require (success);
        success = IERC20(token).transfer(protocolAddress, protocolShare);
        require (success);
        success = IERC20(token).transfer(campaign.creator(), currentBalance());
        require (success);
        
    }

    function claimRefund(uint256 tokenId) external {
        uint256 amount = tokenToPledgeAmount[tokenId];
        address token = ICampaignInfo(info).token();
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
