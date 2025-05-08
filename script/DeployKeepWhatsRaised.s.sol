// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {KeepWhatsRaised} from "src/treasuries/KeepWhatsRaised.sol";

contract DeployKeepWhatsRaisedImplementation is Script {
    function deploy() public returns (address) {
        console.log("Deploying KeepWhatsRaisedImplementation...");
        KeepWhatsRaised KeepWhatsRaisedImplementation = new KeepWhatsRaised();
        console.log("KeepWhatsRaisedImplementation deployed at:", address(KeepWhatsRaisedImplementation));
        return address(KeepWhatsRaisedImplementation);
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

        console.log("KEEP_WHATS_RAISED_IMPLEMENTATION_ADDRESS", implementationAddress);
    }
}