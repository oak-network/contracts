// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./CampaignInfo.sol";
import "./interfaces/ITreasuryFactory.sol";
import "./utils/AdminAccessChecker.sol";
import "./utils/AddressCalculator.sol";

contract TreasuryFactory is ITreasuryFactory, AdminAccessChecker {
    mapping(bytes32 => mapping(uint256 => bytes[])) private s_platformBytecode;
    mapping(bytes32 => mapping(uint256 => bool)) private s_platformBytecodeStatus;
    mapping(bytes => bool) private s_approvedBytecode;

    address private immutable CAMPAIGN_INFO_FACTORY;
    bytes32 private immutable CAMPAIGNINFO_BYTECODEHASH;

    /**
     * @dev Event emitted when a new bytecode is added for a specific platform and index.
     * @param platformBytes The platform identifier.
     * @param bytecodeIndex The index of the bytecode template.
     * @param bytecode The bytecode template added.
     */
    event TreasuryFactoryBytecodeChunkAdded(
        bytes32 indexed platformBytes,
        uint256 indexed bytecodeIndex,
        uint256 indexed bytecodeChunk,
        bytes bytecode
    );

    /**
     * @dev Event emitted when a bytecode is removed for a specific platform and index.
     * @param platformBytes The platform identifier.
     * @param bytecodeIndex The index of the bytecode template.
     */
    event TreasuryFactoryBytecodeRemoved(
        bytes32 indexed platformBytes,
        uint256 indexed bytecodeIndex
    );

    /**
     * @dev Event emitted when a bytecode is enlisted for deployment.
     * @param platformBytes The platform identifier.
     * @param bytecodeIndex The index of the enlisted bytecode.
     */
    event TreasuryFactoryBytecodeEnlisted(
        bytes32 indexed platformBytes,
        uint256 indexed bytecodeIndex
    );

    /**
     * @dev Event emitted when a bytecode is delisted and no longer available for deployment.
     * @param platformBytes The platform identifier.
     * @param bytecodeIndex The index of the delisted bytecode.
     */
    event TreasuryFactoryBytecodeDelisted(
        bytes32 indexed platformBytes,
        uint256 indexed bytecodeIndex
    );

    /**
     * @dev Event emitted when a new treasury is deployed.
     * @param platformBytes The platform identifier.
     * @param bytecodeIndex The index of the deployed bytecode.
     * @param treasuryAddress The address of the deployed treasury.
     */
    event TreasuryFactoryTreasuryDeployed(
        bytes32 indexed platformBytes,
        uint256 indexed bytecodeIndex,
        bytes32 indexed identifierHash,
        address treasuryAddress
    );

    error TreasuryFactoryUnauthorized();
    error TreasuryFactoryInvalidKey();
    error TreasuryFactoryIncorrectChunkIndex();
    error TreasuryFactoryBytecodeExists();
    error TreasuryFactoryBytecodeIsNotAdded();
    error TreasuryFactoryBytecodeAlreadyApproved();
    error TreasuryFactoryBytecodeIncomplete();
    error TreasuryFactoryBytecodeNotApproved();
    error TreasuryFactoryTreasuryCreationFailed();
    error TreasuryFactoryInvalidAddress();

    /**
     * @notice Initializes the TreasuryFactory contract.
     * @dev This constructor sets the address of the GlobalParams contract as the admin.
     * @param globalParams Address of the GlobalParams contract.
     * @param infoFactory Address of the CampaignInfoFactory contract.
     * @param bytecodeHash Keccak256 hash of the CampaignInfo bytecode.
     */
    constructor(
        IGlobalParams globalParams,
        address infoFactory,
        bytes32 bytecodeHash
    ) AdminAccessChecker(globalParams) {
        CAMPAIGN_INFO_FACTORY = infoFactory;
        CAMPAIGNINFO_BYTECODEHASH = bytecodeHash;
    }

    /**
     * @inheritdoc ITreasuryFactory
     */
    function computeTreasuryAddress(
        bytes32 identifierHash,
        bytes32 platformBytes,
        uint256 bytecodeIndex
    )
        external
        view
        override
        returns (address treasuryAddress, bool isDeployed)
    {
        (treasuryAddress, isDeployed) = AddressCalculator.computeAddress(
            keccak256(abi.encodePacked(identifierHash, platformBytes)),
            keccak256(s_platformBytecode[platformBytes][bytecodeIndex]),
            address(this)
        );
    }

    /**
     * @inheritdoc ITreasuryFactory
     */
    function addBytecodeChunk(
        bytes32 platformBytes,
        uint256 bytecodeIndex,
        uint256 chunkIndex,
        bool isLastChunk,
        bytes memory bytecodeChunk,
    ) external override onlyPlatformAdmin(platformBytes) {
        if (s_platformBytecode[platformBytes].length != chunkIndex) {
            revert TreasuryFactoryIncorrectChunkIndex();
        }
        if (s_platformBytecodeStatus[platformBytes][bytecodeIndex]) {
            revert TreasuryFactoryBytecodeExists();
        }
        if (isLastChunk) {
            s_platformBytecodeStatus[platformBytes][bytecodeIndex] = true;
        }
        s_platformBytecode[platformBytes][bytecodeIndex].push(bytecodeChunk);
        emit TreasuryFactoryBytecodeChunkAdded(
            platformBytes,
            bytecodeIndex,
            chunkIndex,
            bytecodeChunk
        );
    }

    /**
     * @inheritdoc ITreasuryFactory
     */
    function removeBytecode(
        bytes32 platformBytes,
        uint256 bytecodeIndex
    ) external override onlyPlatformAdmin(platformBytes) {
        if (s_platformBytecode[platformBytes][bytecodeIndex].length == 0) {
            revert TreasuryFactoryBytecodeIsNotAdded();
        }
        delete s_platformBytecode[platformBytes][bytecodeIndex];
        emit TreasuryFactoryBytecodeRemoved(platformBytes, bytecodeIndex);
    }

    /**
     * @dev Function to enlist a bytecode template for deployment.
     * @param platformBytes The platform identifier.
     * @param bytecodeIndex The index of the enlisted bytecode template.
     */
    function enlistBytecode(
        bytes32 platformBytes,
        uint256 bytecodeIndex
    ) external onlyProtocolAdmin {
        bytes memory bytecode = s_platformBytecode[platformBytes][
            bytecodeIndex
        ];
        if (bytecode.length == 0) {
            revert TreasuryFactoryInvalidKey();
        }
        if (!s_platformBytecodeStatus[platformBytes][bytecodeIndex]) {
            revert TreasuryFactoryBytecodeIncomplete();
        }
        if (s_approvedBytecode[bytecode]) {
            revert TreasuryFactoryBytecodeAlreadyApproved();
        }
        
        s_approvedBytecode[bytecode] = true;
        emit TreasuryFactoryBytecodeEnlisted(platformBytes, bytecodeIndex);
    }

    /**
     * @dev Function to delist a bytecode template, making it unavailable for deployment.
     * @param platformBytes The platform identifier.
     * @param bytecodeIndex The index of the delisted bytecode template.
     */
    function delistBytecode(
        bytes32 platformBytes,
        uint256 bytecodeIndex
    ) external onlyProtocolAdmin {
        bytes storage bytecode = s_platformBytecode[platformBytes][
            bytecodeIndex
        ];
        if (bytecode.length == 0) {
            revert TreasuryFactoryInvalidKey();
        }
        s_approvedBytecode[bytecode] = false;
        delete s_platformBytecode[platformBytes][bytecodeIndex];
        emit TreasuryFactoryBytecodeDelisted(platformBytes, bytecodeIndex);
    }

    /**
     * @inheritdoc ITreasuryFactory
     */
    function deploy(
        bytes32 platformBytes,
        uint256 bytecodeIndex,
        bytes32 identifierHash
    ) external override onlyPlatformAdmin(platformBytes) {
        bytes storage bytecode = s_platformBytecode[platformBytes][
            bytecodeIndex
        ];
        if (!s_approvedBytecode[bytecode]) {
            revert TreasuryFactoryBytecodeNotApproved();
        }
        (address infoAddress, bool isValid) = AddressCalculator.computeAddress(
            identifierHash,
            CAMPAIGNINFO_BYTECODEHASH,
            CAMPAIGN_INFO_FACTORY
        );
        if (!isValid && infoAddress == address(0)) {
            revert TreasuryFactoryInvalidAddress();
        }
        bytes memory argsBytecode = abi.encodePacked(
            bytecode,
            abi.encode(platformBytes, infoAddress)
        );
        bytes32 salt = keccak256(
            abi.encodePacked(identifierHash, platformBytes)
        );
        address treasury;
        assembly {
            treasury := create2(
                0,
                add(argsBytecode, 0x20),
                mload(argsBytecode),
                salt
            )
        }
        if (treasury == address(0)) {
            revert TreasuryFactoryTreasuryCreationFailed();
        }
        CampaignInfo(infoAddress)._setPlatformInfo(platformBytes, treasury);
        emit TreasuryFactoryTreasuryDeployed(
            platformBytes,
            bytecodeIndex,
            identifierHash,
            treasury
        );
    }
}
