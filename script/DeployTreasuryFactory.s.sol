// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TreasuryFactory} from "../src/TreasuryFactory.sol";
import {GlobalParams} from "../src/GlobalParams.sol";
import {DeployBase} from "./lib/DeployBase.s.sol";

contract DeployTreasuryFactory is DeployBase {
    function deploy(address _globalParams) public returns (address) {
        require(_globalParams != address(0), "GlobalParams not set");
        return address(new TreasuryFactory(GlobalParams(_globalParams)));
    }

    function run() external {
        address globalParams = vm.envOr("GLOBAL_PARAMS_ADDRESS", address(0));
        require(globalParams != address(0), "GlobalParams must be set");

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        deploy(globalParams);
        vm.stopBroadcast();
    }
}
