// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract CampaignNFT is ERC721Burnable, AccessControl {
    using Counters for Counters.Counter;

    event pledgeReceipt(
        address indexed backer,
        address indexed campaignInfo,
        address token,
        bytes32 indexed platform,
        uint256 pledgedAmount,
        uint256 timestamp,
        uint256 tokenId,
        string rewardName
    );

    struct PledgeReceipt {
        address campaignInfo;
        address backer;
        address token;
        uint256 pledgedAmount;
        uint256 timestamp;
        bytes32 platformId;
        string rewardName;
    }

    mapping(uint256 => PledgeReceipt) tokenIdToReceipt;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    Counters.Counter private _tokenIdCounter;

    constructor(address _registry) ERC721("CampaignNFT", "CNFT") {
        _grantRole(DEFAULT_ADMIN_ROLE, _registry);
    }

    function grantRole(
        address _campaignInfo
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MINTER_ROLE, _campaignInfo);
    }

    function getPledgeReceipt(
        uint256 tokenId
    )
        external
        view
        returns (
            address campaignInfo,
            address backer,
            address token,
            uint256 pledgedAmount,
            uint256 timestamp,
            bytes32 platformId,
            string memory rewardName
        )
    {
        PledgeReceipt memory receipt = tokenIdToReceipt[tokenId];
        campaignInfo = receipt.campaignInfo;
        backer = receipt.backer;
        pledgedAmount = receipt.pledgedAmount;
        token = receipt.token;
        timestamp = receipt.timestamp;
        platformId = receipt.platformId;
        rewardName = receipt.rewardName;
    }

    function safeMint(
        address backer,
        address token,
        uint256 pledgedAmount,
        bytes32 platformId
    ) public onlyRole(MINTER_ROLE) returns(uint256 tokenId) {
        tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(backer, tokenId);
        PledgeReceipt storage receipt = tokenIdToReceipt[tokenId];
        receipt.campaignInfo = msg.sender;
        receipt.backer = backer;
        receipt.token = token;
        receipt.pledgedAmount = pledgedAmount;
        receipt.timestamp = block.timestamp;
        receipt.platformId = platformId;
        emit pledgeReceipt(
            backer,
            msg.sender,
            token,
            platformId,
            pledgedAmount,
            block.timestamp,
            tokenId,
            ""
        );
    }

    function safeMint(
        address backer,
        address token,
        uint256 pledgedAmount,
        bytes32 platformId,
        string calldata rewardName
    ) public onlyRole(MINTER_ROLE) returns(uint256 tokenId) {
        tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(backer, tokenId);
        PledgeReceipt storage receipt = tokenIdToReceipt[tokenId];
        receipt.campaignInfo = msg.sender;
        receipt.backer = backer;
        receipt.token = token;
        receipt.pledgedAmount = pledgedAmount;
        receipt.timestamp = block.timestamp;
        receipt.platformId = platformId;
        receipt.rewardName = rewardName;
        emit pledgeReceipt(
            backer,
            msg.sender,
            token,
            platformId,
            pledgedAmount,
            block.timestamp,
            tokenId,
            rewardName
        );
    }

    function burn(
        uint256 tokenId
    ) public virtual override onlyRole(MINTER_ROLE) {
        _burn(tokenId);
        delete tokenIdToReceipt[tokenId];
    }

    // The following functions are overrides required by Solidity.
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
