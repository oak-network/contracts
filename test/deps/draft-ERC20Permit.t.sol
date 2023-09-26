// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract MockERC20Permit is ERC20Permit {
    string private constant _NAME = "TestToken";
    string private constant _SYMBOL = "TT";
    uint256 private constant _INITIAL_SUPPLY = type(uint8).max;

    constructor() ERC20(_NAME, _SYMBOL) ERC20Permit(_NAME) {}
}
