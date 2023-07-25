// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./CampaignInfo.sol";
import "./models/AllOrNothing.sol";
import "./models/KeepWhatsRaised.sol";

contract ModelFactory {
    AllOrNothing newAllOrNothing;
    KeepWhatsRaised newKeepWhatsRaised;
    mapping(bytes32 => mapping(address => address)) public bytesToInfoToModel;

}
