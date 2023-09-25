// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    string private constant _NAME = "TestToken";
    string private constant _SYMBOL = "TT";
    uint256 private constant _INITIAL_SUPPLY = type(uint8).max;

    constructor() ERC20(_NAME, _SYMBOL) {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}

contract ERC20Test is Test {
    string private constant _NAME = "TestToken";
    string private constant _SYMBOL = "TT";
    uint256 private constant _INITIAL_SUPPLY = type(uint8).max;
    address deployer = address(0x12);

    ERC20Mock erc20Contract;

    function setUp() external {
        vm.prank(deployer);
        erc20Contract = new ERC20Mock();
        erc20Contract.mint(deployer, _INITIAL_SUPPLY);
    }

    function testInitialSetUp() external {
        assertEq(erc20Contract.name(), _NAME);
        assertEq(erc20Contract.symbol(), _SYMBOL);
        assertEq(erc20Contract.decimals(), 18);
        assertEq(erc20Contract.totalSupply(), _INITIAL_SUPPLY);
        assertEq(erc20Contract.balanceOf(deployer), _INITIAL_SUPPLY);
    }
}
