// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TestUSD
 * @notice A test token `tUSD` which is used in the tests.
 */
contract TestUSD is ERC20, Ownable {
    constructor() ERC20("testUSD", "tUSD") Ownable(msg.sender) {}

    /**
     * @notice Mints testUSD token.
     * @param to The token receivers address.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
