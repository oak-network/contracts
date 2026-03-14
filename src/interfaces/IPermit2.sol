// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title IPermit2
 * @notice Minimal interface for Uniswap's Permit2 contract, used for
 *         signature-based token approvals and transfers.
 * @dev Only includes types and functions required for `permitWitnessTransferFrom`.
 *      The canonical Permit2 deployment address is 0x000000000022D473030F116dDEE9F6B43aC78BA3
 *      across all supported EVM chains.
 */
interface IPermit2 {
    /// @notice Token and maximum amount authorised by the permit signer.
    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    /// @notice The permit message signed for a single token transfer.
    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    /// @notice Recipient address and requested amount for a single transfer.
    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }

    /**
     * @notice Transfers a token using a signed permit that includes a witness.
     * @dev The witness hash is mixed into the EIP-712 digest so that all
     *      caller-supplied parameters (amounts, IDs, line items, etc.) are
     *      cryptographically bound to the owner's signature.  Any attempt by a
     *      third party to modify those parameters will invalidate the signature.
     *
     * @param permit          The permit data signed by the token owner.
     * @param transferDetails Specifies the recipient and the exact amount to move.
     * @param owner           The token owner and permit signer.
     * @param witness         EIP-712 hash of the application-specific witness struct.
     * @param witnessTypeString  EIP-712 type string for the witness, appended to the
     *                           Permit2 type hash stub.  Must follow the form:
     *                           "<WitnessType> witness)<WitnessType>(fields...)
     *                           TokenPermissions(address token,uint256 amount)"
     * @param signature       The owner's EIP-712 signature over the combined digest.
     */
    function permitWitnessTransferFrom(
        PermitTransferFrom memory permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes32 witness,
        string calldata witnessTypeString,
        bytes calldata signature
    ) external;

    /// @notice Returns the EIP-712 domain separator used by this Permit2 deployment.
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

/**
 * @notice Data required for a Permit2 signature-based token transfer.
 * @param nonce     Unique nonce preventing signature replay (managed by Permit2).
 * @param deadline  Unix timestamp after which the permit is no longer valid.
 * @param signature EIP-712 signature produced by the token owner.
 */
struct PermitData {
    uint256 nonce;
    uint256 deadline;
    bytes signature;
}
