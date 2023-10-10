// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

/**
 * @title ITreasuryFactory
 * @dev Interface for the TreasuryFactory contract, which deploys campaign treasuries with specific bytecode.
 */
interface ITreasuryFactory {
    /**
     * @dev Function to compute the address of a treasury based on the identifier hash, platform, and bytecode index.
     * @param identifierHash The unique hash identifier of the campaign.
     * @param platformBytes The platform identifier.
     * @param bytecodeIndex The index of the bytecode template.
     * @return treasuryAddress The computed treasury address.
     * @return isDeployed A boolean indicating whether the treasury is already deployed.
     */
    function computeTreasuryAddress(
        bytes32 identifierHash,
        bytes32 platformBytes,
        uint256 bytecodeIndex
    ) external view returns (address treasuryAddress, bool isDeployed);

    /**
     * @dev Function to add a fragment of the full bytecode of treasury contract for a given platform.
     * @param platformBytes The platform identifier.
     * @param bytecodeIndex The index of the bytecode template.
     * @param chunkIndex The index of the bytecode chunk.
     * @param isLastChunk The boolean to determine if this is the last chunk.
     * @param bytecodeChunk The bytecode fragment to add.
     */
    function addBytecodeChunk(
        bytes32 platformBytes,
        uint256 bytecodeIndex,
        uint256 chunkIndex,
        bool isLastChunk,
        bytes memory bytecodeChunk
    ) external;

    /**
     * @dev Function to remove a bytecode template for a specific platform and index.
     * @param platformBytes The platform identifier.
     * @param bytecodeIndex The index of the bytecode template.
     */
    function removeBytecode(
        bytes32 platformBytes,
        uint256 bytecodeIndex
    ) external;

    /**
     * @dev Function to deploy a new treasury contract with a specified bytecode template.
     * @param platformBytes The platform identifier.
     * @param bytecodeIndex The index of the bytecode template to use for deployment.
     * @param infoAddress The address of the associated campaign.
     */
    function deploy(
        bytes32 platformBytes,
        uint256 bytecodeIndex,
        address infoAddress
    ) external;
}