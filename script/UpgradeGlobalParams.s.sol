// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {GlobalParams} from "../src/GlobalParams.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title UpgradeGlobalParams
 * @notice Script to upgrade the GlobalParams implementation contract
 * @dev Uses UUPS upgrade pattern
 */
contract UpgradeGlobalParams is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("GLOBAL_PARAMS_ADDRESS");
        
        require(proxyAddress != address(0), "Proxy address must be set");

        vm.startBroadcast(deployerKey);

        // Deploy new implementation
        GlobalParams newImplementation = new GlobalParams();
        console2.log("New GlobalParams implementation deployed at:", address(newImplementation));

        // Upgrade the proxy to point to the new implementation
        GlobalParams proxy = GlobalParams(proxyAddress);
        proxy.upgradeToAndCall(address(newImplementation), "");
        
        console2.log("GlobalParams proxy upgraded successfully");
        console2.log("Proxy address:", proxyAddress);
        console2.log("New implementation address:", address(newImplementation));

        vm.stopBroadcast();
    }
}

