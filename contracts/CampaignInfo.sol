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

contract CampaignInfo is ICampaignInfo, Ownable {
    address public registry;
    address public creator;
    address public token;
    uint256 public launchTime;
    uint256 public deadline;
    uint256 public goal;
    bytes32[] public platforms;

    mapping(bytes32 => address) public treasury;

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

    function setPlatformInfo(
        bytes32 _platform,
        address _treasury
    ) external override onlyOwner {
        treasury[_platform] = _treasury;
    }

    function transferOwnership(
        address newOwner
    ) public override(ICampaignInfo, Ownable) {
        super.transferOwnership(newOwner);
    }

}

