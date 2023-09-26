// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ERC721BurnableMock is ERC721Burnable {
    string private constant _NAME = "TestNFT";
    string private constant _SYMBOL = "TNFT";

    constructor() ERC721(_NAME, _SYMBOL) {}
}
