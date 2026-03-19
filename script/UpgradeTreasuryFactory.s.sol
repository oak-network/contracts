// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {TreasuryFactory} from "../src/TreasuryFactory.sol";

/**
 * @title UpgradeTreasuryFactory
 * @notice Script to upgrade the TreasuryFactory implementation contract
 * @dev Uses UUPS upgrade pattern
 */
contract UpgradeTreasuryFactory is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("TREASURY_FACTORY_ADDRESS");
        address campaignInfoFactoryAddress = vm.envAddress("CAMPAIGN_INFO_FACTORY_ADDRESS");

        require(proxyAddress != address(0), "Proxy address must be set");
        require(campaignInfoFactoryAddress != address(0), "CAMPAIGN_INFO_FACTORY_ADDRESS must be set");

        vm.startBroadcast(deployerKey);

        // Deploy new implementation
        TreasuryFactory newImplementation = new TreasuryFactory();
        console2.log("New TreasuryFactory implementation deployed at:", address(newImplementation));

        // Upgrade the proxy to point to the new implementation
        TreasuryFactory proxy = TreasuryFactory(proxyAddress);
        proxy.upgradeToAndCall(address(newImplementation), "");

        console2.log("TreasuryFactory proxy upgraded successfully");
        console2.log("Proxy address:", proxyAddress);
        console2.log("New implementation address:", address(newImplementation));

        // Wire in CampaignInfoFactory so the new validation guard does not brick deploy()
        proxy.setCampaignInfoFactory(campaignInfoFactoryAddress);
        console2.log("CampaignInfoFactory wired into TreasuryFactory:", campaignInfoFactoryAddress);

        vm.stopBroadcast();
    }
}
