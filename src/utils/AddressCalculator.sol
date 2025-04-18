// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @title AddressCalculator
 * @notice A Solidity library for computing contract addresses and checking if a contract is deployed at a given address.
 */
library AddressCalculator {
    /**
     * @dev Computes the contract address using CREATE2 and checks if the contract is deployed.
     * @param salt The salt value used for address computation.
     * @param bytecodeHash The keccak256 hash of the contract's bytecode.
     * @param deployer The address that deploys the contract.
     * @return addr The computed contract address.
     * @return isValid True if a contract is deployed at the address; otherwise, false.
     */
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

    /**
     * @dev Checks if a contract is deployed at the given address.
     * @param addr The address to check for contract deployment.
     * @return isValid True if a contract is deployed at the address; otherwise, false.
     */
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
