// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./ICampaignContainers.sol";

interface ICampaignInfo {
    struct CampaignData {
        uint256 goalAmount;
        uint256 launchTime;
        uint256 deadline;
        uint256 earlyPledgeAmount;
        address registry;
        string identifier;
        string creatorUrl;
    }

    struct CampaignPlatforms {
        bytes32 originPlatform;
        bytes32[] reachPlatforms;
    }

    struct CampaignState {
        uint256 minCampaignTime;
        bool ended;
        bool launchReady;
        bool latePledgeEnabled;
        bytes32 rewardedPlatform;
        mapping(bytes32 => address) treasuries;
        mapping(bytes32 => address) tokens;
        mapping(address => mapping(bytes32 => uint256)) backerPledgeInfoForPlatforms;
        mapping(address => bool) earlyBackers;
        mapping(bytes32 => bool) pausedPlatforms;
    }

    function getBackerPledgeInfoForAPlatform(
        address backer,
        bytes32 platformId
    ) external view returns (uint256);

    function getCampaignData()
        external
        view
        returns (string memory, uint256, uint256, uint256, string memory);

    function getCampaignOriginPlatform() external view returns (bytes32);

    function getCampaignReachPlatforms()
        external
        view
        returns (bytes32[] memory);

    function getPledgedAmountForAPlatformCrypto(
        bytes32 platformId
    ) external view returns (uint256);

    function getTotalPledgedAmountCrypto() external view returns (uint256);

    function getTreasuryAddress(
        bytes32 platformId
    ) external view returns (address);

    function setPlatformInfo(
        bytes32 _platformId,
        address _treasury,
        address _token
    ) external;

    function setLaunch(
        uint256 launchTime,
        uint256 deadline,
        uint256 goalAmount,
        bool enableLatePledge
    ) external;

    function addReward(
        string calldata _rewardId,
        uint256 _rewardValue,
        string calldata _rewardDescription
    ) external;

    function addItem(
        string calldata _itemId,
        string calldata _description
    ) external;

    function addContainer(
        address creator,
        bytes32 id,
        ICampaignContainers.Container memory container
    ) external;

    function addReward(
        bool isAddOn,
        uint256 rewardValue,
        string calldata name,
        string[] memory itemName,
        uint256[] memory itemQuantity
    ) external;

    function setTreasuryAddress(
        bytes32 platformId,
        address treasuryAddress_
    ) external;

    function setTokenAddress(
        bytes32 platformId,
        address tokenAddress_
    ) external;

    function pledgeCrypto(
        bytes32 platformId,
        uint256 amount,
        bool isEarlyPledge
    ) external;

    function updateLaunchTime(uint256 _launchTime) external;

    function updateDeadline(uint256 _deadline) external;

    function updateGoal(uint256 _goalAmount) external;

    function pause() external;

    function unpause() external;

    function transferOwnership(address newOwner) external;
}
