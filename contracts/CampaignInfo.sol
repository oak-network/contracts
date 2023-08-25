// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Interface/ICampaignInfo.sol";
import "./Interface/ICampaignTreasury.sol";
import "./Interface/ICampaignRegistry.sol";
   
contract CampaignInfo is ICampaignInfo, Ownable {
    address public immutable GLOBAL_PARAMS;
    address public immutable TOKEN;
    bytes32 public identifierHash;
    uint256 public launchTime;
    uint256 public deadline;
    uint256 public goalAmount;
    bytes32[] private selectedPlatformBytes;

    mapping(bytes32 => address) public platformTreasuryAddress;


    constructor(
        address _globalParams,
        address _token,
        bytes32 _identifierHash,
        address _creator,
        uint256 _launchTime,
        uint256 _deadline,
        uint256 _goalAmount,
        bytes32[] memory _selectedPlatformBytes
    ) {
        GLOBAL_PARAMS = _globalParams;
        TOKEN = _token;
        launchTime = _launchTime;
        deadline = _deadline;
        goalAmount = _goalAmount;
        identifierHash = _identifierHash;
        selectedPlatformBytes = _selectedPlatformBytes;
        transferOwnership(_creator);
    }

    function platforms() public view override returns (bytes32[] memory) {
        return allowedPlatforms;
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
        bytes32 _platform,
        address _treasury
    ) external override onlyOwner {
        treasury[_platform] = _treasury;
    }

    function transferOwnership(
        address newOwner
    ) public override(ICampaignInfo, Ownable) onlyOwner {
        super.transferOwnership(newOwner);
    }

    function updateLaunchTime(uint256 _launchTime) external onlyOwner {
        launchTime = _launchTime;
    }

    function updateDeadline(uint256 _deadline) external onlyOwner {
        deadline = _deadline;
    }

    function updateGoal(uint256 _goal) external onlyOwner {
        goal = _goal;
    }
}
