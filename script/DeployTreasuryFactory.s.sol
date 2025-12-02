// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {TreasuryFactory} from "../src/TreasuryFactory.sol";
import {GlobalParams} from "../src/GlobalParams.sol";
import {IGlobalParams} from "../src/interfaces/IGlobalParams.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DeployBase} from "./lib/DeployBase.s.sol";

contract DeployTreasuryFactory is DeployBase {
    function deploy(address _globalParams) public returns (address) {
        require(_globalParams != address(0), "GlobalParams not set");

        // Deploy implementation
        TreasuryFactory implementation = new TreasuryFactory();

        // Prepare initialization data
        bytes memory initData =
            abi.encodeWithSelector(TreasuryFactory.initialize.selector, IGlobalParams(_globalParams));

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        return address(proxy);
    }

    function run() external {
        address globalParams = vm.envOr("GLOBAL_PARAMS_ADDRESS", address(0));
        require(globalParams != address(0), "GlobalParams must be set");

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        deploy(globalParams);
        vm.stopBroadcast();
    }
}
