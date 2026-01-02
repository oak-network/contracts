// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {CampaignInfoFactory} from "../src/CampaignInfoFactory.sol";

/**
 * @title UpgradeCampaignInfoFactory
 * @notice Script to upgrade the CampaignInfoFactory implementation contract
 * @dev Uses UUPS upgrade pattern
 */
contract UpgradeCampaignInfoFactory is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("CAMPAIGN_INFO_FACTORY_ADDRESS");

        require(proxyAddress != address(0), "Proxy address must be set");

        vm.startBroadcast(deployerKey);

        // Deploy new implementation
        CampaignInfoFactory newImplementation = new CampaignInfoFactory();
        console2.log("New CampaignInfoFactory implementation deployed at:", address(newImplementation));

        // Upgrade the proxy to point to the new implementation
        CampaignInfoFactory proxy = CampaignInfoFactory(proxyAddress);
        proxy.upgradeToAndCall(address(newImplementation), "");

        console2.log("CampaignInfoFactory proxy upgraded successfully");
        console2.log("Proxy address:", proxyAddress);
        console2.log("New implementation address:", address(newImplementation));

        vm.stopBroadcast();
    }
}
