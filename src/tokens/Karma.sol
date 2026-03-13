// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {IKarmaTreasury} from "../interfaces/IKarmaTreasury.sol";

/**
 * @title KARMA — Soulbound points token
 * @notice Non-transferable ERC-20 that tracks investment amounts.
 * @dev Minted 1:1 by the treasury on deposit; burned on future token conversion.
 */
contract KARMA is ERC20, ERC20Burnable, ERC20Pausable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 private constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Divisor for fee percentage calculations (basis points: 10000 = 100%).
    uint256 public constant PERCENT_DIVIDER = 10000;

    /**
    * @notice Treasury used to read raised amount for claimTokens (e.g. PaymentTreasury).
    * @dev This is the address of the contract that implements the IKarmaTreasury interface.
    */
    address public treasury;

    /**
    * @notice Protocol fee percentage in basis points (e.g. 250 = 2.5%).
    * @dev Deducted from the delta in claimTokens before minting.
    */
    uint256 public protocolFeePercent;

    /**
    * @notice Total KARMA minted so far against treasury raised amount (for incremental claiming).
    * @dev This is the total amount of KARMA minted so far against the treasury raised amount.
    */
    uint256 private _totalMintedAgainstRaised;

     /**
     * @notice Emitted when the treasury address is set or updated.
     * @param previousTreasury The previous treasury address (zero if first set).
     * @param newTreasury The new treasury address.
     */
    event TreasurySet(address indexed previousTreasury, address indexed newTreasury);

    /**
     * @notice Emitted when tokens are claimed via claimTokens().
     * @param to The recipient of the minted tokens.
     * @param amount The amount of KARMA minted (net of protocol fee).
     */
    event TokensClaimed(address indexed to, uint256 amount);

    /**
     * @notice Emitted when the protocol fee percentage is updated.
     * @param previousFeePercent The previous fee percentage.
     * @param newFeePercent The new fee percentage.
     */
    event ProtocolFeePercentSet(uint256 previousFeePercent, uint256 newFeePercent);

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
     * @dev Thrown when claimTokens is called without a treasury set.
     */
    error KarmaTreasuryNotSet();

    /**
     * @dev Thrown when claimTokens is called and there is nothing to claim.
     */
    error KarmaNothingToClaim();

    /**
     * @dev Thrown when the protocol fee percentage exceeds PERCENT_DIVIDER (100%).
     */
    error KarmaInvalidFeePercent();

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
     * @notice Set the treasury used for claimTokens (e.g. PaymentTreasury). Callable by admin only.
     * @param _treasury Address of a contract that implements getRaisedAmount().
     */
    function setTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        address previousTreasury = treasury;
        treasury = _treasury;
        emit TreasurySet(previousTreasury, _treasury);
    }

    /**
     * @notice Set the protocol fee percentage (in basis points). Callable by admin only.
     * @param _protocolFeePercent Fee in basis points (e.g. 250 = 2.5%). Must be < PERCENT_DIVIDER.
     */
    function setProtocolFeePercent(uint256 _protocolFeePercent) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_protocolFeePercent >= PERCENT_DIVIDER) {
            revert KarmaInvalidFeePercent();
        }
        uint256 previousFeePercent = protocolFeePercent;
        protocolFeePercent = _protocolFeePercent;
        emit ProtocolFeePercentSet(previousFeePercent, _protocolFeePercent);
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
     * @notice Claim KARMA up to the treasury's current raised amount, minus what was already minted,
     *         minus the protocol fee.
     *         Callable multiple times: each call mints only the net delta (new raised since last claim, minus fee).
     * @param to Recipient of the minted tokens.
     * @dev Example with 2.5% fee: raised 300, claimTokens → mints 300 - 7.5 = 292.5.
     *      Then raised to 500, claimTokens → mints (500-300) - 5 = 195.
     */
    function claimTokens(address to) external onlyRole(MINTER_ROLE) whenNotPaused {
        if (treasury == address(0)) {
            revert KarmaTreasuryNotSet();
        }
        if (to == address(0)) {
            revert KarmaInvalidMintInput();
        }

        uint256 totalRaised = IKarmaTreasury(treasury).getRaisedAmount();
        uint256 delta = totalRaised > _totalMintedAgainstRaised ? totalRaised - _totalMintedAgainstRaised : 0;
        if (delta == 0) {
            revert KarmaNothingToClaim();
        }

        _totalMintedAgainstRaised = totalRaised;
        uint256 fee = (delta * protocolFeePercent) / PERCENT_DIVIDER;
        uint256 netDelta = delta - fee;
        
        _mint(to, netDelta);
        emit TokensClaimed(to, netDelta);
    }

    /**
     * @notice Returns the total KARMA already minted via claimTokens (raised amount covered so far).
     */
    function totalMintedAgainstRaised() external view returns (uint256) {
        return _totalMintedAgainstRaised;
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
