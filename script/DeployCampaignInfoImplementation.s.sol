// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";

contract DeployCampaignInfoImplementation is Script {
    function deploy() public returns (address) {
        console2.log("Deploying CampaignInfo implementation...");
        // Implementation will use the script address as admin, but this will be replaced
        // when the factory creates new instances
        CampaignInfo campaignInfo = new CampaignInfo(address(this));
        console2.log(
            "CampaignInfo implementation deployed at:",
            address(campaignInfo)
        );
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

        console2.log("CAMPAIGN_INFO_ADDRESS", implementationAddress);
    }
}
