// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/ICampaignInfo.sol";
import "./interfaces/IGlobalParams.sol";
import "./utils/TimestampChecker.sol";

contract CampaignInfo is ICampaignInfo, Ownable, TimestampChecker {
    
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('getRaisedAmount()')));
    
    address private immutable GLOBAL_PARAMS;
    address private immutable TREASURY_FACTORY;
    address private immutable TOKEN;
    uint256 private immutable PROTOCOL_FEE_PERCENT;
    bytes32 private immutable IDENTIFIER_HASH;

    error CampaignInfoInvalidPlatformUpdate(
        bytes32 platformBytes,
        bool selection
    );
    error CampaignInfoPlatformNotSelected(bytes32 platformBytes);
    error CampaignInfoUnauthorized();

    struct CampaignData {
        uint256 launchTime;
        uint256 deadline;
        uint256 goalAmount;
    }

    CampaignData private s_campaignData;

    mapping(bytes32 => bool) private s_selectedPlatformBytes;
    mapping(bytes32 => address) private s_platformTreasuryAddress;

    bytes32[] private s_approvedPlatformBytes;

    constructor(
        address globalParams,
        address treasuryFactory,
        address token,
        address creator,
        uint256 protocolFeePercent,
        bytes32 identifierHash,
        CampaignData memory campaignData
    ) {
        GLOBAL_PARAMS = globalParams;
        TREASURY_FACTORY = treasuryFactory;
        TOKEN = token;
        IDENTIFIER_HASH = identifierHash;
        PROTOCOL_FEE_PERCENT = protocolFeePercent;
        s_campaignData = campaignData;

        transferOwnership(creator);
    }

    function checkIfPlatformSelected(
        bytes32 platformBytes
    ) public view override returns (bool) {
        return s_selectedPlatformBytes[platformBytes];
    }

    function getTotalRaisedAmount() public view override returns (uint256) {
        bytes32[] memory tempPlatforms = s_approvedPlatformBytes;
        uint256 length = s_approvedPlatformBytes.length;
        uint256 amount;
        address tempTreasury;
        bool success;
        bytes memory data;
        for (uint256 i = 0; i < length; i++) {
            tempTreasury = s_platformTreasuryAddress[tempPlatforms[i]];
            (success, data) = tempTreasury.call(abi.encodeWithSelector(SELECTOR));
            if (success) {
                amount += abi.decode(data, (uint256));
            }
        }
        return amount; 
    }

    function getProtocolAdminAddress() external view override returns (address) {
        return IGlobalParams(GLOBAL_PARAMS).getProtocolAdminAddress();
    }

    function getPlatformAdminAddress(bytes32 platformBytes) external view override returns (address) {
        return IGlobalParams(GLOBAL_PARAMS).getPlatformAdminAddress(platformBytes);
    }

    function getLaunchTime() external view override returns (uint256) {
        return s_campaignData.launchTime;
    }

    function getDeadline() external view override returns (uint256) {
        return s_campaignData.deadline;
    }

    function getGoalAmount() external view override returns (uint256) {
        return s_campaignData.goalAmount;
    }

    function getTokenAddress() external view override returns (address) {
        return TOKEN;
    }

    function getProtocolFeePercent() external view override returns (uint256) {
        return PROTOCOL_FEE_PERCENT;
    }

    function getIdentifierHash() external view override returns (bytes32) {
        return IDENTIFIER_HASH;
    }

    function setPlatformInfo(
        bytes32 platformBytes,
        address platformTreasuryAddress
    ) external override {
        if (msg.sender != TREASURY_FACTORY) {
            revert CampaignInfoUnauthorized();
        }
        bool selected = checkIfPlatformSelected(platformBytes);
        if (selected) {
            s_platformTreasuryAddress[platformBytes] = platformTreasuryAddress;
            s_approvedPlatformBytes.push(platformBytes);
        } else {
            revert CampaignInfoPlatformNotSelected(platformBytes);
        }
    }

    function transferOwnership(
        address newOwner
    ) public override(ICampaignInfo, Ownable) onlyOwner {
        super.transferOwnership(newOwner);
    }

    function updateLaunchTime(
        uint256 launchTime
    ) external onlyOwner currentTimeIsLess(launchTime) {
        s_campaignData.launchTime = launchTime;
    }

    function updateDeadline(
        uint256 deadline
    ) external override onlyOwner currentTimeIsLess(s_campaignData.launchTime) {
        s_campaignData.deadline = deadline;
    }

    function updateGoalAmount(
        uint256 goalAmount
    ) external override onlyOwner currentTimeIsLess(s_campaignData.launchTime) {
        s_campaignData.goalAmount = goalAmount;
    }

    function updateSelectedPlatform(
        bytes32 platformBytes,
        bool selection
    ) external override onlyOwner currentTimeIsLess(s_campaignData.launchTime) {
        if (s_selectedPlatformBytes[platformBytes] == selection)
            revert CampaignInfoInvalidPlatformUpdate(platformBytes, selection);
        else {
            s_selectedPlatformBytes[platformBytes] = selection;
        }
    }
}
