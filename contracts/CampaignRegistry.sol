// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Interface/ICampaignRegistry.sol";

contract CampaignRegistry is Ownable, ICampaignRegistry {
    address factoryAddress;
    bool initialized;
    mapping(string => address) campaignIdentifierToAddress;

    function initialize(address _factoryAddress) external onlyOwner {
        factoryAddress = _factoryAddress;
        initialized = true;
    }

    modifier onlyFactory() {
        require(msg.sender == factoryAddress);
        _;
    }

    modifier isInitialized() {
        require(initialized);
        _;
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

    function getCampaignInfoAddress(
        string calldata identifier
    ) external view override isInitialized returns (address) {
        require(
            campaignIdentifierToAddress[identifier] != address(0),
            "CampaignRegistry: CampaignInfo not created"
        );
        return campaignIdentifierToAddress[identifier];
    }

    function setCampaignInfoAddress(
        string calldata _identifier,
        address _campaignAddress
    ) external override isInitialized onlyFactory {
        campaignIdentifierToAddress[_identifier] = _campaignAddress;
    }
}
