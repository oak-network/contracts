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

    // The following functions are overrides required by Solidity.

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
