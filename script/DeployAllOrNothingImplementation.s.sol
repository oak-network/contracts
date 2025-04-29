// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {AllOrNothing} from "src/treasuries/AllOrNothing.sol";

contract DeployAllOrNothingImplementation is Script {
    function deploy() public returns (address) {
        console.log("Deploying AllOrNothingImplementation...");
        AllOrNothing allOrNothingImplementation = new AllOrNothing();
        console.log("AllOrNothingImplementation deployed at:", address(allOrNothingImplementation));
        return address(allOrNothingImplementation);
    }

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        bool simulate = vm.envOr("SIMULATE", false);

        if (!simulate) {
            vm.startBroadcast(deployerKey);
        }

        address implementationAddress = deploy();

        if (!simulate) {
            vm.stopBroadcast();
        }

        console.log("ALL_OR_NOTHING_IMPLEMENTATION_ADDRESS", implementationAddress);
    }
}