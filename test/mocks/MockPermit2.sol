// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";

/**
 * @title MockPermit2
 * @notice A test-only mock that mimics the Permit2 `permitWitnessTransferFrom` interface.
 * @dev Signature verification is intentionally skipped so tests can exercise the contract
 *      logic without needing real ECDSA signatures.  DO NOT deploy to production.
 */
contract MockPermit2 {
    function permitWitnessTransferFrom(
        IPermit2.PermitTransferFrom memory permit,
        IPermit2.SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes32, /* witness */
        string calldata, /* witnessTypeString */
        bytes calldata /* signature */
    ) external {
        // Transfer the requested amount from `owner` to `to`.
        // The owner must have approved this MockPermit2 address for the token.
        IERC20(permit.permitted.token).transferFrom(owner, transferDetails.to, transferDetails.requestedAmount);
    }

    function DOMAIN_SEPARATOR() external pure returns (bytes32) {
        return bytes32(0);
    }
}
