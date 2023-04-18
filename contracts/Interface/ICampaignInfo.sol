// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface ICampaignInfo {
    struct CampaignData {
        string identifier;
        bytes32 originPlatform;
        uint256 goalAmount;
        uint256 launchTime;
        uint256 createdAt;
        uint256 deadline;
        string creatorUrl;
        bytes32[] reachPlatforms;
    }

    struct Item {
        string description;
    }

    struct Reward {
        uint256 rewardValue;
        string rewardDescription;
        string[] itemId;
        mapping(string => uint256) itemQuantity;
    }

    enum State {
        LaunchNotSet,
        LaunchSet,
        Live,
        Over
    }

    function getBackerPledgeInfoForAPlatform(
        address backer,
        bytes32 platformId
    ) external view returns (uint256);

    function getCampaignData()
        external
        view
        returns (
            string memory,
            uint256,
            uint256,
            uint256,
            uint256,
            string memory
        );

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
        address _platformWallet,
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

    function setPlatformWallet(
        bytes32 platformId,
        address platformWallet_
    ) external;

    function pledgeCrypto(
        bytes32 platformId,
        uint256 amount,
        bool isEarlyPledge
    ) external;

    function distributePledge(
        address backer,
        bytes32 platformId
    ) external returns (bool);

    function claimReward(
        address backer,
        string calldata rewardId
    ) external returns (bool);

    function pause() external;

    function unpause() external;

    function transferOwnership(address newOwner) external;
}
