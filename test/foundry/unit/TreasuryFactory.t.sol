// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import {TreasuryFactory} from "src/TreasuryFactory.sol";
import {GlobalParams} from "src/GlobalParams.sol";
import {IGlobalParams} from "src/interfaces/IGlobalParams.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TestToken} from "../../mocks/TestToken.sol";
import {Defaults} from "../Base.t.sol";
import {AdminAccessChecker} from "src/utils/AdminAccessChecker.sol";

contract TreasuryFactory_UpdatedUnitTest is Test, Defaults {
    TreasuryFactory internal factory;
    GlobalParams internal globalParams;
    TestToken internal testToken;

    address internal protocolAdmin = address(0xA11CE);
    address internal platformAdmin = address(0xBEEF);
    address internal other = address(0xDEAD);

    bytes32 internal platformHash = keccak256(abi.encodePacked("TEST"));
    uint256 internal implementationId = 1;
    address internal implementation = address(0xC0DE);

    uint256 internal platformFee = 300; // 3%

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
            GlobalParams.initialize.selector,
            protocolAdmin,
            300,
            currencies,
            tokensPerCurrency
        );
        ERC1967Proxy globalParamsProxy = new ERC1967Proxy(
            address(globalParamsImpl),
            globalParamsInitData
        );
        globalParams = GlobalParams(address(globalParamsProxy));
        
        // Deploy TreasuryFactory with proxy
        TreasuryFactory factoryImpl = new TreasuryFactory();
        bytes memory factoryInitData = abi.encodeWithSelector(
            TreasuryFactory.initialize.selector,
            IGlobalParams(address(globalParams))
        );
        ERC1967Proxy factoryProxy = new ERC1967Proxy(
            address(factoryImpl),
            factoryInitData
        );
        factory = TreasuryFactory(address(factoryProxy));

        // Label addresses for clarity
        vm.label(protocolAdmin, "ProtocolAdmin");
        vm.label(platformAdmin, "PlatformAdmin");
        vm.label(implementation, "Implementation");
        vm.startPrank(protocolAdmin);
        globalParams.enlistPlatform(platformHash, platformAdmin, platformFee);
        vm.stopPrank();
    }

    function testRegisterTreasuryImplementation() public {
        vm.startPrank(platformAdmin);
        vm.mockCall(
            address(globalParams),
            abi.encodeWithSignature(
                "isPlatformAdmin(bytes32,address)",
                platformHash,
                platformAdmin
            ),
            abi.encode(true)
        );
        factory.registerTreasuryImplementation(
            platformHash,
            implementationId,
            implementation
        );
        vm.stopPrank();
    }

    function testRegisterWithZeroAddressReverts() public {
        vm.startPrank(platformAdmin);
        vm.mockCall(
            address(globalParams),
            abi.encodeWithSignature(
                "isPlatformAdmin(bytes32,address)",
                platformHash,
                platformAdmin
            ),
            abi.encode(true)
        );
        vm.expectRevert(TreasuryFactory.TreasuryFactoryInvalidAddress.selector);
        factory.registerTreasuryImplementation(
            platformHash,
            implementationId,
            address(0)
        );
        vm.stopPrank();
    }

    function testApproveTreasuryImplementation() public {
        // First register with platform admin
        vm.startPrank(platformAdmin);
        vm.mockCall(
            address(globalParams),
            abi.encodeWithSignature(
                "isPlatformAdmin(bytes32,address)",
                platformHash,
                platformAdmin
            ),
            abi.encode(true)
        );
        factory.registerTreasuryImplementation(
            platformHash,
            implementationId,
            implementation
        );
        vm.stopPrank();

        // Then approve as protocol admin
        vm.startPrank(protocolAdmin);
        factory.approveTreasuryImplementation(platformHash, implementationId);
        vm.stopPrank();
    }

    function testDeployFailsIfNotApproved() public {
        vm.startPrank(platformAdmin);
        vm.mockCall(
            address(globalParams),
            abi.encodeWithSignature(
                "isPlatformAdmin(bytes32,address)",
                platformHash,
                platformAdmin
            ),
            abi.encode(true)
        );
        factory.registerTreasuryImplementation(
            platformHash,
            implementationId,
            implementation
        );

        vm.expectRevert(
            TreasuryFactory
                .TreasuryFactoryImplementationNotSetOrApproved
                .selector
        );
        factory.deploy(
            platformHash,
            address(0x1234),
            implementationId,
            "Test",
            "TST"
        );
        vm.stopPrank();
    }

    function testUpgrade() public {
        // Deploy new implementation
        TreasuryFactory newImplementation = new TreasuryFactory();
        
        // Upgrade as protocol admin
        vm.prank(protocolAdmin);
        factory.upgradeToAndCall(address(newImplementation), "");
        
        // Factory should still work after upgrade
        vm.startPrank(platformAdmin);
        factory.registerTreasuryImplementation(
            platformHash,
            implementationId,
            implementation
        );
        vm.stopPrank();
    }

    function testUpgradeUnauthorizedReverts() public {
        // Deploy new implementation
        TreasuryFactory newImplementation = new TreasuryFactory();
        
        // Try to upgrade as non-protocol-admin (should revert)
        vm.prank(other);
        vm.expectRevert();
        factory.upgradeToAndCall(address(newImplementation), "");
    }

    function testCannotInitializeTwice() public {
        // Try to initialize again (should revert)
        vm.expectRevert();
        factory.initialize(IGlobalParams(address(globalParams)));
    }
}
