// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {console2} from "forge-std/console2.sol";

import {IntentSender} from "src/crosschain/IntentSender.sol";
import {CrossChainDeployBase} from "./lib/CrossChainDeployBase.s.sol";

contract DeployIntentSender is CrossChainDeployBase {
    function deploy(
        address agent,
        address ccipRouter,
        uint64 destinationSelector,
        address ccipDestinationAdapter,
        uint32 destinationEid,
        address lzDestinationAdapter
    ) public returns (address) {
        console2.log("Deploying IntentSender...");
        IntentSender sender = new IntentSender(
            agent, ccipRouter, destinationSelector, ccipDestinationAdapter, destinationEid, lzDestinationAdapter
        );
        console2.log("IntentSender deployed at:", address(sender));
        return address(sender);
    }

    function run() external {
        (Mode mode, string memory modeLabel) = _loadMode();
        ChainConfig memory config = _loadChainConfig(mode);

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        bool simulate = vm.envOr("SIMULATE", false);

        address agent = vm.envAddress("AGENT_ADDRESS");
        address ccipDestinationAdapter = vm.envAddress("CCIP_DESTINATION_ADAPTER_ADDRESS");
        address lzDestinationAdapter = vm.envAddress("LZ_DESTINATION_ADAPTER_ADDRESS");

        require(agent != address(0), "AGENT_ADDRESS required");
        require(ccipDestinationAdapter != address(0), "CCIP_DESTINATION_ADAPTER_ADDRESS required");
        require(lzDestinationAdapter != address(0), "LZ_DESTINATION_ADAPTER_ADDRESS required");

        _requireChainId(config.sourceChainId, "SOURCE");

        if (!simulate) {
            vm.startBroadcast(deployerKey);
        }

        address intentSender = deploy(
            agent,
            config.sourceCcipRouter,
            config.destinationCcipSelector,
            ccipDestinationAdapter,
            config.destinationLzEid,
            lzDestinationAdapter
        );

        if (!simulate) {
            vm.stopBroadcast();
        }

        console2.log("MODE:", modeLabel);
        console2.log("INTENT_SENDER_ADDRESS", intentSender);
    }
}
