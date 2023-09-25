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

    function safe_mint(address to, uint256 tokenId) external {
        _safeMint(to, tokenId);
    }
}

contract ERC721Test is Test {
    string private constant _NAME = "TestNFT";
    string private constant _SYMBOL = "TNFT";
    ERC721Mock erc721;
    address deployer = makeAddr("deployer");
    address zeroAddress = address(0);

    uint256 nonce = 0;

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

    function testBalanceOf() public {
        address owner = makeAddr("owner");
        uint256 tokenId1 = PRNG();
        uint256 tokenId2 = PRNG();
        vm.startPrank(deployer);
        erc721.safe_mint(owner, tokenId1);
        erc721.safe_mint(owner, tokenId2);
        assertEq(erc721.balanceOf(owner), 2);
        vm.stopPrank();
    }

    function testOwnerOf() public {
        uint256 tokenId1 = PRNG();
        vm.expectRevert("ERC721: invalid token ID");
        erc721.ownerOf(tokenId1);

        vm.prank(deployer);
        uint256 tokenId2 = PRNG();
        address owner = makeAddr("owner");
        erc721.safe_mint(owner, tokenId2);
        assertEq(erc721.ownerOf(tokenId2), owner);
    }

    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );

    function testApprove() public {
        address owner = makeAddr("owner");
        address spender = makeAddr("spender");
        uint256 tokenId = PRNG();
        vm.startPrank(deployer);
        erc721.safe_mint(owner, tokenId);
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, false);
        emit Approval(owner, spender, tokenId);
        erc721.approve(spender, tokenId);
        assertEq(erc721.getApproved(tokenId), spender);
        vm.stopPrank();
    }

    function testTransferFrom() public {
        address owner = makeAddr("owner");
        address approved = makeAddr("approved");
        address operator = makeAddr("operator");
        uint256 tokenId1 = PRNG();
        uint256 tokenId2 = PRNG();
        vm.startPrank(deployer);
        erc721.safe_mint(owner, tokenId1);
        erc721.safe_mint(owner, tokenId2);
        vm.stopPrank();

        vm.startPrank(owner);
        erc721.approve(approved, tokenId1);
        erc721.setApprovalForAll(operator, true);
        vm.stopPrank();

        address receiver = makeAddr("receiver");
        vm.startPrank(approved);
        erc721.transferFrom(owner, receiver, tokenId1);
        assertEq(erc721.ownerOf(tokenId1), receiver);
        vm.stopPrank();

        vm.startPrank(operator);
        erc721.transferFrom(owner, receiver, tokenId2);
        assertEq(erc721.ownerOf(tokenId2), receiver);
        vm.stopPrank();

        vm.expectRevert("ERC721: caller is not token owner or approved");
        erc721.transferFrom(receiver, address(0x1), tokenId1);
    }
}
