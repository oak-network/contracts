// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721Burnable is ERC721Burnable {
    string private constant _NAME = "TestNFT";
    string private constant _SYMBOL = "TNFT";

    constructor() ERC721(_NAME, _SYMBOL) {}

    function safeMint(address to, uint256 tokenId) external {
        _safeMint(to, tokenId);
    }
}

contract ERC721BurnableTest is Test {
    address zeroAddress = address(0);
    uint256 nonce = 0;
    address deployer = makeAddr("deployer");
    MockERC721Burnable erc721Burnable;

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
        erc721Burnable = new MockERC721Burnable();
    }

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    function test_Burn() public {
        address owner = makeAddr("owner");
        uint256 tokenId1 = PRNG();
        vm.startPrank(deployer);
        erc721Burnable.safeMint(owner, tokenId1);
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, false);
        emit Transfer(owner, zeroAddress, tokenId1);
        erc721Burnable.burn(tokenId1);

        vm.expectRevert(bytes("ERC721: invalid token ID"));
        erc721Burnable.burn(tokenId1);
        vm.stopPrank();

        uint256 tokenId2 = PRNG();
        vm.expectRevert(bytes("ERC721: invalid token ID"));
        erc721Burnable.ownerOf(tokenId2);
        assertEq(erc721Burnable.balanceOf(owner), 0);
    }
}
