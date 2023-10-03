// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Base_Test} from "../../Base.t.sol";
import {BytesSplitter} from "../../utils/BytesSplitter.sol";
import "forge-std/Vm.sol";
import "forge-std/Console.sol";
import {AllOrNothing} from "src/treasuries/AllOrNothing.sol";

abstract contract AllOrNothing_Integration_Shared_Test is
    Base_Test,
    BytesSplitter
{
    address campaignAddress;
    address treasuryAddress;

    AllOrNothing internal allOrNothing;

    uint256 pledgeForARewardTokenId;

    function setUp() public virtual override {
        super.setUp();

        //Enlist Platform
        enlistPlatform(PLATFORM_1_BYTES);

        //Add Byte code chunks
        addBytecode(PLATFORM_1_BYTES, TREASURY_BYTE_CODE_INDEX);

        //Enlist Bytecode
        enlistBytecode(PLATFORM_1_BYTES, TREASURY_BYTE_CODE_INDEX);

        //Create Campaign
        createCampaign(PLATFORM_1_BYTES);

        //Deploy Treasury Contract
        deploy(PLATFORM_1_BYTES, TREASURY_BYTE_CODE_INDEX);

        allOrNothing = AllOrNothing(treasuryAddress);
    }

    function enlistPlatform(bytes32 platformBytes) internal {
        vm.startPrank(users.contractOwner);
        globalParams.enlistPlatform(
            platformBytes,
            users.platform1AdminAddress,
            PLATFORM_FEE_PERCENT
        );
        vm.stopPrank();
    }

    function addBytecode(bytes32 platformBytes, uint256 bytecodeIndex) internal {
        //Splitting Treasury Bytecode into 2 chunks
        bytes memory bytesCode = vm.getCode("AllOrNothing.sol:AllOrNothing");
        (bytes memory chunk1, bytes memory chunk2) = splitBytesIntoTwo(
            bytesCode
        );

        vm.startPrank(users.platform1AdminAddress);
        treasuryFactory.addBytecodeChunk(
            platformBytes,
            bytecodeIndex,
            0,
            false,
            chunk1
        );
        treasuryFactory.addBytecodeChunk(
            platformBytes,
            bytecodeIndex,
            1,
            true,
            chunk2
        );
        vm.stopPrank();
    }

    function enlistBytecode(
        bytes32 platformBytes,
        uint256 bytecodeIndex
    ) internal {
        vm.startPrank(users.protocolAdminAddress);
        treasuryFactory.enlistBytecode(platformBytes, bytecodeIndex);
        vm.stopPrank();
    }

    function createCampaign(bytes32 platformBytes) internal {

        bytes32 identifierHash = keccak256(abi.encodePacked(platformBytes));
        bytes32[] memory selectedPlatformBytes = new bytes32[](1);
        bytes32[] memory platformDataKey;
        bytes32[] memory platformDataValue;
        selectedPlatformBytes[0] = platformBytes;

        vm.startPrank(users.creator1Address);
        vm.recordLogs();

        campaignInfoFactory.createCampaign(
            users.creator1Address,
            identifierHash,
            selectedPlatformBytes,
            platformDataKey,
            platformDataValue,
            CAMPAIGN_DATA
        );

        Vm.Log[] memory entries = vm.getRecordedLogs();

        campaignAddress = address(uint160(uint(entries[2].topics[2])));
        vm.stopPrank();
    }

    function deploy(
        bytes32 platformBytes,
        uint256 bytecodeIndex
    ) internal {
        vm.startPrank(users.platform1AdminAddress);
        vm.recordLogs();
        treasuryFactory.deploy(platformBytes, bytecodeIndex, campaignAddress);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        treasuryAddress = address(uint160(uint(abi.decode(entries[1].data, (bytes32)))));
        vm.stopPrank();
     }

    function addReward() internal returns(Vm.Log[] memory) {
        
        vm.startPrank(users.creator1Address);
        vm.recordLogs();

        allOrNothing.addReward(REWARD_NAME_1_BYTES, REWARD1);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        vm.stopPrank();

        return entries;
    }

    function pledgeOnPreLaunch() internal returns(Vm.Log[] memory) {
        vm.startPrank(users.backer1Address);
        vm.recordLogs();

        //Increase Allowance to the AllOrNothing Contract
        testUSD.increaseAllowance(treasuryAddress, PRE_LAUNCH_PLEDGE_AMOUNT);

        allOrNothing.pledgeOnPreLaunch(users.backer1Address);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        vm.stopPrank();

        return entries;
    }

    function pledgeForAReward() internal returns (Vm.Log[] memory) {
        
        vm.startPrank(users.backer1Address);
        vm.recordLogs();

        //Increase Allowance to the AllOrNothing Contract
        testUSD.increaseAllowance(treasuryAddress, PLEDGE_AMOUNT);

        vm.warp(LAUNCH_TIME);

        bytes32[] memory reward = new bytes32[](1);
        reward[0] = REWARD_NAME_1_BYTES;
        allOrNothing.pledgeForAReward(users.backer1Address, reward);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 pledgeAmount;
        uint256 tokenId;
        bool isPreLaunchPledge;
        bytes32[] memory rewards;

        (pledgeAmount, tokenId, isPreLaunchPledge, rewards) = abi.decode(entries[4].data, (uint256,uint256,bool,bytes32[]));

        pledgeForARewardTokenId = tokenId;

        vm.stopPrank();

        return entries;
    }

    function pledgeWithoutAReward() internal returns(Vm.Log[] memory) {
        
        vm.startPrank(users.backer1Address);
        vm.recordLogs();

        //Increase Allowance to the AllOrNothing Contract
        testUSD.increaseAllowance(treasuryAddress, PLEDGE_AMOUNT);

        allOrNothing.pledgeWithoutAReward(users.backer1Address, PLEDGE_AMOUNT);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        vm.stopPrank();

        return entries;
    }

    function claimRefund() internal returns(Vm.Log[] memory) {
        
        vm.startPrank(users.backer1Address);
        vm.recordLogs();

        //Approve NFT Burn to the AllOrNothing Contract
        allOrNothing.approve(address(allOrNothing), pledgeForARewardTokenId);

        allOrNothing.claimRefund(pledgeForARewardTokenId);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        vm.stopPrank();

        return entries;
    }

    function disburseFees() internal returns(Vm.Log[] memory) {
        
        vm.recordLogs();

        allOrNothing.disburseFees();

        Vm.Log[] memory entries = vm.getRecordedLogs();

        return entries;
    }

    function withdraw() internal returns(Vm.Log[] memory) {
        
        vm.recordLogs();

        allOrNothing.withdraw();

        Vm.Log[] memory entries = vm.getRecordedLogs();

        return entries;
    }

}
