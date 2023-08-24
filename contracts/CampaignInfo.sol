// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Interface/ICampaignInfo.sol";
import "./Interface/ICampaignTreasury.sol";
import "./Interface/ICampaignRegistry.sol";

contract CampaignInfo is ICampaignInfo, Ownable {
    address public registry;
    address public creator;
    address public token;
    uint256 public launchTime;
    uint256 public deadline;
    uint256 public goal;
    bytes32[] private allowedPlatforms;

    mapping(bytes32 => address) public treasury;

    string identifier; //@audit-info if `identifier` can be at most 32-bytes long use bytes32 instead for gas optimization

    constructor(
        address _registry,
        address _creator,
        address _token,
        uint256 _launchTime,
        uint256 _deadline,
        uint256 _goal,
        string memory _identifier, //@audit-info use calldata for gas optimization
        bytes32[] memory _platforms // @audit-info use calldata for gas optimization
    ) {
        // @audit-info lacks zero address checking
        // @audit-info `_launchTime` can be set any value to the past. Check `_launchTime` value
        // @audit-info lacks `_goal` value zero checking
        registry = _registry;
        creator = _creator;
        token = _token;
        launchTime = _launchTime;
        deadline = _deadline;
        goal = _goal;
        identifier = _identifier;
        allowedPlatforms = _platforms;
        transferOwnership(_creator);
    }

    function platforms() public view override returns (bytes32[] memory) {
        return allowedPlatforms;
    }

    // @audit-info `totalCurrentBalance()` and `totalRaisedBalance()` functions are almost identical, with only one line difference.
    // These two functions can be replaced with one function and it will reduce the byte code size. 
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
