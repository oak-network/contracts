// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

contract MockContext is Context {
    function msgSender() external view returns (address) {
        return _msgSender();
    }

    function msgData() external view virtual returns (bytes calldata) {
        return _msgData();
    }
}
