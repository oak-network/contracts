// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../Interface/ICampaignTreasury.sol";

contract AllOrNothing is ICampaignTreasury, ERC721 {

    address public immutable registry;
    address public immutable infoAddress;
    bytes32 public immutable platformId;
    uint256 constant percentDivider = 10000;
    uint256 public pledgedAmount;
    uint256 public platformFeePercent;
    uint256 public balanceSinceEpoch;
    uint256 public raisedBalance;

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
    mapping (bytes32 => Reward) rewards;

    constructor(
        address _registryAddress,
        address _infoAddress,
        bytes32 _platformId
    ) {
        registry = _registryAddress;
        infoAddress = _infoAddress;
        platformId = _platformId;
    }

    function pledgeForAReward(
        bytes32 platformId,
        address backer,
        string calldata rewardName
    ) public {
        uint256 amount = rewards[rewardName].rewardValue;
        IERC20(token).transferFrom(backer, address(this), amount);
        tokenId = ICampaignNFT(ICampaignRegistry(registryAddress).getCampaignNFTAddress())
            .safeMint(
                backer,
                token,
                amount + earlyPledgeAmount,
                platformId,
                rewardName
            );
    }}