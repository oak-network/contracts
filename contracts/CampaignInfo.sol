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

    address public registry;
    address public creator;
    address public token;
    uint256 public launchTime;
    uint256 public deadline;
    uint256 public goal;
    bytes32 public platforms;

    mapping (bytes32 => address) public treasury;

    string identifier;

    constructor(
        address _registry,
        address _creator,
        address _token,
        uint256 _launchTime,
        uint256 _deadline,
        uint256 _goal,
        string memory _identifier,
        bytes32[] memory _platforms
    ) {
        identifier = _identifier;
        registry = _registry;
        platforms = _platforms;
        transferOwnership(_creator);
    }

    modifier treasuryIsSet(bytes32 platformId) {
        require(
            treasury[platformId] != address(0),
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

    function totalCurrentBalance() public view override returns (uint256) {
        bytes32[] memory tempPlatforms = platforms;
        uint256 length = platforms.length;
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
        bytes32[] memory tempPlatforms = platforms;
        uint256 length = platforms.length;
        uint256 balance = 0;
        address tempToken = token;
        for (uint256 i = 0; i < length; i++) {
            address tempTreasury = treasury[tempPlatforms[i]];
            if (tempTreasury != address(0)) {
                balance += ICampaignTreasury(tempTreasury).raisedBalance();
            }
        }
        return balance;        
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
        bytes32 _platform,
        address _treasury
    ) external notEnded onlyOwner {
        treasury[_platform] = _treasury;
    }

    function transferOwnership(
        address newOwner
    ) public override(ICampaignInfo, Ownable) {
        super.transferOwnership(newOwner);
    }
}
