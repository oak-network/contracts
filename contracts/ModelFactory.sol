// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./CampaignInfo.sol";
import "./models/AllOrNothing.sol";
import "./models/KeepWhatsRaised.sol";
import "./models/PreOrder.sol";

contract ModelFactory {
    AllOrNothing newAllOrNothing;
    KeepWhatsRaised newKeepWhatsRaised;
    PreOrder newPreOrder;
    mapping(bytes32 => mapping(address => address)) bytesToInfoToModel;

    function getModelAddress(
        bytes32 platform,
        address info
    ) external view returns (address) {
        return bytesToInfoToModel[platform][info];
    }

    function createAllOrNothing(
        address _registry,
        address _info,
        bytes32 _platform
    ) public {
        newAllOrNothing = new AllOrNothing(_registry, _info, _platform);
        address allOrNothing = address(newAllOrNothing);
        require(allOrNothing != address(0));
        bytesToInfoToModel[_platform][_info] = allOrNothing;
    }

    function createKeepWhatsRaised(
        address _registry,
        address _info,
        bytes32 _platform
    ) public {
        newKeepWhatsRaised = new KeepWhatsRaised(_registry, _info, _platform);
        address keepWhatsRaised = address(newKeepWhatsRaised);
        require(keepWhatsRaised != address(0));
        bytesToInfoToModel[_platform][_info] = keepWhatsRaised;
    }

    function createPreOrder(
        address _registry,
        address _info,
        bytes32 _platform,
        uint256 _minimumPledgeCount
    ) public {
        newPreOrder = new PreOrder(_registry, _info, _platform, _minimumPledgeCount);
        address preOrder = address(newPreOrder);
        require(preOrder != address(0));
        bytesToInfoToModel[_platform][_info] = preOrder;
    }

    function createModels(
        address _registry,
        address _info,
        bytes32 _platform
    ) external {
        createAllOrNothing(_registry, _info, _platform);
        createKeepWhatsRaised(_registry, _info, _platform);
    }
}
