// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {KeepWhatsRaised} from "src/treasuries/KeepWhatsRaised.sol";

contract DeployKeepWhatsRaisedImplementation is Script {
    function deploy() public returns (address) {
        console2.log("Deploying KeepWhatsRaisedImplementation...");
        KeepWhatsRaised keepWhatsRaisedImplementation = new KeepWhatsRaised();
        console2.log(
            "KeepWhatsRaisedImplementation deployed at:",
            address(keepWhatsRaisedImplementation)
        );
        return address(keepWhatsRaisedImplementation);
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
            "KEEP_WHATS_RAISED_IMPLEMENTATION_ADDRESS",
            implementationAddress
        );
    }
}