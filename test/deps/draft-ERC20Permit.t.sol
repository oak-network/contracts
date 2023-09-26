// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract MockERC20Permit is ERC20Permit {
    string private constant _NAME = "TestToken";
    string private constant _SYMBOL = "TT";
    uint256 private constant _INITIAL_SUPPLY = type(uint8).max;

    constructor() ERC20(_NAME, _SYMBOL) ERC20Permit(_NAME) {}
}

contract ERC20PermitTest is Test {
    MockERC20Permit erc20Permit;
    bytes32 private constant _PERMIT_TYPE_HASH =
        keccak256(
            bytes(
                "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
            )
        );
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function setUp() external {
        erc20Permit = new MockERC20Permit();
    }

    function testPermitSuccess() public {
        (address owner, uint256 key) = makeAddrAndKey("owner");
        address spender = makeAddr("spender");
        uint256 amount = 100;
        uint256 nonce = erc20Permit.nonces(owner);
        uint256 deadline = block.timestamp + 100_000;
        bytes32 domainSeparator = erc20Permit.DOMAIN_SEPARATOR();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            key,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    domainSeparator,
                    keccak256(
                        abi.encode(
                            _PERMIT_TYPE_HASH,
                            owner,
                            spender,
                            amount,
                            nonce,
                            deadline
                        )
                    )
                )
            )
        );
        vm.expectEmit(true, true, false, true);
        emit Approval(owner, spender, amount);
        erc20Permit.permit(owner, spender, amount, deadline, v, r, s);
        assertEq(erc20Permit.allowance(owner, spender), amount);
        assertEq(erc20Permit.nonces(owner), 1);
    }
}
