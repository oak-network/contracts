// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./CampaignRegistry.sol";
import "./CampaignInfo.sol";

contract CampaignOracle is Ownable {
    function setPledgedAmountForClient(
        bytes32 clientId,
        address campaignAddress,
        uint256 pledgedAmount
    ) external onlyOwner {
        CampaignTreasury(
            CampaignInfo(campaignAddress).getTreasuryAddress(clientId)
        ).setPledgedAmount(pledgedAmount);
    }

    function getPledgedAmountForClient(
        bytes32 clientId,
        address campaignAddress
    ) public view returns (uint256) {
        return
            CampaignTreasury(
                CampaignInfo(campaignAddress).getTreasuryAddress(clientId)
            ).getPledgedAmount();
    }

    function getTotalPledgedAmount(address campaignAddress)
        public
        view
        returns (uint256)
    {
        return CampaignInfo(campaignAddress).getTotalPledgedAmount();
    }
}
