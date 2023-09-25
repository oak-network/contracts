// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

contract ERC721Mock is ERC721 {
    string private constant _NAME = "TestNFT";
    string private constant _SYMBOL = "TNFT";

    constructor() ERC721(_NAME, _SYMBOL) {}
}

contract ERC721Test is Test {
    string private constant _NAME = "TestNFT";
    string private constant _SYMBOL = "TNFT";
    ERC721Mock erc721;

    function setUp() external {
        erc721 = new ERC721Mock();
    }

    function testInitialSetUP() external {
        assertEq(erc721.name(), _NAME);
        assertEq(erc721.symbol(), _SYMBOL);
    }

    function testSupportsInterfaceSuccess() public {
        assertTrue(erc721.supportsInterface(type(IERC721).interfaceId));
        assertTrue(erc721.supportsInterface(type(IERC721Metadata).interfaceId));
    }
}
