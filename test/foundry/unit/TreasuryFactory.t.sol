// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {TreasuryFactory} from "src/TreasuryFactory.sol";
import {GlobalParams} from "src/GlobalParams.sol";
import {TestUSD} from "../../mocks/TestUSD.sol";
import {AdminAccessChecker} from "src/utils/AdminAccessChecker.sol";

contract TreasuryFactory_UpdatedUnitTest is Test {
    TreasuryFactory internal factory;
    GlobalParams internal globalParams;
    TestUSD internal testUSD;

    address internal protocolAdmin = address(0xA11CE);
    address internal platformAdmin = address(0xBEEF);
    address internal other = address(0xDEAD);

    bytes32 internal platformHash = keccak256(abi.encodePacked("TEST"));
    uint256 internal implementationId = 1;
    address internal implementation = address(0xC0DE);

    uint256 internal platformFee = 300; // 3%

    function setUp() public {
        testUSD = new TestUSD();
        globalParams = new GlobalParams(protocolAdmin, address(testUSD), 300);
        factory = new TreasuryFactory(globalParams);

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
}
