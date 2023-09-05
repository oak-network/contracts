// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/ICampaignInfo.sol";
import "./interfaces/ICampaignData.sol";
import "./interfaces/ICampaignTreasury.sol";
import "./interfaces/IGlobalParams.sol";
import "./utils/TimestampChecker.sol";
import "./utils/AdminAccessChecker.sol";

/**
 * @title CampaignInfo
 * @notice Manages campaign information and platform data.
 */
contract CampaignInfo is
    ICampaignData,
    ICampaignInfo,
    Ownable,
    Pausable,
    TimestampChecker,
    AdminAccessChecker
{
    address private immutable TREASURY_FACTORY;
    address private immutable TOKEN;
    uint256 private immutable PROTOCOL_FEE_PERCENT;
    bytes32 private immutable IDENTIFIER_HASH;

    CampaignData private s_campaignData;

    mapping(bytes32 => bool) private s_selectedPlatformBytes;
    mapping(bytes32 => address) private s_platformTreasuryAddress;
    mapping(bytes32 => uint256) private s_platformFeePercent;
    mapping(bytes32 => bytes32) private s_platformData;

    bytes32[] private s_approvedPlatformBytes;

    /**
     * @dev Emitted when a platform is selected for the campaign.
     * @param platformBytes The bytes32 identifier of the platform.
     * @param platformTreasury The address of the platform's treasury.
     */
    event CampaignInfoPlatformSelected(
        bytes32 indexed platformBytes,
        address indexed platformTreasury
    );

    /**
     * @dev Emitted when the launch time of the campaign is updated.
     * @param newLaunchTime The new launch time.
     */
    event CampaignInfoLaunchTimeUpdated(uint256 newLaunchTime);

    /**
     * @dev Emitted when the deadline of the campaign is updated.
     * @param newDeadline The new deadline.
     */
    event CampaignInfoDeadlineUpdated(uint256 newDeadline);

    /**
     * @dev Emitted when the goal amount of the campaign is updated.
     * @param newGoalAmount The new goal amount.
     */
    event CampaignInfoGoalAmountUpdated(uint256 newGoalAmount);

    /**
     * @dev Emitted when the selection state of a platform is updated.
     * @param platformBytes The bytes32 identifier of the platform.
     * @param selection The new selection state.
     */
    event CampaignInfoSelectedPlatformUpdated(
        bytes32 indexed platformBytes,
        bool selection
    );

    /**
     * @dev Emitted when platform information is updated for the campaign.
     * @param platformBytes The bytes32 identifier of the platform.
     * @param platformTreasury The address of the platform's treasury.
     */
    event CampaignInfoPlatformInfoUpdated(
        bytes32 indexed platformBytes,
        address indexed platformTreasury
    );

    /**
     * @dev Emitted when ownership of the contract is transferred.
     * @param previousOwner The address of the previous owner.
     * @param newOwner The address of the new owner.
     */
    event CampaignInfoOwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Emitted when an invalid platform update is attempted.
     * @param platformBytes The bytes32 identifier of the platform.
     * @param selection The selection state (true/false).
     */
    error CampaignInfoInvalidPlatformUpdate(
        bytes32 platformBytes,
        bool selection
    );

    /**
     * @dev Emitted when an unauthorized action is attempted.
     */
    error CampaignInfoUnauthorized();

    /**
     * @dev Emitted when an invalid input is detected.
     */
    error CampaignInfoInvalidInput();

    /**
     * @dev Emitted when a platform is not selected for the campaign.
     * @param platformBytes The bytes32 identifier of the platform.
     */
    error CampaignInfoPlatformNotSelected(bytes32 platformBytes);

    /**
     * @param globalParams The address of the global parameters contract.
     * @param treasuryFactory The address of the treasury factory contract.
     * @param token The address of the campaign token contract.
     * @param creator The address of the campaign creator.
     * @param protocolFeePercent The protocol fee percentage.
     * @param identifierHash The hash identifier for the campaign.
     * @param selectedPlatformBytes The list of selected platform identifiers.
     * @param platformDataKey The list of platform data keys.
     * @param platformDataValue The list of platform data values.
     * @param campaignData The initial campaign data.
     */
    constructor(
        IGlobalParams globalParams,
        address treasuryFactory,
        address token,
        address creator,
        uint256 protocolFeePercent,
        bytes32 identifierHash,
        bytes32[] memory selectedPlatformBytes,
        bytes32[] memory platformDataKey,
        bytes32[] memory platformDataValue,
        CampaignData memory campaignData
    ) AdminAccessChecker(globalParams) {
        TREASURY_FACTORY = treasuryFactory;
        TOKEN = token;
        IDENTIFIER_HASH = identifierHash;
        PROTOCOL_FEE_PERCENT = protocolFeePercent;
        s_campaignData = campaignData;

        uint256 len = selectedPlatformBytes.length;
        unchecked {
            for (uint256 i = 0; i < len; ++i) {
                s_platformFeePercent[selectedPlatformBytes[i]] = GLOBAL_PARAMS
                    .getPlatformFeePercent(selectedPlatformBytes[i]);
            }
            len = platformDataKey.length;
            bool isValid;
            for (uint256 i = 0; i < len; ++i) {
                isValid = GLOBAL_PARAMS.checkIfPlatformDataKeyValid(
                    platformDataKey[i]
                );
                if (!isValid) {
                    revert CampaignInfoInvalidInput();
                }
                s_platformData[platformDataKey[i]] = platformDataValue[i];
            }
        }

        transferOwnership(creator);
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function checkIfPlatformSelected(
        bytes32 platformBytes
    ) public view override returns (bool) {
        return s_selectedPlatformBytes[platformBytes];
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function owner()
        public
        view
        override(ICampaignInfo, Ownable)
        returns (address account)
    {
        account = super.owner();
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function getTotalRaisedAmount() external view override returns (uint256) {
        bytes32[] memory tempPlatforms = s_approvedPlatformBytes;
        uint256 length = s_approvedPlatformBytes.length;
        uint256 amount;
        address tempTreasury;
        for (uint256 i = 0; i < length; i++) {
            tempTreasury = s_platformTreasuryAddress[tempPlatforms[i]];
            amount += ICampaignTreasury(tempTreasury).getRaisedAmount();
        }
        return amount;
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function getProtocolAdminAddress()
        external
        view
        override
        returns (address)
    {
        return GLOBAL_PARAMS.getProtocolAdminAddress();
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function getPlatformAdminAddress(
        bytes32 platformBytes
    ) external view override returns (address) {
        return GLOBAL_PARAMS.getPlatformAdminAddress(platformBytes);
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function getLaunchTime() external view override returns (uint256) {
        return s_campaignData.launchTime;
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function getDeadline() external view override returns (uint256) {
        return s_campaignData.deadline;
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function getGoalAmount() external view override returns (uint256) {
        return s_campaignData.goalAmount;
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function getTokenAddress() external view override returns (address) {
        return TOKEN;
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function getProtocolFeePercent() external view override returns (uint256) {
        return PROTOCOL_FEE_PERCENT;
    }

    function paused() public view override(ICampaignInfo, Pausable) returns (bool) {
        return super.paused();
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function getPlatformFeePercent(
        bytes32 platformBytes
    ) external view override returns (uint256) {
        return s_platformFeePercent[platformBytes];
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function getPlatformData(
        bytes32 platformDataKey
    ) external view override returns (bytes32) {
        bytes32 platformDataValue = s_platformData[platformDataKey];
        if (platformDataValue == bytes32(0)) {
            revert CampaignInfoInvalidInput();
        }
        return platformDataValue;
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function getIdentifierHash() external view override returns (bytes32) {
        return IDENTIFIER_HASH;
    }

    /**
     * @inheritdoc Ownable
     */
    function transferOwnership(
        address newOwner
    ) public override(ICampaignInfo, Ownable) onlyOwner whenNotPaused {
        super.transferOwnership(newOwner);
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function updateLaunchTime(
        uint256 launchTime
    ) external override onlyOwner currentTimeIsLess(launchTime) whenNotPaused {
        s_campaignData.launchTime = launchTime;
        emit CampaignInfoLaunchTimeUpdated(launchTime);
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function updateDeadline(
        uint256 deadline
    )
        external
        override
        onlyOwner
        currentTimeIsLess(s_campaignData.launchTime)
        whenNotPaused
    {
        s_campaignData.deadline = deadline;
        emit CampaignInfoDeadlineUpdated(deadline);
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function updateGoalAmount(
        uint256 goalAmount
    )
        external
        override
        onlyOwner
        currentTimeIsLess(s_campaignData.launchTime)
        whenNotPaused
    {
        s_campaignData.goalAmount = goalAmount;
        emit CampaignInfoGoalAmountUpdated(goalAmount);
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function updateSelectedPlatform(
        bytes32 platformBytes,
        bool selection
    )
        external
        override
        onlyOwner
        currentTimeIsLess(s_campaignData.launchTime)
        whenNotPaused
    {
        if (s_selectedPlatformBytes[platformBytes] != selection) {
            revert CampaignInfoInvalidPlatformUpdate(platformBytes, selection);
        }
        s_selectedPlatformBytes[platformBytes] = selection;
        emit CampaignInfoSelectedPlatformUpdated(platformBytes, selection);
    }

    /**
     * @dev Sets platform information for the campaign.
     * @param platformBytes The bytes32 identifier of the platform.
     * @param platformTreasuryAddress The address of the platform's treasury.
     */
    function _setPlatformInfo(
        bytes32 platformBytes,
        address platformTreasuryAddress
    ) external whenNotPaused {
        if (msg.sender != TREASURY_FACTORY) {
            revert CampaignInfoUnauthorized();
        }
        bool selected = checkIfPlatformSelected(platformBytes);
        if (!selected) {
            revert CampaignInfoPlatformNotSelected(platformBytes);
        }
        s_platformTreasuryAddress[platformBytes] = platformTreasuryAddress;
        s_approvedPlatformBytes.push(platformBytes);
        emit CampaignInfoPlatformInfoUpdated(
            platformBytes,
            platformTreasuryAddress
        );
    }

    function _pauseCampaign() external onlyProtocolAdmin {
        _pause();
    }

    function _unpauseCampaign() external onlyProtocolAdmin {
        _unpause();
    }
}
