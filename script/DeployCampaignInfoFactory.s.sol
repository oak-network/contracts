// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {CampaignInfoFactory} from "src/CampaignInfoFactory.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {GlobalParams} from "src/GlobalParams.sol";
import {IGlobalParams} from "src/interfaces/IGlobalParams.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DeployBase} from "./lib/DeployBase.s.sol";

contract DeployCampaignInfoFactory is DeployBase {
    function deploy(
        address globalParams,
        address treasuryFactory
    ) public returns (address) {
        console2.log("Deploying CampaignInfoFactory...");

        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));

        // Deploy CampaignInfo implementation
        CampaignInfo campaignInfoImpl = new CampaignInfo();
        address campaignInfo = address(campaignInfoImpl);
        console2.log("CampaignInfo implementation deployed at:", campaignInfo);

        // Deploy CampaignInfoFactory implementation
        CampaignInfoFactory factoryImplementation = new CampaignInfoFactory();
        console2.log("CampaignInfoFactory implementation deployed at:", address(factoryImplementation));

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            CampaignInfoFactory.initialize.selector,
            deployer,
            IGlobalParams(globalParams),
            campaignInfo,
            treasuryFactory
        );

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(factoryImplementation), initData);

        console2.log(
            "CampaignInfoFactory proxy deployed and initialized at:",
            address(proxy)
        );
        return address(proxy);
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
