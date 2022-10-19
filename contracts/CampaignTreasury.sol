// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./CampaignOracle.sol";
import "./CampaignInfo.sol";

contract CampaignTreasury is Ownable {
    address oracleAddress;
    address infoAddress;
    bytes32 public clientId;
    uint256 feePercent;
    uint256 pledgedAmount;
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

    function getPledgeAmount() public view returns(uint256) {
        //return CampaignOracle(oracleAddress).getPledgeAmountForClient(clientId, infoAddress);
        return pledgedAmount;
    }

    // Old - not required by current API endpoints
    function getCollectableByCreator() public view returns(uint256 collectableAmount) {
        return CampaignOracle(oracleAddress).getPledgeAmountForClient(clientId, infoAddress) * 
        feePercent / percentDivider;
    }

    function setPledgeAmount(uint256 _pledgedAmount) public onlyOwner {
        pledgedAmount = _pledgedAmount;
    }
}