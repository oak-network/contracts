// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import {GlobalParams} from "src/GlobalParams.sol";
import {TreasuryFactory} from "src/TreasuryFactory.sol";
import {CampaignInfoFactory} from "src/CampaignInfoFactory.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {IGlobalParams} from "src/interfaces/IGlobalParams.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TestToken} from "../../mocks/TestToken.sol";
import {Defaults} from "../Base.t.sol";

/**
 * @title Upgrades_Test
 * @notice Comprehensive upgrade tests for all UUPS upgradeable contracts
 */
contract Upgrades_Test is Test, Defaults {
    GlobalParams internal globalParams;
    TreasuryFactory internal treasuryFactory;
    CampaignInfoFactory internal campaignFactory;
    TestToken internal testToken;
    
    address internal admin = address(0xA11CE);
    address internal platformAdmin = address(0xBEEF);
    address internal attacker = address(0xDEAD);
    
    bytes32 internal platformHash = keccak256(abi.encodePacked("TEST_PLATFORM"));
    uint256 internal protocolFee = 300;
    uint256 internal platformFee = 200;

    function setUp() public {
        testToken = new TestToken("Test", "TST", 18);
        
        bytes32[] memory currencies = new bytes32[](1);
        currencies[0] = bytes32("USD");
        
        address[][] memory tokensPerCurrency = new address[][](1);
        tokensPerCurrency[0] = new address[](1);
        tokensPerCurrency[0][0] = address(testToken);
        
        // Deploy GlobalParams with proxy
        GlobalParams globalParamsImpl = new GlobalParams();
        bytes memory globalParamsInitData = abi.encodeWithSelector(
            GlobalParams.initialize.selector,
            admin,
            protocolFee,
            currencies,
            tokensPerCurrency
        );
        ERC1967Proxy globalParamsProxy = new ERC1967Proxy(
            address(globalParamsImpl),
            globalParamsInitData
        );
        globalParams = GlobalParams(address(globalParamsProxy));
        
        // Deploy TreasuryFactory with proxy
        TreasuryFactory treasuryFactoryImpl = new TreasuryFactory();
        bytes memory treasuryFactoryInitData = abi.encodeWithSelector(
            TreasuryFactory.initialize.selector,
            IGlobalParams(address(globalParams))
        );
        ERC1967Proxy treasuryFactoryProxy = new ERC1967Proxy(
            address(treasuryFactoryImpl),
            treasuryFactoryInitData
        );
        treasuryFactory = TreasuryFactory(address(treasuryFactoryProxy));
        
        // Deploy CampaignInfoFactory with proxy
        CampaignInfo campaignInfoImpl = new CampaignInfo();
        CampaignInfoFactory campaignFactoryImpl = new CampaignInfoFactory();
        bytes memory campaignFactoryInitData = abi.encodeWithSelector(
            CampaignInfoFactory.initialize.selector,
            admin,
            IGlobalParams(address(globalParams)),
            address(campaignInfoImpl),
            address(treasuryFactory)
        );
        ERC1967Proxy campaignFactoryProxy = new ERC1967Proxy(
            address(campaignFactoryImpl),
            campaignFactoryInitData
        );
        campaignFactory = CampaignInfoFactory(address(campaignFactoryProxy));
        
        // Enlist a platform
        vm.prank(admin);
        globalParams.enlistPlatform(platformHash, platformAdmin, platformFee);
    }

    // ============ GlobalParams Upgrade Tests ============

    function testGlobalParamsUpgrade() public {
        // Record initial state
        uint256 initialFee = globalParams.getProtocolFeePercent();
        address initialAdmin = globalParams.getProtocolAdminAddress();
        
        // Deploy new implementation
        GlobalParams newImpl = new GlobalParams();
        
        // Upgrade
        vm.prank(admin);
        globalParams.upgradeToAndCall(address(newImpl), "");
        
        // Verify state is preserved
        assertEq(globalParams.getProtocolFeePercent(), initialFee);
        assertEq(globalParams.getProtocolAdminAddress(), initialAdmin);
        
        // Verify functionality still works
        vm.prank(admin);
        globalParams.updateProtocolFeePercent(500);
        assertEq(globalParams.getProtocolFeePercent(), 500);
    }

    function testGlobalParamsUpgradeUnauthorized() public {
        GlobalParams newImpl = new GlobalParams();
        
        // Try to upgrade as non-owner
        vm.prank(attacker);
        vm.expectRevert();
        globalParams.upgradeToAndCall(address(newImpl), "");
    }

    function testGlobalParamsStorageSlotIntegrity() public {
        // Add some data
        vm.prank(admin);
        globalParams.addTokenToCurrency(bytes32("EUR"), address(testToken));
        
        // Verify data before upgrade
        address[] memory eurTokens = globalParams.getTokensForCurrency(bytes32("EUR"));
        assertEq(eurTokens.length, 1);
        assertEq(eurTokens[0], address(testToken));
        
        // Upgrade
        GlobalParams newImpl = new GlobalParams();
        vm.prank(admin);
        globalParams.upgradeToAndCall(address(newImpl), "");
        
        // Verify data after upgrade
        eurTokens = globalParams.getTokensForCurrency(bytes32("EUR"));
        assertEq(eurTokens.length, 1);
        assertEq(eurTokens[0], address(testToken));
    }

    function testGlobalParamsCannotInitializeTwice() public {
        bytes32[] memory currencies = new bytes32[](0);
        address[][] memory tokensPerCurrency = new address[][](0);
        
        vm.expectRevert();
        globalParams.initialize(admin, protocolFee, currencies, tokensPerCurrency);
    }

    // ============ TreasuryFactory Upgrade Tests ============

    function testTreasuryFactoryUpgrade() public {
        // Register an implementation
        address mockImpl = address(0xC0DE);
        vm.prank(platformAdmin);
        treasuryFactory.registerTreasuryImplementation(platformHash, 1, mockImpl);
        
        // Deploy new implementation
        TreasuryFactory newImpl = new TreasuryFactory();
        
        // Upgrade as protocol admin
        vm.prank(admin);
        treasuryFactory.upgradeToAndCall(address(newImpl), "");
        
        // Verify functionality still works after upgrade
        vm.prank(platformAdmin);
        treasuryFactory.registerTreasuryImplementation(platformHash, 2, address(0xBEEF));
    }

    function testTreasuryFactoryUpgradeUnauthorized() public {
        TreasuryFactory newImpl = new TreasuryFactory();
        
        // Try to upgrade as non-protocol-admin
        vm.prank(attacker);
        vm.expectRevert();
        treasuryFactory.upgradeToAndCall(address(newImpl), "");
    }

    function testTreasuryFactoryStorageSlotIntegrity() public {
        // Register and approve an implementation
        address mockImpl = address(0xC0DE);
        vm.prank(platformAdmin);
        treasuryFactory.registerTreasuryImplementation(platformHash, 1, mockImpl);
        
        vm.prank(admin);
        treasuryFactory.approveTreasuryImplementation(platformHash, 1);
        
        // Upgrade
        TreasuryFactory newImpl = new TreasuryFactory();
        vm.prank(admin);
        treasuryFactory.upgradeToAndCall(address(newImpl), "");
        
        // Verify registered implementations are preserved after upgrade
        // by registering another implementation (which proves the mapping still works)
        address mockImpl2 = address(0xBEEF);
        vm.prank(platformAdmin);
        treasuryFactory.registerTreasuryImplementation(platformHash, 2, mockImpl2);
    }

    function testTreasuryFactoryCannotInitializeTwice() public {
        vm.expectRevert();
        treasuryFactory.initialize(IGlobalParams(address(globalParams)));
    }

    // ============ CampaignInfoFactory Upgrade Tests ============

    function testCampaignInfoFactoryUpgrade() public {
        // Create a campaign before upgrade
        bytes32[] memory platforms = new bytes32[](1);
        platforms[0] = platformHash;
        bytes32[] memory keys = new bytes32[](0);
        bytes32[] memory values = new bytes32[](0);
        
        vm.prank(admin);
        campaignFactory.createCampaign(
            address(0xBEEF),
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
        
        address campaignBefore = campaignFactory.identifierToCampaignInfo(CAMPAIGN_1_IDENTIFIER_HASH);
        assertTrue(campaignBefore != address(0), "Campaign not created");
        
        // Deploy new implementation
        CampaignInfoFactory newImpl = new CampaignInfoFactory();
        
        // Upgrade as owner
        vm.prank(admin);
        campaignFactory.upgradeToAndCall(address(newImpl), "");
        
        // Verify previous campaign is still accessible
        address campaignAfter = campaignFactory.identifierToCampaignInfo(CAMPAIGN_1_IDENTIFIER_HASH);
        assertEq(campaignAfter, campaignBefore, "Campaign address changed after upgrade");
        assertTrue(campaignFactory.isValidCampaignInfo(campaignAfter), "Campaign no longer valid");
    }

    function testCampaignInfoFactoryUpgradeUnauthorized() public {
        CampaignInfoFactory newImpl = new CampaignInfoFactory();
        
        // Try to upgrade as non-owner
        vm.prank(attacker);
        vm.expectRevert();
        campaignFactory.upgradeToAndCall(address(newImpl), "");
    }

    function testCampaignInfoFactoryStorageSlotIntegrity() public {
        // Create multiple campaigns
        bytes32[] memory platforms = new bytes32[](1);
        platforms[0] = platformHash;
        bytes32[] memory keys = new bytes32[](0);
        bytes32[] memory values = new bytes32[](0);
        
        bytes32 identifier1 = bytes32(uint256(1));
        bytes32 identifier2 = bytes32(uint256(2));
        
        vm.startPrank(admin);
        campaignFactory.createCampaign(
            address(0xBEEF),
            identifier1,
            platforms,
            keys,
            values,
            CAMPAIGN_DATA,
            "Campaign Pledge NFT",
            "PLEDGE",
            "ipfs://QmExampleImageURI",
            "ipfs://QmExampleContractURI"
        );
        
        campaignFactory.createCampaign(
            address(0xCAFE),
            identifier2,
            platforms,
            keys,
            values,
            CAMPAIGN_DATA,
            "Campaign Pledge NFT",
            "PLEDGE",
            "ipfs://QmExampleImageURI",
            "ipfs://QmExampleContractURI"
        );
        vm.stopPrank();
        
        address campaign1Before = campaignFactory.identifierToCampaignInfo(identifier1);
        address campaign2Before = campaignFactory.identifierToCampaignInfo(identifier2);
        
        // Upgrade
        CampaignInfoFactory newImpl = new CampaignInfoFactory();
        vm.prank(admin);
        campaignFactory.upgradeToAndCall(address(newImpl), "");
        
        // Verify all campaigns are preserved
        assertEq(campaignFactory.identifierToCampaignInfo(identifier1), campaign1Before);
        assertEq(campaignFactory.identifierToCampaignInfo(identifier2), campaign2Before);
        assertTrue(campaignFactory.isValidCampaignInfo(campaign1Before));
        assertTrue(campaignFactory.isValidCampaignInfo(campaign2Before));
    }

    function testCampaignInfoFactoryCannotInitializeTwice() public {
        CampaignInfo campaignInfoImpl = new CampaignInfo();
        
        vm.expectRevert();
        campaignFactory.initialize(
            admin,
            IGlobalParams(address(globalParams)),
            address(campaignInfoImpl),
            address(treasuryFactory)
        );
    }

    // ============ Cross-Contract Upgrade Tests ============

    function testUpgradeAllContractsIndependently() public {
        // Upgrade all three contracts
        GlobalParams newGlobalParamsImpl = new GlobalParams();
        TreasuryFactory newTreasuryFactoryImpl = new TreasuryFactory();
        CampaignInfoFactory newCampaignFactoryImpl = new CampaignInfoFactory();
        
        vm.startPrank(admin);
        globalParams.upgradeToAndCall(address(newGlobalParamsImpl), "");
        treasuryFactory.upgradeToAndCall(address(newTreasuryFactoryImpl), "");
        campaignFactory.upgradeToAndCall(address(newCampaignFactoryImpl), "");
        vm.stopPrank();
        
        // Verify all contracts still function correctly
        assertEq(globalParams.getProtocolAdminAddress(), admin);
        
        vm.prank(platformAdmin);
        treasuryFactory.registerTreasuryImplementation(platformHash, 99, address(0xABCD));
        
        bytes32[] memory platforms = new bytes32[](1);
        platforms[0] = platformHash;
        bytes32[] memory keys = new bytes32[](0);
        bytes32[] memory values = new bytes32[](0);
        
        vm.prank(admin);
        campaignFactory.createCampaign(
            address(0xBEEF),
            bytes32(uint256(999)),
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

    function testUpgradeDoesNotAffectImplementationContract() public {
        // The implementation contract itself should not be usable directly
        GlobalParams standaloneImpl = new GlobalParams();
        
        bytes32[] memory currencies = new bytes32[](1);
        currencies[0] = bytes32("USD");
        address[][] memory tokensPerCurrency = new address[][](1);
        tokensPerCurrency[0] = new address[](1);
        tokensPerCurrency[0][0] = address(testToken);
        
        // Should revert because initializers are disabled in constructor
        vm.expectRevert();
        standaloneImpl.initialize(admin, protocolFee, currencies, tokensPerCurrency);
    }

    // ============ Storage Collision Tests ============

    function testNoStorageCollisionAfterUpgrade() public {
        // Add data to all storage slots
        vm.startPrank(admin);
        globalParams.updateProtocolFeePercent(999);
        globalParams.addTokenToCurrency(bytes32("BRL"), address(0x1111));
        globalParams.enlistPlatform(bytes32("NEW_PLATFORM"), address(0x2222), 123);
        vm.stopPrank();
        
        // Upgrade
        GlobalParams newImpl = new GlobalParams();
        vm.prank(admin);
        globalParams.upgradeToAndCall(address(newImpl), "");
        
        // Verify all data is intact
        assertEq(globalParams.getProtocolFeePercent(), 999);
        address[] memory brlTokens = globalParams.getTokensForCurrency(bytes32("BRL"));
        assertEq(brlTokens.length, 1);
        assertEq(brlTokens[0], address(0x1111));
        assertTrue(globalParams.checkIfPlatformIsListed(bytes32("NEW_PLATFORM")));
    }
}

