// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";

abstract contract LogDecoder is Test {
    function findLogByTopic(
        Vm.Log[] memory logs,
        bytes32 topic0
    ) internal pure returns (Vm.Log memory) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == topic0) {
                return logs[i];
            }
        }
        revert("Log with specified topic not found");
    }

    function decodeEventFromLogs(
        Vm.Log[] memory logs,
        string memory eventSignature,
        address expectedEmitter
    ) internal pure returns (bytes memory) {
        bytes32 expectedTopic = keccak256(bytes(eventSignature));

        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].topics[0] == expectedTopic &&
                logs[i].emitter == expectedEmitter
            ) {
                return logs[i].data;
            }
        }
        revert("Event not found in logs");
    }

    function decodeTopicsAndData(
        Vm.Log[] memory logs,
        string memory eventSignature,
        address expectedEmitter
    ) internal pure returns (bytes32[] memory topics, bytes memory data) {
        bytes32 expectedTopic = keccak256(bytes(eventSignature));

        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].topics.length > 0 &&
                logs[i].topics[0] == expectedTopic &&
                logs[i].emitter == expectedEmitter
            ) {
                return (logs[i].topics, logs[i].data);
            }
        }

        revert("Event not found in logs");
    }
}
