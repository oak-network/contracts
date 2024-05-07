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


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

interface IFactory {
    function addByteCodeChunk(bytes calldata chunk) external;
    function deployContract() external returns (address);
}

contract DeployWithFactoryScript is Script {
    // Address of the factory contract
    address factoryAddress = 0x1234567890abcdef1234567890abcdef12345678;

    function run() external {
        // Read the bytecode from the artifacts folder
        bytes memory bytecode = vm.readFile("out/YourContract.sol/YourContract.json");

        // Assuming the factory expects the bytecode in chunks of 32 bytes each
        uint256 chunkSize = 32;
        uint256 bytecodeLength = bytecode.length;

        IFactory factory = IFactory(factoryAddress);

        for (uint256 i = 0; i < bytecodeLength; i += chunkSize) {
            uint256 end = i + chunkSize < bytecodeLength ? i + chunkSize : bytecodeLength;
            bytes memory chunk = bytecode[i:end];
            factory.addByteCodeChunk(chunk);
        }

        // Deploy the contract from the factory
        address deployedAddress = factory.deployContract();

        // Log the address of the deployed contract
        console.log("Deployed contract at:", deployedAddress);
    }
}
