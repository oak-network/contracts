// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/ICampaignInfo.sol";
import "./interfaces/IGlobalParams.sol";
import "./utils/TimestampChecker.sol";

contract CampaignInfo is ICampaignInfo, Ownable, TimestampChecker {
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
        PROTOCOL_FEE_PERCENT = globalParams.protocolFeePercent;
        s_campaignData = campaignData;

        transferOwnership(creator);
    }

    function checkIfPlatformSelected(
        bytes32 platformBytes
    ) public view override returns (bool) {
        return s_selectedPlatformBytes[platformBytes];
    }

    function getProtocolAdminAddress() external view returns (address) {
        return IGlobalParams(GLOBAL_PARAMS).getProtocolAdminAddress();
    }

    function getPlatformAdminAddress() external view returns (address) {
        return IGlobalParams(GLOBAL_PARAMS).getPlatformAdminAddress();
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

    function getProtocolFeePercent() external view override returns (address) {
        return PROTOCOL_FEE_PERCENT;
    }

    function getIdentifierHash() external view override returns (bytes32) {
        return IDENTIFIER_HASH;
    }

    function totalCurrentBalance() public view override returns (uint256) {
        bytes32[] memory tempPlatforms = allowedPlatforms;
        uint256 length = allowedPlatforms.length;
        uint256 balance = 0;
        address tempToken = token;
        for (uint256 i = 0; i < length; i++) {
            address tempTreasury = treasury[tempPlatforms[i]];
            if (tempTreasury != address(0)) {
                balance += IERC20(tempToken).balanceOf(tempTreasury);
            }
        }
        return balance;
    }

    function totalRaisedBalance() public view override returns (uint256) {
        bytes32[] memory tempPlatforms = allowedPlatforms;
        uint256 length = allowedPlatforms.length;
        uint256 balance = 0;
        for (uint256 i = 0; i < length; i++) {
            address tempTreasury = treasury[tempPlatforms[i]];
            if (tempTreasury != address(0)) {
                balance += ICampaignTreasury(tempTreasury).raisedBalance();
            }
        }
        return balance;
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
    ) external onlyOwner currentTimeIsLess(s_campaignData.launchTime) {
        s_campaignData.deadline = deadline;
    }

    function updateGoalAmount(
        uint256 goalAmount
    ) external onlyOwner currentTimeIsLess(s_campaignData.launchTime) {
        s_campaignData.goalAmount = goalAmount;
    }

    function updateSelectedPlatform(
        bytes32 platformBytes,
        bool selection
    ) external onlyOwner currentTimeIsLess(s_campaignData.launchTime) {
        if (s_selectedPlatformBytes[platformBytes] == selection)
            revert CampaignInfoInvalidPlatformUpdate(platformBytes, selection);
        else {
            s_selectedPlatformBytes[platformBytes] = selection;
        }
    }
}
