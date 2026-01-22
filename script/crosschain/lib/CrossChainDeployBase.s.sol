// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {DeployBase} from "../../lib/DeployBase.s.sol";

abstract contract CrossChainDeployBase is DeployBase {
    enum Mode {
        TEST,
        MAIN
    }

    struct ChainConfig {
        uint256 destinationChainId;
        uint256 sourceChainId;
        address destinationCcipRouter;
        address destinationLzEndpoint;
        address sourceCcipRouter;
        uint64 destinationCcipSelector;
        uint64 sourceCcipSelector;
        uint32 destinationLzEid;
        uint32 sourceLzEid;
    }

    bytes1 private constant BRACKET_OPEN = 0x5b; // [
    bytes1 private constant BRACKET_CLOSE = 0x5d; // ]
    bytes1 private constant DOUBLE_QUOTE = 0x22; // "
    bytes1 private constant SINGLE_QUOTE = 0x27; // '

    function _loadMode() internal view returns (Mode mode, string memory label) {
        string memory modeEnv = vm.envOr("MODE", string("TEST"));
        modeEnv = _toUpper(_trimWhitespace(modeEnv));

        if (_equals(modeEnv, "MAIN")) {
            return (Mode.MAIN, "MAIN");
        }
        if (_equals(modeEnv, "TEST") || bytes(modeEnv).length == 0) {
            return (Mode.TEST, "TEST");
        }
        revert("MODE must be MAIN or TEST");
    }

    function _loadChainConfig(Mode mode) internal pure returns (ChainConfig memory config) {
        if (mode == Mode.MAIN) {
            config.destinationChainId = 1; // Ethereum mainnet
            config.sourceChainId = 42161; // Arbitrum
            config.destinationCcipRouter = 0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D;
            config.destinationLzEndpoint = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B;
            config.sourceCcipRouter = 0x141fa059441E0ca23ce184B6A78bafD2A517DdE8;
            config.destinationCcipSelector = 5009297550715157269;
            config.sourceCcipSelector = 4949039107694359620;
            config.destinationLzEid = 30391;
            config.sourceLzEid = 30110;
        } else {
            config.destinationChainId = 11155111; // Ethereum Sepolia
            config.sourceChainId = 421614; // Arbitrum Sepolia
            config.destinationCcipRouter = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;
            config.destinationLzEndpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f;
            config.sourceCcipRouter = 0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165;
            config.destinationCcipSelector = 16015286601757825753;
            config.sourceCcipSelector = 3478487238524512106;
            config.destinationLzEid = 40161;
            config.sourceLzEid = 40231;
        }
    }

    function _parseSourceNetworks() internal view returns (string[] memory networks) {
        string memory sourceNetworks = vm.envOr("SOURCE_NETWORKS", string(""));
        if (bytes(sourceNetworks).length == 0) {
            networks = new string[](1);
            networks[0] = "ARB";
            return networks;
        }

        sourceNetworks = _stripBrackets(_trimWhitespace(sourceNetworks));
        if (bytes(sourceNetworks).length == 0) {
            revert("SOURCE_NETWORKS empty");
        }

        string[] memory raw = _split(sourceNetworks, ",");
        networks = new string[](raw.length);
        for (uint256 i = 0; i < raw.length; i++) {
            string memory item = _trimWhitespace(raw[i]);
            item = _stripQuotes(item);
            item = _toUpper(item);
            if (bytes(item).length == 0) {
                revert("SOURCE_NETWORKS entry empty");
            }
            networks[i] = item;
        }
    }

    function _requireArbitrumOnly(string[] memory networks) internal pure {
        if (networks.length != 1 || !_equals(networks[0], "ARB")) {
            revert("Unsupported source network");
        }
    }

    function _requireChainId(uint256 expectedChainId, string memory label) internal view {
        if (block.chainid != expectedChainId) {
            revert(string(abi.encodePacked(label, " chainId mismatch")));
        }
    }

    function _stripBrackets(string memory input) internal pure returns (string memory) {
        bytes memory data = bytes(input);
        uint256 start = 0;
        uint256 end = data.length;

        if (end > 0 && data[0] == BRACKET_OPEN) {
            start = 1;
        }
        if (end > start && data[end - 1] == BRACKET_CLOSE) {
            end -= 1;
        }

        if (start == 0 && end == data.length) {
            return input;
        }
        return _substring(data, start, end);
    }

    function _stripQuotes(string memory input) internal pure returns (string memory) {
        bytes memory data = bytes(input);
        if (data.length >= 2) {
            bytes1 first = data[0];
            bytes1 last = data[data.length - 1];
            bool isDoubleQuoted = first == DOUBLE_QUOTE && last == DOUBLE_QUOTE;
            bool isSingleQuoted = first == SINGLE_QUOTE && last == SINGLE_QUOTE;
            if (isDoubleQuoted || isSingleQuoted) {
                return _substring(data, 1, data.length - 1);
            }
        }
        return input;
    }

    function _toUpper(string memory input) internal pure returns (string memory) {
        bytes memory data = bytes(input);
        for (uint256 i = 0; i < data.length; i++) {
            if (data[i] >= 0x61 && data[i] <= 0x7A) {
                data[i] = bytes1(uint8(data[i]) - 32);
            }
        }
        return string(data);
    }

    function _equals(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
