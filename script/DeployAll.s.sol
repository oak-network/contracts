// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {console2} from "forge-std/console2.sol";
import {TestToken} from "../test/mocks/TestToken.sol";
import {GlobalParams} from "src/GlobalParams.sol";
import {CampaignInfoFactory} from "src/CampaignInfoFactory.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {TreasuryFactory} from "src/TreasuryFactory.sol";
import {IGlobalParams} from "src/interfaces/IGlobalParams.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DataRegistryKeys} from "src/constants/DataRegistryKeys.sol";
import {DeployBase} from "./lib/DeployBase.s.sol";

contract DeployAll is DeployBase {
    function run() external {
        bool simulate = vm.envOr("SIMULATE", false);
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerKey);

        if (!simulate) {
            vm.startBroadcast(deployerKey);
        }

        // Deploy TestToken only if needed
        address testTokenAddress;
        bool testTokenDeployed = false;
        
        if (shouldDeployTestToken()) {
            string memory tokenName = vm.envOr("TOKEN_NAME", string("TestToken"));
            string memory tokenSymbol = vm.envOr("TOKEN_SYMBOL", string("TST"));
            uint8 decimals = uint8(vm.envOr("TOKEN_DECIMALS", uint256(18)));

            TestToken testToken = new TestToken(tokenName, tokenSymbol, decimals);
            testTokenAddress = address(testToken);
            testTokenDeployed = true;
            console2.log("TestToken deployed at:", testTokenAddress);
        } else {
            console2.log("Skipping TestToken deployment - using custom tokens for currencies");
        }

        // Deploy GlobalParams with UUPS proxy
        uint256 protocolFeePercent = vm.envOr("PROTOCOL_FEE_PERCENT", uint256(100));

        (bytes32[] memory currencies, address[][] memory tokensPerCurrency) =
            loadCurrenciesAndTokens(testTokenAddress);

        // Deploy GlobalParams implementation
        GlobalParams globalParamsImpl = new GlobalParams();
        console2.log("GlobalParams implementation deployed at:", address(globalParamsImpl));

        // Prepare initialization data for GlobalParams
        bytes memory globalParamsInitData = abi.encodeWithSelector(
            GlobalParams.initialize.selector, deployerAddress, protocolFeePercent, currencies, tokensPerCurrency
        );

        // Deploy GlobalParams proxy
        ERC1967Proxy globalParamsProxy = new ERC1967Proxy(address(globalParamsImpl), globalParamsInitData);
        console2.log("GlobalParams proxy deployed at:", address(globalParamsProxy));

        // Deploy TreasuryFactory with UUPS proxy
        TreasuryFactory treasuryFactoryImpl = new TreasuryFactory();
        console2.log("TreasuryFactory implementation deployed at:", address(treasuryFactoryImpl));

        // Prepare initialization data for TreasuryFactory
        bytes memory treasuryFactoryInitData =
            abi.encodeWithSelector(TreasuryFactory.initialize.selector, IGlobalParams(address(globalParamsProxy)));

        // Deploy TreasuryFactory proxy
        ERC1967Proxy treasuryFactoryProxy = new ERC1967Proxy(address(treasuryFactoryImpl), treasuryFactoryInitData);
        console2.log("TreasuryFactory proxy deployed at:", address(treasuryFactoryProxy));

        // Deploy CampaignInfo implementation
        CampaignInfo campaignInfoImplementation = new CampaignInfo();
        console2.log("CampaignInfo implementation deployed at:", address(campaignInfoImplementation));

        // Deploy CampaignInfoFactory with UUPS proxy
        CampaignInfoFactory campaignFactoryImpl = new CampaignInfoFactory();
        console2.log("CampaignInfoFactory implementation deployed at:", address(campaignFactoryImpl));

        // Prepare initialization data for CampaignInfoFactory
        bytes memory campaignFactoryInitData = abi.encodeWithSelector(
            CampaignInfoFactory.initialize.selector,
            deployerAddress,
            IGlobalParams(address(globalParamsProxy)),
            address(campaignInfoImplementation),
            address(treasuryFactoryProxy)
        );

        // Deploy CampaignInfoFactory proxy
        ERC1967Proxy campaignFactoryProxy = new ERC1967Proxy(address(campaignFactoryImpl), campaignFactoryInitData);
        console2.log("CampaignInfoFactory proxy deployed at:", address(campaignFactoryProxy));

        // Configure registry values
        uint256 bufferTime = vm.envOr("BUFFER_TIME", uint256(0));
        uint256 campaignLaunchBuffer = vm.envOr("CAMPAIGN_LAUNCH_BUFFER", uint256(0));
        uint256 minimumCampaignDuration = vm.envOr("MINIMUM_CAMPAIGN_DURATION", uint256(0));

        GlobalParams(address(globalParamsProxy)).addToRegistry(DataRegistryKeys.BUFFER_TIME, bytes32(bufferTime));
        GlobalParams(address(globalParamsProxy))
            .addToRegistry(DataRegistryKeys.CAMPAIGN_LAUNCH_BUFFER, bytes32(campaignLaunchBuffer));
        GlobalParams(address(globalParamsProxy))
            .addToRegistry(DataRegistryKeys.MINIMUM_CAMPAIGN_DURATION, bytes32(minimumCampaignDuration));

        if (!simulate) {
            vm.stopBroadcast();
        }

        // Summary
        console2.log("\n===========================================");
        console2.log("    Deployment Summary");
        console2.log("===========================================");
        
        console2.log("\n--- Core Protocol Contracts (UUPS Proxies) ---");
        console2.log("GLOBAL_PARAMS_PROXY:", address(globalParamsProxy));
        console2.log("  Implementation:", address(globalParamsImpl));
        console2.log("TREASURY_FACTORY_PROXY:", address(treasuryFactoryProxy));
        console2.log("  Implementation:", address(treasuryFactoryImpl));
        console2.log("CAMPAIGN_INFO_FACTORY_PROXY:", address(campaignFactoryProxy));
        console2.log("  Implementation:", address(campaignFactoryImpl));
        
        console2.log("\n--- Implementation Contracts ---");
        console2.log("CAMPAIGN_INFO_IMPLEMENTATION:", address(campaignInfoImplementation));
        
        console2.log("\n--- Supported Currencies & Tokens ---");
        string memory currenciesConfig = vm.envOr("CURRENCIES", string(""));
        if (bytes(currenciesConfig).length > 0) {
            string[] memory currencyStrings = _split(currenciesConfig, ",");
            string memory tokensConfig = vm.envOr("TOKENS_PER_CURRENCY", string(""));
            string[] memory perCurrencyConfigs = _split(tokensConfig, ";");
            
            for (uint256 i = 0; i < currencyStrings.length; i++) {
                string memory currency = _trimWhitespace(currencyStrings[i]);
                console2.log(string(abi.encodePacked("Currency: ", currency)));
                
                string[] memory tokenStrings = _split(perCurrencyConfigs[i], ",");
                for (uint256 j = 0; j < tokenStrings.length; j++) {
                    console2.log("  Token:", _trimWhitespace(tokenStrings[j]));
                }
            }
        } else {
            console2.log("Currency: USD (default)");
            if (testTokenDeployed) {
                console2.log("  Token:", testTokenAddress);
                console2.log("  (TestToken deployed for testing)");
            }
        }
        
        console2.log("\n===========================================");
        console2.log("Deployment completed successfully!");
        console2.log("===========================================");
    }
}
