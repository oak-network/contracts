// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";

contract DeployCampaignInfoImplementation is Script {
    function deploy() public returns (address) {
        console.log("Deploying CampaignInfo implementation...");
        // Implementation will use the script address as admin, but this will be replaced 
        // when the factory creates new instances
        CampaignInfo campaignInfo = new CampaignInfo(address(this));
        console.log("CampaignInfo implementation deployed at:", address(campaignInfo));
        return address(campaignInfo);
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

        console.log("CAMPAIGN_INFO_ADDRESS", implementationAddress);
    }
}