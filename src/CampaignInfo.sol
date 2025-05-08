// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "./interfaces/ICampaignInfo.sol";
import "./interfaces/ICampaignData.sol";
import "./interfaces/ICampaignTreasury.sol";
import "./interfaces/IGlobalParams.sol";
import "./utils/TimestampChecker.sol";
import "./utils/AdminAccessChecker.sol";
import "./utils/PausableCancellable.sol";

/**
 * @title CampaignInfo
 * @notice Manages campaign information and platform data.
 */
contract CampaignInfo is
    ICampaignData,
    ICampaignInfo,
    Ownable,
    PausableCancellable,
    TimestampChecker,
    AdminAccessChecker,
    Initializable
{
    CampaignData private s_campaignData;

    mapping(bytes32 => address) private s_platformTreasuryAddress;
    mapping(bytes32 => uint256) private s_platformFeePercent;
    mapping(bytes32 => bool) private s_isSelectedPlatform;
    mapping(bytes32 => bool) private s_isApprovedPlatform;
    mapping(bytes32 => bytes32) private s_platformData;

    bytes32[] private s_approvedPlatformHashes;

    function getApprovedPlatformHashes()
        external
        view
        returns (bytes32[] memory)
    {
        return s_approvedPlatformHashes;
    }

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
     * @param platformHash The bytes32 identifier of the platform.
     * @param selection The new selection state.
     */
    event CampaignInfoSelectedPlatformUpdated(
        bytes32 indexed platformHash,
        bool selection
    );

    /**
     * @dev Emitted when platform information is updated for the campaign.
     * @param platformHash The bytes32 identifier of the platform.
     * @param platformTreasury The address of the platform's treasury.
     */
    event CampaignInfoPlatformInfoUpdated(
        bytes32 indexed platformHash,
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
     * @param platformHash The bytes32 identifier of the platform.
     * @param selection The selection state (true/false).
     */
    error CampaignInfoInvalidPlatformUpdate(
        bytes32 platformHash,
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
     * @param platformHash The bytes32 identifier of the platform.
     */
    error CampaignInfoPlatformNotSelected(bytes32 platformHash);

    /**
     * @dev Emitted when a platform is already approved for the campaign.
     * @param platformHash The bytes32 identifier of the platform.
     */
    error CampaignInfoPlatformAlreadyApproved(bytes32 platformHash);

    constructor(address creator) Ownable(creator) {}

    function initialize(
        address creator,
        IGlobalParams globalParams,
        bytes32[] calldata selectedPlatformHash,
        bytes32[] calldata platformDataKey,
        bytes32[] calldata platformDataValue,
        CampaignData calldata campaignData
    ) external initializer {
        __AccessChecker_init(globalParams);
        _transferOwnership(creator);
        s_campaignData = campaignData;
        uint256 len = selectedPlatformHash.length;
        for (uint256 i = 0; i < len; ++i) {
            s_platformFeePercent[selectedPlatformHash[i]] = GLOBAL_PARAMS
                .getPlatformFeePercent(selectedPlatformHash[i]);
            s_isSelectedPlatform[selectedPlatformHash[i]] = true;
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

    struct Config {
        address treasuryFactory;
        address token;
        uint256 protocolFeePercent;
        bytes32 identifierHash;
    }

    function getCampaignConfig() public view returns (Config memory config) {
        bytes memory args = Clones.fetchCloneArgs(address(this));
        (
            config.treasuryFactory,
            config.token,
            config.protocolFeePercent,
            config.identifierHash
        ) = abi.decode(args, (address, address, uint256, bytes32));
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function checkIfPlatformSelected(
        bytes32 platformHash
    ) public view override returns (bool) {
        return s_isSelectedPlatform[platformHash];
    }

    /**
     * @dev Check if a platform is already approved
     * @param platformHash The bytes32 identifier of the platform.
     * @return True if the platform is already approved, false otherwise.
     */
    function checkIfPlatformApproved(
        bytes32 platformHash
    ) public view returns (bool) {
        return s_isApprovedPlatform[platformHash];
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
    function getProtocolAdminAddress() public view override returns (address) {
        return GLOBAL_PARAMS.getProtocolAdminAddress();
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function getTotalRaisedAmount() external view override returns (uint256) {
        bytes32[] memory tempPlatforms = s_approvedPlatformHashes;
        uint256 length = s_approvedPlatformHashes.length;
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
    function getPlatformAdminAddress(
        bytes32 platformHash
    ) external view override returns (address) {
        return GLOBAL_PARAMS.getPlatformAdminAddress(platformHash);
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function getLaunchTime() public view override returns (uint256) {
        return s_campaignData.launchTime;
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function getDeadline() public view override returns (uint256) {
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
        Config memory config = getCampaignConfig();
        return config.token;
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function getProtocolFeePercent() external view override returns (uint256) {
        Config memory config = getCampaignConfig();
        return config.protocolFeePercent;
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function paused()
        public
        view
        override(ICampaignInfo, PausableCancellable)
        returns (bool)
    {
        return super.paused();
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function cancelled()
        public
        view
        override(ICampaignInfo, PausableCancellable)
        returns (bool)
    {
        return super.cancelled();
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function getPlatformFeePercent(
        bytes32 platformHash
    ) external view override returns (uint256) {
        return s_platformFeePercent[platformHash];
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
        Config memory config = getCampaignConfig();
        return config.identifierHash;
    }

    /**
     * @inheritdoc Ownable
     */
    function transferOwnership(
        address newOwner
    )
        public
        override(ICampaignInfo, Ownable)
        onlyOwner
        whenNotPaused
        whenNotCancelled
    {
        super.transferOwnership(newOwner);
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function updateLaunchTime(
        uint256 launchTime
    )
        external
        override
        onlyOwner
        currentTimeIsLess(getLaunchTime())
        whenNotPaused
        whenNotCancelled
    {
        if (launchTime < block.timestamp || getDeadline() <= launchTime) {
            revert CampaignInfoInvalidInput();
        }
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
        currentTimeIsLess(getLaunchTime())
        whenNotPaused
        whenNotCancelled
    {
        if (deadline <= getLaunchTime()) {
            revert CampaignInfoInvalidInput();
        }

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
        currentTimeIsLess(getLaunchTime())
        whenNotPaused
        whenNotCancelled
    {
        if (goalAmount == 0) {
            revert CampaignInfoInvalidInput();
        }
        s_campaignData.goalAmount = goalAmount;
        emit CampaignInfoGoalAmountUpdated(goalAmount);
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function updateSelectedPlatform(
        bytes32 platformHash,
        bool selection
    )
        external
        override
        onlyOwner
        currentTimeIsLess(getLaunchTime())
        whenNotPaused
        whenNotCancelled
    {
        if (checkIfPlatformSelected(platformHash) == selection) {
            revert CampaignInfoInvalidInput();
        }
        if (!GLOBAL_PARAMS.checkIfPlatformIsListed(platformHash)) {
            revert CampaignInfoInvalidPlatformUpdate(platformHash, selection);
        }

        if (!selection && checkIfPlatformApproved(platformHash)) {
            revert CampaignInfoPlatformAlreadyApproved(platformHash);
        }
        s_isSelectedPlatform[platformHash] = selection;
        if (selection) {
            s_platformFeePercent[platformHash] = GLOBAL_PARAMS
                .getPlatformFeePercent(platformHash);
        } else {
            s_platformFeePercent[platformHash] = 0;
        }
        emit CampaignInfoSelectedPlatformUpdated(platformHash, selection);
    }

    /**
     * @dev External function to pause the campaign.
     */
    function _pauseCampaign(bytes32 message) external onlyProtocolAdmin {
        _pause(message);
    }

    /**
     * @dev External function to unpause the campaign.
     */
    function _unpauseCampaign(bytes32 message) external onlyProtocolAdmin {
        _unpause(message);
    }

    /**
     * @dev External function to cancel the campaign.
     */
    function _cancelCampaign(bytes32 message) external {
        if (msg.sender != getProtocolAdminAddress() && msg.sender != owner()) {
            revert CampaignInfoUnauthorized();
        }
        _cancel(message);
    }

    /**
     * @dev Sets platform information for the campaign.
     * @param platformHash The bytes32 identifier of the platform.
     * @param platformTreasuryAddress The address of the platform's treasury.
     */
    function _setPlatformInfo(
        bytes32 platformHash,
        address platformTreasuryAddress
    ) external whenNotPaused {
        Config memory config = getCampaignConfig();
        if (msg.sender != config.treasuryFactory) {
            revert CampaignInfoUnauthorized();
        }
        bool selected = checkIfPlatformSelected(platformHash);
        if (!selected) {
            revert CampaignInfoPlatformNotSelected(platformHash);
        }
        if (s_isApprovedPlatform[platformHash]) {
            revert CampaignInfoPlatformAlreadyApproved(platformHash);
        }
        s_platformTreasuryAddress[platformHash] = platformTreasuryAddress;
        s_approvedPlatformHashes.push(platformHash);
        s_isApprovedPlatform[platformHash] = true;

        emit CampaignInfoPlatformInfoUpdated(
            platformHash,
            platformTreasuryAddress
        );
    }
}
