// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Users} from "./utils/Types.sol";
import {TestUSD} from "src/TestUSD.sol";
import {GlobalParams} from "src/GlobalParams.sol";
import {CampaignInfoFactory} from "src/CampaignInfoFactory.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {TreasuryFactory} from "src/TreasuryFactory.sol";
import {AllOrNothing} from "src/treasuries/AllOrNothing.sol";

abstract contract Base_Test is Test {

    //Variables
    Users internal users;
    uint256 internal protocolFeePercent = 200;

    //Test Contracts
    TestUSD internal testUSD;
    GlobalParams internal globalParams;
    CampaignInfoFactory internal campaignInfoFactory;
    TreasuryFactory internal treasuryFactory;
    AllOrNothing internal allOrNothing;

    function setUp() public virtual { 

        // Create users for testing.
        users = Users({
            contractOwner: createUser("ContractOwner"),
            protocolAdminAddress: createUser("ProtocolAdminAddress"),
            platform1AdminAddress: createUser("Platform1AdminAddress"),
            platform2AdminAddress: createUser("Platform2AdminAddress"),
            creator1Address: createUser("Creator1Address"),
            creator2Address: createUser("Creator2Address")
        });

        // Deploy the base test contracts.
        testUSD = new TestUSD();
        globalParams = new GlobalParams(users.protocolAdminAddress, address(testUSD), protocolFeePercent);
        campaignInfoFactory = new CampaignInfoFactory(globalParams);
        bytes32 bytecodeHash = keccak256(type(CampaignInfo).creationCode);
        treasuryFactory = new TreasuryFactory(globalParams, address(campaignInfoFactory), bytecodeHash);

         // Label the base test contracts.
        vm.label({ account: address(testUSD), newLabel: "TestUSD" });
        vm.label({ account: address(globalParams), newLabel: "Global Parameter" });
        vm.label({ account: address(campaignInfoFactory), newLabel: "Campaign Info Factory" });
        vm.label({ account: address(treasuryFactory), newLabel: "Treasury Factory" });
    }

    /// @dev Generates a user, labels its address, and funds it with test assets.
    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({ account: user, newBalance: 100 ether });
        return user;
    }
}