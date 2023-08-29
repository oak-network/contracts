// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ICampaignRegistry.sol";

contract CampaignRegistry is Ownable, ICampaignRegistry {
    address factoryAddress;
    address treasuryFactoryAddress;
    bool initialized;
    mapping(bytes32 => address) identifierHashToAddress;

    error CampaignRegistryNotInitialized();
    error CampaignRegistryNotAuthorized();
    error CampaignRegistryCampaignInfoNotRegistered(address campaignAddress);

    function initialize(address _factoryAddress) external onlyOwner {
        factoryAddress = _factoryAddress;
        initialized = true;
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
        if (!initialized) {
            revert CampaignRegistryNotInitialized();
        }
    }

    function _checkIfCampaignFactory() internal view {
        if (msg.sender != factoryAddress) {
            revert CampaignRegistryNotAuthorized();
        }
    }

    function getFactoryAddress()
        external
        view
        override
        isInitialized
        returns (address)
    {
        return factoryAddress;
    }

    function getTreasuryFactoryAddress() external view override isInitialized returns (address) {
        return treasuryFactoryAddress;
    }

    function getCampaignInfoAddress(
        bytes32 identifier
    ) external view override isInitialized returns (address campaignAddress) {
        campaignAddress = identifierHashToAddress[identifier];
        if (campaignAddress == address(0)) {
            revert CampaignRegistryCampaignInfoNotRegistered(campaignAddress);
        }
    }

    function setCampaignInfoAddress(
        bytes32 identifierHash,
        address campaignAddress
    ) external override isInitialized onlyFactory {
        identifierHashToAddress[identifierHash] = campaignAddress;
    }
}
