// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ISignatureTransfer} from "permit2/src/interfaces/ISignatureTransfer.sol";

/**
 * @title IPermit2
 * @notice Re-exports Uniswap's canonical ISignatureTransfer interface so that
 *         existing import paths continue to work unchanged.
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
