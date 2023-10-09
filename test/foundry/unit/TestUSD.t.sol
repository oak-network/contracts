// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Base_Test} from "../Base.t.sol";

/// @notice Test contract for TestUSD contract.
contract TestUSD_Test is Base_Test {
    
    function setUp() public override {
       super.setUp();
       vm.startPrank(users.contractOwner);
       testUSD.mint(users.creator1Address, 10e18);
       vm.stopPrank();
    }
    
    /// @dev Test mint function.
    function test_Mint() external {
        assertEq(testUSD.balanceOf(users.creator1Address), 10e18); 
    }

    /// @dev Test TransferFrom function.
    function test_TransferFrom() external {
        vm.startPrank(users.creator1Address);
        testUSD.approve(address(this), 1e18);
        vm.stopPrank();

        bool isSuccess = testUSD.transferFrom(users.creator1Address, users.creator2Address, 1e18);
        assert(isSuccess);
        assertEq(testUSD.balanceOf(users.creator1Address), 9e18);
        assertEq(testUSD.balanceOf(users.creator2Address), 1e18);
    }

}
