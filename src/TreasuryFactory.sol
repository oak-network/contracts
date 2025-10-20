// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {ITreasuryFactory} from "./interfaces/ITreasuryFactory.sol";
import {IGlobalParams, AdminAccessChecker} from "./utils/AdminAccessChecker.sol";

contract TreasuryFactory is ITreasuryFactory, AdminAccessChecker {
    mapping(bytes32 => mapping(uint256 => address)) private implementationMap;
    mapping(address => bool) private approvedImplementations;

    error TreasuryFactoryUnauthorized();
    error TreasuryFactoryInvalidKey();
    error TreasuryFactoryTreasuryCreationFailed();
    error TreasuryFactoryInvalidAddress();
    error TreasuryFactoryImplementationNotSet();
    error TreasuryFactoryImplementationNotSetOrApproved();
    error TreasuryFactoryTreasuryInitializationFailed();
    error TreasuryFactorySettingPlatformInfoFailed();

    /**
     * @notice Initializes the TreasuryFactory contract.
     * @dev This constructor sets the address of the GlobalParams contract as the admin.
     */
    constructor(IGlobalParams globalParams) {
        __AccessChecker_init(globalParams);
    }

    /**
     * @inheritdoc ITreasuryFactory
     */
    function registerTreasuryImplementation(
        bytes32 platformHash,
        uint256 implementationId,
        address implementation
    ) external override onlyPlatformAdmin(platformHash) {
        if (implementation == address(0)) {
            revert TreasuryFactoryInvalidAddress();
        }
        implementationMap[platformHash][implementationId] = implementation;
    }

    /**
     * @inheritdoc ITreasuryFactory
     */
    function approveTreasuryImplementation(
        bytes32 platformHash,
        uint256 implementationId
    ) external override onlyProtocolAdmin {
        address implementation = implementationMap[platformHash][
            implementationId
        ];
        if (implementation == address(0)) {
            revert TreasuryFactoryImplementationNotSet();
        }
        approvedImplementations[implementation] = true;
    }

    /**
     * @inheritdoc ITreasuryFactory
     */
    function disapproveTreasuryImplementation(
        address implementation
    ) external override onlyProtocolAdmin {
        approvedImplementations[implementation] = false;
    }

    /**
     * @inheritdoc ITreasuryFactory
     */
    function removeTreasuryImplementation(
        bytes32 platformHash,
        uint256 implementationId
    ) external override onlyPlatformAdmin(platformHash) {
        delete implementationMap[platformHash][implementationId];
    }

    /**
     * @inheritdoc ITreasuryFactory
     */
    function deploy(
        bytes32 platformHash,
        address infoAddress,
        uint256 implementationId,
        string calldata name,
        string calldata symbol
    )
        external
        override
        onlyPlatformAdmin(platformHash)
        returns (address clone)
    {
        address implementation = implementationMap[platformHash][
            implementationId
        ];
        if (!approvedImplementations[implementation]) {
            revert TreasuryFactoryImplementationNotSetOrApproved();
        }

        clone = Clones.clone(implementation);

        (bool success, ) = clone.call(
            abi.encodeWithSignature(
                "initialize(bytes32,address,string,string)",
                platformHash,
                infoAddress,
                name,
                symbol
            )
        );
        if (!success) {
            revert TreasuryFactoryTreasuryInitializationFailed();
        }
        (success, ) = infoAddress.call(
            abi.encodeWithSignature(
                "_setPlatformInfo(bytes32,address)",
                platformHash,
                clone
            )
        );
        if (!success) {
            revert TreasuryFactorySettingPlatformInfoFailed();
        }
        emit TreasuryFactoryTreasuryDeployed(
            platformHash,
            implementationId,
            infoAddress,
            clone
        );
    }
}
