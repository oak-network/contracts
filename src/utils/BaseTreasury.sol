// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "../interfaces/ICampaignInfo.sol";
import "../interfaces/ICampaignTreasury.sol";
import "./CampaignAccessChecker.sol";
import "./PausableCancellable.sol";
import "forge-std/console.sol";

/**
 * @title BaseTreasury
 * @notice A base contract for creating and managing treasuries in crowdfunding campaigns.
 * @dev This contract defines common functionality and storage for campaign treasuries.
 * @dev Contracts implementing this base contract should provide specific success conditions.
 */
abstract contract BaseTreasury is
    Initializable,
    ICampaignTreasury,
    CampaignAccessChecker,
    PausableCancellable
{
    using SafeERC20 for IERC20;
    bytes32 internal constant ZERO_BYTES =
        0x0000000000000000000000000000000000000000000000000000000000000000;
    uint256 internal constant PERCENT_DIVIDER = 10000;

    bytes32 internal PLATFORM_HASH;
    uint256 internal PLATFORM_FEE_PERCENT;
    IERC20 internal TOKEN;
    ICampaignInfo internal CAMPAIGN_INFO;

    uint256 internal s_pledgedAmount;
    bool internal s_feesDisbursed;

    /**
     * @notice Emitted when fees are successfully disbursed.
     * @param protocolShare The amount of fees sent to the protocol.
     * @param platformShare The amount of fees sent to the platform.
     */
    event FeesDisbursed(uint256 protocolShare, uint256 platformShare);

    /**
     * @notice Emitted when a withdrawal is successful.
     * @param to The recipient of the withdrawal.
     * @param amount The amount withdrawn.
     */
    event WithdrawalSuccessful(address to, uint256 amount);

    /**
     * @notice Emitted when the success condition is not fulfilled during fee disbursement.
     */
    event SuccessConditionNotFulfilled();

    /**
     * @dev Throws an error indicating a failed treasury transfer.
     */
    error TreasuryTransferFailed();

    /**
     * @dev Throws an error indicating that the success condition was not fulfilled.
     */
    error TreasurySuccessConditionNotFulfilled();

    /**
     * @dev Throws an error indicating that fees have not been disbursed.
     */
    error TreasuryFeeNotDisbursed();

    /**
     * @dev Throws an error indicating that the campaign is paused.
     */
    error TreasuryCampaignInfoIsPaused();

    function __BaseContract_init(
        bytes32 platformHash,
        address infoAddress
    ) internal {
        __CampaignAccessChecker_init(infoAddress);
        PLATFORM_HASH = platformHash;
        CAMPAIGN_INFO = ICampaignInfo(infoAddress);
        TOKEN = IERC20(INFO.getTokenAddress());
        PLATFORM_FEE_PERCENT = INFO.getPlatformFeePercent(platformHash);
    }

    /**
     * @dev Modifier that checks if the campaign is not paused.
     */
    modifier whenCampaignNotPaused() {
        _revertIfCampaignPaused();
        _;
    }

    modifier whenCampaignNotCancelled() {
        _revertIfCampaignCancelled();
        _;
    }

    /**
     * @inheritdoc ICampaignTreasury
     */
    function getplatformHash() external view override returns (bytes32) {
        return PLATFORM_HASH;
    }

    /**
     * @inheritdoc ICampaignTreasury
     */
    function getplatformFeePercent() external view override returns (uint256) {
        return PLATFORM_FEE_PERCENT;
    }

    /**
     * @inheritdoc ICampaignTreasury
     */
    function disburseFees()
        public
        virtual
        override
        whenCampaignNotPaused
        whenCampaignNotCancelled
    {
        if (!_checkSuccessCondition()) {
            revert TreasurySuccessConditionNotFulfilled();
        }
        uint256 balance = s_pledgedAmount;
        uint256 protocolShare = (balance * INFO.getProtocolFeePercent()) /
            PERCENT_DIVIDER;
        uint256 platformShare = (balance *
            INFO.getPlatformFeePercent(PLATFORM_HASH)) / PERCENT_DIVIDER;
        TOKEN.safeTransfer(INFO.getProtocolAdminAddress(), protocolShare);

        TOKEN.safeTransfer(
            INFO.getPlatformAdminAddress(PLATFORM_HASH),
            platformShare
        );

        s_feesDisbursed = true;
        emit FeesDisbursed(protocolShare, platformShare);
    }

    /**
     * @inheritdoc ICampaignTreasury
     */
    function withdraw()
        public
        virtual
        override
        whenCampaignNotPaused
        whenCampaignNotCancelled
    {
        if (!s_feesDisbursed) {
            revert TreasuryFeeNotDisbursed();
        }
        uint256 balance = TOKEN.balanceOf(address(this));
        address recipient = INFO.owner();
        TOKEN.safeTransfer(recipient, balance);

        emit WithdrawalSuccessful(recipient, balance);
    }

    /**
     * @dev External function to pause the campaign.
     */
    function pauseTreasury(
        bytes32 message
    ) public virtual onlyPlatformAdmin(PLATFORM_HASH) {
        _pause(message);
    }

    /**
     * @dev External function to unpause the campaign.
     */
    function unpauseTreasury(
        bytes32 message
    ) public virtual onlyPlatformAdmin(PLATFORM_HASH) {
        _unpause(message);
    }

    /**
     * @dev External function to cancel the campaign.
     */
    function cancelTreasury(
        bytes32 message
    ) public virtual onlyPlatformAdmin(PLATFORM_HASH) {
        _cancel(message);
    }

    /**
     * @dev Internal function to check if the campaign is paused.
     * If the campaign is paused, it reverts with TreasuryCampaignInfoIsPaused error.
     */
    function _revertIfCampaignPaused() internal view {
        if (INFO.paused()) {
            revert TreasuryCampaignInfoIsPaused();
        }
    }

    function _revertIfCampaignCancelled() internal view {
        if (INFO.cancelled()) {
            revert TreasuryCampaignInfoIsPaused();
        }
    }

    /**
     * @dev Internal function to check the success condition for fee disbursement.
     * @return Whether the success condition is met.
     */
    function _checkSuccessCondition() internal view virtual returns (bool);
}
