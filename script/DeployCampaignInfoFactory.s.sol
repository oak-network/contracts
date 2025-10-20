// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {CampaignInfoFactory} from "src/CampaignInfoFactory.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {GlobalParams} from "src/GlobalParams.sol";
import {DeployBase} from "./lib/DeployBase.s.sol";

contract DeployCampaignInfoFactory is DeployBase {
    function deploy(
        address globalParams,
        address treasuryFactory
    ) public returns (address) {
        console2.log("Deploying CampaignInfoFactory...");

        // Properly deploy CampaignInfo with direct instantiation
        CampaignInfo campaignInfoImpl = new CampaignInfo(address(this));
        address campaignInfo = address(campaignInfoImpl);
        console2.log("CampaignInfo implementation deployed at:", campaignInfo);

        // Create and initialize the factory
        CampaignInfoFactory campaignInfoFactory = new CampaignInfoFactory(
            GlobalParams(globalParams),
            campaignInfo
        );

        campaignInfoFactory._initialize(treasuryFactory, globalParams);

        console2.log(
            "CampaignInfoFactory deployed and initialized at:",
            address(campaignInfoFactory)
        );
        return address(campaignInfoFactory);
    }

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        bool simulate = vm.envOr("SIMULATE", false);

        address globalParams = vm.envAddress("GLOBAL_PARAMS_ADDRESS");
        address treasuryFactory = vm.envAddress("TREASURY_FACTORY_ADDRESS");

        if (!simulate) {
            vm.startBroadcast(deployerKey);
        }

        address factoryAddress = deploy(globalParams, treasuryFactory);

        if (!simulate) {
            vm.stopBroadcast();
        }

        console2.log("CAMPAIGN_INFO_FACTORY_ADDRESS", factoryAddress);
    }
}
