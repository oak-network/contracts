// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {TestToken} from "../test/mocks/TestToken.sol";
import {DeployBase} from "./lib/DeployBase.s.sol";

contract DeployTestToken is DeployBase {
    function deploy() public returns (address) {
        return deployOrUse("TOKEN_ADDRESS", _deploy);
    }

    function _deploy() internal returns (address) {
        string memory tokenName = vm.envOr("TOKEN_NAME", string("TestToken"));
        string memory tokenSymbol = vm.envOr("TOKEN_SYMBOL", string("TST"));
        uint8 decimals = uint8(vm.envOr("TOKEN_DECIMALS", uint256(18)));
        return address(new TestToken(tokenName, tokenSymbol, decimals));
    }

    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        deploy();
        vm.stopBroadcast();
    }
}
