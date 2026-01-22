// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {console2} from "forge-std/console2.sol";

import {ChainlinkCCIPAdapter} from "src/crosschain/bridges/ChainlinkCCIPAdapter.sol";
import {LayerZeroStargateAdapter} from "src/crosschain/bridges/LayerZeroStargateAdapter.sol";
import {CrossChainExecutor} from "src/crosschain/CrossChainExecutor.sol";
import {IntentSender} from "src/crosschain/IntentSender.sol";
import {IGlobalParams} from "src/interfaces/IGlobalParams.sol";
import {CrossChainDeployBase} from "./lib/CrossChainDeployBase.s.sol";

contract DeployAllAndSetupExecutor is CrossChainDeployBase {
    bytes32 internal constant BRIDGE_ID_CCIP =
        0x5fa42365004d29017b6e1fff462c90ecf163a6f09987e7af7e4b8c324fc7cc5f;
    bytes32 internal constant BRIDGE_ID_LAYERZERO =
        0xe34d309d2a3947d08baad60196a07f69352ed61cce4b781f48c19141173b2894;

    bytes4 internal constant SELECTOR_0 = 0xf1d2ae6a;
    bytes4 internal constant SELECTOR_1 = 0x44019d1e;
    bytes4 internal constant SELECTOR_2 = 0x80b213af;
    bytes4 internal constant SELECTOR_3 = 0xa3d19199;
    bytes4 internal constant SELECTOR_4 = 0xc13f3393;

    string internal constant DESTINATION_NETWORK = "ETH";

    bool internal simulate;
    Mode internal mode;
    string internal modeLabel;
    ChainConfig internal config;
    string internal sourceNetwork;

    address internal globalParams;
    address internal agent;

    address internal crossChainExecutor;
    address internal ccipAdapter;
    address internal lzAdapter;
    address internal intentSender;

    string internal destinationRpcUrl;
    string internal sourceRpcUrl;
    uint256 internal destinationFork;
    uint256 internal sourceFork;

    function run() external {
        _loadParams();

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        destinationFork = vm.createFork(destinationRpcUrl);
        sourceFork = vm.createFork(sourceRpcUrl);

        _deployDestination(deployerKey);
        _deploySource(deployerKey);
        _setupExecutor(deployerKey);

        _printSummary();
    }

    function _loadParams() internal {
        simulate = vm.envOr("SIMULATE", false);
        (mode, modeLabel) = _loadMode();
        config = _loadChainConfig(mode);

        string[] memory networks = _parseSourceNetworks();
        _requireArbitrumOnly(networks);
        sourceNetwork = networks[0];

        globalParams = vm.envAddress("GLOBAL_PARAMS_ADDRESS");
        agent = vm.envAddress("AGENT_ADDRESS");
        require(globalParams != address(0), "GLOBAL_PARAMS_ADDRESS required");
        require(agent != address(0), "AGENT_ADDRESS required");

        destinationRpcUrl = vm.envString("DEST_RPC_URL");
        sourceRpcUrl = vm.envString("SOURCE_RPC_URL");
    }

    function _deployDestination(uint256 deployerKey) internal {
        vm.selectFork(destinationFork);
        _requireChainId(config.destinationChainId, "DESTINATION");

        if (!simulate) {
            vm.startBroadcast(deployerKey);
        }

        console2.log("Deploying destination contracts...");
        crossChainExecutor = address(new CrossChainExecutor(agent));
        ccipAdapter = address(new ChainlinkCCIPAdapter(config.destinationCcipRouter, IGlobalParams(globalParams)));
        lzAdapter = address(new LayerZeroStargateAdapter(config.destinationLzEndpoint, IGlobalParams(globalParams)));

        if (!simulate) {
            vm.stopBroadcast();
        }

        console2.log("CrossChainExecutor:", crossChainExecutor);
        console2.log("ChainlinkCCIPAdapter:", ccipAdapter);
        console2.log("LayerZeroStargateAdapter:", lzAdapter);
    }

    function _deploySource(uint256 deployerKey) internal {
        vm.selectFork(sourceFork);
        _requireChainId(config.sourceChainId, "SOURCE");

        if (!simulate) {
            vm.startBroadcast(deployerKey);
        }

        console2.log("Deploying source contracts...");
        intentSender = address(
            new IntentSender(
                agent,
                config.sourceCcipRouter,
                config.destinationCcipSelector,
                ccipAdapter,
                config.destinationLzEid,
                lzAdapter
            )
        );

        if (!simulate) {
            vm.stopBroadcast();
        }

        console2.log("IntentSender:", intentSender);
    }

    function _setupExecutor(uint256 deployerKey) internal {
        vm.selectFork(destinationFork);
        _requireChainId(config.destinationChainId, "DESTINATION");

        if (!simulate) {
            vm.startBroadcast(deployerKey);
        }

        console2.log("Configuring CrossChainExecutor...");
        CrossChainExecutor executor = CrossChainExecutor(crossChainExecutor);

        bytes32[] memory bridgeIds = new bytes32[](2);
        address[] memory adapters = new address[](2);
        bridgeIds[0] = BRIDGE_ID_CCIP;
        adapters[0] = ccipAdapter;
        bridgeIds[1] = BRIDGE_ID_LAYERZERO;
        adapters[1] = lzAdapter;
        executor.setBridgeAdapters(bridgeIds, adapters);

        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = config.sourceChainId;

        uint64[] memory selectors = new uint64[](1);
        selectors[0] = config.sourceCcipSelector;
        executor.setCcipChainSelectors(chainIds, selectors);

        uint32[] memory eids = new uint32[](1);
        eids[0] = config.sourceLzEid;
        executor.setLayerZeroEids(chainIds, eids);

        executor.setIntentSender(config.sourceChainId, intentSender);

        executor.setSelector(SELECTOR_0, true);
        executor.setSelector(SELECTOR_1, true);
        executor.setSelector(SELECTOR_2, true);
        executor.setSelector(SELECTOR_3, true);
        executor.setSelector(SELECTOR_4, true);

        if (!simulate) {
            vm.stopBroadcast();
        }

        console2.log("CrossChainExecutor configured");
    }

    function _printSummary() internal view {
        console2.log("\n===========================================");
        console2.log("Crosschain Deployment Summary");
        console2.log("===========================================");
        console2.log("MODE:", modeLabel);
        console2.log("Destination Network:", DESTINATION_NETWORK);
        console2.log("Source Network:", sourceNetwork);
        console2.log("Destination ChainId:", config.destinationChainId);
        console2.log("Source ChainId:", config.sourceChainId);
        console2.log("GLOBAL_PARAMS_ADDRESS:", globalParams);
        console2.log("AGENT_ADDRESS:", agent);

        console2.log("\n--- Destination (Ethereum) ---");
        console2.log("CROSS_CHAIN_EXECUTOR:", crossChainExecutor);
        console2.log("CHAINLINK_CCIP_ADAPTER:", ccipAdapter);
        console2.log("LAYERZERO_STARGATE_ADAPTER:", lzAdapter);
        console2.log("CCIP_ROUTER:", config.destinationCcipRouter);
        console2.log("LZ_ENDPOINT:", config.destinationLzEndpoint);

        console2.log("\n--- Source (Arbitrum) ---");
        console2.log("INTENT_SENDER:", intentSender);
        console2.log("SOURCE_CCIP_ROUTER:", config.sourceCcipRouter);
        console2.log("DESTINATION_CCIP_SELECTOR:", config.destinationCcipSelector);
        console2.log("DESTINATION_LZ_EID:", config.destinationLzEid);

        console2.log("\n--- Executor Setup ---");
        console2.log("Registered IntentSender chainId:", config.sourceChainId);
        console2.log("Source CCIP selector:", config.sourceCcipSelector);
        console2.log("Source LZ eid:", config.sourceLzEid);
        console2.log("Allowed selectors:");
        console2.logBytes4(SELECTOR_0);
        console2.logBytes4(SELECTOR_1);
        console2.logBytes4(SELECTOR_2);
        console2.logBytes4(SELECTOR_3);
        console2.logBytes4(SELECTOR_4);

        console2.log("\n===========================================");
        console2.log("Deployment and setup completed successfully!");
        console2.log("===========================================");
    }
}
