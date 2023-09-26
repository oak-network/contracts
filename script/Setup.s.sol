// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/TestUSD.sol";
import "../src/GlobalParams.sol";
import "../src/CampaignInfoFactory.sol";
import "../src/TreasuryFactory.sol";

contract SetupScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address account = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        TestUSD testUSD = new TestUSD();
        GlobalParams globalParams = new GlobalParams(account, address(testUSD), 200);
        CampaignInfoFactory campaignInfoFactory = new CampaignInfoFactory(globalParams);
        bytes32 bytecodeHash = keccak256(type(CampaignInfo).creationCode);
        TreasuryFactory treasuryFactory = new TreasuryFactory(globalParams, address(campaignInfoFactory), bytecodeHash);

        vm.stopBroadcast();
    }
}
