// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {DeployGlobalParams} from "./DeployGlobalParams.s.sol";
import {DeployTestToken} from "./DeployTestToken.s.sol";
import {DeployCampaignInfoFactory} from "./DeployCampaignInfoFactory.s.sol";
import {DeployTreasuryFactory} from "./DeployTreasuryFactory.s.sol";

contract DeployAll is Script {
    function deployTestToken() internal returns (address) {
        DeployTestToken script = new DeployTestToken();
        return script.deploy();
    }

    function deployGlobalParams(address testToken) internal returns (address) {
        DeployGlobalParams script = new DeployGlobalParams();
        return script.deployWithToken(testToken);
    }

    function deployTreasuryFactory(
        address globalParams
    ) internal returns (address) {
        DeployTreasuryFactory script = new DeployTreasuryFactory();
        return script.deploy(globalParams);
    }

    function deployCampaignFactory(
        address globalParams,
        address treasuryFactory
    ) internal returns (address) {
        DeployCampaignInfoFactory script = new DeployCampaignInfoFactory();
        return script.deploy(globalParams, treasuryFactory);
    }

    function run() external {
        bool simulate = vm.envOr("SIMULATE", false);
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        if (!simulate) {
            vm.startBroadcast(deployerKey);
        }

        address testToken = deployTestToken();
        address globalParams = deployGlobalParams(testToken);
        address treasuryFactory = deployTreasuryFactory(globalParams);
        address campaignFactory = deployCampaignFactory(
            globalParams,
            treasuryFactory
        );

        if (!simulate) {
            vm.stopBroadcast();
        }

        console2.log("TOKEN_ADDRESS", testToken);
        console2.log("GLOBAL_PARAMS_ADDRESS", globalParams);
        console2.log("TREASURY_FACTORY_ADDRESS", treasuryFactory);
        console2.log("CAMPAIGN_INFO_FACTORY_ADDRESS", campaignFactory);
    }
}
