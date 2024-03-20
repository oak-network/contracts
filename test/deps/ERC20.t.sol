// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
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
    address zeroAddress = address(0x0);

    MockERC20 erc20Contract;

    function setUp() external {
        vm.prank(deployer);
        erc20Contract = new MockERC20();
        erc20Contract.mint(deployer, _INITIAL_SUPPLY);
    }

    function test_InitialSetUp() external {
        assertEq(erc20Contract.name(), _NAME);
        assertEq(erc20Contract.symbol(), _SYMBOL);
        assertEq(erc20Contract.decimals(), 18);
        assertEq(erc20Contract.totalSupply(), _INITIAL_SUPPLY);
        assertEq(erc20Contract.balanceOf(deployer), _INITIAL_SUPPLY);
    }

    event Transfer(address indexed from, address indexed to, uint256 value);

    function test_Transfer() external {
        address owner = deployer;
        address to = makeAddr("to");
        uint256 amount = erc20Contract.balanceOf(owner);
        vm.startPrank(owner);
        vm.expectEmit(true, true, false, true);
        emit Transfer(owner, to, amount);
        bool returnValue = erc20Contract.transfer(to, amount);
        assertTrue(returnValue);
        assertEq(erc20Contract.balanceOf(owner), 0);
        assertEq(erc20Contract.balanceOf(to), amount);
        vm.stopPrank();
    }

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function test_Approve() external {
        address owner = deployer;
        address spender = makeAddr("spender");
        uint256 amount = erc20Contract.balanceOf(owner);
        vm.startPrank(owner);
        vm.expectEmit(true, true, false, true);
        emit Approval(owner, spender, amount);
        bool returnValue = erc20Contract.approve(spender, amount);
        assertTrue(returnValue);
        assertEq(erc20Contract.allowance(owner, spender), amount);
        vm.stopPrank();
    }

    function test_TransferFrom() external {
        address owner = deployer;
        address spender = makeAddr("spender");
        address to = makeAddr("to");
        uint256 amount = erc20Contract.balanceOf(owner);
        vm.prank(owner);
        erc20Contract.approve(spender, amount);
        vm.startPrank(spender);
        vm.expectEmit(true, true, false, true);
        emit Approval(
            owner,
            spender,
            erc20Contract.allowance(owner, spender) - amount
        );
        vm.expectEmit(true, true, false, true);
        emit Transfer(owner, to, amount);
        bool returnValue = erc20Contract.transferFrom(owner, to, amount);
        assertTrue(returnValue);
        assertEq(erc20Contract.balanceOf(owner), 0);
        assertEq(erc20Contract.balanceOf(to), amount);
        assertEq(erc20Contract.allowance(owner, spender), 0);
        vm.stopPrank();
    }

    function test_Burn() external {
        address owner = deployer;
        uint256 balance = erc20Contract.balanceOf(owner);
        uint256 totalSupply = erc20Contract.totalSupply();
        uint256 amount = 0;
        vm.startPrank(owner);
        vm.expectEmit(true, true, false, true);
        emit Transfer(owner, zeroAddress, amount);
        erc20Contract.burn(owner, amount);
        assertEq(erc20Contract.balanceOf(owner), balance - amount);
        assertEq(erc20Contract.totalSupply(), totalSupply - amount);
        vm.stopPrank();
    }

    function test_Mint() external {
        address minter = deployer;
        address owner = makeAddr("owner");
        uint256 amount = type(uint8).max;
        vm.startPrank(minter);
        vm.expectEmit(true, true, false, true);
        emit Transfer(zeroAddress, owner, amount);
        erc20Contract.mint(owner, amount);
        assertEq(erc20Contract.balanceOf(owner), amount);
        assertEq(erc20Contract.totalSupply(), (amount + _INITIAL_SUPPLY));
        vm.stopPrank();
    }
}
