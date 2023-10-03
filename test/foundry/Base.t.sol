// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Users} from "./utils/Types.sol";
import {Defaults} from "./utils/Defaults.sol";
import {TestUSD} from "src/TestUSD.sol";
import {GlobalParams} from "src/GlobalParams.sol";
import {CampaignInfoFactory} from "src/CampaignInfoFactory.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {TreasuryFactory} from "src/TreasuryFactory.sol";

/// @notice Base test contract with common logic needed by all tests.
abstract contract Base_Test is Test, Defaults {

    //Variables
    Users internal users;

    //Test Contracts
    TestUSD internal testUSD;
    GlobalParams internal globalParams;
    CampaignInfoFactory internal campaignInfoFactory;
    TreasuryFactory internal treasuryFactory;

    function setUp() public virtual { 

        // Create users for testing.
        users = Users({
            contractOwner: createUser("ContractOwner"),
            protocolAdminAddress: createUser("ProtocolAdminAddress"),
            platform1AdminAddress: createUser("Platform1AdminAddress"),
            platform2AdminAddress: createUser("Platform2AdminAddress"),
            creator1Address: createUser("Creator1Address"),
            creator2Address: createUser("Creator2Address"),
            backer1Address: createUser("Backer1Address"),
            backer2Address: createUser("Backer2Address")
        });

        
        vm.startPrank(users.contractOwner);

        // Deploy the base test contracts.
        testUSD = new TestUSD();
        globalParams = new GlobalParams(users.protocolAdminAddress, address(testUSD), PROTOCOL_FEE_PERCENT);
        campaignInfoFactory = new CampaignInfoFactory(globalParams);
        bytes32 bytecodeHash = keccak256(type(CampaignInfo).creationCode);
        treasuryFactory = new TreasuryFactory(globalParams, address(campaignInfoFactory), bytecodeHash);

        //Initialize campaignInfoFactory
        campaignInfoFactory._initialize(address(treasuryFactory), address(globalParams));

        //Mint token to the backer
        testUSD.mint(users.backer1Address, TOKEN_MINT_AMOUNT);
        testUSD.mint(users.backer2Address, TOKEN_MINT_AMOUNT);

        vm.stopPrank();

         // Label the base test contracts.
        vm.label({ account: address(testUSD), newLabel: "TestUSD" });
        vm.label({ account: address(globalParams), newLabel: "Global Parameter" });
        vm.label({ account: address(campaignInfoFactory), newLabel: "Campaign Info Factory" });
        vm.label({ account: address(treasuryFactory), newLabel: "Treasury Factory" });

        // Warp to October 1, 2023 at 00:00 GMT to provide a more realistic testing environment.
        vm.warp(OCTOBER_1_2023);
    }

    /// @dev Generates a user, labels its address, and funds it with test assets.
    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({ account: user, newBalance: 100 ether });
        return user;
    }
}