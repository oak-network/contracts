// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title TestToken
 * @notice A test token `tUSD` which is used in the tests.
 */
contract TestToken is ERC20, Ownable {
    uint8 private _decimals;

    constructor(string memory _name, string memory _symbol, uint8 decimals_)
        ERC20(_name, _symbol)
        Ownable(msg.sender)
    {
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @notice Mints testToken token.
     * @param to The token receivers address.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
