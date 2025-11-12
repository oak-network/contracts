// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import {ICampaignInfo} from "./interfaces/ICampaignInfo.sol";
import {ICampaignData} from "./interfaces/ICampaignData.sol";
import {ICampaignTreasury} from "./interfaces/ICampaignTreasury.sol";
import {ICampaignPaymentTreasury} from "./interfaces/ICampaignPaymentTreasury.sol";
import {IGlobalParams} from "./interfaces/IGlobalParams.sol";
import {TimestampChecker} from "./utils/TimestampChecker.sol";
import {AdminAccessChecker} from "./utils/AdminAccessChecker.sol";
import {PausableCancellable} from "./utils/PausableCancellable.sol";
import {PledgeNFT} from "./utils/PledgeNFT.sol";
import {Counters} from "./utils/Counters.sol";
import {DataRegistryKeys} from "./constants/DataRegistryKeys.sol";

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
    PledgeNFT,
    Initializable
{
    using Counters for Counters.Counter;

    CampaignData private s_campaignData;

    mapping(bytes32 => address) private s_platformTreasuryAddress;
    mapping(bytes32 => uint256) private s_platformFeePercent;
    mapping(bytes32 => bool) private s_isSelectedPlatform;
    mapping(bytes32 => bool) private s_isApprovedPlatform;
    mapping(bytes32 => bytes32) private s_platformData;

    bytes32[] private s_approvedPlatformHashes;
    
    // Multi-token support
    address[] private s_acceptedTokens;  // Accepted tokens for this campaign
    mapping(address => bool) private s_isAcceptedToken;  // O(1) token validation
    
    // Lock mechanism - prevents certain operations after treasury deployment
    bool private s_isLocked;

    function getApprovedPlatformHashes()
        external
        view
        returns (bytes32[] memory)
    {
        return s_approvedPlatformHashes;
    }

    /**
     * @dev Returns whether the campaign is locked (after treasury deployment).
     * @return True if the campaign is locked, false otherwise.
     */
    function isLocked() external view override returns (bool) {
        return s_isLocked;
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

    /**
     * @dev Emitted when an operation is attempted on a locked campaign.
     */
    error CampaignInfoIsLocked();


    /**
     * @dev Modifier that checks if the campaign is not locked.
     */
    modifier whenNotLocked() {
        if (s_isLocked) {
            revert CampaignInfoIsLocked();
        }
        _;
    }
    
    /**
     * @notice Constructor passes empty strings to ERC721
     */
    constructor() Ownable(_msgSender()) ERC721("", "") {
        _disableInitializers();
    }

    function initialize(
        address creator,
        IGlobalParams globalParams,
        bytes32[] calldata selectedPlatformHash,
        bytes32[] calldata platformDataKey,
        bytes32[] calldata platformDataValue,
        CampaignData calldata campaignData,
        address[] calldata acceptedTokens,
        string calldata nftName,
        string calldata nftSymbol,
        string calldata nftImageURI,
        string calldata nftContractURI
    ) external initializer {
        __AccessChecker_init(globalParams);
        _transferOwnership(creator);
        s_campaignData = campaignData;
        
        // Store accepted tokens
        uint256 tokenLen = acceptedTokens.length;
        for (uint256 i = 0; i < tokenLen; ++i) {
            address token = acceptedTokens[i];
            s_acceptedTokens.push(token);
            s_isAcceptedToken[token] = true;
        }
        
        uint256 len = selectedPlatformHash.length;
        for (uint256 i = 0; i < len; ++i) {
            s_platformFeePercent[selectedPlatformHash[i]] = _getGlobalParams()
                .getPlatformFeePercent(selectedPlatformHash[i]);
            s_isSelectedPlatform[selectedPlatformHash[i]] = true;
        }
        len = platformDataKey.length;
        for (uint256 i = 0; i < len; ++i) {
            s_platformData[platformDataKey[i]] = platformDataValue[i];
        }
        
        // Initialize NFT metadata
        _initializeNFT(nftName, nftSymbol, nftImageURI, nftContractURI);
    }

    struct Config {
        address treasuryFactory;
        uint256 protocolFeePercent;
        bytes32 identifierHash;
    }

    function getCampaignConfig() public view returns (Config memory config) {
        bytes memory args = Clones.fetchCloneArgs(address(this));
        (
            config.treasuryFactory,
            config.protocolFeePercent,
            config.identifierHash
        ) = abi.decode(args, (address, uint256, bytes32));
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
        return _getGlobalParams().getProtocolAdminAddress();
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
            // Skip cancelled treasuries
            if (!ICampaignTreasury(tempTreasury).cancelled()) {
                amount += ICampaignTreasury(tempTreasury).getRaisedAmount();
            }
        }
        return amount;
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function getTotalLifetimeRaisedAmount() external view returns (uint256) {
        bytes32[] memory tempPlatforms = s_approvedPlatformHashes;
        uint256 length = s_approvedPlatformHashes.length;
        uint256 amount;
        address tempTreasury;
        for (uint256 i = 0; i < length; i++) {
            tempTreasury = s_platformTreasuryAddress[tempPlatforms[i]];
            amount += ICampaignTreasury(tempTreasury).getLifetimeRaisedAmount();
        }
        return amount;
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function getTotalRefundedAmount() external view returns (uint256) {
        bytes32[] memory tempPlatforms = s_approvedPlatformHashes;
        uint256 length = s_approvedPlatformHashes.length;
        uint256 amount;
        address tempTreasury;
        for (uint256 i = 0; i < length; i++) {
            tempTreasury = s_platformTreasuryAddress[tempPlatforms[i]];
            amount += ICampaignTreasury(tempTreasury).getRefundedAmount();
        }
        return amount;
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function getTotalAvailableRaisedAmount() external view returns (uint256) {
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
    function getTotalCancelledAmount() external view returns (uint256) {
        bytes32[] memory tempPlatforms = s_approvedPlatformHashes;
        uint256 length = s_approvedPlatformHashes.length;
        uint256 amount;
        address tempTreasury;
        for (uint256 i = 0; i < length; i++) {
            tempTreasury = s_platformTreasuryAddress[tempPlatforms[i]];
            // Only include cancelled treasuries
            if (ICampaignTreasury(tempTreasury).cancelled()) {
                amount += ICampaignTreasury(tempTreasury).getRaisedAmount();
            }
        }
        return amount;
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function getTotalExpectedAmount() external view returns (uint256) {
        bytes32[] memory tempPlatforms = s_approvedPlatformHashes;
        uint256 length = s_approvedPlatformHashes.length;
        uint256 amount;
        address tempTreasury;
        for (uint256 i = 0; i < length; i++) {
            tempTreasury = s_platformTreasuryAddress[tempPlatforms[i]];
            // Try to call getExpectedAmount - will only work for payment treasuries
            try ICampaignPaymentTreasury(tempTreasury).getExpectedAmount() returns (uint256 expectedAmount) {
                amount += expectedAmount;
            } catch {
                // Not a payment treasury or call failed, skip
            }
        }
        return amount;
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function getPlatformAdminAddress(
        bytes32 platformHash
    ) external view override returns (address) {
        return _getGlobalParams().getPlatformAdminAddress(platformHash);
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
    function getProtocolFeePercent() external view override returns (uint256) {
        Config memory config = getCampaignConfig();
        return config.protocolFeePercent;
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function getCampaignCurrency() external view override returns (bytes32) {
        return s_campaignData.currency;
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function getAcceptedTokens() external view override returns (address[] memory) {
        return s_acceptedTokens;
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function isTokenAccepted(address token) external view override returns (bool) {
        return s_isAcceptedToken[token];
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
     * @inheritdoc ICampaignInfo
     */
    function getDataFromRegistry(bytes32 key) external view override returns (bytes32 value) {
        return _getGlobalParams().getFromRegistry(key);
    }

    /**
     * @inheritdoc ICampaignInfo
     */
    function getBufferTime() external view override returns (uint256 bufferTime) {
        bytes32 valueBytes = _getGlobalParams().getFromRegistry(DataRegistryKeys.BUFFER_TIME);
        bufferTime = uint256(valueBytes);
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
        whenNotPaused
        whenNotCancelled
        whenNotLocked
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
        whenNotPaused
        whenNotCancelled
        whenNotLocked
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
        whenNotPaused
        whenNotCancelled
        whenNotLocked
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
        bool selection,
        bytes32[] calldata platformDataKey,
        bytes32[] calldata platformDataValue
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
        if (!_getGlobalParams().checkIfPlatformIsListed(platformHash)) {
            revert CampaignInfoInvalidPlatformUpdate(platformHash, selection);
        }

        if (!selection && checkIfPlatformApproved(platformHash)) {
            revert CampaignInfoPlatformAlreadyApproved(platformHash);
        }

        if (platformDataKey.length != platformDataValue.length) {
            revert CampaignInfoInvalidInput();
        }

        if (selection) {
            bool isValid;
            for (uint256 i = 0; i < platformDataKey.length; i++) {
                isValid = _getGlobalParams().checkIfPlatformDataKeyValid(
                    platformDataKey[i]
                );
                if (!isValid) {
                    revert CampaignInfoInvalidInput();
                }
                if (platformDataValue[i] == bytes32(0)) {
                    revert CampaignInfoInvalidInput();
                }

                s_platformData[platformDataKey[i]] = platformDataValue[i];
            }
        }

        s_isSelectedPlatform[platformHash] = selection;
        if (selection) {
            s_platformFeePercent[platformHash] = _getGlobalParams()
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
        if (_msgSender() != getProtocolAdminAddress() && _msgSender() != owner()) {
            revert CampaignInfoUnauthorized();
        }
        _cancel(message);
    }

    /**
     * @notice Sets the image URI for NFT metadata
     * @dev Can only be updated before campaign launch
     * @param newImageURI The new image URI
     */
    function setImageURI(
        string calldata newImageURI
    ) external override(ICampaignInfo, PledgeNFT) onlyOwner currentTimeIsLess(getLaunchTime()) {
        s_imageURI = newImageURI;
        emit ImageURIUpdated(newImageURI);
    }

    /**
     * @notice Updates the contract-level metadata URI
     * @dev Can only be updated before campaign launch
     * @param newContractURI The new contract URI
     */
    function updateContractURI(
        string calldata newContractURI
    ) external override(ICampaignInfo, PledgeNFT) onlyOwner currentTimeIsLess(getLaunchTime()) {
        s_contractURI = newContractURI;
        emit ContractURIUpdated(newContractURI);
    }

    function mintNFTForPledge(
        address backer,
        bytes32 reward,
        address tokenAddress,
        uint256 amount,
        uint256 shippingFee,
        uint256 tipAmount
    ) public override(ICampaignInfo, PledgeNFT) returns (uint256 tokenId) {
        return super.mintNFTForPledge(backer, reward, tokenAddress, amount, shippingFee, tipAmount);
    }

    function burn(uint256 tokenId) public override(ICampaignInfo, PledgeNFT) {
        super.burn(tokenId);
    }

    /**
     * @dev Sets platform information for the campaign and grants treasury role.
     * @param platformHash The bytes32 identifier of the platform.
     * @param platformTreasuryAddress The address of the platform's treasury.
     */
    function _setPlatformInfo(
        bytes32 platformHash,
        address platformTreasuryAddress
    ) external whenNotPaused {
        Config memory config = getCampaignConfig();
        if (_msgSender() != config.treasuryFactory) {
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

        // Grant MINTER_ROLE to allow treasury to mint pledge NFTs
        _grantRole(MINTER_ROLE, platformTreasuryAddress);
        // Lock the campaign after the first treasury deployment
        if (!s_isLocked) {
            s_isLocked = true;
        }

        emit CampaignInfoPlatformInfoUpdated(
            platformHash,
            platformTreasuryAddress
        );
    }

}
