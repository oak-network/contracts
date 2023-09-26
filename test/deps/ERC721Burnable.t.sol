// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ERC721BurnableMock is ERC721Burnable {
    string private constant _NAME = "TestNFT";
    string private constant _SYMBOL = "TNFT";

    constructor() ERC721(_NAME, _SYMBOL) {}

    function safe_mint(address to, uint256 tokenId) external {
        _safeMint(to, tokenId);
    }
}

contract ERC721BurnableTest is Test {
    address zeroAddress = address(0);
    uint256 nonce = 0;
    address deployer = makeAddr("deployer");
    ERC721BurnableMock erc721Burnable;

    function PRNG() internal returns (uint256) {
        nonce += 1;
        return
            uint(
                keccak256(
                    abi.encodePacked(
                        nonce,
                        msg.sender,
                        blockhash(block.number - 1)
                    )
                )
            );
    }

    function setUp() external {
        erc721Burnable = new ERC721BurnableMock();
    }
}
