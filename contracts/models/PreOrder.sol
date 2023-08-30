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

    uint256 private constant MINIMUM_NO_OF_ORDER_REQUIRED = 1000;
    uint256 private s_orderValueAmount;
    uint256 public s_platformFeePercent;

    mapping(uint256 => uint256) private s_tokenToPledgedAmount;

    Counters.Counter private s_tokenIdCounter;
    Counters.Counter private s_numberOfOrders;

    mapping(bytes32 => Reward) rewards;

    event receipt(
        address indexed backer,
        bytes32 indexed reward,
        uint256 pledgeAmount,
        uint256 tokenId
    );

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
        uint256 tokenId = s_tokenIdCounter.current();
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
        s_tokenIdCounter.increment();
        _safeMint(
            backer,
            tokenId
            // ,
            // abi.encodePacked(backer, " ", reward[0])
        );
        raisedBalance += rewardValue;
        tokenToPledgeAmount[tokenId] = rewardValue;
        noOfPledges.increment();
        emit receipt(backer, rewardName, rewardValue, tokenId);
    }

    function claimRefund(uint256 tokenId) external {
        uint256 amount = tokenToPledgeAmount[tokenId];
        address token = ICampaignInfo(info).token();
        tokenToPledgeAmount[tokenId] = 0;
        burn(tokenId);
        bool success = IERC20(token).transfer(_msgSender(), amount);
        require(success);
    }

    function _checkSuccessCondition() internal view override returns (bool) {
        return (s_numberOfOrders > MINIMUM_NO_OF_ORDER_REQUIRED);
    } 

    // The following functions are overrides required by Solidity.
    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
