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
        uint256 goalAmount;
        uint256 launchTime;
        uint256 createdAt;
        uint256 deadline;
        string creatorUrl;
        bytes32[] reachPlatforms;
    }

    CampaignData campaign;
    address registryAddress;
    bool rewardplatformSet;
    uint256 minCampaignTime;


    /* Hyperparameters */
    uint256 denominator = 2;
    bytes32 rewardedplatform;
    uint256 constant percentDivider = 10000;
    uint256 platformTotalFeePercent;
    uint256 rewardPlatformFeePercent;
    uint256 specifiedTime;

    mapping(bytes32 => address) treasuryAddress;
    mapping(bytes32 => address) tokens;
    mapping(bytes32 => address) platformWallet;
    mapping(address => mapping(bytes32 => uint256)) backerPledgeInfoForPlatforms;

    constructor(
        string memory _identifier,
        bytes32 _originPlatform,
        uint256 _goalAmount,
        uint256 _launchTime,
        uint256 _deadline,
        uint256 _platformTotalFeePercent,
        uint256 _rewardPlatformFeePercent,
        string memory _creatorUrl,
        bytes32[] memory _reachPlatform,
        address _registryAddress
    ) {
        require(
            _launchTime + minCampaignTime < _deadline,
            "CampaignInfo: Minimum campaign duaration not met"
        );
        campaign.identifier = _identifier;
        campaign.originPlatform = _originPlatform;
        campaign.goalAmount = _goalAmount;
        campaign.launchTime = _launchTime;
        campaign.createdAt = uint256(block.timestamp);
        campaign.deadline = _deadline;
        campaign.creatorUrl = _creatorUrl;
        campaign.reachPlatforms = _reachPlatform;
        registryAddress = _registryAddress;
        specifiedTime = block.timestamp;
        platformTotalFeePercent = _platformTotalFeePercent;
        rewardPlatformFeePercent = _rewardPlatformFeePercent;
    }

    function getFeeSplitsProportionately(
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

    function getFeeSplitsProportionatelyWithPlatformReward(
        uint256 totalFeePercent,
        uint256 platformRewardPercent,
        uint256 pledgedAmountByOrigin,
        uint256[] memory pledgedAmountsByReach
    ) public pure returns (uint256, uint256[] memory) {
        uint256 noOfReach = pledgedAmountsByReach.length;
        uint256 reachFeePercent = (totalFeePercent - platformRewardPercent) /
            (noOfReach + 1);
        uint256 feeByOrigin = (pledgedAmountByOrigin *
            (platformRewardPercent + reachFeePercent)) / percentDivider;
        return (
            feeByOrigin,
            getFeeSplitsProportionately(reachFeePercent, pledgedAmountsByReach)
        );
    }

    modifier onlyRegistryOwner() {
        require(msg.sender == CampaignRegistry(registryAddress).owner());
        _;
    }

    modifier treasuryIsSet(bytes32 platformId) {
        require(
            treasuryAddress[platformId] != address(0),
            "CampaignInfo: Treasury address for platform is not set"
        );
        _;
    }

    modifier rewardplatformIsSet() {
        require(rewardplatformSet, "CampaignInfo: Reward platform not set yet");
        _;
    }

    function getBackerPledgeInfoForAPlatform(
        address backer,
        bytes32 platformId
    ) public view returns (uint256) {
        return backerPledgeInfoForPlatforms[backer][platformId];
    }

    function getCampaignData()
        public
        view
        returns (
            string memory,
            uint256,
            uint256,
            uint256,
            uint256,
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

    function getPledgedAmountForAPlatformCrypto(
        bytes32 platformId
    ) public view returns (uint256) {
        return
            IERC20(tokens[platformId]).balanceOf(treasuryAddress[platformId]);
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

    function getFeeSplitsProportionately() public view returns (uint256) {}

    function getTreasuryAddress(
        bytes32 platformId
    ) public view treasuryIsSet(platformId) returns (address) {
        return treasuryAddress[platformId];
    }

    function editLaunchTime(uint256 _launchTime) external onlyRegistryOwner {
        require(_launchTime + minCampaignTime < campaign.deadline);
        campaign.launchTime = _launchTime;
    }

    function editDeadline(uint256 _deadline) external onlyRegistryOwner {
        require(campaign.launchTime + minCampaignTime < _deadline);
        campaign.deadline = _deadline;
    }

    function editGoal(uint256 _goalAmount) external onlyRegistryOwner {
        campaign.goalAmount = _goalAmount;
    }

    function setplatformInfo(
        bytes32 _platformId,
        address _platformWallet,
        address _treasury,
        address _token
    ) external onlyRegistryOwner {
        platformWallet[_platformId] = _platformWallet;
        treasuryAddress[_platformId] = _treasury;
        tokens[_platformId] = _token;
    }

    function addReachPlatform(bytes32 _platformId) external onlyRegistryOwner {
        campaign.reachPlatforms.push(_platformId);
    }

    function pledgeThroughPlatform(
        bytes32 platformId,
        address backer,
        uint256 amount
    ) public {
        if (
            !rewardplatformSet &&
            getPledgedAmountForPlatformCrypto(platformId) >=
            campaign.goalAmount / denominator &&
            block.timestamp >= specifiedTime
        ) {
            rewardplatformSet = true;
            rewardedplatform = platformId;
        }
        IERC20(tokens[platformId]).transferFrom(
            backer,
            treasuryAddress[platformId],
            amount
        );
        backerPledgeInfoForPlatforms[backer][platformId] = amount;
    }

    function disburseFee(bytes32 _platformId, uint256 _feeShare) public {
        if (_feeShare > 0 && treasuryAddress[_platformId] != address(0)) {
            CampaignTreasury(treasuryAddress[_platformId])
                .disburseFeeToPlatform(
                    platformWallet[_platformId],
                    tokens[_platformId],
                    _feeShare
                );
        }
    }

    function disburseFees(
        bytes32[] memory _platformIds,
        uint256[] memory _feeShares
    ) internal {
        uint256 length = _platformIds.length;
        for (uint256 i = 0; i < length; i++) {
            disburseFee(_platformIds[i], _feeShares[i]);
        }
    }

    function getPledgedAmountForPlatformCrypto(
        bytes32 platformId
    ) public view treasuryIsSet(platformId) returns (uint256) {
        return
            IERC20(tokens[platformId]).balanceOf(treasuryAddress[platformId]);
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
    //         pledgedAmountByPlatforms[i - 1] = getPledgedAmountForPlatformCrypto(
    //             tempReachPlatforms[i - 1]
    //         );
    //     }
    //     uint256[] memory feeShareByPlatforms = getFeeSplitsProportionately(
    //         platformTotalFeePercent,
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
            pledgedAmountByPlatforms[i] = getPledgedAmountForPlatformCrypto(
                tempReachPlatforms[i]
            );
        }
        tempPlatforms[tempReachPlatforms.length] = campaign.originPlatform;
        pledgedAmountByPlatforms[
            tempReachPlatforms.length
        ] = getPledgedAmountForPlatformCrypto(campaign.originPlatform);
        uint256[] memory feeShareByPlatforms = getFeeSplitsProportionately(
            platformTotalFeePercent,
            pledgedAmountByPlatforms
        );
        disburseFees(tempPlatforms, feeShareByPlatforms);
    }

    function splitFeeWithRewards() public rewardplatformIsSet {
        uint256 feePercent = platformTotalFeePercent;
        uint256 rewardPercent = rewardPlatformFeePercent;
        uint256 pledgedAmountByRewardedPlatform = getPledgedAmountForPlatformCrypto(
                rewardedplatform
            );
        bytes32[] memory tempReachPlatforms = campaign.reachPlatforms;
        uint256[] memory pledgedAmountByOtherPlatforms = new uint256[](
            tempReachPlatforms.length
        );
        bytes32 tempOriginPlatform = campaign.originPlatform;
        bytes32[] memory platforms = new bytes32[](tempReachPlatforms.length);
        if (rewardedplatform == tempOriginPlatform) {
            for (uint256 i = 0; i < tempReachPlatforms.length; i++) {
                pledgedAmountByOtherPlatforms[
                    i
                ] = getPledgedAmountForPlatformCrypto(tempReachPlatforms[i]);
            }
        } else {
            uint256 i = 0;
            pledgedAmountByOtherPlatforms[
                i
            ] = getPledgedAmountForPlatformCrypto(tempOriginPlatform);
            platforms[i] = tempOriginPlatform;
            for (i = 1; i <= tempReachPlatforms.length; i++) {
                if (tempReachPlatforms[i - 1] != rewardedplatform) {
                    platforms[i] = tempReachPlatforms[i - 1];
                    pledgedAmountByOtherPlatforms[
                        i
                    ] = getPledgedAmountForPlatformCrypto(
                        tempReachPlatforms[i]
                    );
                }
            }
        }
        (
            uint256 feeShareByRewardedPlatform,
            uint256[] memory feeShareByOtherPlatforms
        ) = getFeeSplitsProportionatelyWithPlatformReward(
                feePercent,
                rewardPercent,
                pledgedAmountByRewardedPlatform,
                pledgedAmountByOtherPlatforms
            );
        disburseFee(rewardedplatform, feeShareByRewardedPlatform);
        disburseFees(platforms, feeShareByOtherPlatforms);
    }

    function splitFeeWithVelocityOfFundraising() public rewardplatformIsSet {
        uint256 feePercent = platformTotalFeePercent;
        uint256 rewardPercent = rewardPlatformFeePercent;
        uint256 pledgedAmountByRewardedPlatform = getPledgedAmountForPlatformCrypto(
                rewardedplatform
            );
        bytes32[] memory tempReachPlatforms = campaign.reachPlatforms;
        uint256[] memory pledgedAmountByOtherPlatforms = new uint256[](
            tempReachPlatforms.length
        );
        bytes32 tempOriginPlatform = campaign.originPlatform;
        bytes32[] memory platforms = new bytes32[](tempReachPlatforms.length);
        if (rewardedplatform == tempOriginPlatform) {
            for (uint256 i = 0; i < tempReachPlatforms.length; i++) {
                pledgedAmountByOtherPlatforms[
                    i
                ] = getPledgedAmountForPlatformCrypto(tempReachPlatforms[i]);
            }
        } else {
            uint256 i = 0;
            pledgedAmountByOtherPlatforms[
                i
            ] = getPledgedAmountForPlatformCrypto(tempOriginPlatform);
            platforms[i] = tempOriginPlatform;
            for (i = 1; i <= tempReachPlatforms.length; i++) {
                if (tempReachPlatforms[i - 1] != rewardedplatform) {
                    platforms[i] = tempReachPlatforms[i - 1];
                    pledgedAmountByOtherPlatforms[
                        i
                    ] = getPledgedAmountForPlatformCrypto(
                        tempReachPlatforms[i]
                    );
                }
            }
        }
        (
            uint256 feeShareByRewardedPlatform,
            uint256[] memory feeShareByOtherPlatforms
        ) = getFeeSplitsProportionatelyWithPlatformReward(
                feePercent,
                rewardPercent,
                pledgedAmountByRewardedPlatform,
                pledgedAmountByOtherPlatforms
            );
        disburseFee(rewardedplatform, feeShareByRewardedPlatform);
        disburseFees(platforms, feeShareByOtherPlatforms);
    }
}
