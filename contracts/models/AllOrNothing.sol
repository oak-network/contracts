// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../Interface/ICampaignTreasury.sol";
import "../Interface/ICampaignInfo.sol";

contract AllOrNothing is ICampaignTreasury, ERC721Burnable {
    using Counters for Counters.Counter;

    address public immutable registry;
    address public immutable infoAddress;
    bytes32 public immutable platformId;
    uint256 constant percentDivider = 10000;
    uint256 public pledgedAmount;
    uint256 public platformFeePercent;
    uint256 public raisedBalance;

    event receipt(
        address indexed backer,
        bytes32 indexed reward,
        uint256 pledgedAmount,
        uint256 tokenId
    );

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    Counters.Counter private _tokenIdCounter;

    struct Item {
        string description;
    }

    struct Reward {
        uint256 rewardValue;
        string rewardDescription;
        bytes32[] itemId;
        mapping(bytes32 => uint256) itemQuantity;
    }

    address token;
    mapping(bytes32 => Reward) rewards;

    constructor(
        address _registryAddress,
        address _infoAddress,
        bytes32 _platformId
    ) ERC721("CampaignNFT", "CNFT") {
        registry = _registryAddress;
        infoAddress = _infoAddress;
        platformId = _platformId;
    }

    function pledge(address backer, bytes32 reward) public {
        uint256 amount = rewards[reward].rewardValue;
        IERC20(token).transferFrom(backer, address(this), amount);
        uint256 tokenId = _tokenIdCounter.current();
        if (reward != 0x00) {
            _tokenIdCounter.increment();
            _safeMint(backer, tokenId);
        }
        emit receipt(backer, reward, amount, tokenId);
    }

    // function burn(uint256 tokenId) private override {
    //     _burn(tokenId);
    // }

    // The following functions are overrides required by Solidity.
    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function getplatformId() public view returns (bytes32) {
        return platformId;
    }

    function getplatformFeePercent() public view returns (uint256) {
        return platformFeePercent;
    }

    function getplatformFee() public view returns (uint256) {
        return (pledgedAmount * platformFeePercent) / percentDivider;
    }

    function getTotalCollectableByCreator() public view returns (uint256) {
        return pledgedAmount - getplatformFee();
    }

    function getPledgedAmount() public view returns (uint256) {
        return pledgedAmount;
    }

    function pledgeInFiat(uint256 amount) external {
        pledgedAmount += amount;
    }

    function setplatformFeePercent(uint256 _platformFeePercent) external {
        platformFeePercent = _platformFeePercent;
    }

    // function raisedBalance() external view override returns (uint256) {}

    function currentBalance() external view override returns (uint256) {
        return IERC20(ICampaignInfo(infoAddress).token()).balanceOf(address(this));
    }
}
