// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {console2} from "forge-std/console2.sol";

import {CrossChainExecutor} from "src/crosschain/CrossChainExecutor.sol";
import {DeployBase} from "../lib/DeployBase.s.sol";

contract DeployCrossChainExecutor is DeployBase {
    function deploy(address agent) public returns (address) {
        console2.log("Deploying CrossChainExecutor...");
        CrossChainExecutor executor = new CrossChainExecutor(agent);
        console2.log("CrossChainExecutor deployed at:", address(executor));
        return address(executor);
    }

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        bool simulate = vm.envOr("SIMULATE", false);

        address agent = vm.envAddress("AGENT_ADDRESS");
        require(agent != address(0), "AGENT_ADDRESS required");

        if (!simulate) {
            vm.startBroadcast(deployerKey);
        }

        address executor = deploy(agent);

        if (!simulate) {
            vm.stopBroadcast();
        }

        console2.log("CROSS_CHAIN_EXECUTOR_ADDRESS", executor);
    }
}
