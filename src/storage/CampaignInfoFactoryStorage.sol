// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IGlobalParams} from "../interfaces/IGlobalParams.sol";

/**
 * @title CampaignInfoFactoryStorage
 * @notice Storage contract for CampaignInfoFactory using ERC-7201 namespaced storage
 * @dev This contract contains the storage layout and accessor functions for CampaignInfoFactory
 */
library CampaignInfoFactoryStorage {
    /// @custom:storage-location erc7201:ccprotocol.storage.CampaignInfoFactory
    struct Storage {
        IGlobalParams globalParams;
        address treasuryFactoryAddress;
        address implementation;
        mapping(address => bool) isValidCampaignInfo;
        mapping(bytes32 => address) identifierToCampaignInfo;
    }

    // keccak256(abi.encode(uint256(keccak256("ccprotocol.storage.CampaignInfoFactory")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CAMPAIGN_INFO_FACTORY_STORAGE_LOCATION =
        0x2857858a392b093e1f8b3f368c2276ce911f27cef445605a2932ebe945968d00;

    function _getCampaignInfoFactoryStorage() internal pure returns (Storage storage $) {
        assembly {
            $.slot := CAMPAIGN_INFO_FACTORY_STORAGE_LOCATION
        }
    }
}
