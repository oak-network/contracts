// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../interfaces/ICampaignInfo.sol";
import "../interfaces/ICampaignTreasury.sol";
import "./CampaignAccessChecker.sol";
import "./PausableWithMsg.sol";
import "./PledgeManager.sol";

/**
 * @title BaseTreasury
 * @notice A base contract for creating and managing treasuries in crowdfunding campaigns.
 * @dev This contract defines common functionality and storage for campaign treasuries.
 * @dev Contracts implementing this base contract should provide specific success conditions.
 */
abstract contract BaseTreasury is
    ICampaignTreasury,
    CampaignAccessChecker,
    PausableWithMsg,
    PledgeManager
{
    bytes32 internal constant ZERO_BYTES =
        0x0000000000000000000000000000000000000000000000000000000000000000;
    uint256 internal constant PERCENT_DIVIDER = 10000;

    bytes32 internal immutable PLATFORM_BYTES;
    uint256 internal immutable PLATFORM_FEE_PERCENT;
    IERC20 internal immutable TOKEN;
    ICampaignInfo internal immutable CAMPAIGN_INFO;

    uint256 internal s_cryptoFeeDisbursed;

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
    event WithdrawalSuccessful(address indexed to, uint256 amount);

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

    /**
     * @dev Constructs a new BaseTreasury instance.
     * @param platformBytes The identifier for the platform associated with this treasury.
     * @param infoAddress The address of the CampaignInfo contract.
     */
    constructor(
        bytes32 platformBytes,
        address infoAddress
    ) CampaignAccessChecker(infoAddress) {
        PLATFORM_BYTES = platformBytes;
        CAMPAIGN_INFO = ICampaignInfo(infoAddress);
        TOKEN = IERC20(INFO.getTokenAddress());
        PLATFORM_FEE_PERCENT = INFO.getPlatformFeePercent(platformBytes);
    }

    /**
     * @dev Modifier that checks if the campaign is not paused.
     */
    modifier whenCampaignNotPaused() {
        _checkIfCampaignPaused();
        _;
    }

    /**
     * @inheritdoc ICampaignTreasury
     */
    function getplatformBytes() external view override returns (bytes32) {
        return PLATFORM_BYTES;
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
    function disburseFees() public virtual override whenCampaignNotPaused {
        if (!_checkSuccessCondition()) {
            revert TreasurySuccessConditionNotFulfilled();
        }
        uint256 balance = totalPledged; // Use totalPledged from PledgeManager
        uint256 protocolShare = (balance * INFO.getProtocolFeePercent()) /
            PERCENT_DIVIDER;
        uint256 platformShare = (balance *
            INFO.getPlatformFeePercent(PLATFORM_BYTES)) / PERCENT_DIVIDER;

        totalPledged -= (protocolShare + platformShare); // Adjust totalPledged

        s_cryptoFeeDisbursed = true;
        emit FeesDisbursed(protocolShare, platformShare);
    }

    /**
     * @inheritdoc ICampaignTreasury
     */
    function withdraw() public virtual override whenCampaignNotPaused {
        if (!s_cryptoFeeDisbursed) {
            revert TreasuryFeeNotDisbursed();
        }
        uint256 balance = totalPledged; // Use totalPledged from PledgeManager
        totalPledged = 0; // Reset totalPledged after withdrawal
        emit WithdrawalSuccessful(INFO.owner(), balance);
    }

    /**
     * @dev External function to pause the campaign.
     */
    function _pauseTreasury(
        bytes32 message
    ) external onlyPlatformAdmin(PLATFORM_BYTES) {
        _pause(message);
    }

    /**
     * @dev External function to unpause the campaign.
     */
    function _unpauseTreasury(
        bytes32 message
    ) external onlyPlatformAdmin(PLATFORM_BYTES) {
        _unpause(message);
    }

    /**
     * @dev Internal function to check if the campaign is paused.
     * If the campaign is paused, it reverts with TreasuryCampaignInfoIsPaused error.
     */
    function _checkIfCampaignPaused() internal view {
        if (INFO.paused()) {
            revert TreasuryCampaignInfoIsPaused();
        }
    }

    /**
     * @dev Internal function to check the success condition for fee disbursement.
     * @return Whether the success condition is met.
     */
    function _checkSuccessCondition() internal view virtual returns (bool);
}
