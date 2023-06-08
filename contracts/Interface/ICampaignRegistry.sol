// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface ICampaignRegistry {
    function initialize(
        address _factoryAddress,
        address _oracleAddress,
        address _campaignNFTAddress,
        address _campaignGlobalParemeters,
        address _campaignFeeSplitter
    ) external;

    function owner() external view returns (address);
    
    function getOracleAddress() external view returns (address);

    function getFactoryAddress() external view returns (address);

    function getCampaignNFTAddress() external view returns (address);

    function getCampaignGlobalParameters() external view returns (address);

    function getCampaignFeeSplitter() external view returns (address);

    function getCampaignContainers() external view returns (address);

    function getCampaignInfoAddress(
        string calldata identifier
    ) external view returns (address);

    function setCampaignInfoAddress(
        string calldata _identifier,
        address _campaignAddress
    ) external;
}
