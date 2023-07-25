// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./CampaignInfo.sol";
import "./models/AllOrNothing.sol";
import "./models/KeepWhatsRaised.sol";

contract ModelFactory {
    AllOrNothing newAllOrNothing;
    KeepWhatsRaised newKeepWhatsRaised;
    mapping(bytes32 => mapping(address => address)) public bytesToInfoToModel;

    function createAllOrNothing(
        address _registry,
        address _info,
        bytes32 _platform
    ) external {
        newAllOrNothing = new AllOrNothing(_registry, _info, _platform);
        address newAllOrNothing = address(newAllOrNothing);
        require(newAllOrNothing != address(0));
        bytesToInfoToModel[_platform][_info] = newAllOrNothing;
    }
}
