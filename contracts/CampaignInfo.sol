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

    enum State {
        LaunchNotSet,
        LaunchSet,
        Live,
        Over
    }

    mapping(string => Reward) rewards;
    mapping(string => Item) items;

    CampaignData campaign;
    address registryAddress;
    bool ended;
    uint256 minCampaignTime;
    bool launchReady;
    bool latePledgeEnabled;
    bytes32 public rewardedPlatform;
    uint256 public specifiedTime;

    mapping(bytes32 => address) treasuryAddress;
    mapping(bytes32 => address) tokens;
    mapping(bytes32 => address) platformWallet;
    mapping(address => mapping(bytes32 => uint256)) backerPledgeInfoForPlatforms;
    mapping(address => bool) earlyBackers;

    constructor(
        string memory _identifier,
        bytes32 _originPlatform,
        string memory _creatorUrl,
        bytes32[] memory _reachPlatform,
        address _registryAddress,
        address _creator
    ) {
        campaign.identifier = _identifier;
        campaign.originPlatform = _originPlatform;
        campaign.createdAt = uint256(block.timestamp);
        campaign.creatorUrl = _creatorUrl;
        campaign.reachPlatforms = _reachPlatform;
        registryAddress = _registryAddress;
        specifiedTime = block.timestamp;
        transferOwnership(_creator);
    }

    modifier treasuryIsSet(bytes32 platformId) {
        require(
            treasuryAddress[platformId] != address(0),
            "CampaignInfo: Treasury address for platform is not set"
        );
        _;
    }

    modifier notEnded() {
        require(!ended, "CampaignInfo: Campaign ended");
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

    function getState() private view returns (State) {
        // Pre-launch - launch not set
        if (!launchReady) {
            return State.LaunchNotSet;
        }
        // Pre-launch - launch set
        else if (block.timestamp <= campaign.launchTime) {
            return State.LaunchSet;
        }
        // Launch
        else if (block.timestamp < campaign.deadline) {
            return State.Live;
        }
        // Over
        else {
            return State.Over;
        }
    }

    function setLaunch(
        uint256 launchTime,
        uint256 deadline,
        uint256 goalAmount,
        bool enableLatePledge
    ) external {
        // if (getState() != State.LaunchNotSet) {
        //     revert("CampaignInfo: Launch already set");
        // }
        campaign.launchTime = launchTime;
        campaign.deadline = deadline;
        campaign.goalAmount = goalAmount;
        latePledgeEnabled = enableLatePledge;
        launchReady = true;
    }

    function addItem(
        string calldata name,
        string calldata description
    ) external {
        // if (getState() != State.Live) {
        //     revert("CampaignInfo: Not allowed");
        // }
        items[name].description = description;
    }

    function addReward(
        string calldata name,
        uint256 rewardValue,
        string[] memory itemName,
        uint256[] memory itemQuantity
    ) external {
        // if (getState() != State.Live) {
        //     revert("CampaignInfo: Not allowed");
        // }
        Reward storage reward = rewards[name];
        reward.rewardValue = rewardValue;
        reward.itemId = itemName;
        uint256 len = itemQuantity.length;
        for (uint256 i = 0; i < len; i++) {
            reward.itemQuantity[itemName[i]] = itemQuantity[i];
        }
    }

    function updateLaunchTime(uint256 _launchTime) external notEnded onlyOwner {
        require(_launchTime + minCampaignTime < campaign.deadline);
        campaign.launchTime = _launchTime;
    }

    function updateDeadline(uint256 _deadline) external notEnded onlyOwner {
        require(campaign.launchTime + minCampaignTime < _deadline);
        campaign.deadline = _deadline;
    }

    function updateGoal(uint256 _goalAmount) external notEnded onlyOwner {
        campaign.goalAmount = _goalAmount;
    }

    function pause() external notEnded onlyOwner {
        // if (getState() != State.Live) {
        //     revert("CampaignInfo: Not Allowed");
        // }
        _pause();
    }

    function unpause() external notEnded onlyOwner {
        // if (getState() != State.Live) {
        //     revert("CampaignInfo: Not Allowed");
        // }
        _unpause();
    }

    function end() external notEnded onlyOwner {
        ended = true;
    }

    function setPlatformInfo(
        bytes32 _platformId,
        address _platformWallet,
        address _treasury,
        address _token
    ) external notEnded onlyOwner {
        platformWallet[_platformId] = _platformWallet;
        treasuryAddress[_platformId] = _treasury;
        tokens[_platformId] = _token;
    }

    function addReachPlatform(bytes32 _platformId) external notEnded onlyOwner {
        campaign.reachPlatforms.push(_platformId);
    }

    function becomeAnEarlyBacker(
        bytes32 platformId,
        address backer
    ) external notEnded whenNotPaused {
        require(!launchReady || campaign.launchTime > block.timestamp);
        address token = tokens[platformId];
        uint256 amount = 1;
        IERC20(token).transferFrom(backer, treasuryAddress[platformId], amount);
        ICampaignNFT(ICampaignRegistry(registryAddress).getCampaignNFTAddress())
            .safeMint(backer, token, amount, platformId);
    }

    function pledgeForAReward(
        bytes32 platformId,
        address backer,
        string calldata rewardName
    ) public notEnded whenNotPaused {
        require(launchReady && campaign.launchTime < block.timestamp);
        address token = tokens[platformId];
        uint256 amount = rewards[rewardName].rewardValue;
        if (earlyBackers[backer]) {
            amount = amount - 1;
            earlyBackers[backer] = false;
        }
        IERC20(token).transferFrom(backer, treasuryAddress[platformId], amount);
        ICampaignNFT(ICampaignRegistry(registryAddress).getCampaignNFTAddress())
            .safeMint(backer, token, amount + 1, platformId, rewardName);
    }

    function pledgeWithoutAReward(
        bytes32 platformId,
        address backer,
        uint256 amount
    ) public notEnded whenNotPaused {
        if (campaign.deadline < block.timestamp) {
            require(
                getTotalPledgedAmountCrypto() >= campaign.goalAmount &&
                    latePledgeEnabled
            );
        }
        require(campaign.launchTime < block.timestamp);
        address token = tokens[platformId];
        IERC20(token).transferFrom(backer, treasuryAddress[platformId], amount);
        backerPledgeInfoForPlatforms[backer][platformId] = amount;
        // ICampaignNFT(ICampaignRegistry(registryAddress).getCampaignNFTAddress())
        //     .safeMint(backer, token, amount, platformId);
    }

    function redeemPledge(address backer, uint256 tokenId) external {
        address campaignNFT = ICampaignRegistry(registryAddress)
            .getCampaignNFTAddress();
        string memory rewardName;
        bytes32 platformId;
        (, , , , , platformId, rewardName) = ICampaignNFT(campaignNFT)
            .getPledgeReceipt(tokenId);
        uint256 rewardValue = rewards[rewardName].rewardValue;
        ICampaignNFT(campaignNFT).burn(tokenId);
        ICampaignTreasury(treasuryAddress[platformId]).disburseFeeToPlatform(
            backer,
            tokens[platformId],
            rewardValue
        );
    }

    function redeemPledge(address backer, uint256 amount, bytes32 platformId) external {
        uint256 pledgedAmount = backerPledgeInfoForPlatforms[backer][platformId];
        require(amount <= pledgedAmount, "CampaignInfo: Invalid Amount");         
        backerPledgeInfoForPlatforms[backer][platformId] = pledgedAmount - amount;
        ICampaignTreasury(treasuryAddress[platformId]).disburseFeeToPlatform(
            backer,
            tokens[platformId],
            amount
        );
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
