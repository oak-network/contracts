// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./CampaignRegistry.sol";
import "./CampaignInfo.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CampaignTreasury {
    address registryAddress;
    address infoAddress;
    bytes32 clientId;
    uint256 pledgedAmount;
    uint256 clientFeePercent;
    uint256 constant percentDivider = 10000;

    constructor(
        address _registryAddress,
        address _infoAddress,
        bytes32 _clientId
    ) {
        registryAddress = _registryAddress;
        infoAddress = _infoAddress;
        clientId = _clientId;
    }

    modifier onlyCampaignInfo() {
        require(
            msg.sender == infoAddress,
            "CampaignTreasury: Caller is not CampaignInfo contract"
        );
        _;
    }

    function getClientId() public view returns (bytes32) {
        return clientId;
    }

    function getClientFeePercent() public view returns (uint256) {
        return clientFeePercent;
    }

    function getClientFee() public view returns (uint256) {
        return (pledgedAmount * clientFeePercent) / percentDivider;
    }

    function getTotalCollectableByCreator() public view returns (uint256) {
        return pledgedAmount - getClientFee();
    }

    function getPledgedAmount() public view returns (uint256) {
        return pledgedAmount;
    }

    function setClientFeePercent(uint256 _clientFeePercent) public {
        clientFeePercent = _clientFeePercent;
    }

    function setPledgedAmount(uint256 _pledgedAmount) public {
        require(
            CampaignRegistry(registryAddress).getOracleAddress() == msg.sender
        );
        pledgedAmount = _pledgedAmount;
    }

    function disburseFeeToClient(
        address _client,
        address _token,
        uint256 _amount
    ) public onlyCampaignInfo {
        IERC20(_token).transfer(_client, _amount);
    }
}
