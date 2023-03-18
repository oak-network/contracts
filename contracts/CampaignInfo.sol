// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Interface/ICampaignGlobalParameters.sol";
import "./Interface/ICampaignFeeSplitter.sol";
import "./Interface/ICampaignTreasury.sol";
import "./Interface/ICampaignRegistry.sol";
import "./Interface/ICampaignNFT.sol";

contract CampaignInfo is Ownable, Pausable {
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

    mapping(string => Reward) rewards;
    mapping(string => Item) items;

    CampaignData campaign;
    address registryAddress;
    bool ended;
    uint256 minCampaignTime;

    bytes32 public rewardedPlatform;
    uint256 public specifiedTime;

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
    }

    modifier treasuryIsSet(bytes32 platformId) {
        require(
            treasuryAddress[platformId] != address(0),
            "CampaignInfo: Treasury address for platform is not set"
        );
        _;
    }

    modifier notEndedOrOver() {
        require(!ended, "CampaignInfo: Campaign ended");
        require(
            block.timestamp < campaign.deadline,
            "CampaignInfo: Campaign over"
        );
        _;
    }

    modifier isLive() {
        require(
            campaign.launchTime < block.timestamp,
            "CampaignInfo: Campaign is not live yet"
        );
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

    function getTreasuryAddress(
        bytes32 platformId
    ) public view treasuryIsSet(platformId) returns (address) {
        return treasuryAddress[platformId];
    }

    function addItem(
        string calldata name,
        string calldata description
    ) external {
        items[name].description = description;
    }

    function addReward(
        string calldata name,
        uint256 rewardValue,
        string[] calldata itemName,
        uint256[] calldata itemQuantity
    ) external {
        Reward storage reward = rewards[name];
        reward.rewardValue = rewardValue;
        reward.itemId = itemName;
        uint256 len = itemQuantity.length;
        for (uint256 i = 0; i < len; i ++) {
            reward.itemQuantity[itemName[i]] = itemQuantity[i];
        }
    }

    function editLaunchTime(
        uint256 _launchTime
    ) external notEndedOrOver onlyOwner {
        require(_launchTime + minCampaignTime < campaign.deadline);
        campaign.launchTime = _launchTime;
    }

    function editDeadline(uint256 _deadline) external notEndedOrOver onlyOwner {
        require(campaign.launchTime + minCampaignTime < _deadline);
        campaign.deadline = _deadline;
    }

    function editGoal(uint256 _goalAmount) external notEndedOrOver onlyOwner {
        campaign.goalAmount = _goalAmount;
    }

    function pause() external isLive notEndedOrOver onlyOwner {
        _pause();
    }

    function unpause() external isLive notEndedOrOver onlyOwner {
        _unpause();
    }

    function end() external notEndedOrOver onlyOwner {
        ended = true;
    }

    function setPlatformInfo(
        bytes32 _platformId,
        address _platformWallet,
        address _treasury,
        address _token
    ) external notEndedOrOver onlyOwner {
        platformWallet[_platformId] = _platformWallet;
        treasuryAddress[_platformId] = _treasury;
        tokens[_platformId] = _token;
    }

    function addReachPlatform(
        bytes32 _platformId
    ) external notEndedOrOver onlyOwner {
        campaign.reachPlatforms.push(_platformId);
    }

    function pledgeThroughPlatform(
        bytes32 platformId,
        address backer,
        uint256 amount
    ) public notEndedOrOver whenNotPaused {
        address token = tokens[platformId];
        IERC20(token).transferFrom(backer, treasuryAddress[platformId], amount);
        backerPledgeInfoForPlatforms[backer][platformId] = amount;
        ICampaignNFT(ICampaignRegistry(registryAddress).getCampaignNFTAddress())
            .safeMint(backer, token, amount, platformId);
    }

    function disburseFee(bytes32 _platformId, uint256 _feeShare) private {
        if (_feeShare > 0 && treasuryAddress[_platformId] != address(0)) {
            ICampaignTreasury(treasuryAddress[_platformId])
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
    ) private {
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

    function splitFeesProportionately() public {
        address globalParams = ICampaignRegistry(registryAddress)
            .getCampaignGlobalParameters();

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
        uint256[] memory feeShareByPlatforms = ICampaignFeeSplitter(
            ICampaignRegistry(registryAddress).getCampaignFeeSplitter()
        ).getFeeSplitsProportionately(
                ICampaignGlobalParameters(globalParams)
                    .platformTotalFeePercent(),
                ICampaignGlobalParameters(globalParams).percentDivider(),
                pledgedAmountByPlatforms
            );
        disburseFees(tempPlatforms, feeShareByPlatforms);
    }
}
