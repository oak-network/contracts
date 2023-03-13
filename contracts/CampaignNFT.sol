// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract CampaignNFT is ERC721, AccessControl {
    using Counters for Counters.Counter;

    event pledgeReceipt(
        address indexed backer,
        address indexed campaignInfo,
        address token,
        bytes32 indexed platform,
        uint256 pledgedAmount,
        uint256 timestamp
    );

    struct PledgeReceipt {
        address campaignInfo;
        address backer;
        address token;
        uint256 pledgedAmount;
        uint256 timestamp;
        bytes32 platformId;
    }

    mapping(uint256 => PledgeReceipt) tokenIdToReceipt;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("CampaignNFT", "CNFT") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
