// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

contract CampaignRegistry is Ownable {
    
    address factoryAddress;
    address oracleAddress;
    mapping(uint256 => address) public campaignIdToAddress;

    constructor(address _factoryAddress, address _oracleAddress) {
        factoryAddress = _factoryAddress;
        oracleAddress = _oracleAddress;
    }

    modifier onlyFactory() {
        require(msg.sender == factoryAddress);
        _;
    }

    function getCampaignInfoAddress(uint256 campaignId) public view returns(address) {
        return campaignIdToAddress[campaignId];
    }

    function setCampaignInfoAddress(uint256 campaignId, address campaignAddress) public onlyFactory returns(bool) {
        campaignIdToAddress[campaignId] = campaignAddress;
        return true;
    }

}