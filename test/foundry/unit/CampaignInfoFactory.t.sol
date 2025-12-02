// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import {CampaignInfoFactory} from "src/CampaignInfoFactory.sol";
import {GlobalParams} from "src/GlobalParams.sol";
import {TreasuryFactory} from "src/TreasuryFactory.sol";
import {IGlobalParams} from "src/interfaces/IGlobalParams.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TestToken} from "../../mocks/TestToken.sol";
import {Defaults} from "../Base.t.sol";
import {ICampaignData} from "src/interfaces/ICampaignData.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {DataRegistryKeys} from "src/constants/DataRegistryKeys.sol";

contract CampaignInfoFactory_UnitTest is Test, Defaults {
    CampaignInfoFactory internal factory;
    TreasuryFactory internal treasuryFactory;
    GlobalParams internal globalParams;
    TestToken internal testToken;
    CampaignInfo internal campaignInfoImplementation;

    address internal admin = address(0xA11CE);

    function setUp() public {
        testToken = new TestToken(tokenName, tokenSymbol, 18);

        // Setup currencies and tokens for multi-token support
        bytes32[] memory currencies = new bytes32[](1);
        currencies[0] = bytes32("USD");

        address[][] memory tokensPerCurrency = new address[][](1);
        tokensPerCurrency[0] = new address[](1);
        tokensPerCurrency[0][0] = address(testToken);

        // Deploy GlobalParams with proxy
        GlobalParams globalParamsImpl = new GlobalParams();
        bytes memory globalParamsInitData = abi.encodeWithSelector(
            GlobalParams.initialize.selector, admin, PROTOCOL_FEE_PERCENT, currencies, tokensPerCurrency
        );
        ERC1967Proxy globalParamsProxy = new ERC1967Proxy(address(globalParamsImpl), globalParamsInitData);
        globalParams = GlobalParams(address(globalParamsProxy));

        // Deploy CampaignInfo implementation
        campaignInfoImplementation = new CampaignInfo();

        // Deploy TreasuryFactory with proxy
        TreasuryFactory treasuryFactoryImpl = new TreasuryFactory();
        bytes memory treasuryFactoryInitData =
            abi.encodeWithSelector(TreasuryFactory.initialize.selector, IGlobalParams(address(globalParams)));
        ERC1967Proxy treasuryFactoryProxy = new ERC1967Proxy(address(treasuryFactoryImpl), treasuryFactoryInitData);
        treasuryFactory = TreasuryFactory(address(treasuryFactoryProxy));

        // Deploy CampaignInfoFactory with proxy
        CampaignInfoFactory factoryImpl = new CampaignInfoFactory();
        bytes memory factoryInitData = abi.encodeWithSelector(
            CampaignInfoFactory.initialize.selector,
            address(this),
            IGlobalParams(address(globalParams)),
            address(campaignInfoImplementation),
            address(treasuryFactory)
        );
        ERC1967Proxy factoryProxy = new ERC1967Proxy(address(factoryImpl), factoryInitData);
        factory = CampaignInfoFactory(address(factoryProxy));

        vm.startPrank(admin);
        globalParams.enlistPlatform(
            PLATFORM_1_HASH,
            admin,
            PLATFORM_FEE_PERCENT,
            address(0) // Platform adapter - can be set later with setPlatformAdapter
        );

        // Set time constraints in dataRegistry
        globalParams.addToRegistry(DataRegistryKeys.CAMPAIGN_LAUNCH_BUFFER, bytes32(uint256(1 hours)));
        globalParams.addToRegistry(DataRegistryKeys.MINIMUM_CAMPAIGN_DURATION, bytes32(uint256(1 days)));
        vm.stopPrank();
    }

    function testCreateCampaignDeploysSuccessfully() public {
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
            CAMPAIGN_DATA,
            "Campaign Pledge NFT",
            "PLEDGE",
            "ipfs://QmExampleImageURI",
            "ipfs://QmExampleContractURI"
        );

        Vm.Log[] memory logs = vm.getRecordedLogs();
        vm.stopPrank();

        // Check logs emitted
        assertGt(logs.length, 0, "Expected at least one log");

        // Decode expected event
        bytes32 eventSig = keccak256("CampaignInfoFactoryCampaignCreated(bytes32,address)");
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
        address storedCampaign = factory.identifierToCampaignInfo(CAMPAIGN_1_IDENTIFIER_HASH);
        assertEq(storedCampaign, campaignAddr, "Stored campaign doesn't match");

        // Check that it's valid
        assertTrue(factory.isValidCampaignInfo(campaignAddr), "Campaign not marked valid");
    }

    function testUpgrade() public {
        // Deploy new implementation
        CampaignInfoFactory newImplementation = new CampaignInfoFactory();

        // Upgrade as owner (address(this))
        factory.upgradeToAndCall(address(newImplementation), "");

        // Factory should still work after upgrade
        bytes32[] memory platforms = new bytes32[](1);
        platforms[0] = PLATFORM_1_HASH;

        bytes32[] memory keys = new bytes32[](0);
        bytes32[] memory values = new bytes32[](0);

        address creator = address(0xBEEF);

        vm.prank(admin);
        factory.createCampaign(
            creator,
            CAMPAIGN_1_IDENTIFIER_HASH,
            platforms,
            keys,
            values,
            CAMPAIGN_DATA,
            "Campaign Pledge NFT",
            "PLEDGE",
            "ipfs://QmExampleImageURI",
            "ipfs://QmExampleContractURI"
        );
    }

    function testUpgradeUnauthorizedReverts() public {
        // Deploy new implementation
        CampaignInfoFactory newImplementation = new CampaignInfoFactory();

        // Try to upgrade as non-owner (should revert)
        vm.prank(admin);
        vm.expectRevert();
        factory.upgradeToAndCall(address(newImplementation), "");
    }

    function testCannotInitializeTwice() public {
        // Try to initialize again (should revert)
        vm.expectRevert();
        factory.initialize(
            address(this),
            IGlobalParams(address(globalParams)),
            address(campaignInfoImplementation),
            address(treasuryFactory)
        );
    }

    function testCreateCampaignRevertsWithInsufficientLaunchBuffer() public {
        bytes32[] memory platforms = new bytes32[](1);
        platforms[0] = PLATFORM_1_HASH;

        bytes32[] memory keys = new bytes32[](0);
        bytes32[] memory values = new bytes32[](0);

        address creator = address(0xBEEF);

        // Create campaign data with launch time less than required buffer (1 hour)
        ICampaignData.CampaignData memory campaignData = ICampaignData.CampaignData({
            launchTime: block.timestamp + 30 minutes, // Only 30 minutes buffer
            deadline: block.timestamp + 30 minutes + 7 days,
            goalAmount: GOAL_AMOUNT,
            currency: bytes32("USD")
        });

        vm.prank(admin);
        vm.expectRevert(CampaignInfoFactory.CampaignInfoFactoryInvalidInput.selector);
        factory.createCampaign(
            creator,
            CAMPAIGN_1_IDENTIFIER_HASH,
            platforms,
            keys,
            values,
            campaignData,
            "Campaign Pledge NFT",
            "PLEDGE",
            "ipfs://QmExampleImageURI",
            "ipfs://QmExampleContractURI"
        );
    }

    function testCreateCampaignRevertsWithInsufficientDuration() public {
        bytes32[] memory platforms = new bytes32[](1);
        platforms[0] = PLATFORM_1_HASH;

        bytes32[] memory keys = new bytes32[](0);
        bytes32[] memory values = new bytes32[](0);

        address creator = address(0xBEEF);

        // Create campaign data with duration less than minimum (1 day)
        ICampaignData.CampaignData memory campaignData = ICampaignData.CampaignData({
            launchTime: block.timestamp + 2 hours, // Good buffer
            deadline: block.timestamp + 2 hours + 12 hours, // Only 12 hours duration
            goalAmount: GOAL_AMOUNT,
            currency: bytes32("USD")
        });

        vm.prank(admin);
        vm.expectRevert(CampaignInfoFactory.CampaignInfoFactoryInvalidInput.selector);
        factory.createCampaign(
            creator,
            CAMPAIGN_1_IDENTIFIER_HASH,
            platforms,
            keys,
            values,
            campaignData,
            "Campaign Pledge NFT",
            "PLEDGE",
            "ipfs://QmExampleImageURI",
            "ipfs://QmExampleContractURI"
        );
    }
}
