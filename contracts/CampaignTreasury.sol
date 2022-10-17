// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./CampaignOracle.sol";
import "./CampaignInfo.sol";

contract CampaignTreasury {
    address oracleAddress;
    address infoAddress;
    bytes32 clientId;
    uint256 feePercent;
    uint256 public constant percentDivider = 10000;

    constructor(
        address _oracleAddress,
        address _infoAddress,
        bytes32 _clientId,
        uint256 _feePercent
    ) {
        oracleAddress = _oracleAddress;
        infoAddress = _infoAddress;
        clientId = _clientId;
        feePercent = _feePercent;
    }

    function getPledgeAmount() public view returns(uint256 pledgedAmount) {
        return CampaignOracle(oracleAddress).getPledgeAmountForClient(clientId, infoAddress);
    }

    function getCollectableByCreator() public view returns(uint256 collectableAmount) {
        return CampaignOracle(oracleAddress).getPledgeAmountForClient(clientId, infoAddress) * 
        feePercent / percentDivider;
    }
}