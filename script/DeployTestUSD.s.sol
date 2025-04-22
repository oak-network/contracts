// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {TestUSD} from "../src/TestUSD.sol";
import {DeployBase} from "./lib/DeployBase.s.sol";

contract DeployTestUSD is DeployBase {
    function deploy() public returns (address) {
        return deployOrUse("TEST_USD_ADDRESS", _deploy);
    }

    function _deploy() internal returns (address) {
        return address(new TestUSD());
    }

    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        deploy();
        vm.stopBroadcast();
    }
}
