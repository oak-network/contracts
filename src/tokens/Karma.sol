// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

/**
 * @title KARMA — Soulbound points token
 * @notice Non-transferable ERC-20 that tracks investment amounts.
 * @dev Minted 1:1 by the treasury on deposit; burned on future token conversion.
 */
contract KARMA is ERC20, ERC20Burnable, ERC20Pausable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 private constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /**
     * @dev Thrown when a holder attempts a wallet-to-wallet transfer.
     */
    error KarmaSoulboundTransferNotAllowed();

    /**
     * @dev Thrown when the admin address is invalid.
     */
    error KarmaInvalidAdmin();

    /**
     * @dev Thrown when the mint address is == address(0) or amount is 0.
     */
    error KarmaInvalidMintInput();

    /**
     * @notice Constructor for the Karma contract.
     * @param admin The address of the admin.
     */
    constructor(address admin) ERC20("KARMA", "KARMA") AccessControl() {
        if (admin == address(0)) {
            revert KarmaInvalidAdmin();
        }
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    /**
     * @notice Mint points. Callable by treasury or any address with MINTER_ROLE.
     * @param to The address to mint points to.
     * @param amount The amount of points to mint.
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        if (to == address(0) || amount == 0) {
            revert KarmaInvalidMintInput();
        }
        _mint(to, amount);
    }

    /**
     * @notice Pause the Karma contract.
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the Karma contract.
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Soulbound enforcement + pausable hook.
     * @param from The address from which the points are being transferred.
     * @param to The address to which the points are being transferred.
     * @param value The amount of points being transferred.
     * @dev Only mint (from == address(0)) and burn (to == address(0)) are allowed.
     */
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Pausable) {
        if (from != address(0) && to != address(0)) {
            revert KarmaSoulboundTransferNotAllowed();
        }
        super._update(from, to, value);
    }
}
