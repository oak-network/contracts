// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./CampaignTreasury.sol";
import "./CampaignRegistry.sol";
import "./library/FeeSplit.sol";

contract CampaignInfo is Ownable {
    using FeeSplit for uint256;
    using FeeSplit for uint256[];

    struct CampaignData {
        string identifier;
        bytes32 originPlatform;
        uint64 goalAmount;
        uint64 launchTime;
        uint64 createdAt;
        uint64 deadline;
        string creatorUrl;
        bytes32[] reachPlatforms;
    }

    CampaignData campaign;
    address registryAddress;
    bool rewardClientSet;

    /* Hyperparameters */
    uint256 denominator = 2;
    bytes32 rewardedClient;

    mapping(bytes32 => address) treasuryAddress;
    mapping(bytes32 => address) tokens;

    constructor(
        string memory _identifier,
        bytes32 _originPlatform,
        uint64 _goalAmount,
        uint64 _launchTime,
        uint64 _deadline,
        string memory _creatorUrl,
        bytes32[] memory _reachPlatform,
        address _registryAddress
    ) {
        require(_launchTime + 30 days < _deadline);
        campaign.identifier = _identifier;
        campaign.originPlatform = _originPlatform;
        campaign.goalAmount = _goalAmount;
        campaign.launchTime = _launchTime;
        campaign.createdAt = uint64(block.timestamp);
        campaign.deadline = _deadline;
        campaign.creatorUrl = _creatorUrl;
        campaign.reachPlatforms = _reachPlatform;
        registryAddress = _registryAddress;
    }

    modifier onlyRegistryOwner() {
        require(msg.sender == CampaignRegistry(registryAddress).owner());
        _;
    }

    function getCampaignData()
        public
        view
        returns (
            string memory,
            uint64,
            uint64,
            uint64,
            uint64,
            string memory
        )
    {
        return (
            campaign.identifier,
            campaign.goalAmount,
            campaign.launchTime,
            campaign.createdAt,
            campaign.deadline,
            campaign.creatorUrl
        );
    }

    function getCampaignOriginPlatform() public view returns (bytes32) {
        return campaign.originPlatform;
    }

    function getCampaignReachPlatforms()
        public
        view
        returns (bytes32[] memory)
    {
        return campaign.reachPlatforms;
    }

    function getTotalPledgedAmount() public view returns (uint256) {
        address tempOriginPlatform = treasuryAddress[campaign.originPlatform];
        require(
            tempOriginPlatform != address(0),
            "CampaignInfo: Origin platform treasury not set yet"
        );
        bytes32[] memory tempReachPlatforms = campaign.reachPlatforms;
        uint256 length = tempReachPlatforms.length;
        uint256 pledgedAmount = CampaignTreasury(tempOriginPlatform)
            .getPledgedAmount();
        for (uint256 i = 0; i < length; i++) {
            address tempReachPlatform = treasuryAddress[tempReachPlatforms[i]];
            if (tempReachPlatform != address(0)) {
                pledgedAmount =
                    pledgedAmount +
                    CampaignTreasury(tempReachPlatform).getPledgedAmount();
            }
        }
        return pledgedAmount;
    }

    function getTotalPledgedAmountCrypto() public view returns (uint256) {
        address tempOriginPlatform = treasuryAddress[campaign.originPlatform];
        require(
            tempOriginPlatform != address(0),
            "CampaignInfo: Origin platform treasury not set yet"
        );
        bytes32[] memory tempReachPlatforms = campaign.reachPlatforms;
        uint256 length = tempReachPlatforms.length;
        uint256 pledgedAmount = IERC20(tokens[campaign.originPlatform])
            .balanceOf(tempOriginPlatform);
        for (uint256 i = 0; i < length; i++) {
            address tempReachPlatform = treasuryAddress[tempReachPlatforms[i]];
            address tempToken = tokens[tempReachPlatforms[i]];
            if (tempReachPlatform != address(0)) {
                pledgedAmount =
                    pledgedAmount +
                    IERC20(tempToken).balanceOf(tempReachPlatform);
            }
        }
        return pledgedAmount;
    }

    function getTreasuryAddress(bytes32 clientId)
        public
        view
        returns (address)
    {
        require(
            treasuryAddress[clientId] != address(0),
            "CampaignInfo: Treasury address for client is not set"
        );
        return treasuryAddress[clientId];
    }

    function editLaunchTime(uint64 _launchTime) external onlyRegistryOwner {
        require(_launchTime + 30 days < campaign.deadline);
        campaign.launchTime = _launchTime;
    }

    function editDeadline(uint64 _deadline) external onlyRegistryOwner {
        require(_deadline - 30 days > campaign.launchTime);
        campaign.deadline = _deadline;
    }

    function setTreasuryAddress(bytes32 _clientId, address _treasuryAddress)
        external
        onlyRegistryOwner
    {
        treasuryAddress[_clientId] = _treasuryAddress;
    }

    function addReachPlatform(bytes32 _clientId) external onlyRegistryOwner {
        campaign.reachPlatforms.push(_clientId);
    }

    function pledge(bytes32 clientId, uint256 amount) public {
        IERC20(tokens[clientId]).transferFrom(
            msg.sender,
            treasuryAddress[clientId],
            amount
        );
        if (
            getPledgedAmountForClientCrypto(clientId) >=
            campaign.goalAmount / denominator &&
            !rewardClientSet
        ) {
            rewardClientSet = true;
            rewardedClient = clientId;
        }
    }

    function getPledgedAmountForClientCrypto(bytes32 clientId)
        public
        view
        returns (uint256)
    {
        return IERC20(tokens[clientId]).balanceOf(treasuryAddress[clientId]);
    }

    function splitFeeWithRewards(uint256 feePercent, uint256 rewardPercent)
        public
        view
        returns (uint256, uint256[] memory)
    {
        uint256 pledgedAmountByRewardedPlatform = getPledgedAmountForClientCrypto(
                rewardedClient
            );
        bytes32[] memory tempReachPlatforms = campaign.reachPlatforms;
        uint256[] memory pledgedAmountByOtherPlatforms = new uint256[](
            tempReachPlatforms.length
        );
        bytes32 tempOriginPlatform = campaign.originPlatform;
        if (rewardedClient == tempOriginPlatform) {
            for (uint256 i = 0; i < tempReachPlatforms.length; i++) {
                pledgedAmountByOtherPlatforms[
                    i
                ] = getPledgedAmountForClientCrypto(tempReachPlatforms[i]);
            }
        } else {
            uint256 i = 0;
            pledgedAmountByOtherPlatforms[i] = getPledgedAmountForClientCrypto(
                tempOriginPlatform
            );
            for (i = 1; i < tempReachPlatforms.length; i++) {
                if (tempReachPlatforms[i - 1] != rewardedClient) {
                    pledgedAmountByOtherPlatforms[
                        i
                    ] = getPledgedAmountForClientCrypto(tempReachPlatforms[i]);
                }
            }
        }
        (
            uint256 feeShareByRewardedPlatform,
            uint256[] memory feeShareByOtherPlatforms
        ) = FeeSplit.splitWithOriginReward(
                feePercent,
                rewardPercent,
                pledgedAmountByRewardedPlatform,
                pledgedAmountByOtherPlatforms
            );
        return (feeShareByRewardedPlatform, feeShareByOtherPlatforms);
    }
}
