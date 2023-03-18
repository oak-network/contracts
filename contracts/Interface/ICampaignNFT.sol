// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface ICampaignNFT {
    function safeMint(
        address backer,
        address token,
        uint256 pledgedAmount,
        bytes32 platformId
    ) external;
}
