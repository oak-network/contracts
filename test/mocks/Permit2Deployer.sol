// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Force compilation of the Permit2 contract so that `deployCodeTo("Permit2.sol:Permit2", ...)`
// can locate the artifact during tests.
import {Permit2} from "permit2/src/Permit2.sol";
