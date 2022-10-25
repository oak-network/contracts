// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./CampaignTreasury.sol";

contract CampaignRegistry is Ownable {
    
    address factoryAddress;
    address oracleAddress;
    bool initialized;
    mapping(uint256 => address) public campaignIdToAddress;

    function initialize(address _factoryAddress, address _oracleAddress) public onlyOwner {
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

    function getOracleAddress() public view isInitialized returns(address) {
        return oracleAddress;
    }

    function getFactoryAddress() public view isInitialized returns(address) {
        return factoryAddress;
    }

    function getCampaignInfoAddress(uint256 campaignId) public view isInitialized returns(address) {
        return campaignIdToAddress[campaignId];
    }

    // function getTreasuryAddress(address campaignAddress, bytes32 clientId) public view returns (address) {
    //     address[] memory temp = campaignInfoToTreasury[campaignAddress];
    //     uint256 length = campaignInfoToTreasury[campaignAddress].length;
    //     for(uint256 i = 0; i < length; i++) {
    //         if (keccak256(abi.encodePacked(CampaignTreasury(temp[i]).clientId)) == keccak256(abi.encodePacked(clientId))) {
    //             return temp[i];
    //         }
    //     }
    //     return address(0);
    // }

    function setCampaignInfoAddress(uint256 campaignId, address campaignAddress) public isInitialized onlyFactory {
        campaignIdToAddress[campaignId] = campaignAddress;
    }

}