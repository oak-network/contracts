// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import {GlobalParams} from "src/GlobalParams.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Defaults} from "../Base.t.sol";
import {TestToken} from "../../mocks/TestToken.sol";

contract GlobalParams_UnitTest is Test, Defaults {
    GlobalParams internal globalParams;
    GlobalParams internal implementation;
    TestToken internal token1;
    TestToken internal token2;
    TestToken internal token3;

    address internal admin = address(0xA11CE);
    uint256 internal protocolFee = 300; // 3%

    bytes32 internal constant USD = bytes32("USD");
    bytes32 internal constant EUR = bytes32("EUR");
    bytes32 internal constant BRL = bytes32("BRL");

    function setUp() public {
        token1 = new TestToken("Token1", "TK1", 18);
        token2 = new TestToken("Token2", "TK2", 18);
        token3 = new TestToken("Token3", "TK3", 18);

        // Setup initial currencies and tokens
        bytes32[] memory currencies = new bytes32[](2);
        currencies[0] = USD;
        currencies[1] = EUR;

        address[][] memory tokensPerCurrency = new address[][](2);
        tokensPerCurrency[0] = new address[](2);
        tokensPerCurrency[0][0] = address(token1);
        tokensPerCurrency[0][1] = address(token2);

        tokensPerCurrency[1] = new address[](1);
        tokensPerCurrency[1][0] = address(token3);

        // Deploy implementation
        implementation = new GlobalParams();

        // Prepare initialization data
        bytes memory initData =
            abi.encodeWithSelector(GlobalParams.initialize.selector, admin, protocolFee, currencies, tokensPerCurrency);

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        globalParams = GlobalParams(address(proxy));
    }

    function testInitialValues() public {
        assertEq(globalParams.getProtocolAdminAddress(), admin);
        assertEq(globalParams.getProtocolFeePercent(), protocolFee);

        // Test USD tokens
        address[] memory usdTokens = globalParams.getTokensForCurrency(USD);
        assertEq(usdTokens.length, 2);
        assertEq(usdTokens[0], address(token1));
        assertEq(usdTokens[1], address(token2));

        // Test EUR tokens
        address[] memory eurTokens = globalParams.getTokensForCurrency(EUR);
        assertEq(eurTokens.length, 1);
        assertEq(eurTokens[0], address(token3));

        // Token validation is done by checking if token is in the returned array
        // This is handled by the getTokensForCurrency function above
    }

    function testSetProtocolAdmin() public {
        address newAdmin = address(0xBEEF);
        vm.prank(admin);
        globalParams.updateProtocolAdminAddress(newAdmin);
        assertEq(globalParams.getProtocolAdminAddress(), newAdmin);
    }

    function testSetProtocolFeePercent() public {
        vm.prank(admin);
        globalParams.updateProtocolFeePercent(500); // 5%
        assertEq(globalParams.getProtocolFeePercent(), 500);
    }

    function testAddTokenToCurrency() public {
        TestToken newToken = new TestToken("NewToken", "NEW", 18);

        vm.prank(admin);
        globalParams.addTokenToCurrency(USD, address(newToken));

        // Verify token was added
        address[] memory usdTokens = globalParams.getTokensForCurrency(USD);
        assertEq(usdTokens.length, 3);
        assertEq(usdTokens[2], address(newToken));
    }

    function testAddTokenToNewCurrency() public {
        TestToken newToken = new TestToken("BRLToken", "BRL", 18);

        vm.prank(admin);
        globalParams.addTokenToCurrency(BRL, address(newToken));

        // Verify token was added to new currency
        address[] memory brlTokens = globalParams.getTokensForCurrency(BRL);
        assertEq(brlTokens.length, 1);
        assertEq(brlTokens[0], address(newToken));
    }

    function testAddTokenRevertWhenNotOwner() public {
        TestToken newToken = new TestToken("NewToken", "NEW", 18);

        vm.expectRevert();
        globalParams.addTokenToCurrency(USD, address(newToken));
    }

    function testAddTokenToMultipleCurrencies() public {
        // A token can be assigned to multiple currencies
        vm.prank(admin);
        globalParams.addTokenToCurrency(EUR, address(token1));

        // Verify token is now in both USD and EUR
        address[] memory usdTokens = globalParams.getTokensForCurrency(USD);
        address[] memory eurTokens = globalParams.getTokensForCurrency(EUR);

        assertEq(usdTokens.length, 2);
        assertEq(eurTokens.length, 2);
        assertEq(eurTokens[1], address(token1));
    }

    function testRemoveTokenFromCurrency() public {
        vm.prank(admin);
        globalParams.removeTokenFromCurrency(USD, address(token1));

        // Verify token was removed
        address[] memory usdTokens = globalParams.getTokensForCurrency(USD);
        assertEq(usdTokens.length, 1);
        assertEq(usdTokens[0], address(token2));
    }

    function testRemoveTokenRevertWhenNotOwner() public {
        vm.expectRevert();
        globalParams.removeTokenFromCurrency(USD, address(token1));
    }

    function testRemoveTokenThatDoesNotExist() public {
        // Removing a non-existent token
        TestToken nonExistentToken = new TestToken("NonExistent", "NE", 18);

        vm.expectRevert();
        vm.prank(admin);
        globalParams.removeTokenFromCurrency(USD, address(nonExistentToken));
    }

    function testUpdatePlatformClaimDelay() public {
        bytes32 platformHash = keccak256("claimDelayPlatform");
        address platformAdmin = address(0xB0B);

        vm.prank(admin);
        globalParams.enlistPlatform(platformHash, platformAdmin, 500, address(0));

        uint256 claimDelay = 5 days;
        vm.prank(platformAdmin);
        globalParams.updatePlatformClaimDelay(platformHash, claimDelay);

        assertEq(globalParams.getPlatformClaimDelay(platformHash), claimDelay);
    }

    function testUpdatePlatformClaimDelayRevertsForNonAdmin() public {
        bytes32 platformHash = keccak256("claimDelayPlatformRevert");
        address platformAdmin = address(0xC0DE);

        vm.prank(admin);
        globalParams.enlistPlatform(platformHash, platformAdmin, 600, address(0));

        vm.expectRevert(abi.encodeWithSelector(GlobalParams.GlobalParamsUnauthorized.selector));
        globalParams.updatePlatformClaimDelay(platformHash, 3 days);
    }

    function testSetPlatformLineItemTypeAllowsRefundableWithProtocolFee() public {
        bytes32 platformHash = keccak256("lineItemPlatform");
        address platformAdmin = address(0xCAFE);
        bytes32 typeId = keccak256("refundable_fee_with_protocol");

        vm.prank(admin);
        globalParams.enlistPlatform(platformHash, platformAdmin, 500, address(0));

        vm.prank(platformAdmin);
        globalParams.setPlatformLineItemType(
            platformHash,
            typeId,
            "refundable_fee_with_protocol",
            false, // countsTowardGoal
            true, // applyProtocolFee
            true, // canRefund
            false // instantTransfer
        );

        (bool exists,, bool countsTowardGoal, bool applyProtocolFee, bool canRefund, bool instantTransfer) =
            globalParams.getPlatformLineItemType(platformHash, typeId);

        assertTrue(exists);
        assertFalse(countsTowardGoal);
        assertTrue(applyProtocolFee);
        assertTrue(canRefund);
        assertFalse(instantTransfer);
    }

    function testSetPlatformLineItemTypeRevertsWhenGoalAppliesProtocolFee() public {
        bytes32 platformHash = keccak256("goalPlatform");
        address platformAdmin = address(0xDEAD);
        bytes32 typeId = keccak256("goal_type");

        vm.prank(admin);
        globalParams.enlistPlatform(platformHash, platformAdmin, 400, address(0));

        vm.expectRevert(GlobalParams.GlobalParamsInvalidInput.selector);
        vm.prank(platformAdmin);
        globalParams.setPlatformLineItemType(
            platformHash,
            typeId,
            "goal_type",
            true, // countsTowardGoal
            true, // applyProtocolFee (should revert)
            true, // canRefund
            false // instantTransfer
        );
    }

    function testSetPlatformLineItemTypeRevertsWhenGoalCannotRefund() public {
        bytes32 platformHash = keccak256("goalRefundPlatform");
        address platformAdmin = address(0xFEED);
        bytes32 typeId = keccak256("goal_no_refund");

        vm.prank(admin);
        globalParams.enlistPlatform(platformHash, platformAdmin, 450, address(0));

        vm.expectRevert(GlobalParams.GlobalParamsInvalidInput.selector);
        vm.prank(platformAdmin);
        globalParams.setPlatformLineItemType(
            platformHash,
            typeId,
            "goal_no_refund",
            true, // countsTowardGoal
            false, // applyProtocolFee
            false, // canRefund (should revert)
            false // instantTransfer
        );
    }

    function testSetPlatformLineItemTypeRevertsWhenInstantTransferRefundable() public {
        bytes32 platformHash = keccak256("instantPlatform");
        address platformAdmin = address(0xABCD);
        bytes32 typeId = keccak256("instant_refundable");

        vm.prank(admin);
        globalParams.enlistPlatform(platformHash, platformAdmin, 300, address(0));

        vm.expectRevert(GlobalParams.GlobalParamsInvalidInput.selector);
        vm.prank(platformAdmin);
        globalParams.setPlatformLineItemType(
            platformHash,
            typeId,
            "instant_refundable",
            false, // countsTowardGoal (non-goal)
            false, // applyProtocolFee
            true, // canRefund (should revert with instantTransfer)
            true // instantTransfer
        );
    }

    function testGetTokensForCurrency() public {
        address[] memory usdTokens = globalParams.getTokensForCurrency(USD);
        assertEq(usdTokens.length, 2);

        address[] memory eurTokens = globalParams.getTokensForCurrency(EUR);
        assertEq(eurTokens.length, 1);

        // Non-existent currency returns empty array
        address[] memory nonExistentTokens = globalParams.getTokensForCurrency(BRL);
        assertEq(nonExistentTokens.length, 0);
    }

    function testUnauthorizedSettersRevert() public {
        vm.expectRevert();
        globalParams.updateProtocolFeePercent(1000);

        vm.expectRevert();
        globalParams.updateProtocolAdminAddress(address(0xBEEF));
    }

    function testInitializerWithEmptyArrays() public {
        bytes32[] memory currencies = new bytes32[](0);
        address[][] memory tokensPerCurrency = new address[][](0);

        GlobalParams emptyImpl = new GlobalParams();
        bytes memory initData =
            abi.encodeWithSelector(GlobalParams.initialize.selector, admin, protocolFee, currencies, tokensPerCurrency);

        ERC1967Proxy emptyProxy = new ERC1967Proxy(address(emptyImpl), initData);
        GlobalParams emptyGlobalParams = GlobalParams(address(emptyProxy));

        address[] memory tokens = emptyGlobalParams.getTokensForCurrency(USD);
        assertEq(tokens.length, 0);
    }

    function testInitializerRevertOnMismatchedArrays() public {
        bytes32[] memory currencies = new bytes32[](2);
        currencies[0] = USD;
        currencies[1] = EUR;

        address[][] memory tokensPerCurrency = new address[][](1);
        tokensPerCurrency[0] = new address[](1);
        tokensPerCurrency[0][0] = address(token1);

        GlobalParams mismatchImpl = new GlobalParams();
        bytes memory initData =
            abi.encodeWithSelector(GlobalParams.initialize.selector, admin, protocolFee, currencies, tokensPerCurrency);

        vm.expectRevert();
        new ERC1967Proxy(address(mismatchImpl), initData);
    }

    function testMultipleTokensPerCurrency() public {
        // USD should have 2 tokens
        address[] memory usdTokens = globalParams.getTokensForCurrency(USD);
        assertEq(usdTokens.length, 2);

        // Add a third token to USD
        TestToken token4 = new TestToken("Token4", "TK4", 18);
        vm.prank(admin);
        globalParams.addTokenToCurrency(USD, address(token4));

        // Verify USD now has 3 tokens
        usdTokens = globalParams.getTokensForCurrency(USD);
        assertEq(usdTokens.length, 3);
        assertEq(usdTokens[0], address(token1));
        assertEq(usdTokens[1], address(token2));
        assertEq(usdTokens[2], address(token4));
    }

    function testRemoveMiddleToken() public {
        // Remove token1 (first token) from USD
        vm.prank(admin);
        globalParams.removeTokenFromCurrency(USD, address(token1));

        address[] memory usdTokens = globalParams.getTokensForCurrency(USD);
        assertEq(usdTokens.length, 1);
        assertEq(usdTokens[0], address(token2));
    }

    function testAddRemoveMultipleTokens() public {
        TestToken token4 = new TestToken("Token4", "TK4", 18);
        TestToken token5 = new TestToken("Token5", "TK5", 18);

        // Add two new tokens
        vm.startPrank(admin);
        globalParams.addTokenToCurrency(USD, address(token4));
        globalParams.addTokenToCurrency(USD, address(token5));
        vm.stopPrank();

        address[] memory usdTokens = globalParams.getTokensForCurrency(USD);
        assertEq(usdTokens.length, 4);

        // Remove original tokens
        vm.startPrank(admin);
        globalParams.removeTokenFromCurrency(USD, address(token1));
        globalParams.removeTokenFromCurrency(USD, address(token2));
        vm.stopPrank();

        usdTokens = globalParams.getTokensForCurrency(USD);
        assertEq(usdTokens.length, 2);
        assertEq(usdTokens[0], address(token5)); // token5 moved to index 0
        assertEq(usdTokens[1], address(token4)); // token4 moved to index 1
    }

    function testUpgrade() public {
        // Deploy new implementation
        GlobalParams newImplementation = new GlobalParams();

        // Upgrade as admin
        vm.prank(admin);
        globalParams.upgradeToAndCall(address(newImplementation), "");

        // Verify state is preserved after upgrade
        assertEq(globalParams.getProtocolAdminAddress(), admin);
        assertEq(globalParams.getProtocolFeePercent(), protocolFee);

        address[] memory usdTokens = globalParams.getTokensForCurrency(USD);
        assertEq(usdTokens.length, 2);
    }

    function testUpgradeUnauthorizedReverts() public {
        // Deploy new implementation
        GlobalParams newImplementation = new GlobalParams();

        // Try to upgrade as non-admin (should revert)
        vm.expectRevert();
        globalParams.upgradeToAndCall(address(newImplementation), "");
    }

    function testCannotInitializeTwice() public {
        bytes32[] memory currencies = new bytes32[](0);
        address[][] memory tokensPerCurrency = new address[][](0);

        // Try to initialize again (should revert)
        vm.expectRevert();
        globalParams.initialize(admin, protocolFee, currencies, tokensPerCurrency);
    }
}
