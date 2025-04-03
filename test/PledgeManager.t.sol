// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "../src/utils/PledgeManager.sol";

contract PledgeManagerTest is Test, PledgeManager {
    address private backer1 = address(0x1);
    address private backer2 = address(0x2);

    function setUp() public {
        // Set up any initial state if needed
    }

    /**
     * @notice Public wrapper for `_getPendingPledge` to expose it for testing.
     * @param backer The address of the backer.
     * @return The pending pledge.
     */
    function getPendingPledge(
        address backer
    ) public view returns (PendingPledge memory) {
        return _getPendingPledge(backer);
    }

    /**
     * @notice Public wrapper for `clearExpiredPledges` to expose it for testing.
     */
    function clearExpiredPledgesPublic() public {
        clearExpiredPledges();
    }

    function testMakePledge() public {
        uint256 pledgeAmount = 100 ether;
        uint256 expiration = block.timestamp + 1 days;

        vm.prank(backer1);
        _makePledge(backer1, pledgeAmount, expiration);

        PendingPledge memory pledge = getPendingPledge(backer1);
        assertEq(pledge.amount, pledgeAmount, "Pledge amount mismatch");
        assertEq(pledge.expiration, expiration, "Pledge expiration mismatch");
        assertFalse(pledge.confirmed, "Pledge should not be confirmed");
    }

    function testConfirmPledge() public {
        uint256 pledgeAmount = 100 ether;
        uint256 expiration = block.timestamp + 1 days;

        vm.prank(backer1);
        _makePledge(backer1, pledgeAmount, expiration);
        _confirmPledge(backer1);

        PendingPledge memory pledge = getPendingPledge(backer1);
        assertTrue(pledge.confirmed, "Pledge should be confirmed");
        assertEq(totalPledged, pledgeAmount, "Total pledged amount mismatch");
    }

    function testInvalidateExpiredPledge() public {
        uint256 pledgeAmount = 100 ether;
        uint256 expiration = block.timestamp + 1 days;

        vm.prank(backer1);
        _makePledge(backer1, pledgeAmount, expiration);

        vm.warp(block.timestamp + 2 days);

        _invalidateExpiredPledge(backer1);

        PendingPledge memory pledge = getPendingPledge(backer1);
        assertEq(pledge.amount, 0, "Pledge should be removed");
    }

    function testClearExpiredPledges() public {
        uint256 pledgeAmount1 = 100 ether;
        uint256 expiration1 = block.timestamp + 1 days;

        uint256 pledgeAmount2 = 200 ether;
        uint256 expiration2 = block.timestamp + 2 days;

        vm.prank(backer1);
        _makePledge(backer1, pledgeAmount1, expiration1);
        _makePledge(backer2, pledgeAmount2, expiration2);

        vm.warp(block.timestamp + 1.5 days);

        clearExpiredPledgesPublic();

        PendingPledge memory pledge1 = getPendingPledge(backer1);
        PendingPledge memory pledge2 = getPendingPledge(backer2);

        assertEq(pledge1.amount, 0, "First pledge should be removed");
        assertEq(pledge2.amount, pledgeAmount2, "Second pledge should remain");
    }
}
