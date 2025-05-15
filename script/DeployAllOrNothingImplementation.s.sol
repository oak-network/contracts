// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {AllOrNothing} from "src/treasuries/AllOrNothing.sol";

contract DeployAllOrNothingImplementation is Script {
    function deploy() public returns (address) {
        console2.log("Deploying AllOrNothingImplementation...");
        AllOrNothing allOrNothingImplementation = new AllOrNothing();
        console2.log(
            "AllOrNothingImplementation deployed at:",
            address(allOrNothingImplementation)
        );
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

        console2.log(
            "ALL_OR_NOTHING_IMPLEMENTATION_ADDRESS",
            implementationAddress
        );
    }
}
