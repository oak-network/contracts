// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ICampaignRegistry.sol";

contract CampaignRegistry is Ownable, ICampaignRegistry {
    address private s_camapaignFactoryAddress;
    address private s_treasuryFactoryAddress;
    bool private s_initialized;
    mapping(bytes32 => address) private s_identifierHashToAddress;

    error CampaignRegistryNotInitialized();
    error CampaignRegistryNotAuthorized();
    error CampaignRegistryCampaignInfoNotRegistered(address campaignAddress);

    function _initialize(
        address campaignfactoryAddress,
        address treasuryFactoryAddress
    ) external onlyOwner {
        s_camapaignFactoryAddress = campaignfactoryAddress;
        s_treasuryFactoryAddress = treasuryFactoryAddress;
        s_initialized = true;
    }

    modifier onlyFactory() {
        _checkIfCampaignFactory();
        _;
    }

    modifier isInitialized() {
        _checkIfInitialized();
        _;
    }

    function _checkIfInitialized() internal view {
        if (!s_initialized) {
            revert CampaignRegistryNotInitialized();
        }
    }

    function _checkIfCampaignFactory() internal view {
        if (msg.sender != s_camapaignFactoryAddress) {
            revert CampaignRegistryNotAuthorized();
        }
    }

    function getCampaignInfoFactoryAddress()
        external
        view
        override
        isInitialized
        returns (address)
    {
        return s_camapaignFactoryAddress;
    }

    function getTreasuryFactoryAddress()
        external
        view
        override
        isInitialized
        returns (address)
    {
        return s_treasuryFactoryAddress;
    }

    function getCampaignInfoAddress(
        bytes32 identifierHash
    ) external view override isInitialized returns (address campaignAddress) {
        campaignAddress = s_identifierHashToAddress[identifierHash];
        if (campaignAddress == address(0)) {
            revert CampaignRegistryCampaignInfoNotRegistered(campaignAddress);
        }
    }

    function setCampaignInfoAddress(
        bytes32 identifierHash,
        address campaignAddress
    ) external override isInitialized onlyFactory {
        s_identifierHashToAddress[identifierHash] = campaignAddress;
    }
}
