// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

contract DeployBase is Script {
    function deployOrUse(
        string memory envVar,
        function() internal returns (address) deployFn
    ) internal returns (address deployedOrExisting) {
        address existing = vm.envOr(envVar, address(0));
        if (existing != address(0)) {
            console2.log(envVar, "Using existing contract at:", existing);
            return existing;
        }

        deployedOrExisting = deployFn();
        console2.log(envVar, "Deployed new contract at:", deployedOrExisting);
    }
}
