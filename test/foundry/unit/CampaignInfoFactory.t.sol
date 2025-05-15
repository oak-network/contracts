// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {CampaignInfoFactory} from "src/CampaignInfoFactory.sol";
import {GlobalParams} from "src/GlobalParams.sol";
import {TreasuryFactory} from "src/TreasuryFactory.sol";
import {TestUSD} from "../../mocks/TestUSD.sol";
import {Defaults} from "../Base.t.sol";
import {ICampaignData} from "src/interfaces/ICampaignData.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";

contract CampaignInfoFactory_UnitTest is Test, Defaults {
    CampaignInfoFactory internal factory;
    TreasuryFactory internal treasuryFactory;
    GlobalParams internal globalParams;
    TestUSD internal testUSD;
    CampaignInfo internal campaignInfoImplementation;

    address internal admin = address(0xA11CE);

    function setUp() public {
        testUSD = new TestUSD();
        globalParams = new GlobalParams(
            admin,
            address(testUSD),
            PROTOCOL_FEE_PERCENT
        );
        campaignInfoImplementation = new CampaignInfo(address(this));
        treasuryFactory = new TreasuryFactory(globalParams);
        factory = new CampaignInfoFactory(
            globalParams,
            address(campaignInfoImplementation)
        );
        vm.startPrank(admin);
        globalParams.enlistPlatform(
            PLATFORM_1_HASH,
            admin,
            PLATFORM_FEE_PERCENT
        );
        vm.stopPrank();
    }

    function testInitializeSetsTreasuryAndGlobalParams() public {
        // vm.startPrank(address(this)); // this is owner

        factory._initialize(address(treasuryFactory), address(globalParams));
        // Success assumed if no revert
        // vm.stopPrank();
    }

    function testCreateCampaignDeploysSuccessfully() public {
        factory._initialize(address(treasuryFactory), address(globalParams));

        bytes32[] memory platforms = new bytes32[](1);
        platforms[0] = PLATFORM_1_HASH;

        bytes32[] memory keys = new bytes32[](0);
        bytes32[] memory values = new bytes32[](0);

        address creator = address(0xBEEF);

        vm.startPrank(admin);
        vm.recordLogs();

        factory.createCampaign(
            creator,
            CAMPAIGN_1_IDENTIFIER_HASH,
            platforms,
            keys,
            values,
            CAMPAIGN_DATA
        );

        Vm.Log[] memory logs = vm.getRecordedLogs();
        vm.stopPrank();

        // Check logs emitted
        assertGt(logs.length, 0, "Expected at least one log");

        // Decode expected event
        bytes32 eventSig = keccak256(
            "CampaignInfoFactoryCampaignCreated(bytes32,address)"
        );
        bool found = false;
        address campaignAddr;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventSig) {
                // topics[2] is the address (indexed), cast from bytes32
                campaignAddr = address(uint160(uint256(logs[i].topics[2])));
                found = true;
                break;
            }
        }

        require(found, "CampaignCreated event not found");
        assertTrue(campaignAddr != address(0), "Invalid campaign address");

        // Check that campaign was stored in mapping
        address storedCampaign = factory.identifierToCampaignInfo(
            CAMPAIGN_1_IDENTIFIER_HASH
        );
        assertEq(storedCampaign, campaignAddr, "Stored campaign doesn't match");

        // Check that it's valid
        assertTrue(
            factory.isValidCampaignInfo(campaignAddr),
            "Campaign not marked valid"
        );
    }
}
