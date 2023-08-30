// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../utils/TimestampChecker.sol";
import "../utils/BasicTreasury.sol";

contract AllOrNothing is BasicTreasury, ERC721Burnable, TimestampChecker {
    using Counters for Counters.Counter;

    struct Reward {
        uint256 rewardValue;
        bool isRewardTier;
        bytes32[] itemId;
        uint256[] itemValue;
        uint256[] itemQuantity;
    }

    uint256 private constant PRELAUNCH_PLEDGE = 1 ether;

    uint256 private s_pledgedAmountInFiat;
    bool private s_fiatFeeDisbursed;

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

    function addReward(bytes32 rewardName, Reward calldata reward) external {
        s_reward[rewardName] = reward;
    }

    function getRaisedAmount() external view override returns (uint256) {
        return s_pledgedAmountInFiat + s_pledgedAmountInCrypto;
    }

    function updateFiatPledge(
        bytes32 fiatPledgeId,
        uint256 fiatPledgeAmount
    ) external onlyPlatformAdmin {
        s_fiatPledge[fiatPledgeId] = fiatPledgeAmount;
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
        emit receipt(
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
    )
        external
        currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
    {
        bool success = TOKEN.transferFrom(backer, address(this), pledgeAmount);
        if (success) {
            s_pledgedAmountInCrypto += pledgeAmount;
            bytes32[] memory emptyByteArray = new bytes32[](0);
            emit receipt(backer, ZERO_BYTES, pledgeAmount, 0, false, emptyByteArray);
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
    function _checkSuccessCondition() internal view override returns (bool) {
        return INFO.getTotalRaisedAmount() > INFO.getGoalAmount();
    }

    // The following functions are overrides required by Solidity.
    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
