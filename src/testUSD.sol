// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestUSD is ERC20, ERC20Permit, Ownable {
    constructor() ERC20("testUSD", "tUSD") ERC20Permit("testUSD") {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}