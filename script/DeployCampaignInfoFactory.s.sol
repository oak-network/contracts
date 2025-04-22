// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {CampaignInfo} from "../src/CampaignInfo.sol";
import {CampaignInfoFactory} from "../src/CampaignInfoFactory.sol";
import {GlobalParams} from "../src/GlobalParams.sol";
import {TreasuryFactory} from "../src/TreasuryFactory.sol";
import {DeployBase} from "./lib/DeployBase.s.sol";

contract DeployCampaignInfoFactory is DeployBase {
    function deploy(
        address _globalParams,
        address _treasuryFactory
    ) public returns (address) {
        require(_globalParams != address(0), "GlobalParams not set");
        require(_treasuryFactory != address(0), "TreasuryFactory not set");

        // Deploy CampaignInfo implementation
        CampaignInfo campaignInfo = new CampaignInfo(msg.sender);

        // Deploy CampaignInfoFactory
        CampaignInfoFactory factory = new CampaignInfoFactory(
            GlobalParams(_globalParams),
            address(campaignInfo)
        );

        // Initialize the factory
        factory._initialize(_treasuryFactory, _globalParams);

        return address(factory);
    }

    function run() external {
        address globalParams = vm.envOr("GLOBAL_PARAMS_ADDRESS", address(0));
        address treasuryFactory = vm.envOr(
            "TREASURY_FACTORY_ADDRESS",
            address(0)
        );

        require(globalParams != address(0), "GlobalParams must be set");
        require(treasuryFactory != address(0), "TreasuryFactory must be set");

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        deploy(globalParams, treasuryFactory);
        vm.stopBroadcast();
    }
}