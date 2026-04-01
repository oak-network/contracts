// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISignatureTransfer, IEIP712} from "../../src/interfaces/IPermit2.sol";

/**
 * @title MockPermit2
 * @notice A solc 0.8.22-compatible re-implementation of Uniswap's Permit2
 *         (SignatureTransfer only) for use in Foundry tests.
 * @dev Faithfully reproduces the EIP-712 domain, struct hashing, nonce bitmap,
 *      signature verification, and token transfer logic of the canonical Permit2
 *      so that tests exercise real cryptographic signing paths.
 */
contract MockPermit2 is ISignatureTransfer {
    using SafeERC20 for IERC20;

    // -------------------------------------------------------------------------
    // EIP-712 domain
    // -------------------------------------------------------------------------
    bytes32 private immutable _CACHED_DOMAIN_SEPARATOR;
    uint256 private immutable _CACHED_CHAIN_ID;

    bytes32 private constant _HASHED_NAME = keccak256("Permit2");
    bytes32 private constant _TYPE_HASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    // -------------------------------------------------------------------------
    // PermitHash constants (mirrors permit2/src/libraries/PermitHash.sol)
    // -------------------------------------------------------------------------
    bytes32 private constant _TOKEN_PERMISSIONS_TYPEHASH =
        keccak256("TokenPermissions(address token,uint256 amount)");

    bytes32 private constant _PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    bytes32 private constant _PERMIT_BATCH_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitBatchTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    string private constant _PERMIT_TRANSFER_FROM_WITNESS_TYPEHASH_STUB =
        "PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,";

    string private constant _PERMIT_BATCH_WITNESS_TRANSFER_FROM_TYPEHASH_STUB =
        "PermitBatchWitnessTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline,";

    // -------------------------------------------------------------------------
    // Errors (mirrors permit2/src/PermitErrors.sol & SignatureVerification.sol)
    // -------------------------------------------------------------------------
    error SignatureExpired(uint256 signatureDeadline);
    error InvalidNonce();
    error InvalidSignatureLength();
    error InvalidSignature();
    error InvalidSigner();
    error InvalidContractSignature();

    // -------------------------------------------------------------------------
    // Nonce bitmap
    // -------------------------------------------------------------------------
    /// @inheritdoc ISignatureTransfer
    mapping(address => mapping(uint256 => uint256)) public nonceBitmap;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    constructor() {
        _CACHED_CHAIN_ID = block.chainid;
        _CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator(_TYPE_HASH, _HASHED_NAME);
    }

    // -------------------------------------------------------------------------
    // IEIP712
    // -------------------------------------------------------------------------
    function DOMAIN_SEPARATOR() public view override returns (bytes32) {
        return block.chainid == _CACHED_CHAIN_ID
            ? _CACHED_DOMAIN_SEPARATOR
            : _buildDomainSeparator(_TYPE_HASH, _HASHED_NAME);
    }

    // -------------------------------------------------------------------------
    // ISignatureTransfer — single-token functions
    // -------------------------------------------------------------------------
    /// @inheritdoc ISignatureTransfer
    function permitTransferFrom(
        PermitTransferFrom memory permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external {
        _permitTransferFrom(permit, transferDetails, owner, _hash(permit), signature);
    }

    /// @inheritdoc ISignatureTransfer
    function permitWitnessTransferFrom(
        PermitTransferFrom memory permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes32 witness,
        string calldata witnessTypeString,
        bytes calldata signature
    ) external {
        _permitTransferFrom(
            permit, transferDetails, owner, _hashWithWitness(permit, witness, witnessTypeString), signature
        );
    }

    // -------------------------------------------------------------------------
    // ISignatureTransfer — batch functions
    // -------------------------------------------------------------------------
    /// @inheritdoc ISignatureTransfer
    function permitTransferFrom(
        PermitBatchTransferFrom memory permit,
        SignatureTransferDetails[] calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external {
        _permitBatchTransferFrom(permit, transferDetails, owner, _hash(permit), signature);
    }

    /// @inheritdoc ISignatureTransfer
    function permitWitnessTransferFrom(
        PermitBatchTransferFrom memory permit,
        SignatureTransferDetails[] calldata transferDetails,
        address owner,
        bytes32 witness,
        string calldata witnessTypeString,
        bytes calldata signature
    ) external {
        _permitBatchTransferFrom(
            permit, transferDetails, owner, _hashWithWitness(permit, witness, witnessTypeString), signature
        );
    }

    /// @inheritdoc ISignatureTransfer
    function invalidateUnorderedNonces(uint256 wordPos, uint256 mask) external {
        nonceBitmap[msg.sender][wordPos] |= mask;
        emit UnorderedNonceInvalidation(msg.sender, wordPos, mask);
    }

    // =========================================================================
    // Internal helpers
    // =========================================================================

    // ---- single-token transfer core ----
    function _permitTransferFrom(
        PermitTransferFrom memory permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes32 dataHash,
        bytes calldata signature
    ) private {
        uint256 requestedAmount = transferDetails.requestedAmount;

        if (block.timestamp > permit.deadline) revert SignatureExpired(permit.deadline);
        if (requestedAmount > permit.permitted.amount) revert InvalidAmount(permit.permitted.amount);

        _useUnorderedNonce(owner, permit.nonce);
        _verify(signature, _hashTypedData(dataHash), owner);

        IERC20(permit.permitted.token).safeTransferFrom(owner, transferDetails.to, requestedAmount);
    }

    // ---- batch-token transfer core ----
    function _permitBatchTransferFrom(
        PermitBatchTransferFrom memory permit,
        SignatureTransferDetails[] calldata transferDetails,
        address owner,
        bytes32 dataHash,
        bytes calldata signature
    ) private {
        uint256 numPermitted = permit.permitted.length;

        if (block.timestamp > permit.deadline) revert SignatureExpired(permit.deadline);
        if (numPermitted != transferDetails.length) revert LengthMismatch();

        _useUnorderedNonce(owner, permit.nonce);
        _verify(signature, _hashTypedData(dataHash), owner);

        unchecked {
            for (uint256 i = 0; i < numPermitted; ++i) {
                TokenPermissions memory permitted = permit.permitted[i];
                uint256 requestedAmount = transferDetails[i].requestedAmount;

                if (requestedAmount > permitted.amount) revert InvalidAmount(permitted.amount);

                if (requestedAmount != 0) {
                    IERC20(permitted.token).safeTransferFrom(owner, transferDetails[i].to, requestedAmount);
                }
            }
        }
    }

    // ---- EIP-712 ----
    function _buildDomainSeparator(bytes32 typeHash, bytes32 nameHash) private view returns (bytes32) {
        return keccak256(abi.encode(typeHash, nameHash, block.chainid, address(this)));
    }

    function _hashTypedData(bytes32 dataHash) private view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), dataHash));
    }

    // ---- struct hashing (mirrors PermitHash library) ----
    function _hashTokenPermissions(TokenPermissions memory permitted) private pure returns (bytes32) {
        return keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permitted));
    }

    function _hash(PermitTransferFrom memory permit) private view returns (bytes32) {
        bytes32 tokenPermissionsHash = _hashTokenPermissions(permit.permitted);
        return keccak256(
            abi.encode(_PERMIT_TRANSFER_FROM_TYPEHASH, tokenPermissionsHash, msg.sender, permit.nonce, permit.deadline)
        );
    }

    function _hash(PermitBatchTransferFrom memory permit) private view returns (bytes32) {
        uint256 numPermitted = permit.permitted.length;
        bytes32[] memory tokenPermissionHashes = new bytes32[](numPermitted);

        for (uint256 i = 0; i < numPermitted; ++i) {
            tokenPermissionHashes[i] = _hashTokenPermissions(permit.permitted[i]);
        }

        return keccak256(
            abi.encode(
                _PERMIT_BATCH_TRANSFER_FROM_TYPEHASH,
                keccak256(abi.encodePacked(tokenPermissionHashes)),
                msg.sender,
                permit.nonce,
                permit.deadline
            )
        );
    }

    function _hashWithWitness(
        PermitTransferFrom memory permit,
        bytes32 witness,
        string calldata witnessTypeString
    ) private view returns (bytes32) {
        bytes32 typeHash =
            keccak256(abi.encodePacked(_PERMIT_TRANSFER_FROM_WITNESS_TYPEHASH_STUB, witnessTypeString));
        bytes32 tokenPermissionsHash = _hashTokenPermissions(permit.permitted);
        return keccak256(
            abi.encode(typeHash, tokenPermissionsHash, msg.sender, permit.nonce, permit.deadline, witness)
        );
    }

    function _hashWithWitness(
        PermitBatchTransferFrom memory permit,
        bytes32 witness,
        string calldata witnessTypeString
    ) private view returns (bytes32) {
        bytes32 typeHash =
            keccak256(abi.encodePacked(_PERMIT_BATCH_WITNESS_TRANSFER_FROM_TYPEHASH_STUB, witnessTypeString));

        uint256 numPermitted = permit.permitted.length;
        bytes32[] memory tokenPermissionHashes = new bytes32[](numPermitted);

        for (uint256 i = 0; i < numPermitted; ++i) {
            tokenPermissionHashes[i] = _hashTokenPermissions(permit.permitted[i]);
        }

        return keccak256(
            abi.encode(
                typeHash,
                keccak256(abi.encodePacked(tokenPermissionHashes)),
                msg.sender,
                permit.nonce,
                permit.deadline,
                witness
            )
        );
    }

    // ---- nonce management ----
    function _useUnorderedNonce(address from, uint256 nonce) private {
        (uint256 wordPos, uint256 bitPos) = _bitmapPositions(nonce);
        uint256 bit = 1 << bitPos;
        uint256 flipped = nonceBitmap[from][wordPos] ^= bit;

        if (flipped & bit == 0) revert InvalidNonce();
    }

    function _bitmapPositions(uint256 nonce) private pure returns (uint256 wordPos, uint256 bitPos) {
        wordPos = uint248(nonce >> 8);
        bitPos = uint8(nonce);
    }

    // ---- signature verification (mirrors SignatureVerification library) ----
    bytes32 private constant _UPPER_BIT_MASK =
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    function _verify(bytes calldata signature, bytes32 hash, address claimedSigner) private view {
        bytes32 r;
        bytes32 s;
        uint8 v;

        if (claimedSigner.code.length == 0) {
            if (signature.length == 65) {
                (r, s) = abi.decode(signature, (bytes32, bytes32));
                v = uint8(signature[64]);
            } else if (signature.length == 64) {
                // EIP-2098
                bytes32 vs;
                (r, vs) = abi.decode(signature, (bytes32, bytes32));
                s = vs & _UPPER_BIT_MASK;
                v = uint8(uint256(vs >> 255)) + 27;
            } else {
                revert InvalidSignatureLength();
            }
            address signer = ecrecover(hash, v, r, s);
            if (signer == address(0)) revert InvalidSignature();
            if (signer != claimedSigner) revert InvalidSigner();
        } else {
            (bool success, bytes memory result) = claimedSigner.staticcall(
                abi.encodeWithSignature("isValidSignature(bytes32,bytes)", hash, signature)
            );
            if (!success || result.length < 32 || abi.decode(result, (bytes4)) != bytes4(0x1626ba7e)) {
                revert InvalidContractSignature();
            }
        }
    }
}
