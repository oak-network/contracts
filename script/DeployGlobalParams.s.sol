// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {GlobalParams} from "../src/GlobalParams.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DeployBase} from "./lib/DeployBase.s.sol";

contract DeployGlobalParams is DeployBase {
    function deployWithToken(address token) public returns (address) {
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));

        (bytes32[] memory currencies, address[][] memory tokensPerCurrency) = loadCurrenciesAndTokens(token);

        // Deploy implementation
        GlobalParams implementation = new GlobalParams();

        // Prepare initialization data
        bytes memory initData =
            abi.encodeWithSelector(GlobalParams.initialize.selector, deployer, 200, currencies, tokensPerCurrency);

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        return address(proxy);
    }

    function deploy() public returns (address) {
        return deployOrUse("GLOBAL_PARAMS_ADDRESS", _deploy);
    }

    function _deploy() internal returns (address) {
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        address token = vm.envOr("TOKEN_ADDRESS", address(0));
        require(token != address(0), "TestToken address must be set");

        (bytes32[] memory currencies, address[][] memory tokensPerCurrency) = loadCurrenciesAndTokens(token);

        // Deploy implementation
        GlobalParams implementation = new GlobalParams();

        // Prepare initialization data
        bytes memory initData =
            abi.encodeWithSelector(GlobalParams.initialize.selector, deployer, 200, currencies, tokensPerCurrency);

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        return address(proxy);
    }

    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        deploy();
        vm.stopBroadcast();
    }
}
