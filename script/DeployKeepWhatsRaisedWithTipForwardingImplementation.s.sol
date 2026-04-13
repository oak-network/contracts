// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {KeepWhatsRaisedWithTipForwarding} from "src/treasuries/KeepWhatsRaisedWithTipForwarding.sol";

contract DeployKeepWhatsRaisedWithTipForwardingImplementation is Script {
    function deploy() public returns (address) {
        console2.log("Deploying KeepWhatsRaisedWithTipForwardingImplementation...");
        KeepWhatsRaisedWithTipForwarding keepWhatsRaisedWithTipForwardingImplementation = new KeepWhatsRaisedWithTipForwarding();
        console2.log("KeepWhatsRaisedWithTipForwardingImplementation deployed at:", address(keepWhatsRaisedWithTipForwardingImplementation));
        return address(keepWhatsRaisedWithTipForwardingImplementation);
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

        console2.log("KWR_TIP_FORWARDING_IMPLEMENTATION_ADDRESS", implementationAddress);
    }
}
