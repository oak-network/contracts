// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {TimeConstrainedPaymentTreasury} from "src/treasuries/TimeConstrainedPaymentTreasury.sol";

contract DeployTimeConstrainedPaymentTreasuryImplementation is Script {
    function deploy() public returns (address) {
        console2.log("Deploying TimeConstrainedPaymentTreasuryImplementation...");
        TimeConstrainedPaymentTreasury timeConstrainedPaymentTreasuryImplementation = new TimeConstrainedPaymentTreasury();
        console2.log("TimeConstrainedPaymentTreasuryImplementation deployed at:", address(timeConstrainedPaymentTreasuryImplementation));
        return address(timeConstrainedPaymentTreasuryImplementation);
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

        console2.log("TIME_CONSTRAINED_PAYMENT_TREASURY_IMPLEMENTATION_ADDRESS", implementationAddress);
    }
}

