// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./CampaignTreasury.sol";
import "./CampaignNFT.sol";

contract CampaignRegistry is Ownable {
    address factoryAddress;
    address oracleAddress;
    address campaignNFTAddress;
    bool initialized;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    mapping(string => address) campaignIdentifierToAddress;

    function initialize(address _factoryAddress, address _oracleAddress, address _campaignNFTAddress)
        public
        onlyOwner
    {
        factoryAddress = _factoryAddress;
        oracleAddress = _oracleAddress;
        campaignNFTAddress = _campaignNFTAddress;
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

    function getCampaignNFTAddress() public view isInitialized returns (address) {
        return campaignNFTAddress;
    }    

    function getCampaignInfoAddress(string calldata identifier)
        public
        view
        isInitialized
        returns (address)
    {
        require(
            campaignIdentifierToAddress[identifier] != address(0),
            "CampaignRegistry: CampaignInfo not created"
        );
        return campaignIdentifierToAddress[identifier];
    }

    function setCampaignInfoAddress(
        string calldata _identifier,
        address _campaignAddress
    ) public isInitialized onlyFactory {
        campaignIdentifierToAddress[_identifier] = _campaignAddress;
        CampaignNFT(campaignNFTAddress).grantRole(MINTER_ROLE, _campaignAddress);
        
    }
}
