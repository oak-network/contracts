// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
    bytes32 private constant ZERO_BYTES =
        0x0000000000000000000000000000000000000000000000000000000000000000;
    uint256 private constant PERCENT_DIVIDER = 10000;
    uint256 private constant PRELAUNCH_PLEDGE = 1 ether;
    uint256 private constant PLATFORM_FEE_PERCENT = 300;

    ICampaignInfo private immutable INFO;
    IERC20 private immutable TOKEN;

    uint256 private s_pledgedAmountInCrypto;
    uint256 private s_pledgedAmountInFiat;

    bool private s_cryptoFeeDisbursed;
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

    constructor(address info) ERC721("Xstarter", "XNFT") {
        INFO = ICampaignInfo(info);
        TOKEN = IERC20(INFO.getTokenAddress());

        s_tokenIdCounter.increment();
    }

    modifier onlyPlatformAdmin() {
        _checkIfPlatformAdmin();
        _;
    }

    function _checkIfPlatformAdmin() internal view {
        if (msg.sender != INFO.getPlatformAdminAddress(PLATFORM_BYTES)) {
            revert AllOrNothingUnAuthorized();
        }
    }

    function addReward(bytes32 rewardName, Reward calldata reward) external {
        s_reward[rewardName] = reward;
    }

    function getplatformBytes() external pure override returns (bytes32) {
        return PLATFORM_BYTES;
    }

    function getplatformFeePercent() external pure override returns (uint256) {
        return PLATFORM_FEE_PERCENT;
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
            0x00,
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
            if (reward[i] == 0x00) {
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
    ) external {
        bool success = TOKEN.transferFrom(backer, address(this), pledgeAmount);
        if (success) {
            s_pledgedAmountInCrypto += pledgeAmount;
            bytes32[] memory emptyByteArray = new bytes32[](0);
            emit receipt(backer, 0x00, pledgeAmount, 0, false, emptyByteArray);
        } else {
            revert AllOrNothingTransferFailed();
        }
    }

    function disburseFees() external currentTimeIsGreater(INFO.getDeadline()) {
        uint256 balance = s_pledgedAmountInCrypto;
        if (INFO.getTotalRaisedAmount() > INFO.getGoalAmount()) {
            uint256 protocolShare = (balance * INFO.getProtocolFeePercent()) /
                PERCENT_DIVIDER;
            uint256 platformShare = (balance * PLATFORM_FEE_PERCENT) /
                PERCENT_DIVIDER;
            bool success = TOKEN.transfer(
                INFO.getProtocolAdminAddress(),
                protocolShare
            );
            if (!success) {
                revert AllOrNothingTransferFailed();
            }
            success = TOKEN.transfer(
                INFO.getPlatformAdminAddress(PLATFORM_BYTES),
                platformShare
            );
            if (!success) {
                revert AllOrNothingTransferFailed();
            }
            s_cryptoFeeDisbursed = true;
        } else {
            revert AllOrNothingNotSuccessful();
        }
    }

    function withdrawCrptoPledgedAmount() external {
        if (s_cryptoFeeDisbursed) {
            uint256 balance = TOKEN.balanceOf(address(this));
            bool success = TOKEN.transfer(INFO.owner(), balance);
            if (!success) revert AllOrNothingTransferFailed();
        } else {
            revert AllOrNothingFeeNotDisbursed();
        }
    }

    function claimRefund(
        uint256 tokenId
    )
        external
        currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
    {
        uint256 amount = s_tokenToPledgedAmount[tokenId];
        if (amount == 0) require(amount != 0, "AllOrNothing: PreLaunch pledge");
        s_tokenToPledgedAmount[tokenId] = 0;
        burn(tokenId);
        bool success = TOKEN.transfer(_msgSender(), amount);
        if (!success) {
            revert AllOrNothingTransferFailed();
        }
    }

    // The following functions are overrides required by Solidity.
    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
