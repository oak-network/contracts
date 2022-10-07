// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

contract CampaignOracle is Ownable {
    mapping(address => mapping (bytes32 => uint256)) pledgeAcrossClientsByCampaign;

    function setPledgeAmountForClient(bytes32 clientId, address campaignAddress, uint256 pledgeAmount) onlyOwner external {
        pledgeAcrossClientsByCampaign[campaignAddress][clientId] = pledgeAmount;
    }

    function getPledgeAmountForClient(bytes32 clientId, address campaignAddress) public view returns(uint256) {
        return pledgeAcrossClientsByCampaign[campaignAddress][clientId];
    }
}