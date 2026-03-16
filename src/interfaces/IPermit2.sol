// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

// ============================================================================
// Inlined Permit2 interfaces (originally from Uniswap permit2 package)
// ============================================================================

/// @title IEIP712
interface IEIP712 {
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

/// @title ISignatureTransfer
/// @notice Handles ERC20 token transfers through signature based actions
/// @dev Requires user's token approval on the Permit2 contract
interface ISignatureTransfer is IEIP712 {
    /// @notice Thrown when the requested amount for a transfer is larger than the permissioned amount
    /// @param maxAmount The maximum amount a spender can request to transfer
    error InvalidAmount(uint256 maxAmount);

    /// @notice Thrown when the number of tokens permissioned to a spender does not match the number of tokens being transferred
    error LengthMismatch();

    /// @notice Emits an event when the owner successfully invalidates an unordered nonce.
    event UnorderedNonceInvalidation(address indexed owner, uint256 word, uint256 mask);

    /// @notice The token and amount details for a transfer signed in the permit transfer signature
    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    /// @notice The signed permit message for a single token transfer
    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    /// @notice Specifies the recipient address and amount for batched transfers.
    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }

    /// @notice Used to reconstruct the signed permit message for multiple token transfers
    struct PermitBatchTransferFrom {
        TokenPermissions[] permitted;
        uint256 nonce;
        uint256 deadline;
    }

    /// @notice A map from token owner address and a caller specified word index to a bitmap.
    function nonceBitmap(address, uint256) external view returns (uint256);

    /// @notice Transfers a token using a signed permit message
    function permitTransferFrom(
        PermitTransferFrom memory permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;

    /// @notice Transfers a token using a signed permit message with extra witness data
    function permitWitnessTransferFrom(
        PermitTransferFrom memory permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes32 witness,
        string calldata witnessTypeString,
        bytes calldata signature
    ) external;

    /// @notice Transfers multiple tokens using a signed permit message
    function permitTransferFrom(
        PermitBatchTransferFrom memory permit,
        SignatureTransferDetails[] calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;

    /// @notice Transfers multiple tokens using a signed permit message with extra witness data
    function permitWitnessTransferFrom(
        PermitBatchTransferFrom memory permit,
        SignatureTransferDetails[] calldata transferDetails,
        address owner,
        bytes32 witness,
        string calldata witnessTypeString,
        bytes calldata signature
    ) external;

    /// @notice Invalidates the bits specified in mask for the bitmap at the word position
    function invalidateUnorderedNonces(uint256 wordPos, uint256 mask) external;
}

// ============================================================================
// Application-level types
// ============================================================================

/**
 * @title IPermit2
 * @notice Re-exports ISignatureTransfer so that existing import paths work unchanged.
 * @dev The canonical Permit2 deployment address is
 *      0x000000000022D473030F116dDEE9F6B43aC78BA3 across all supported EVM chains.
 */
interface IPermit2 is ISignatureTransfer {}

/**
 * @notice Application-specific struct bundling the Permit2 fields a caller must
 *         supply alongside each signature-based token transfer.
 * @param nonce     Unique nonce preventing signature replay (managed by Permit2).
 * @param deadline  Unix timestamp after which the permit is no longer valid.
 * @param signature EIP-712 signature produced by the token owner.
 */
struct PermitData {
    uint256 nonce;
    uint256 deadline;
    bytes signature;
}
