// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./CampaignTreasury.sol";
import "./CampaignRegistry.sol";

//import "./library/FeeSplit.sol";

contract CampaignInfo is Ownable {
    // using FeeSplit for uint256;
    // using FeeSplit for uint256[];

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
    uint256 constant percentDivider = 10000;
    uint256 clientTotalFeePercent = 500;
    uint256 rewardClientPercent = 100;

    mapping(bytes32 => address) treasuryAddress;
    mapping(bytes32 => address) tokens;
    mapping(bytes32 => address) clientWallet;

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

    function splitProportionately(
        uint256 feePercent,
        uint256[] memory pledgedAmountByPlatforms
    ) public pure returns (uint256[] memory) {
        uint256 length = pledgedAmountByPlatforms.length;
        uint256[] memory feeShareByPlatforms = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            feeShareByPlatforms[i] =
                (pledgedAmountByPlatforms[i] * feePercent) /
                percentDivider;
        }
        return feeShareByPlatforms;
    }

    function splitWithClientReward(
        uint256 totalFeePercent,
        uint256 clientRewardPercent,
        uint256 pledgedAmountByOrigin,
        uint256[] memory pledgedAmountsByReach
    ) public pure returns (uint256, uint256[] memory) {
        uint256 noOfReach = pledgedAmountsByReach.length;
        uint256 reachFeePercent = (totalFeePercent - clientRewardPercent) /
            (noOfReach + 1);
        uint256 feeByOrigin = (pledgedAmountByOrigin *
            (clientRewardPercent + reachFeePercent)) / percentDivider;
        return (
            feeByOrigin,
            splitProportionately(reachFeePercent, pledgedAmountsByReach)
        );
    }

    modifier onlyRegistryOwner() {
        require(msg.sender == CampaignRegistry(registryAddress).owner());
        _;
    }

    modifier treasuryIsSet(bytes32 clientId) {
        require(
            treasuryAddress[clientId] != address(0),
            "CampaignInfo: Treasury address for client is not set"
        );
        _;
    }

    modifier rewardClientIsSet() {
        require(rewardClientSet, "CampaignInfo: Reward client not set yet");
        _;
    }

    function getCampaignData()
        public
        view
        returns (string memory, uint64, uint64, uint64, uint64, string memory)
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

    function getTreasuryAddress(
        bytes32 clientId
    ) public view treasuryIsSet(clientId) returns (address) {
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

    function setClientInfo(
        bytes32 _clientId,
        address _clientWallet,
        address _treasury,
        address _token
    ) external onlyRegistryOwner {
        clientWallet[_clientId] = _clientWallet;
        treasuryAddress[_clientId] = _treasury;
        tokens[_clientId] = _token;
    }

    function addReachPlatform(bytes32 _clientId) external onlyRegistryOwner {
        campaign.reachPlatforms.push(_clientId);
    }

    function pledgeThroughClient(bytes32 clientId, uint256 amount) public {
        if (
            getPledgedAmountForClientCrypto(clientId) >=
            campaign.goalAmount / denominator &&
            !rewardClientSet
        ) {
            rewardClientSet = true;
            rewardedClient = clientId;
        }
        IERC20(tokens[clientId]).transferFrom(
            msg.sender,
            treasuryAddress[clientId],
            amount
        );
    }

    function disburseFee(bytes32 _clientId, uint256 _feeShare) public {
        if (_feeShare > 0 && treasuryAddress[_clientId] != address(0)) {
            CampaignTreasury(treasuryAddress[_clientId]).disburseFeeToClient(
                clientWallet[_clientId],
                tokens[_clientId],
                _feeShare
            );
        }
    }

    function disburseFees(
        bytes32[] memory _clientIds,
        uint256[] memory _feeShares
    ) internal {
        uint256 length = _clientIds.length;
        for (uint256 i = 0; i < length; i++) {
            disburseFee(_clientIds[i], _feeShares[i]);
        }
    }

    function getPledgedAmountForClientCrypto(
        bytes32 clientId
    ) public view treasuryIsSet(clientId) returns (uint256) {
        return IERC20(tokens[clientId]).balanceOf(treasuryAddress[clientId]);
    }

    // function splitFeesProportionately() public {
    //     bytes32[] memory tempReachPlatforms = campaign.reachPlatforms;
    //     bytes32[] memory tempPlatforms = new bytes32[](
    //         tempReachPlatforms.length + 1
    //     );
    //     tempPlatforms[0] = campaign.originPlatform;
    //     uint256[] memory pledgedAmountByPlatforms = new uint256[](
    //         tempReachPlatforms.length + 1
    //     );
    //     for (uint256 i = 1; i <= tempReachPlatforms.length; i++) {
    //         tempPlatforms[i] = tempReachPlatforms[i - 1];
    //         pledgedAmountByPlatforms[i - 1] = getPledgedAmountForClientCrypto(
    //             tempReachPlatforms[i - 1]
    //         );
    //     }
    //     uint256[] memory feeShareByPlatforms = splitProportionately(
    //         clientTotalFeePercent,
    //         pledgedAmountByPlatforms
    //     );
    //     disburseFees(tempPlatforms, feeShareByPlatforms);
    // }

    function splitFeesProportionately() public {
        bytes32[] memory tempReachPlatforms = campaign.reachPlatforms;
        bytes32[] memory tempPlatforms = new bytes32[](
            tempReachPlatforms.length + 1
        );
        uint256[] memory pledgedAmountByPlatforms = new uint256[](
            tempReachPlatforms.length + 1
        );
        for (uint256 i = 0; i < tempReachPlatforms.length; i++) {
            tempPlatforms[i] = tempReachPlatforms[i];
            pledgedAmountByPlatforms[i] = getPledgedAmountForClientCrypto(
                tempReachPlatforms[i]
            );
        }
        tempPlatforms[tempReachPlatforms.length] = campaign.originPlatform;
        pledgedAmountByPlatforms[
            tempReachPlatforms.length
        ] = getPledgedAmountForClientCrypto(campaign.originPlatform);
        uint256[] memory feeShareByPlatforms = splitProportionately(
            clientTotalFeePercent,
            pledgedAmountByPlatforms
        );
        disburseFees(tempPlatforms, feeShareByPlatforms);
    }

    function splitFeeWithRewards() public rewardClientIsSet {
        uint256 feePercent = clientTotalFeePercent;
        uint256 rewardPercent = rewardClientPercent;
        uint256 pledgedAmountByRewardedPlatform = getPledgedAmountForClientCrypto(
                rewardedClient
            );
        bytes32[] memory tempReachPlatforms = campaign.reachPlatforms;
        uint256[] memory pledgedAmountByOtherPlatforms = new uint256[](
            tempReachPlatforms.length
        );
        bytes32 tempOriginPlatform = campaign.originPlatform;
        bytes32[] memory platforms = new bytes32[](tempReachPlatforms.length);
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
            platforms[i] = tempOriginPlatform;
            for (i = 1; i <= tempReachPlatforms.length; i++) {
                if (tempReachPlatforms[i - 1] != rewardedClient) {
                    platforms[i] = tempReachPlatforms[i - 1];
                    pledgedAmountByOtherPlatforms[
                        i
                    ] = getPledgedAmountForClientCrypto(tempReachPlatforms[i]);
                }
            }
        }
        (
            uint256 feeShareByRewardedPlatform,
            uint256[] memory feeShareByOtherPlatforms
        ) = splitWithClientReward(
                feePercent,
                rewardPercent,
                pledgedAmountByRewardedPlatform,
                pledgedAmountByOtherPlatforms
            );
        disburseFee(rewardedClient, feeShareByRewardedPlatform);
        disburseFees(platforms, feeShareByOtherPlatforms);
    }
}
