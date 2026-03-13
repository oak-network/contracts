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
        // Deploy with broadcaster as initial admin so setup calls succeed,
        // then transfer admin role to the intended admin at the end.
        address broadcaster = msg.sender;
        address admin = vm.envAddress("KARMA_ADMIN_ADDRESS");
        KARMA karma = new KARMA(broadcaster);

        // Optional: set treasury and grant it MINTER_ROLE
        address treasury = vm.envOr("KARMA_TREASURY_ADDRESS", address(0));
        if (treasury != address(0)) {
            karma.setTreasury(treasury);
            karma.grantRole(karma.MINTER_ROLE(), treasury);
            console2.log("KARMA treasury set to:", treasury);
        }

        // Optional: set protocol fee
        uint256 protocolFeePercent = vm.envOr("KARMA_PROTOCOL_FEE_PERCENT", uint256(0));
        if (protocolFeePercent > 0) {
            karma.setProtocolFeePercent(protocolFeePercent);
            console2.log("KARMA protocol fee set to:", protocolFeePercent, "bps");
        }

        // Transfer admin role to the intended admin and revoke from broadcaster
        if (admin != broadcaster) {
            karma.grantRole(karma.DEFAULT_ADMIN_ROLE(), admin);
            karma.grantRole(karma.MINTER_ROLE(), admin);
            karma.grantRole(keccak256("PAUSER_ROLE"), admin);
            karma.revokeRole(karma.MINTER_ROLE(), broadcaster);
            karma.revokeRole(keccak256("PAUSER_ROLE"), broadcaster);
            karma.revokeRole(karma.DEFAULT_ADMIN_ROLE(), broadcaster);
            console2.log("KARMA admin transferred to:", admin);
        }

        return address(karma);
    }

    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        deploy();
        vm.stopBroadcast();
    }
}
