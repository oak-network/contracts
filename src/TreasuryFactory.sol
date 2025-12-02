// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ITreasuryFactory} from "./interfaces/ITreasuryFactory.sol";
import {IGlobalParams, AdminAccessChecker} from "./utils/AdminAccessChecker.sol";
import {TreasuryFactoryStorage} from "./storage/TreasuryFactoryStorage.sol";

/**
 * @title TreasuryFactory
 * @notice Factory contract for creating treasury contracts
 * @dev UUPS Upgradeable contract with ERC-7201 namespaced storage
 */
contract TreasuryFactory is Initializable, ITreasuryFactory, AdminAccessChecker, UUPSUpgradeable {
    error TreasuryFactoryUnauthorized();
    error TreasuryFactoryInvalidKey();
    error TreasuryFactoryTreasuryCreationFailed();
    error TreasuryFactoryInvalidAddress();
    error TreasuryFactoryImplementationNotSet();
    error TreasuryFactoryImplementationNotSetOrApproved();
    error TreasuryFactoryTreasuryInitializationFailed();
    error TreasuryFactorySettingPlatformInfoFailed();

    /**
     * @dev Constructor that disables initializers to prevent implementation contract initialization
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the TreasuryFactory contract.
     * @param globalParams The address of the GlobalParams contract
     */
    function initialize(IGlobalParams globalParams) public initializer {
        __AccessChecker_init(globalParams);
        __UUPSUpgradeable_init();
    }

    /**
     * @dev Function that authorizes an upgrade to a new implementation
     * @param newImplementation Address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyProtocolAdmin {}

    /**
     * @inheritdoc ITreasuryFactory
     */
    function registerTreasuryImplementation(bytes32 platformHash, uint256 implementationId, address implementation)
        external
        override
        onlyPlatformAdmin(platformHash)
    {
        if (implementation == address(0)) {
            revert TreasuryFactoryInvalidAddress();
        }
        TreasuryFactoryStorage.Storage storage $ = TreasuryFactoryStorage._getTreasuryFactoryStorage();
        $.implementationMap[platformHash][implementationId] = implementation;
    }

    /**
     * @inheritdoc ITreasuryFactory
     */
    function approveTreasuryImplementation(bytes32 platformHash, uint256 implementationId)
        external
        override
        onlyProtocolAdmin
    {
        TreasuryFactoryStorage.Storage storage $ = TreasuryFactoryStorage._getTreasuryFactoryStorage();
        address implementation = $.implementationMap[platformHash][implementationId];
        if (implementation == address(0)) {
            revert TreasuryFactoryImplementationNotSet();
        }
        $.approvedImplementations[implementation] = true;
    }

    /**
     * @inheritdoc ITreasuryFactory
     */
    function disapproveTreasuryImplementation(address implementation) external override onlyProtocolAdmin {
        TreasuryFactoryStorage.Storage storage $ = TreasuryFactoryStorage._getTreasuryFactoryStorage();
        $.approvedImplementations[implementation] = false;
    }

    /**
     * @inheritdoc ITreasuryFactory
     */
    function removeTreasuryImplementation(bytes32 platformHash, uint256 implementationId)
        external
        override
        onlyPlatformAdmin(platformHash)
    {
        TreasuryFactoryStorage.Storage storage $ = TreasuryFactoryStorage._getTreasuryFactoryStorage();
        delete $.implementationMap[platformHash][implementationId];
    }

    /**
     * @inheritdoc ITreasuryFactory
     */
    function deploy(bytes32 platformHash, address infoAddress, uint256 implementationId)
        external
        override
        onlyPlatformAdmin(platformHash)
        returns (address clone)
    {
        TreasuryFactoryStorage.Storage storage $ = TreasuryFactoryStorage._getTreasuryFactoryStorage();
        address implementation = $.implementationMap[platformHash][implementationId];
        if (!$.approvedImplementations[implementation]) {
            revert TreasuryFactoryImplementationNotSetOrApproved();
        }

        clone = Clones.clone(implementation);

        // Fetch the platform adapter (trusted forwarder) from GlobalParams
        address platformAdapter = _getGlobalParams().getPlatformAdapter(platformHash);

        (bool success,) = clone.call(
            abi.encodeWithSignature("initialize(bytes32,address,address)", platformHash, infoAddress, platformAdapter)
        );
        if (!success) {
            revert TreasuryFactoryTreasuryInitializationFailed();
        }
        (success,) = infoAddress.call(abi.encodeWithSignature("_setPlatformInfo(bytes32,address)", platformHash, clone));
        if (!success) {
            revert TreasuryFactorySettingPlatformInfoFailed();
        }
        emit TreasuryFactoryTreasuryDeployed(platformHash, implementationId, infoAddress, clone);
    }
}
