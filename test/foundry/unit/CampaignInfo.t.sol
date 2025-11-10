// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {CampaignInfoFactory} from "src/CampaignInfoFactory.sol";
import {GlobalParams} from "src/GlobalParams.sol";
import {TreasuryFactory} from "src/TreasuryFactory.sol";
import {AllOrNothing} from "src/treasuries/AllOrNothing.sol";
import {IGlobalParams} from "src/interfaces/IGlobalParams.sol";
import {ICampaignData} from "src/interfaces/ICampaignData.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TestToken} from "../../mocks/TestToken.sol";
import {Defaults} from "../Base.t.sol";

contract CampaignInfo_UnitTest is Test, Defaults {
    CampaignInfo internal campaignInfo;
    CampaignInfoFactory internal campaignInfoFactory;
    GlobalParams internal globalParams;
    TreasuryFactory internal treasuryFactory;
    AllOrNothing internal allOrNothingImpl;
    TestToken internal testToken;

    address internal admin = address(0xA11CE);
    address internal campaignOwner = address(0xB22DE);
    address internal newOwner = address(0xC33FF);
    bytes32 internal platformHash1 = keccak256("platform1");
    bytes32 internal platformHash2 = keccak256("platform2");
    bytes32 internal platformDataKey1 = keccak256("key1");
    bytes32 internal platformDataKey2 = keccak256("key2");
    bytes32 internal platformDataValue1 = keccak256("value1");
    bytes32 internal platformDataValue2 = keccak256("value2");

    function setUp() public {
        testToken = new TestToken(tokenName, tokenSymbol, 18);
        
        // Setup currencies and tokens
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
            PROTOCOL_FEE_PERCENT,
            currencies,
            tokensPerCurrency
        );
        ERC1967Proxy globalParamsProxy = new ERC1967Proxy(
            address(globalParamsImpl),
            globalParamsInitData
        );
        globalParams = GlobalParams(address(globalParamsProxy));

        // Setup platforms in GlobalParams
        vm.startPrank(admin);
        globalParams.enlistPlatform(platformHash1, admin, 1000); // 10% fee
        globalParams.enlistPlatform(platformHash2, admin, 2000); // 20% fee
        
        // Add platform data keys
        globalParams.addPlatformData(platformHash1, platformDataKey1);
        globalParams.addPlatformData(platformHash2, platformDataKey2);
        vm.stopPrank();

        // Deploy TreasuryFactory
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

        // Deploy AllOrNothing implementation for testing
        allOrNothingImpl = new AllOrNothing();

        // Register and approve treasury implementation (after platform is enlisted)
        vm.startPrank(admin);
        treasuryFactory.registerTreasuryImplementation(platformHash1, 1, address(allOrNothingImpl));
        treasuryFactory.approveTreasuryImplementation(platformHash1, 1);
        vm.stopPrank();

        // Deploy CampaignInfoFactory
        CampaignInfoFactory campaignInfoFactoryImpl = new CampaignInfoFactory();
        bytes memory campaignInfoFactoryInitData = abi.encodeWithSelector(
            CampaignInfoFactory.initialize.selector,
            admin,
            IGlobalParams(address(globalParams)),
            address(new CampaignInfo()),
            address(treasuryFactory)
        );
        ERC1967Proxy campaignInfoFactoryProxy = new ERC1967Proxy(
            address(campaignInfoFactoryImpl),
            campaignInfoFactoryInitData
        );
        campaignInfoFactory = CampaignInfoFactory(address(campaignInfoFactoryProxy));

        // Create a campaign using the factory
        ICampaignData.CampaignData memory campaignData = ICampaignData.CampaignData({
            launchTime: block.timestamp + 1 days,
            deadline: block.timestamp + 30 days,
            goalAmount: 1000 * 10**18,
            currency: bytes32("USD")
        });
        
        bytes32[] memory selectedPlatformHashes = new bytes32[](0); // No platforms selected initially
        bytes32[] memory platformDataKeys = new bytes32[](0);
        bytes32[] memory platformDataValues = new bytes32[](0);
        bytes32 identifierHash = keccak256("test-campaign");
        
        vm.startPrank(admin);
        campaignInfoFactory.createCampaign(
            campaignOwner,
            identifierHash,
            selectedPlatformHashes,
            platformDataKeys,
            platformDataValues,
            campaignData
        );
        vm.stopPrank();
        
        campaignInfo = CampaignInfo(campaignInfoFactory.identifierToCampaignInfo(identifierHash));
    }

    // ============ View Functions Tests ============

    function test_Owner() public {
        assertEq(campaignInfo.owner(), campaignOwner);
    }

    function test_IsLocked_InitiallyFalse() public {
        assertFalse(campaignInfo.isLocked());
    }

    function test_GetLaunchTime() public {
        uint256 launchTime = campaignInfo.getLaunchTime();
        assertTrue(launchTime > 0);
    }

    function test_GetDeadline() public {
        uint256 deadline = campaignInfo.getDeadline();
        assertTrue(deadline > campaignInfo.getLaunchTime());
    }

    function test_GetGoalAmount() public {
        uint256 goalAmount = campaignInfo.getGoalAmount();
        assertEq(goalAmount, 1000 * 10**18);
    }


    function test_GetCampaignCurrency() public {
        bytes32 currency = campaignInfo.getCampaignCurrency();
        assertEq(currency, bytes32("USD"));
    }

    function test_GetAcceptedTokens() public {
        address[] memory tokens = campaignInfo.getAcceptedTokens();
        assertEq(tokens.length, 1);
        assertEq(tokens[0], address(testToken));
    }

    function test_IsTokenAccepted() public {
        assertTrue(campaignInfo.isTokenAccepted(address(testToken)));
        assertFalse(campaignInfo.isTokenAccepted(address(0x1234)));
    }

    function test_GetPlatformFeePercent() public {
        // Initially no platforms selected, should return 0
        assertEq(campaignInfo.getPlatformFeePercent(platformHash1), 0);
    }

    function test_GetPlatformData_NotSet() public {
        vm.expectRevert(CampaignInfo.CampaignInfoInvalidInput.selector);
        campaignInfo.getPlatformData(platformDataKey1);
    }

    function test_CheckIfPlatformSelected_InitiallyFalse() public {
        assertFalse(campaignInfo.checkIfPlatformSelected(platformHash1));
    }

    function test_CheckIfPlatformApproved_InitiallyFalse() public {
        assertFalse(campaignInfo.checkIfPlatformApproved(platformHash1));
    }

    function test_GetApprovedPlatformHashes_InitiallyEmpty() public {
        bytes32[] memory approvedPlatforms = campaignInfo.getApprovedPlatformHashes();
        assertEq(approvedPlatforms.length, 0);
    }

    function test_Paused_InitiallyFalse() public {
        assertFalse(campaignInfo.paused());
    }

    function test_Cancelled_InitiallyFalse() public {
        assertFalse(campaignInfo.cancelled());
    }

    // ============ UpdateSelectedPlatform Tests ============

    function test_UpdateSelectedPlatform_SelectPlatform_Success() public {
        vm.startPrank(campaignOwner);
        
        bytes32[] memory dataKeys = new bytes32[](2);
        dataKeys[0] = platformDataKey1;
        dataKeys[1] = platformDataKey2;
        
        bytes32[] memory dataValues = new bytes32[](2);
        dataValues[0] = platformDataValue1;
        dataValues[1] = platformDataValue2;

        campaignInfo.updateSelectedPlatform(
            platformHash1,
            true,
            dataKeys,
            dataValues
        );

        // Verify platform is selected
        assertTrue(campaignInfo.checkIfPlatformSelected(platformHash1));
        
        // Verify platform data is stored
        assertEq(campaignInfo.getPlatformData(platformDataKey1), platformDataValue1);
        assertEq(campaignInfo.getPlatformData(platformDataKey2), platformDataValue2);
        
        // Verify platform fee is set
        assertEq(campaignInfo.getPlatformFeePercent(platformHash1), 1000);
        
        vm.stopPrank();
    }


    function test_UpdateSelectedPlatform_InvalidPlatform_Reverts() public {
        vm.startPrank(campaignOwner);
        
        bytes32 invalidPlatformHash = keccak256("invalid");
        bytes32[] memory dataKeys = new bytes32[](1);
        dataKeys[0] = platformDataKey1;
        
        bytes32[] memory dataValues = new bytes32[](1);
        dataValues[0] = platformDataValue1;

        vm.expectRevert(
            abi.encodeWithSelector(
                CampaignInfo.CampaignInfoInvalidPlatformUpdate.selector,
                invalidPlatformHash,
                true
            )
        );
        campaignInfo.updateSelectedPlatform(
            invalidPlatformHash,
            true,
            dataKeys,
            dataValues
        );
        vm.stopPrank();
    }

    function test_UpdateSelectedPlatform_AlreadySelected_Reverts() public {
        vm.startPrank(campaignOwner);
        
        bytes32[] memory dataKeys = new bytes32[](1);
        dataKeys[0] = platformDataKey1;
        
        bytes32[] memory dataValues = new bytes32[](1);
        dataValues[0] = platformDataValue1;

        // Select platform first time
        campaignInfo.updateSelectedPlatform(
            platformHash1,
            true,
            dataKeys,
            dataValues
        );

        // Try to select again - should revert
        vm.expectRevert(CampaignInfo.CampaignInfoInvalidInput.selector);
        campaignInfo.updateSelectedPlatform(
            platformHash1,
            true,
            dataKeys,
            dataValues
        );
        vm.stopPrank();
    }

    function test_UpdateSelectedPlatform_DataKeyValueLengthMismatch_Reverts() public {
        vm.startPrank(campaignOwner);
        
        bytes32[] memory dataKeys = new bytes32[](2);
        dataKeys[0] = platformDataKey1;
        dataKeys[1] = platformDataKey2;
        
        bytes32[] memory dataValues = new bytes32[](1);
        dataValues[0] = platformDataValue1;

        vm.expectRevert(CampaignInfo.CampaignInfoInvalidInput.selector);
        campaignInfo.updateSelectedPlatform(
            platformHash1,
            true,
            dataKeys,
            dataValues
        );
        vm.stopPrank();
    }

    function test_UpdateSelectedPlatform_InvalidDataKey_Reverts() public {
        vm.startPrank(campaignOwner);
        
        bytes32[] memory dataKeys = new bytes32[](1);
        dataKeys[0] = keccak256("invalid_key");
        
        bytes32[] memory dataValues = new bytes32[](1);
        dataValues[0] = platformDataValue1;

        vm.expectRevert(CampaignInfo.CampaignInfoInvalidInput.selector);
        campaignInfo.updateSelectedPlatform(
            platformHash1,
            true,
            dataKeys,
            dataValues
        );
        vm.stopPrank();
    }

    function test_UpdateSelectedPlatform_ZeroDataValue_Reverts() public {
        vm.startPrank(campaignOwner);
        
        bytes32[] memory dataKeys = new bytes32[](1);
        dataKeys[0] = platformDataKey1;
        
        bytes32[] memory dataValues = new bytes32[](1);
        dataValues[0] = bytes32(0);

        vm.expectRevert(CampaignInfo.CampaignInfoInvalidInput.selector);
        campaignInfo.updateSelectedPlatform(
            platformHash1,
            true,
            dataKeys,
            dataValues
        );
        vm.stopPrank();
    }

    function test_UpdateSelectedPlatform_Unauthorized_Reverts() public {
        address unauthorizedUser = address(0xC33FF);
        
        bytes32[] memory dataKeys = new bytes32[](1);
        dataKeys[0] = platformDataKey1;
        
        bytes32[] memory dataValues = new bytes32[](1);
        dataValues[0] = platformDataValue1;

        vm.startPrank(unauthorizedUser);
        vm.expectRevert();
        campaignInfo.updateSelectedPlatform(
            platformHash1,
            true,
            dataKeys,
            dataValues
        );
        vm.stopPrank();
    }

    // ============ Update Functions Tests ============

    function test_UpdateLaunchTime_Success() public {
        vm.startPrank(campaignOwner);
        
        uint256 newLaunchTime = block.timestamp + 1 days;
        
        vm.expectEmit(true, false, false, true);
        emit CampaignInfo.CampaignInfoLaunchTimeUpdated(newLaunchTime);
        
        campaignInfo.updateLaunchTime(newLaunchTime);
        
        assertEq(campaignInfo.getLaunchTime(), newLaunchTime);
        vm.stopPrank();
    }

    function test_UpdateLaunchTime_InvalidTime_Reverts() public {
        vm.startPrank(campaignOwner);
        
        // Launch time in the past
        vm.expectRevert(CampaignInfo.CampaignInfoInvalidInput.selector);
        campaignInfo.updateLaunchTime(block.timestamp - 1);
        
        vm.stopPrank();
    }

    function test_UpdateDeadline_Success() public {
        vm.startPrank(campaignOwner);
        
        uint256 newDeadline = campaignInfo.getLaunchTime() + 60 days;
        
        vm.expectEmit(true, false, false, true);
        emit CampaignInfo.CampaignInfoDeadlineUpdated(newDeadline);
        
        campaignInfo.updateDeadline(newDeadline);
        
        assertEq(campaignInfo.getDeadline(), newDeadline);
        vm.stopPrank();
    }

    function test_UpdateGoalAmount_Success() public {
        vm.startPrank(campaignOwner);
        
        uint256 newGoalAmount = 2000 * 10**18;
        
        vm.expectEmit(true, false, false, true);
        emit CampaignInfo.CampaignInfoGoalAmountUpdated(newGoalAmount);
        
        campaignInfo.updateGoalAmount(newGoalAmount);
        
        assertEq(campaignInfo.getGoalAmount(), newGoalAmount);
        vm.stopPrank();
    }

    function test_UpdateGoalAmount_ZeroAmount_Reverts() public {
        vm.startPrank(campaignOwner);
        
        vm.expectRevert(CampaignInfo.CampaignInfoInvalidInput.selector);
        campaignInfo.updateGoalAmount(0);
        
        vm.stopPrank();
    }


    // ============ Transfer Ownership Tests ============

    function test_TransferOwnership_Success() public {
        vm.startPrank(campaignOwner);
        
        campaignInfo.transferOwnership(newOwner);
        
        assertEq(campaignInfo.owner(), newOwner);
        vm.stopPrank();
    }

    function test_TransferOwnership_WhenPaused_Reverts() public {
        // Pause the campaign
        vm.startPrank(admin);
        campaignInfo._pauseCampaign(keccak256("test"));
        vm.stopPrank();

        vm.startPrank(campaignOwner);
        vm.expectRevert();
        campaignInfo.transferOwnership(newOwner);
        vm.stopPrank();
    }

    function test_TransferOwnership_WhenCancelled_Reverts() public {
        // Cancel the campaign
        vm.startPrank(admin);
        campaignInfo._cancelCampaign(keccak256("test"));
        vm.stopPrank();

        vm.startPrank(campaignOwner);
        vm.expectRevert();
        campaignInfo.transferOwnership(newOwner);
        vm.stopPrank();
    }

    // ============ Admin Functions Tests ============

    function test_PauseCampaign_Success() public {
        vm.startPrank(admin);
        
        bytes32 message = keccak256("test pause");
        campaignInfo._pauseCampaign(message);
        
        assertTrue(campaignInfo.paused());
        vm.stopPrank();
    }

    function test_UnpauseCampaign_Success() public {
        // First pause
        vm.startPrank(admin);
        campaignInfo._pauseCampaign(keccak256("test pause"));
        vm.stopPrank();

        // Then unpause
        vm.startPrank(admin);
        bytes32 message = keccak256("test unpause");
        campaignInfo._unpauseCampaign(message);
        
        assertFalse(campaignInfo.paused());
        vm.stopPrank();
    }

    function test_CancelCampaign_ByAdmin_Success() public {
        vm.startPrank(admin);
        
        bytes32 message = keccak256("test cancel");
        campaignInfo._cancelCampaign(message);
        
        assertTrue(campaignInfo.cancelled());
        vm.stopPrank();
    }

    function test_CancelCampaign_ByOwner_Success() public {
        vm.startPrank(campaignOwner);
        
        bytes32 message = keccak256("test cancel");
        campaignInfo._cancelCampaign(message);
        
        assertTrue(campaignInfo.cancelled());
        vm.stopPrank();
    }

    function test_CancelCampaign_Unauthorized_Reverts() public {
        address unauthorizedUser = address(0xD44F);
        
        vm.startPrank(unauthorizedUser);
        vm.expectRevert(CampaignInfo.CampaignInfoUnauthorized.selector);
        campaignInfo._cancelCampaign(keccak256("test cancel"));
        vm.stopPrank();
    }

    // ============ Locked Functionality Tests ============


    function test_UpdateSelectedPlatform_SelectPlatform_WhenNotLocked_Success() public {
        // Test that platform selection works when not locked
        vm.startPrank(campaignOwner);
        
        bytes32[] memory dataKeys = new bytes32[](1);
        dataKeys[0] = platformDataKey1;
        bytes32[] memory dataValues = new bytes32[](1);
        dataValues[0] = platformDataValue1;

        campaignInfo.updateSelectedPlatform(
            platformHash1,
            true,
            dataKeys,
            dataValues
        );

        // Verify platform is selected
        assertTrue(campaignInfo.checkIfPlatformSelected(platformHash1));
        vm.stopPrank();
    }

    function test_UpdateSelectedPlatform_DeselectPlatform_WhenNotLocked_Success() public {
        // First select a platform
        vm.startPrank(campaignOwner);
        
        bytes32[] memory dataKeys = new bytes32[](1);
        dataKeys[0] = platformDataKey1;
        bytes32[] memory dataValues = new bytes32[](1);
        dataValues[0] = platformDataValue1;

        campaignInfo.updateSelectedPlatform(
            platformHash1,
            true,
            dataKeys,
            dataValues
        );

        // Now deselect it
        campaignInfo.updateSelectedPlatform(
            platformHash1,
            false,
            new bytes32[](0),
            new bytes32[](0)
        );

        // Verify platform is not selected
        assertFalse(campaignInfo.checkIfPlatformSelected(platformHash1));
        
        // Verify platform fee is reset to 0
        assertEq(campaignInfo.getPlatformFeePercent(platformHash1), 0);
        
        vm.stopPrank();
    }

    function test_UpdateLaunchTime_WhenNotLocked_Success() public {
        // Test that launch time update works when not locked
        vm.startPrank(campaignOwner);
        
        uint256 newLaunchTime = block.timestamp + 1 days;
        
        campaignInfo.updateLaunchTime(newLaunchTime);
        
        assertEq(campaignInfo.getLaunchTime(), newLaunchTime);
        vm.stopPrank();
    }

    function test_UpdateDeadline_WhenNotLocked_Success() public {
        // Test that deadline update works when not locked
        vm.startPrank(campaignOwner);
        
        uint256 newDeadline = campaignInfo.getLaunchTime() + 60 days;
        
        campaignInfo.updateDeadline(newDeadline);
        
        assertEq(campaignInfo.getDeadline(), newDeadline);
        vm.stopPrank();
    }

    function test_UpdateGoalAmount_WhenNotLocked_Success() public {
        // Test that goal amount update works when not locked
        vm.startPrank(campaignOwner);
        
        uint256 newGoalAmount = 2000 * 10**18;
        
        campaignInfo.updateGoalAmount(newGoalAmount);
        
        assertEq(campaignInfo.getGoalAmount(), newGoalAmount);
        vm.stopPrank();
    }

    // ============ Locked Campaign Tests ============

    function test_LockMechanism_AfterTreasuryDeployment() public {
        // First select a platform
        vm.startPrank(campaignOwner);
        bytes32[] memory dataKeys = new bytes32[](1);
        dataKeys[0] = platformDataKey1;
        bytes32[] memory dataValues = new bytes32[](1);
        dataValues[0] = platformDataValue1;

        campaignInfo.updateSelectedPlatform(
            platformHash1,
            true,
            dataKeys,
            dataValues
        );
        vm.stopPrank();

        // Verify campaign is not locked initially
        assertFalse(campaignInfo.isLocked());

        // Deploy a treasury using the treasury factory - this will call _setPlatformInfo
        vm.startPrank(admin);
        address treasury = treasuryFactory.deploy(
            platformHash1,
            address(campaignInfo),
            1, // implementationId
            "Test Treasury",
            "TT"
        );
        vm.stopPrank();

        // Verify campaign is now locked
        assertTrue(campaignInfo.isLocked());
        assertTrue(campaignInfo.checkIfPlatformApproved(platformHash1));
    }

    function test_UpdateLaunchTime_WhenLocked_Reverts() public {
        // Lock the campaign first
        _lockCampaign();

        vm.startPrank(campaignOwner);
        uint256 newLaunchTime = block.timestamp + 1 days;
        
        vm.expectRevert(CampaignInfo.CampaignInfoIsLocked.selector);
        campaignInfo.updateLaunchTime(newLaunchTime);
        vm.stopPrank();
    }

    function test_UpdateDeadline_WhenLocked_Reverts() public {
        // Lock the campaign first
        _lockCampaign();

        vm.startPrank(campaignOwner);
        uint256 newDeadline = campaignInfo.getLaunchTime() + 60 days;
        
        vm.expectRevert(CampaignInfo.CampaignInfoIsLocked.selector);
        campaignInfo.updateDeadline(newDeadline);
        vm.stopPrank();
    }

    function test_UpdateGoalAmount_WhenLocked_Reverts() public {
        // Lock the campaign first
        _lockCampaign();

        vm.startPrank(campaignOwner);
        uint256 newGoalAmount = 2000 * 10**18;
        
        vm.expectRevert(CampaignInfo.CampaignInfoIsLocked.selector);
        campaignInfo.updateGoalAmount(newGoalAmount);
        vm.stopPrank();
    }

    function test_UpdateSelectedPlatform_DeselectPlatform_WhenLocked_Reverts() public {
        // First select a platform and lock the campaign
        vm.startPrank(campaignOwner);
        bytes32[] memory dataKeys = new bytes32[](1);
        dataKeys[0] = platformDataKey1;
        bytes32[] memory dataValues = new bytes32[](1);
        dataValues[0] = platformDataValue1;

        campaignInfo.updateSelectedPlatform(
            platformHash1,
            true,
            dataKeys,
            dataValues
        );
        vm.stopPrank();

        // Lock the campaign by deploying treasury
        vm.startPrank(admin);
        treasuryFactory.deploy(
            platformHash1,
            address(campaignInfo),
            1, // implementationId
            "Test Treasury",
            "TT"
        );
        vm.stopPrank();

        // Now try to deselect the platform - should revert with already approved error
        vm.startPrank(campaignOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                CampaignInfo.CampaignInfoPlatformAlreadyApproved.selector,
                platformHash1
            )
        );
        campaignInfo.updateSelectedPlatform(
            platformHash1,
            false,
            new bytes32[](0),
            new bytes32[](0)
        );
        vm.stopPrank();
    }

    function test_UpdateSelectedPlatform_SelectNewPlatform_WhenLocked_Success() public {
        // Lock the campaign first
        _lockCampaign();

        // Selecting a new platform should still work when locked
        vm.startPrank(campaignOwner);
        bytes32[] memory dataKeys = new bytes32[](1);
        dataKeys[0] = platformDataKey2;
        bytes32[] memory dataValues = new bytes32[](1);
        dataValues[0] = platformDataValue2;

        campaignInfo.updateSelectedPlatform(
            platformHash2,
            true,
            dataKeys,
            dataValues
        );

        // Verify platform is selected
        assertTrue(campaignInfo.checkIfPlatformSelected(platformHash2));
        assertEq(campaignInfo.getPlatformFeePercent(platformHash2), 2000); // 20% fee
        vm.stopPrank();
    }

    function test_TransferOwnership_WhenLocked_Success() public {
        // Lock the campaign first
        _lockCampaign();

        // Transfer ownership should still work when locked
        vm.startPrank(campaignOwner);
        campaignInfo.transferOwnership(newOwner);
        
        assertEq(campaignInfo.owner(), newOwner);
        vm.stopPrank();
    }

    function test_PauseCampaign_WhenLocked_Success() public {
        // Lock the campaign first
        _lockCampaign();

        // Pausing should still work when locked
        vm.startPrank(admin);
        bytes32 message = keccak256("test pause");
        campaignInfo._pauseCampaign(message);
        
        assertTrue(campaignInfo.paused());
        vm.stopPrank();
    }

    function test_UnpauseCampaign_WhenLocked_Success() public {
        // Lock the campaign first
        _lockCampaign();

        // First pause
        vm.startPrank(admin);
        campaignInfo._pauseCampaign(keccak256("test pause"));
        vm.stopPrank();

        // Then unpause - should still work when locked
        vm.startPrank(admin);
        bytes32 message = keccak256("test unpause");
        campaignInfo._unpauseCampaign(message);
        
        assertFalse(campaignInfo.paused());
        vm.stopPrank();
    }

    function test_CancelCampaign_ByAdmin_WhenLocked_Success() public {
        // Lock the campaign first
        _lockCampaign();

        // Cancelling should still work when locked
        vm.startPrank(admin);
        bytes32 message = keccak256("test cancel");
        campaignInfo._cancelCampaign(message);
        
        assertTrue(campaignInfo.cancelled());
        vm.stopPrank();
    }

    function test_CancelCampaign_ByOwner_WhenLocked_Success() public {
        // Lock the campaign first
        _lockCampaign();

        // Cancelling should still work when locked
        vm.startPrank(campaignOwner);
        bytes32 message = keccak256("test cancel");
        campaignInfo._cancelCampaign(message);
        
        assertTrue(campaignInfo.cancelled());
        vm.stopPrank();
    }

    function test_ViewFunctions_WhenLocked_StillWork() public {
        // Lock the campaign first
        _lockCampaign();

        // All view functions should still work when locked
        assertTrue(campaignInfo.isLocked());
        assertEq(campaignInfo.owner(), campaignOwner);
        assertTrue(campaignInfo.getLaunchTime() > 0);
        assertTrue(campaignInfo.getDeadline() > campaignInfo.getLaunchTime());
        assertEq(campaignInfo.getGoalAmount(), 1000 * 10**18);
        assertEq(campaignInfo.getCampaignCurrency(), bytes32("USD"));
        assertFalse(campaignInfo.paused());
        assertFalse(campaignInfo.cancelled());
    }

    function test_PlatformOperations_WhenLocked_StillWork() public {
        // Lock the campaign first
        _lockCampaign();

        // Platform-related view functions should still work
        assertFalse(campaignInfo.checkIfPlatformSelected(platformHash2));
        assertFalse(campaignInfo.checkIfPlatformApproved(platformHash2));
        
        bytes32[] memory approvedPlatforms = campaignInfo.getApprovedPlatformHashes();
        assertEq(approvedPlatforms.length, 1);
        assertEq(approvedPlatforms[0], platformHash1);
    }

    function test_UpdateSelectedPlatform_AlreadyApproved_WhenLocked_Reverts() public {
        // First select and approve a platform (this locks the campaign)
        vm.startPrank(campaignOwner);
        bytes32[] memory dataKeys = new bytes32[](1);
        dataKeys[0] = platformDataKey1;
        bytes32[] memory dataValues = new bytes32[](1);
        dataValues[0] = platformDataValue1;

        campaignInfo.updateSelectedPlatform(
            platformHash1,
            true,
            dataKeys,
            dataValues
        );
        vm.stopPrank();

        // Approve the platform (this locks the campaign)
        vm.startPrank(admin);
        treasuryFactory.deploy(
            platformHash1,
            address(campaignInfo),
            1, // implementationId
            "Test Treasury",
            "TT"
        );
        vm.stopPrank();

        // Now try to deselect the already approved platform - should revert with already approved error
        vm.startPrank(campaignOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                CampaignInfo.CampaignInfoPlatformAlreadyApproved.selector,
                platformHash1
            )
        );
        campaignInfo.updateSelectedPlatform(
            platformHash1,
            false,
            new bytes32[](0),
            new bytes32[](0)
        );
        vm.stopPrank();
    }

    function test_UpdateSelectedPlatform_SelectApprovedPlatform_WhenLocked_Reverts() public {
        // First select and approve a platform (this locks the campaign)
        vm.startPrank(campaignOwner);
        bytes32[] memory dataKeys = new bytes32[](1);
        dataKeys[0] = platformDataKey1;
        bytes32[] memory dataValues = new bytes32[](1);
        dataValues[0] = platformDataValue1;

        campaignInfo.updateSelectedPlatform(
            platformHash1,
            true,
            dataKeys,
            dataValues
        );
        vm.stopPrank();

        // Approve the platform (this locks the campaign)
        vm.startPrank(address(treasuryFactory));
        campaignInfo._setPlatformInfo(platformHash1, address(0x1234));
        vm.stopPrank();

        // Now try to select the already approved platform again - should revert
        vm.startPrank(campaignOwner);
        vm.expectRevert(CampaignInfo.CampaignInfoInvalidInput.selector);
        campaignInfo.updateSelectedPlatform(
            platformHash1,
            true,
            dataKeys,
            dataValues
        );
        vm.stopPrank();
    }

    // Helper function to lock the campaign
    function _lockCampaign() internal {
        // First select a platform
        vm.startPrank(campaignOwner);
        bytes32[] memory dataKeys = new bytes32[](1);
        dataKeys[0] = platformDataKey1;
        bytes32[] memory dataValues = new bytes32[](1);
        dataValues[0] = platformDataValue1;

        campaignInfo.updateSelectedPlatform(
            platformHash1,
            true,
            dataKeys,
            dataValues
        );
        vm.stopPrank();

        // Then deploy a treasury (this locks the campaign)
        vm.startPrank(admin);
        treasuryFactory.deploy(
            platformHash1,
            address(campaignInfo),
            1, // implementationId
            "Test Treasury",
            "TT"
        );
        vm.stopPrank();
    }
}