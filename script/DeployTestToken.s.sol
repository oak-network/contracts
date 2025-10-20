// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TestToken} from "../test/mocks/TestToken.sol";
import {DeployBase} from "./lib/DeployBase.s.sol";

contract DeployTestToken is DeployBase {
    function deploy() public returns (address) {
        return deployOrUse("TOKEN_ADDRESS", _deploy);
    }

    function _deploy() internal returns (address) {
        string memory tokenName = vm.envOr("TOKEN_NAME", string("TestToken"));
        string memory tokenSymbol = vm.envOr("TOKEN_SYMBOL", string("TST"));
        return address(new TestToken(tokenName, tokenSymbol));
    }

    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        deploy();
        vm.stopBroadcast();
    }
}
