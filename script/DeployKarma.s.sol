// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {KARMA} from "../src/tokens/Karma.sol";
import {DeployBase} from "./lib/DeployBase.s.sol";
import {console2} from "forge-std/console2.sol";

contract DeployKarma is DeployBase {
    function deploy() public returns (address) {
        return deployOrUse("KARMA_ADDRESS", _deploy);
    }

    function _deploy() internal returns (address) {
        address admin = vm.envAddress("KARMA_ADMIN_ADDRESS");
        KARMA karma = new KARMA(admin);

        // Optional: set treasury if provided
        address treasury = vm.envOr("KARMA_TREASURY_ADDRESS", address(0));
        if (treasury != address(0)) {
            karma.setTreasury(treasury);
            console2.log("KARMA treasury set to:", treasury);
        }

        // Optional: set protocol fee if provided
        uint256 protocolFeePercent = vm.envOr("KARMA_PROTOCOL_FEE_PERCENT", uint256(0));
        if (protocolFeePercent > 0) {
            karma.setProtocolFeePercent(protocolFeePercent);
            console2.log("KARMA protocol fee set to:", protocolFeePercent, "bps");
        }

        return address(karma);
    }

    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        deploy();
        vm.stopBroadcast();
    }
}
