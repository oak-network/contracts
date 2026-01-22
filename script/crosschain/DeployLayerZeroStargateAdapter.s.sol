// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {console2} from "forge-std/console2.sol";

import {LayerZeroStargateAdapter} from "src/crosschain/bridges/LayerZeroStargateAdapter.sol";
import {IGlobalParams} from "src/interfaces/IGlobalParams.sol";
import {CrossChainDeployBase} from "./lib/CrossChainDeployBase.s.sol";

contract DeployLayerZeroStargateAdapter is CrossChainDeployBase {
    function deploy(address endpoint, address globalParams) public returns (address) {
        console2.log("Deploying LayerZeroStargateAdapter...");
        LayerZeroStargateAdapter adapter = new LayerZeroStargateAdapter(endpoint, IGlobalParams(globalParams));
        console2.log("LayerZeroStargateAdapter deployed at:", address(adapter));
        return address(adapter);
    }

    function run() external {
        (Mode mode, string memory modeLabel) = _loadMode();
        ChainConfig memory config = _loadChainConfig(mode);

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        bool simulate = vm.envOr("SIMULATE", false);
        address globalParams = vm.envAddress("GLOBAL_PARAMS_ADDRESS");
        require(globalParams != address(0), "GLOBAL_PARAMS_ADDRESS required");

        _requireChainId(config.destinationChainId, "DESTINATION");

        if (!simulate) {
            vm.startBroadcast(deployerKey);
        }

        address adapter = deploy(config.destinationLzEndpoint, globalParams);

        if (!simulate) {
            vm.stopBroadcast();
        }

        console2.log("MODE:", modeLabel);
        console2.log("LAYERZERO_STARGATE_ADAPTER_ADDRESS", adapter);
    }
}
