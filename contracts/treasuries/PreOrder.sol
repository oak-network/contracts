// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../interfaces/ICampaignInfo.sol";
import "../utils/BasicTreasury.sol";
import "../utils/TimestampChecker.sol";

contract PreOrder is BasicTreasury, ERC721Burnable, TimestampChecker {
    using Counters for Counters.Counter;

    struct Reward {
        uint256 rewardValue;
        bytes32[] itemId;
        uint256[] itemValue;
        uint256[] itemQuantity;
    }

    uint256 private constant MINIMUM_PREORDER_REQUIRED = 1000;
    uint256 private s_preOrderValueAmount;
    uint256 public s_platformFeePercent;

    mapping(uint256 => uint256) private s_tokenToPledgedAmount;
    mapping(bytes32 => Reward) private s_reward;

    Counters.Counter private s_tokenIdCounter;
    Counters.Counter private s_numberOfPreOrders;

    event Receipt(
        address indexed backer,
        bytes32 indexed reward,
        uint256 pledgeAmount,
        uint256 tokenId
    );

    event RewardAdded(bytes32 indexed rewardName, Reward reward);

    event RewardRemoved(bytes32 indexed rewardName);

    event RefundClaimed(uint256 tokenId, uint256 refundAmount, address claimer);

    error PreOrderTransferFailed();
    error PreOrderInvalidInput();

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
    {}

    function getReward(
        bytes32 rewardName
    ) external view returns (Reward memory) {
        if (s_reward[rewardName].rewardValue == 0) {
            revert PreOrderInvalidInput();
        }
        return s_reward[rewardName];
    }

    function getRaisedAmount() external view returns (uint256) {
        return s_preOrderValueAmount;
    }

    function addReward(bytes32 rewardName, Reward calldata reward) external {
        Reward storage tempReward = s_reward[rewardName];
        if (
            tempReward.rewardValue != 0 &&
            tempReward.itemId.length > 0 &&
            tempReward.itemId.length == tempReward.itemValue.length &&
            tempReward.itemId.length == tempReward.itemQuantity.length
        ) {
            s_reward[rewardName] = reward;
            emit RewardAdded(rewardName, tempReward);
        } else {
            revert PreOrderInvalidInput();
        }
    }

    function removeReward(bytes32 rewardName) external {
        uint256 tempRewardValue = s_reward[rewardName].rewardValue;
        if (tempRewardValue == 0) {
            revert PreOrderInvalidInput();
        }
        delete s_reward[rewardName];
        emit RewardRemoved(rewardName);
    }

    function PreOrderForAReward(
        address backer,
        bytes32 rewardName
    )
        external
        currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
    {
        uint256 tokenId = s_tokenIdCounter.current();
        uint256 rewardValue = s_reward[rewardName].rewardValue;
        bool success = TOKEN.transferFrom(backer, address(this), rewardValue);
        if (!success) {
            revert PreOrderTransferFailed();
        }
        s_tokenIdCounter.increment();
        _safeMint(backer, tokenId, abi.encodePacked(backer, " ", rewardName));
        s_preOrderValueAmount += rewardValue;
        s_tokenToPledgedAmount[tokenId] = rewardValue;
        s_numberOfPreOrders.increment();
        emit Receipt(backer, rewardName, rewardValue, tokenId);
    }

    function claimRefund(uint256 tokenId) external {
        uint256 amount = s_tokenToPledgedAmount[tokenId];
        s_tokenToPledgedAmount[tokenId] = 0;
        burn(tokenId);
        bool success = TOKEN.transfer(msg.sender, amount);
        emit RefundClaimed(tokenId, amount, msg.sender);
        if (!success) {
            revert PreOrderTransferFailed();
        }
    }

    function _checkSuccessCondition() internal view override returns (bool) {
        return (s_numberOfPreOrders.current() > MINIMUM_PREORDER_REQUIRED);
    }

    // The following functions are overrides required by Solidity.
    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
