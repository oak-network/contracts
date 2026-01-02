// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

contract DeployBase is Script {
    function deployOrUse(string memory envVar, function() internal returns (address) deployFn)
        internal
        returns (address deployedOrExisting)
    {
        address existing = vm.envOr(envVar, address(0));
        if (existing != address(0)) {
            console2.log(envVar, "Using existing contract at:", existing);
            return existing;
        }

        deployedOrExisting = deployFn();
        console2.log(envVar, "Deployed new contract at:", deployedOrExisting);
    }

    /**
     * @notice Checks if TestToken deployment should be skipped
     * @dev TestToken is only needed when CURRENCIES is not provided (defaults to USD)
     * @return true if TestToken should be deployed, false otherwise
     */
    function shouldDeployTestToken() internal returns (bool) {
        string memory currenciesConfig = vm.envOr("CURRENCIES", string(""));
        return bytes(currenciesConfig).length == 0;
    }

    function loadCurrenciesAndTokens(address defaultToken)
        internal
        returns (bytes32[] memory currencies, address[][] memory tokensPerCurrency)
    {
        string memory currenciesConfig = vm.envOr("CURRENCIES", string(""));
        if (bytes(currenciesConfig).length == 0) {
            currencies = new bytes32[](1);
            currencies[0] = _toCurrencyKey("USD");

            tokensPerCurrency = new address[][](1);
            tokensPerCurrency[0] = new address[](1);
            tokensPerCurrency[0][0] = defaultToken;
            return (currencies, tokensPerCurrency);
        }

        string memory tokensConfig = vm.envOr("TOKENS_PER_CURRENCY", string(""));
        require(bytes(tokensConfig).length != 0, "TOKENS_PER_CURRENCY env must be set");

        string[] memory currencyStrings = _split(currenciesConfig, ",");
        string[] memory perCurrencyConfigs = _split(tokensConfig, ";");
        require(currencyStrings.length == perCurrencyConfigs.length, "TOKENS_PER_CURRENCY length mismatch");

        currencies = new bytes32[](currencyStrings.length);
        for (uint256 i = 0; i < currencyStrings.length; i++) {
            string memory currency = _trimWhitespace(currencyStrings[i]);
            require(bytes(currency).length != 0, "Currency value empty");
            currencies[i] = _toCurrencyKey(currency);
        }

        tokensPerCurrency = new address[][](perCurrencyConfigs.length);
        for (uint256 i = 0; i < perCurrencyConfigs.length; i++) {
            string[] memory tokenStrings = _split(perCurrencyConfigs[i], ",");
            require(tokenStrings.length > 0, "Currency must have at least one token");

            tokensPerCurrency[i] = new address[](tokenStrings.length);
            for (uint256 j = 0; j < tokenStrings.length; j++) {
                string memory tokenString = _trimWhitespace(tokenStrings[j]);
                require(bytes(tokenString).length != 0, "Token address string empty");

                address tokenAddress = vm.parseAddress(tokenString);
                require(tokenAddress != address(0), "Token address cannot be zero");
                tokensPerCurrency[i][j] = tokenAddress;
            }
        }
    }

    function _split(string memory input, string memory delimiter) internal pure returns (string[] memory) {
        bytes memory inputBytes = bytes(input);
        bytes memory delimiterBytes = bytes(delimiter);
        require(delimiterBytes.length == 1, "Delimiter must be a single character");

        if (inputBytes.length == 0) {
            string[] memory empty = new string[](1);
            empty[0] = "";
            return empty;
        }

        uint256 parts = 1;
        for (uint256 i = 0; i < inputBytes.length; i++) {
            if (inputBytes[i] == delimiterBytes[0]) {
                unchecked {
                    ++parts;
                }
            }
        }

        string[] memory output = new string[](parts);
        uint256 lastIndex = 0;
        uint256 partIndex = 0;

        for (uint256 i = 0; i <= inputBytes.length; i++) {
            if (i == inputBytes.length || inputBytes[i] == delimiterBytes[0]) {
                output[partIndex] = _substring(inputBytes, lastIndex, i);
                unchecked {
                    ++partIndex;
                }
                lastIndex = i + 1;
            }
        }

        return output;
    }

    function _substring(bytes memory input, uint256 start, uint256 end) internal pure returns (string memory) {
        require(end >= start && end <= input.length, "Invalid substring range");

        bytes memory result = new bytes(end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = input[i];
        }
        return string(result);
    }

    function _trimWhitespace(string memory input) internal pure returns (string memory) {
        bytes memory inputBytes = bytes(input);
        uint256 start = 0;
        uint256 end = inputBytes.length;

        while (start < end && _isWhitespace(inputBytes[start])) {
            unchecked {
                ++start;
            }
        }

        while (end > start && _isWhitespace(inputBytes[end - 1])) {
            unchecked {
                --end;
            }
        }

        if (start == 0 && end == inputBytes.length) {
            return input;
        }

        return _substring(inputBytes, start, end);
    }

    function _isWhitespace(bytes1 char) private pure returns (bool) {
        return char == 0x20 /* space */ || char == 0x09 /* tab */ || char == 0x0A /* line feed */ || char == 0x0D; /* carriage return */
    }

    function _toCurrencyKey(string memory currency) internal pure returns (bytes32) {
        bytes memory currencyBytes = bytes(currency);
        require(currencyBytes.length <= 32, "Currency too long");

        bytes32 key;
        assembly {
            key := mload(add(currency, 32))
        }
        return key;
    }
}
