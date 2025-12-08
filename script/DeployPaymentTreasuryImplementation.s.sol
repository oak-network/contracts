// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {PaymentTreasury} from "src/treasuries/PaymentTreasury.sol";

contract DeployPaymentTreasuryImplementation is Script {
    function deploy() public returns (address) {
        console2.log("Deploying PaymentTreasuryImplementation...");
        PaymentTreasury paymentTreasuryImplementation = new PaymentTreasury();
        console2.log("PaymentTreasuryImplementation deployed at:", address(paymentTreasuryImplementation));
        return address(paymentTreasuryImplementation);
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

        console2.log("PAYMENT_TREASURY_IMPLEMENTATION_ADDRESS", implementationAddress);
    }
}

