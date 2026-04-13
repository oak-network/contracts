// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import {KeepWhatsRaised} from "src/treasuries/KeepWhatsRaised.sol";
import {KeepWhatsRaisedWithTipForwarding} from "src/treasuries/KeepWhatsRaisedWithTipForwarding.sol";
import {KeepWhatsRaised_Integration_Shared_Test} from "../KeepWhatsRaised/KeepWhatsRaised.t.sol";
import {Base_Test} from "../../Base.t.sol";

/// @notice Common testing logic needed by all KeepWhatsRaisedWithTipForwarding integration tests.
abstract contract KWRTipForwarding_Integration_Shared_Test is KeepWhatsRaised_Integration_Shared_Test {
    KeepWhatsRaisedWithTipForwarding internal tipForwardingImplementation;

    /// @dev Sets up the test environment with KeepWhatsRaisedWithTipForwarding as the treasury implementation.
    ///      Calls Base_Test.setUp() directly to avoid the parent's full setup, then registers both
    ///      the base KWR (ID=1) and tip-forwarding (ID=2) implementations, deploying with ID=2.
    function setUp() public virtual override {
        Base_Test.setUp();

        // Deploy tip-forwarding implementation
        tipForwardingImplementation = new KeepWhatsRaisedWithTipForwarding();

        // Enlist platform
        enlistPlatform(PLATFORM_2_HASH);
        console.log("enlisted platform");

        // Register base KWR at ID=1
        vm.startPrank(users.platform2AdminAddress);
        treasuryFactory.registerTreasuryImplementation(PLATFORM_2_HASH, 1, address(keepWhatsRaisedImplementation));
        vm.stopPrank();
        console.log("registered base KWR at ID=1");

        // Register tip-forwarding at ID=2
        vm.startPrank(users.platform2AdminAddress);
        treasuryFactory.registerTreasuryImplementation(PLATFORM_2_HASH, 2, address(tipForwardingImplementation));
        vm.stopPrank();
        console.log("registered tip-forwarding KWR at ID=2");

        // Approve both implementations
        vm.startPrank(users.protocolAdminAddress);
        treasuryFactory.approveTreasuryImplementation(PLATFORM_2_HASH, 1);
        treasuryFactory.approveTreasuryImplementation(PLATFORM_2_HASH, 2);
        vm.stopPrank();
        console.log("approved both implementations");

        // Create campaign
        createCampaign(PLATFORM_2_HASH);
        console.log("created campaign");

        // Deploy treasury using tip-forwarding implementation (ID=2)
        vm.startPrank(users.platform2AdminAddress);
        vm.recordLogs();

        treasuryFactory.deploy(PLATFORM_2_HASH, campaignAddress, 2);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        vm.stopPrank();

        // Decode the TreasuryDeployed event to get the clone address
        (bytes32[] memory topics, bytes memory data) = decodeTopicsAndData(
            entries, "TreasuryFactoryTreasuryDeployed(bytes32,uint256,address,address)", address(treasuryFactory)
        );

        require(topics.length >= 3, "Expected indexed params missing");

        treasuryAddress = abi.decode(data, (address));
        keepWhatsRaised = KeepWhatsRaised(treasuryAddress);
        console.log("deployed tip-forwarding treasury");

        // Configure treasury with standard fee values
        KeepWhatsRaised.FeeValues memory feeValues = KeepWhatsRaised.FeeValues({
            flatFeeValue: uint256(FLAT_FEE_VALUE),
            cumulativeFlatFeeValue: uint256(CUMULATIVE_FLAT_FEE_VALUE),
            grossPercentageFeeValues: new uint256[](2)
        });
        feeValues.grossPercentageFeeValues[0] = uint256(PLATFORM_FEE_VALUE);
        feeValues.grossPercentageFeeValues[1] = uint256(VAKI_COMMISSION_VALUE);

        configureTreasury(users.platform2AdminAddress, treasuryAddress, CONFIG, CAMPAIGN_DATA, FEE_KEYS, feeValues);
        console.log("configured treasury");
    }
}
