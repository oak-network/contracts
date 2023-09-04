// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

library AddressCalculator {
    function computeAddress(
        bytes32 salt,
        bytes32 bytecodeHash,
        address deployer
    ) internal view returns (address addr, bool isValid) {
        assembly {
            let freePtr := mload(0x40)
            mstore(add(freePtr, 0x40), bytecodeHash)
            mstore(add(freePtr, 0x20), salt)
            mstore(freePtr, deployer)
            let start := add(freePtr, 0x0b)
            mstore8(start, 0xff)
            addr := keccak256(start, 85)
        }
        return (addr, checkIfContractDeployed(addr));
    }

    function checkIfContractDeployed(
        address addr
    ) internal view returns (bool isValid) {
        bytes32 codeHash;
        assembly {
            codeHash := extcodehash(addr)
        }
        return (codeHash != 0x0 &&
            codeHash !=
            0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470);
    }
}
