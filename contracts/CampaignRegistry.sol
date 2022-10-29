// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./CampaignTreasury.sol";

contract CampaignRegistry is Ownable {
    address factoryAddress;
    address oracleAddress;
    bool initialized;
    mapping(string => address) campaignIdentifierToAddress;

    function initialize(address _factoryAddress, address _oracleAddress)
        public
        onlyOwner
    {
        factoryAddress = _factoryAddress;
        oracleAddress = _oracleAddress;
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

    function getOracleAddress() public view isInitialized returns (address) {
        return oracleAddress;
    }

    function getFactoryAddress() public view isInitialized returns (address) {
        return factoryAddress;
    }

    function getCampaignInfoAddress(string calldata identifier)
        public
        view
        isInitialized
        returns (address)
    {
        return campaignIdentifierToAddress[identifier];
    }

    function setCampaignInfoAddress(
        string calldata identifier,
        address campaignAddress
    ) public isInitialized onlyFactory {
        campaignIdentifierToAddress[identifier] = campaignAddress;
    }
}
