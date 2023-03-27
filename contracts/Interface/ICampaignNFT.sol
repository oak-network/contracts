// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface ICampaignNFT {
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
        );

    function burn(uint256 tokenId) external;

    function safeMint(
        address backer,
        address token,
        uint256 pledgedAmount,
        bytes32 platformId
    ) external;

    function safeMint(
        address backer,
        address token,
        uint256 pledgedAmount,
        bytes32 platformId,
        string calldata rewardName
    ) external;
}
