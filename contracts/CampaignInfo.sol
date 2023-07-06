// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Interface/ICampaignInfo.sol";
import "./Interface/ICampaignGlobalParameters.sol";
import "./Interface/ICampaignFeeSplitter.sol";
import "./Interface/ICampaignTreasury.sol";
import "./Interface/ICampaignRegistry.sol";
import "./Interface/ICampaignNFT.sol";
import "./Interface/ICampaignContainers.sol";

contract CampaignInfo is ICampaignInfo, Ownable, Pausable {
    CampaignData data;
    CampaignPlatforms platforms;
    CampaignState state;

    constructor(
        string memory _identifier,
        string memory _creatorUrl,
        address _registryAddress,
        address _creator,
        uint256 _earlyPledgeAmount,
        bytes32 _originPlatform,
        bytes32[] memory _reachPlatform
    ) {
        data.identifier = _identifier;
        data.creatorUrl = _creatorUrl;
        data.registry = _registryAddress;
        data.earlyPledgeAmount = _earlyPledgeAmount;
        platforms.originPlatform = _originPlatform;
        platforms.reachPlatforms = _reachPlatform;
        transferOwnership(_creator);
    }

    modifier treasuryIsSet(bytes32 platformId) {
        require(
            state.treasuries[platformId] != address(0),
            "CampaignInfo: Treasury address for platform is not set"
        );
        _;
    }

    modifier notEnded() {
        require(!state.ended, "CampaignInfo: data ended");
        _;
    }

    modifier isLive() {
        require(
            data.launchTime < block.timestamp,
            "CampaignInfo: data is not live yet"
        );
        _;
    }

    modifier isProtocolAdmin() {
        require(
            ICampaignGlobalParameters(
                ICampaignRegistry(data.registry).getCampaignGlobalParameters()
            ).protocol() == msg.sender
        );
        _;
    }

    modifier isPlatformAdmin(bytes32 platformHex) {
        require(
            ICampaignGlobalParameters(
                ICampaignRegistry(data.registry).getCampaignGlobalParameters()
            ).platformAdmin(platformHex) == msg.sender
        );
        _;
    }

    modifier platformNotPaused(bytes32 platformHex) {
        require(!state.pausedPlatforms[platformHex]);
        _;
    }

    function getBackerPledgeInfoForAPlatform(
        address backer,
        bytes32 platformId
    ) public view returns (uint256) {
        return state.backerPledgeInfoForPlatforms[backer][platformId];
    }

    function getCampaignData()
        public
        view
        returns (string memory, uint256, uint256, uint256, string memory)
    {
        return (
            data.identifier,
            data.goalAmount,
            data.launchTime,
            data.deadline,
            data.creatorUrl
        );
    }

    function getCampaignOriginPlatform() public view returns (bytes32) {
        return platforms.originPlatform;
    }

    function getCampaignReachPlatforms()
        public
        view
        returns (bytes32[] memory)
    {
        return platforms.reachPlatforms;
    }

    function getPledgedAmountForAPlatformCrypto(
        bytes32 platformId
    ) public view returns (uint256) {
        return
            IERC20(state.tokens[platformId]).balanceOf(
                state.treasuries[platformId]
            );
    }

    function getTotalPledgedAmountCrypto() public view returns (uint256) {
        address tempOriginPlatform = state.treasuries[platforms.originPlatform];
        require(
            tempOriginPlatform != address(0),
            "CampaignInfo: Origin platform treasury not set yet"
        );
        bytes32[] memory tempReachPlatforms = platforms.reachPlatforms;
        uint256 length = tempReachPlatforms.length;
        uint256 pledgedAmount = IERC20(state.tokens[platforms.originPlatform])
            .balanceOf(tempOriginPlatform);
        for (uint256 i = 0; i < length; i++) {
            address tempReachPlatform = state.treasuries[tempReachPlatforms[i]];
            address tempToken = state.tokens[tempReachPlatforms[i]];
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
        return state.treasuries[platformId];
    }

    function _pledge(
        address _token,
        address _treasury,
        address _backer,
        uint256 _amount,
        bool _isFiat
    ) private whenNotPaused {
        if (_isFiat) {
            ICampaignTreasury(_treasury).pledgeInFiat(_amount);
        } else {
            IERC20(_token).transferFrom(_backer, _treasury, _amount);
        }
    }

    function addContainer(
        address creator,
        bytes32 id,
        ICampaignContainers.Container memory container
    ) external onlyOwner {
        ICampaignContainers(
            ICampaignRegistry(data.registry).getCampaignContainers()
        ).addContainer(creator, id, container);
    }

    function setLaunch(
        uint256 launchTime,
        uint256 deadline,
        uint256 goalAmount,
        bool enableLatePledge
    ) external onlyOwner {
        data.launchTime = launchTime;
        data.deadline = deadline;
        data.goalAmount = goalAmount;
        state.latePledgeEnabled = enableLatePledge;
        state.launchReady = true;
    }

    function updateLaunchTime(uint256 _launchTime) external notEnded onlyOwner {
        require(_launchTime + state.minCampaignTime < data.deadline);
        data.launchTime = _launchTime;
    }

    function updateDeadline(uint256 _deadline) external notEnded onlyOwner {
        require(data.launchTime + state.minCampaignTime < _deadline);
        data.deadline = _deadline;
    }

    function updateGoal(uint256 _goalAmount) external notEnded onlyOwner {
        data.goalAmount = _goalAmount;
    }

    function pause() external notEnded isProtocolAdmin {
        _pause();
    }

    function unpause() external notEnded isProtocolAdmin {
        _unpause();
    }

    function pauseOrUnpauseForPlatform(
        bytes32 platformHex,
        bool paused
    ) external isPlatformAdmin(platformHex) {
        state.pausedPlatforms[platformHex] = paused;
    }

    function end() external notEnded isProtocolAdmin {
        state.ended = true;
    }

    function setPlatformInfo(
        bytes32 _platformId,
        address _treasury,
        address _token
    ) external notEnded onlyOwner {
        state.treasuries[_platformId] = _treasury;
        state.tokens[_platformId] = _token;
    }

    function addReachPlatform(bytes32 _platformId) external notEnded onlyOwner {
        platforms.reachPlatforms.push(_platformId);
    }

    function becomeAnEarlyBacker(
        bytes32 platformId,
        address backer,
        bool isFiat
    ) external notEnded whenNotPaused returns (uint256 tokenId) {
        require(
            !state.launchReady || data.launchTime > block.timestamp,
            "CampaignInfo: Not allowed"
        );
        address treasury = state.treasuries[platformId];
        address token = state.tokens[platformId];
        _pledge(token, treasury, backer, data.earlyPledgeAmount, isFiat);
        tokenId = ICampaignNFT(
            ICampaignRegistry(data.registry).getCampaignNFTAddress()
        ).safeMint(backer, token, data.earlyPledgeAmount, platformId);
    }

    function pledgeForAReward(
        bytes32 platformId,
        address backer,
        bytes32 reward,
        bytes32 addOn,
        bool isFiat
    ) public notEnded whenNotPaused returns (uint256 tokenId) {
        require(
            state.launchReady && data.launchTime < block.timestamp,
            "CampaignInfo: Not Allowed"
        );
        address token = state.tokens[platformId];
        uint256 amount = ICampaignContainers(
            ICampaignRegistry(data.registry).getCampaignContainers()
        ).getContainer(owner(), reward) +
            ICampaignContainers(
                ICampaignRegistry(data.registry).getCampaignContainers()
            ).getContainer(owner(), addOn);
        if (state.earlyBackers[backer]) {
            amount = amount - data.earlyPledgeAmount;
            state.earlyBackers[backer] = false;
        }
        _pledge(token, state.treasuries[platformId], backer, amount, isFiat);
        tokenId = ICampaignNFT(
            ICampaignRegistry(data.registry).getCampaignNFTAddress()
        ).safeMint(
                backer,
                token,
                amount + data.earlyPledgeAmount,
                platformId,
                reward
            );
    }

    function pledgeWithoutAReward(
        bytes32 platformId,
        address backer,
        uint256 amount,
        bool isFiat
    ) public notEnded whenNotPaused {
        if (data.deadline < block.timestamp) {
            require(
                getTotalPledgedAmountCrypto() >= data.goalAmount &&
                    state.latePledgeEnabled,
                "CampaignInfo: Not allowed"
            );
        }
        require(data.launchTime < block.timestamp);
        address token = state.tokens[platformId];
        _pledge(token, state.treasuries[platformId], backer, amount, isFiat);
        state.backerPledgeInfoForPlatforms[backer][platformId] += amount;
        // ICampaignNFT(ICampaignRegistry(registryAddress).getCampaignNFTAddress())
        //     .safeMint(backer, token, amount, platformId);
    }

    function claimRefundForAReward(address backer, uint256 tokenId) external {
        address campaignNFT = ICampaignRegistry(data.registry)
            .getCampaignNFTAddress();
        bytes32 reward;
        bytes32 platformId;
        (, , , , , platformId, reward) = ICampaignNFT(campaignNFT)
            .getPledgeReceipt(tokenId);
        uint256 rewardValue = ICampaignContainers(
            ICampaignRegistry(data.registry).getCampaignContainers()
        ).getContainer(owner(), reward);
        ICampaignNFT(campaignNFT).burn(tokenId);
        ICampaignTreasury(state.treasuries[platformId]).disburseFeeToPlatform(
            backer,
            state.tokens[platformId],
            rewardValue
        );
    }

    function claimRefundWithoutAReward(
        address backer,
        uint256 amount,
        bytes32 platformId
    ) external {
        uint256 pledgedAmount = state.backerPledgeInfoForPlatforms[backer][
            platformId
        ];
        require(amount <= pledgedAmount, "CampaignInfo: Invalid Amount");
        state.backerPledgeInfoForPlatforms[backer][platformId] =
            pledgedAmount -
            amount;
        ICampaignTreasury(state.treasuries[platformId]).disburseFeeToPlatform(
            backer,
            state.tokens[platformId],
            amount
        );
    }

    function disburseFee(bytes32 _platformId, uint256 _feeShare) private {
        address treasury = state.treasuries[_platformId];
        address token = state.tokens[_platformId];

        ICampaignRegistry registry = ICampaignRegistry(data.registry);
        ICampaignGlobalParameters globalParams = ICampaignGlobalParameters(
            registry.getCampaignGlobalParameters()
        );

        address platform = globalParams.platformAddresses(_platformId);
        uint256 pledgedAmount = getPledgedAmountForAPlatformCrypto(_platformId);
        if (_feeShare > 0 && treasury != address(0)) {
            ICampaignTreasury(state.treasuries[_platformId])
                .disburseFeeToPlatform(platform, token, _feeShare);
            ICampaignTreasury(treasury).disburseFeeToPlatform(
                globalParams.protocol(),
                token,
                (pledgedAmount * (globalParams.protocolFeePercent())) /
                    globalParams.percentDivider()
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
            IERC20(state.tokens[platformId]).balanceOf(
                state.treasuries[platformId]
            );
    }

    function splitFeesProportionately() public {
        address globalParams = ICampaignRegistry(data.registry)
            .getCampaignGlobalParameters();

        bytes32[] memory tempReachPlatforms = platforms.reachPlatforms;
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
        tempPlatforms[tempReachPlatforms.length] = platforms.originPlatform;
        pledgedAmountByPlatforms[
            tempReachPlatforms.length
        ] = getPledgedAmountForPlatformCrypto(platforms.originPlatform);
        uint256[] memory feeShareByPlatforms = ICampaignFeeSplitter(
            ICampaignRegistry(data.registry).getCampaignFeeSplitter()
        ).getFeeSplitsProportionately(
                ICampaignGlobalParameters(globalParams)
                    .platformTotalFeePercent(),
                ICampaignGlobalParameters(globalParams).percentDivider(),
                pledgedAmountByPlatforms
            );
        disburseFees(tempPlatforms, feeShareByPlatforms);
    }

    function addReward(
        string calldata _rewardId,
        uint256 _rewardValue,
        string calldata _rewardDescription
    ) external override {}

    function addItem(
        string calldata _itemId,
        string calldata _description
    ) external override {}

    function addReward(
        bool isAddOn,
        uint256 rewardValue,
        string calldata name,
        string[] memory itemName,
        uint256[] memory itemQuantity
    ) external override {}

    function setTreasuryAddress(
        bytes32 platformId,
        address treasuryAddress_
    ) external override {}

    function setTokenAddress(
        bytes32 platformId,
        address tokenAddress_
    ) external override {}

    function pledgeCrypto(
        bytes32 platformId,
        uint256 amount,
        bool isEarlyPledge
    ) external override {}

    function transferOwnership(
        address newOwner
    ) public override(ICampaignInfo, Ownable) {
        super.transferOwnership(newOwner);
    }
}
