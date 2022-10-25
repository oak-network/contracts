// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./CampaignRegistry.sol";
import "./CampaignInfo.sol";

contract CampaignOracle is Ownable {

    function setPledgeAmountForClient(bytes8 clientId, address campaignAddress, uint256 pledgeAmount) onlyOwner external {
        require(CampaignInfo(campaignAddress).getTreasuryAddress(clientId) != address(0));
        CampaignTreasury(CampaignInfo(campaignAddress).getTreasuryAddress(clientId)).setPledgeAmount(pledgeAmount);
    }

    function getPledgeAmountForClient(bytes8 clientId, address campaignAddress) public view returns(uint256) {
        require(CampaignInfo(campaignAddress).getTreasuryAddress(clientId) != address(0));
        return CampaignTreasury(CampaignInfo(campaignAddress).getTreasuryAddress(clientId)).getPledgeAmount();
    }
}