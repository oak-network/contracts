// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./PaymentTreasury.t.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";
import {LogDecoder} from "../../utils/LogDecoder.sol";
import {PaymentTreasury} from "src/treasuries/PaymentTreasury.sol";

contract PaymentTreasuryBatchLimit_Test is PaymentTreasury_Integration_Shared_Test {
    uint256 constant CELO_BLOCK_GAS_LIMIT = 30_000_000;

    function setUp() public override {
        super.setUp();
        console.log("=== CELO BATCH LIMIT TEST ===");
        console.log("Block Gas Limit: 30,000,000");
        console.log("Block gas target: 6,000,000");
        console.log("");
    }

    /**
     * @notice Creates payments for testing
     */
    function _createBatchPayments(uint256 count) internal returns (bytes32[] memory paymentIds) {
        paymentIds = new bytes32[](count);
        uint256 paymentAmount = 10e18;
        uint256 expiration = block.timestamp + 7 days;

        vm.startPrank(users.platform1AdminAddress);
        for (uint256 i = 0; i < count; i++) {
            bytes32 paymentId = keccak256(abi.encodePacked("payment", i));
            bytes32 buyerId = keccak256(abi.encodePacked("buyer", i));
            bytes32 itemId = keccak256(abi.encodePacked("item", i));

            paymentTreasury.createPayment(paymentId, buyerId, itemId, address(testToken), paymentAmount, expiration);

            paymentIds[i] = paymentId;
        }
        vm.stopPrank();

        // Fund the treasury
        deal(address(testToken), treasuryAddress, paymentAmount * count);

        return paymentIds;
    }

    /**
     * @notice Test to find batch limits
     */
    function test_FindBatchLimits() public {
        uint256[] memory batchSizes = new uint256[](5);
        batchSizes[0] = 100;
        batchSizes[1] = 200;
        batchSizes[2] = 300;
        batchSizes[3] = 400;
        batchSizes[4] = 500;

        console.log("TESTING BATCH SIZES FROM 100 TO 500");
        console.log("====================================");

        for (uint256 i = 0; i < batchSizes.length; i++) {
            uint256 batchSize = batchSizes[i];

            bytes32[] memory paymentIds = _createBatchPayments(batchSize);

            vm.prank(users.platform1AdminAddress);
            uint256 gasStart = gasleft();

            try paymentTreasury.confirmPaymentBatch(paymentIds) {
                uint256 gasUsed = gasStart - gasleft();
                uint256 percentOfBlock = (gasUsed * 100) / CELO_BLOCK_GAS_LIMIT;

                console.log(string(abi.encodePacked("Batch Size: ", vm.toString(batchSize))));
                console.log(string(abi.encodePacked("Gas Used: ", vm.toString(gasUsed))));
                console.log(string(abi.encodePacked("Percent of Block: ", vm.toString(percentOfBlock), "%")));

                // Check safety thresholds
                if (percentOfBlock <= 30) {
                    console.log("Status: SAFE");
                } else {
                    console.log("Status: RISKY");
                }
                console.log("----------------------------");

            } catch {
                console.log(string(abi.encodePacked("Batch Size: ", vm.toString(batchSize))));
                console.log("FAILED - Exceeds gas limit or reverted");
                console.log("----------------------------");
                break; 
            }

            setUp();
        }
    }
}

