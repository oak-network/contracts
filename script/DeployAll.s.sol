// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {TestToken} from "../test/mocks/TestToken.sol";
import {GlobalParams} from "src/GlobalParams.sol";
import {CampaignInfoFactory} from "src/CampaignInfoFactory.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {TreasuryFactory} from "src/TreasuryFactory.sol";
import {IGlobalParams} from "src/interfaces/IGlobalParams.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployAll is Script {
    function run() external {
        bool simulate = vm.envOr("SIMULATE", false);
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerKey);

        if (!simulate) {
            vm.startBroadcast(deployerKey);
        }

        // Deploy TestToken
        string memory tokenName = vm.envOr("TOKEN_NAME", string("TestToken"));
        string memory tokenSymbol = vm.envOr("TOKEN_SYMBOL", string("TST"));
        uint8 decimals = uint8(vm.envOr("TOKEN_DECIMALS", uint256(18)));
        
        TestToken testToken = new TestToken(tokenName, tokenSymbol, decimals);
        console2.log("TestToken deployed at:", address(testToken));

        // Deploy GlobalParams with UUPS proxy
        uint256 protocolFeePercent = vm.envOr("PROTOCOL_FEE_PERCENT", uint256(100));
        
        bytes32[] memory currencies = new bytes32[](1);
        address[][] memory tokensPerCurrency = new address[][](1);
        currencies[0] = keccak256(abi.encodePacked("USD"));
        tokensPerCurrency[0] = new address[](1);
        tokensPerCurrency[0][0] = address(testToken);
        
        // Deploy GlobalParams implementation
        GlobalParams globalParamsImpl = new GlobalParams();
        console2.log("GlobalParams implementation deployed at:", address(globalParamsImpl));
        
        // Prepare initialization data for GlobalParams
        bytes memory globalParamsInitData = abi.encodeWithSelector(
            GlobalParams.initialize.selector,
            deployerAddress,
            protocolFeePercent,
            currencies,
            tokensPerCurrency
        );
        
        // Deploy GlobalParams proxy
        ERC1967Proxy globalParamsProxy = new ERC1967Proxy(
            address(globalParamsImpl),
            globalParamsInitData
        );
        console2.log("GlobalParams proxy deployed at:", address(globalParamsProxy));

        // Deploy TreasuryFactory with UUPS proxy
        TreasuryFactory treasuryFactoryImpl = new TreasuryFactory();
        console2.log("TreasuryFactory implementation deployed at:", address(treasuryFactoryImpl));
        
        // Prepare initialization data for TreasuryFactory
        bytes memory treasuryFactoryInitData = abi.encodeWithSelector(
            TreasuryFactory.initialize.selector,
            IGlobalParams(address(globalParamsProxy))
        );
        
        // Deploy TreasuryFactory proxy
        ERC1967Proxy treasuryFactoryProxy = new ERC1967Proxy(
            address(treasuryFactoryImpl),
            treasuryFactoryInitData
        );
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
        ERC1967Proxy campaignFactoryProxy = new ERC1967Proxy(
            address(campaignFactoryImpl),
            campaignFactoryInitData
        );
        console2.log("CampaignInfoFactory proxy deployed at:", address(campaignFactoryProxy));

        if (!simulate) {
            vm.stopBroadcast();
        }

        // Summary
        console2.log("\n--- Deployment Summary ---");
        console2.log("TOKEN_ADDRESS", address(testToken));
        console2.log("GLOBAL_PARAMS_ADDRESS", address(globalParamsProxy));
        console2.log("GLOBAL_PARAMS_IMPLEMENTATION", address(globalParamsImpl));
        console2.log("TREASURY_FACTORY_ADDRESS", address(treasuryFactoryProxy));
        console2.log("TREASURY_FACTORY_IMPLEMENTATION", address(treasuryFactoryImpl));
        console2.log("CAMPAIGN_INFO_FACTORY_ADDRESS", address(campaignFactoryProxy));
        console2.log("CAMPAIGN_INFO_FACTORY_IMPLEMENTATION", address(campaignFactoryImpl));
    }
}
