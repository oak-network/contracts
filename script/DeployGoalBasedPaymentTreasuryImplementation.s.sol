// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {GoalBasedPaymentTreasury} from "src/treasuries/GoalBasedPaymentTreasury.sol";

contract DeployGoalBasedPaymentTreasuryImplementation is Script {
    function deploy() public returns (address) {
        console2.log("Deploying GoalBasedPaymentTreasuryImplementation...");
        GoalBasedPaymentTreasury goalBasedPaymentTreasuryImplementation = new GoalBasedPaymentTreasury();
        console2.log("GoalBasedPaymentTreasuryImplementation deployed at:", address(goalBasedPaymentTreasuryImplementation));
        return address(goalBasedPaymentTreasuryImplementation);
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

        console2.log("GOAL_BASED_PAYMENT_TREASURY_IMPLEMENTATION_ADDRESS", implementationAddress);
    }
}

