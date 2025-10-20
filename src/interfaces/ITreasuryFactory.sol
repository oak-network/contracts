// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ITreasuryFactory
 * @dev Interface for the TreasuryFactory contract, which registers, approves, and deploys treasury clones.
 */
interface ITreasuryFactory {
    /**
     * @dev Emitted when a new treasury is deployed.
     * @param platformHash The platform identifier.
     * @param implementationId The ID of the approved implementation.
     * @param infoAddress The campaign info address linked to the treasury.
     * @param treasuryAddress The deployed treasury address.
     */
    event TreasuryFactoryTreasuryDeployed(
        bytes32 indexed platformHash,
        uint256 indexed implementationId,
        address indexed infoAddress,
        address treasuryAddress
    );

    /**
     * @notice Registers a treasury implementation for a given platform.
     * @dev Callable only by the platform admin.
     * @param platformHash The platform identifier.
     * @param implementationId The ID to assign to the implementation.
     * @param implementation The contract address of the implementation.
     */
    function registerTreasuryImplementation(
        bytes32 platformHash,
        uint256 implementationId,
        address implementation
    ) external;

    /**
     * @notice Approves a previously registered implementation.
     * @dev Callable only by the protocol admin.
     * @param platformHash The platform identifier.
     * @param implementationId The ID of the implementation to approve.
     */
    function approveTreasuryImplementation(
        bytes32 platformHash,
        uint256 implementationId
    ) external;

    /**
     * @notice Disapproves a previously approved treasury implementation.
     * @param implementation The address of the implementation to disapprove.
     */
    function disapproveTreasuryImplementation(address implementation) external;

    /**
     * @notice Removes a registered treasury implementation from a platform.
     * @param platformHash The platform identifier.
     * @param implementationId The implementation ID to remove.
     */
    function removeTreasuryImplementation(
        bytes32 platformHash,
        uint256 implementationId
    ) external;

    /**
     * @notice Deploys a treasury clone using an approved implementation.
     * @dev Callable only by the platform admin.
     * @param platformHash The platform identifier.
     * @param infoAddress The address of the campaign info contract.
     * @param implementationId The ID of the implementation to use.
     * @param name The name of the treasury token.
     * @param symbol The symbol of the treasury token.
     * @return clone The address of the deployed treasury contract.
     */
    function deploy(
        bytes32 platformHash,
        address infoAddress,
        uint256 implementationId,
        string calldata name,
        string calldata symbol
    ) external returns (address clone);
}
