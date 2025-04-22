// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {GlobalParams} from "../src/GlobalParams.sol";
import {DeployBase} from "./lib/DeployBase.s.sol";

contract DeployGlobalParams is DeployBase {
    function deployWithToken(address token) public returns (address) {
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        return address(new GlobalParams(deployer, token, 200));
    }

    function deploy() public returns (address) {
        return deployOrUse("GLOBAL_PARAMS_ADDRESS", _deploy);
    }

    function _deploy() internal returns (address) {
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        address token = vm.envOr("TEST_USD_ADDRESS", address(0));
        require(token != address(0), "TestUSD address must be set");
        return address(new GlobalParams(deployer, token, 200));
    }

    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        deploy();
        vm.stopBroadcast();
    }
}
