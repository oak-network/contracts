// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./CampaignInfo.sol";
import "./interfaces/ITreasuryFactory.sol";
import "./utils/AdminAccessChecker.sol";
import "./utils/AddressCalculator.sol";
import "hardhat/console.sol";

contract TreasuryFactory is ITreasuryFactory, AdminAccessChecker {
    mapping(bytes32 => mapping(uint256 => bytes[])) private s_platformBytecode;
    mapping(bytes32 => mapping(uint256 => bool))
        private s_platformBytecodeStatus;
    mapping(bytes32 => mapping(uint256 => bool)) private s_approvedBytecode;

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
     * @param infoAddress The address of the associated campaign.
     * @param treasuryAddress The address of the deployed treasury.
     */
    event TreasuryFactoryTreasuryDeployed(
        bytes32 indexed platformBytes,
        uint256 indexed bytecodeIndex,
        address indexed infoAddress,
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
            keccak256(
                abi.encode(s_platformBytecode[platformBytes][bytecodeIndex])
            ),
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
        bytes memory bytecodeChunk
    ) external override onlyPlatformAdmin(platformBytes) {
        if (
            s_platformBytecode[platformBytes][bytecodeIndex].length !=
            chunkIndex
        ) {
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
        if (!s_platformBytecodeStatus[platformBytes][bytecodeIndex]) {
            revert TreasuryFactoryBytecodeIncomplete();
        }
        if (s_approvedBytecode[platformBytes][bytecodeIndex]) {
            revert TreasuryFactoryBytecodeAlreadyApproved();
        }
        s_approvedBytecode[platformBytes][bytecodeIndex] = true;
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
        if (!s_approvedBytecode[platformBytes][bytecodeIndex]) {
            revert TreasuryFactoryInvalidKey();
        }
        s_approvedBytecode[platformBytes][bytecodeIndex] = false;
        delete s_platformBytecode[platformBytes][bytecodeIndex];
        emit TreasuryFactoryBytecodeDelisted(platformBytes, bytecodeIndex);
    }

    /**
     * @inheritdoc ITreasuryFactory
     */
    function deploy(
        bytes32 platformBytes,
        uint256 bytecodeIndex,
        address infoAddress
    ) external override onlyPlatformAdmin(platformBytes) {
        if (!s_approvedBytecode[platformBytes][bytecodeIndex]) {
            revert TreasuryFactoryBytecodeNotApproved();
        }
        if (infoAddress == address(0)) {
            revert TreasuryFactoryInvalidAddress();
        }
        bytes memory argsBytecode = abi.encodePacked(
            _concatenateBytes(s_platformBytecode[platformBytes][bytecodeIndex]),
            abi.encode(platformBytes, infoAddress)
        );
        bytes32 salt = keccak256(abi.encodePacked(infoAddress, platformBytes));
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
            infoAddress,
            treasury
        );
    }

    /**
     * @dev Concatenates multiple byte arrays into one.
     * @param chunks The byte arrays to concatenate.
     */
    function _concatenateBytes(
        bytes[] memory chunks
    ) private pure returns (bytes memory) {
        uint totalLength = 0;
        for (uint i = 0; i < chunks.length; i++) {
            totalLength += chunks[i].length;
        }

        bytes memory result = new bytes(totalLength);

        uint destOffset = 0;
        for (uint i = 0; i < chunks.length; i++) {
            bytes memory chunk = chunks[i];
            uint chunkLength = chunk.length;

            assembly {
                for {
                    let j := 0
                } lt(j, chunkLength) {
                    j := add(j, 1)
                } {
                    let byteData := byte(0, mload(add(add(chunk, 0x20), j)))
                    mstore8(add(add(result, 0x20), destOffset), byteData)
                    destOffset := add(destOffset, 1)
                }
            }
        }
        return result;
    }
}
