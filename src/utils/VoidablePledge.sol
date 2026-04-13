// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title VoidablePledge
 * @notice Abstract module that adds per-pledge void capability to treasury contracts.
 *
 * @dev Opt-in design: a treasury inherits this contract, implements the three hook
 *      functions, and calls `_recordPledgeFees` during fee calculation. It then
 *      implements its own public `voidPledge` function that calls `_prepareVoid` to
 *      mark the pledge as voided and retrieve amounts to reverse, then performs the
 *      treasury-specific accounting mutations and ERC20 transfers.
 *
 * Responsibilities of THIS module:
 *  - Void flag storage (`_voided`)
 *  - Per-pledge fee breakdown storage (`_pledgeProtocolFee`, `_pledgePlatformFee`)
 *  - Per-token voided amount accumulator (`s_tokenVoidedAmounts`)
 *  - `_recordPledgeFees` — called by the treasury during pledge fee calculation
 *  - `_prepareVoid`      — called by the treasury's public voidPledge; validates,
 *                          marks as voided, accumulates voided totals, and returns
 *                          a `VoidAmounts` struct with all amounts to reverse
 *  - `whenPledgeNotVoided` modifier
 *  - `isPledgeVoided` and `getVoidedAmountPerToken` view helpers
 *  - `PledgeVoided` event and void-related errors
 *
 * Responsibilities of the IMPLEMENTING treasury:
 *  - Implement `_getVoidablePledgeAmount`, `_getVoidablePledgeToken`, `_getVoidablePledgeTip`
 *  - Call `_recordPledgeFees` inside its fee calculation logic
 *  - Write a public `voidPledge` function that:
 *      1. Calls `_prepareVoid(tokenId)` to get `VoidAmounts`
 *      2. Reverses treasury-owned state (fee buckets, available amounts, raised amounts, etc.)
 *      3. Transfers recovered tokens to the platform admin
 *      4. Emits `PledgeVoided`
 *  - Add `whenPledgeNotVoided(tokenId)` modifier to `claimRefund`
 */
abstract contract VoidablePledge {

    // ── Storage ──────────────────────────────────────────────────────────────

    /// @dev Whether a pledge (by tokenId) has been voided.
    mapping(uint256 => bool) private _voided;

    /// @dev Protocol fee that was accrued for each pledge at pledge time.
    ///      Cleared after void so reversal logic is idempotent.
    mapping(uint256 => uint256) private _pledgeProtocolFee;

    /// @dev Platform fee (gross percentage + payment gateway) accrued for each pledge.
    ///      Cleared after void so reversal logic is idempotent.
    mapping(uint256 => uint256) private _pledgePlatformFee;

    /// @dev Cumulative voided pledge amount per token (raw token decimals).
    ///      Used by the treasury to keep `getRefundedAmount()` accurate — voided
    ///      pledges must not be counted as refunds.
    mapping(address => uint256) internal s_tokenVoidedAmounts;

    // ── Structs ──────────────────────────────────────────────────────────────

    /**
     * @dev All amounts that the implementing treasury needs to reverse when voiding
     *      a pledge. Returned by `_prepareVoid`.
     *
     * @param pledgeToken   The ERC20 token used for this pledge.
     * @param pledgeAmount  The original pledge amount (in token's native decimals).
     * @param protocolFee   Protocol fee accrued for this pledge.
     * @param platformFee   Platform fee (percentage + gateway) accrued for this pledge.
     * @param tip           Tip amount stored for this pledge (may be 0 if already forwarded).
     * @param totalFee      protocolFee + platformFee (convenience; equals s_tokenToPaymentFee[tokenId]).
     */
    struct VoidAmounts {
        address pledgeToken;
        uint256 pledgeAmount;
        uint256 protocolFee;
        uint256 platformFee;
        uint256 tip;
        uint256 totalFee;
    }

    // ── Events ───────────────────────────────────────────────────────────────

    /**
     * @dev Emitted when a pledge is successfully voided.
     * @param tokenId         The NFT token ID of the voided pledge.
     * @param pledgeToken     The ERC20 token used for the pledge.
     * @param recoveredAmount Total tokens recovered and sent to the platform admin.
     *                        May be less than the original pledge if funds were already
     *                        withdrawn or disbursed.
     * @param reason          An arbitrary bytes32 reason code for the void (e.g. hash of
     *                        "FRAUD", "DISPUTE_LOST").
     */
    event PledgeVoided(
        uint256 indexed tokenId,
        address indexed pledgeToken,
        uint256 recoveredAmount,
        bytes32 reason
    );

    // ── Errors ───────────────────────────────────────────────────────────────

    /// @dev Reverts when voidPledge is called on a tokenId that was already voided.
    error VoidablePledgeAlreadyVoided(uint256 tokenId);

    /// @dev Reverts when voidPledge is called on a tokenId that does not correspond
    ///      to an active pledge (zero amount — either nonexistent or already refunded).
    error VoidablePledgeNotFound(uint256 tokenId);

    // ── Modifier ─────────────────────────────────────────────────────────────

    /**
     * @dev Guards functions (e.g. claimRefund) that must not execute on voided pledges.
     */
    modifier whenPledgeNotVoided(uint256 tokenId) {
        if (_voided[tokenId]) {
            revert VoidablePledgeAlreadyVoided(tokenId);
        }
        _;
    }

    // ── Internal: called during pledge fee calculation ────────────────────────

    /**
     * @notice Records the per-pledge fee breakdown required for future void reversal.
     * @dev Must be called by the treasury inside its fee calculation function
     *      (e.g. `_calculateNetAvailable`) after computing protocol and platform fees.
     *      The sum `protocolFee + platformFee` should equal the total fee deducted from
     *      the pledge (i.e. the value stored in `s_tokenToPaymentFee[tokenId]`).
     *
     * @param tokenId      The NFT token ID for the pledge.
     * @param protocolFee  Protocol fee amount (in token's native decimals).
     * @param platformFee  Platform fee amount including payment gateway fee (in token's native decimals).
     */
    function _recordPledgeFees(uint256 tokenId, uint256 protocolFee, uint256 platformFee) internal {
        _pledgeProtocolFee[tokenId] = protocolFee;
        _pledgePlatformFee[tokenId] = platformFee;
    }

    // ── Internal: called at the start of the treasury's voidPledge ───────────

    /**
     * @notice Validates and marks a pledge as voided, returning all amounts the
     *         treasury needs to reverse.
     * @dev The implementing treasury MUST call this as the first step in its
     *      `voidPledge` function. After this call the pledge is irrevocably voided —
     *      the treasury must complete the accounting reversal in the same transaction.
     *
     *      This function:
     *       - Reverts if the pledge is already voided.
     *       - Reverts if the pledge amount is zero (nonexistent or already refunded).
     *       - Sets `_voided[tokenId] = true`.
     *       - Accumulates `s_tokenVoidedAmounts` for the pledge token.
     *       - Clears per-pledge fee storage (idempotency).
     *       - Returns a `VoidAmounts` struct for the treasury to act on.
     *
     * @param tokenId The NFT token ID to void.
     * @return amounts All amounts the treasury should reverse.
     */
    function _prepareVoid(uint256 tokenId) internal returns (VoidAmounts memory amounts) {
        if (_voided[tokenId]) {
            revert VoidablePledgeAlreadyVoided(tokenId);
        }

        uint256 pledgeAmount = _getVoidablePledgeAmount(tokenId);
        if (pledgeAmount == 0) {
            revert VoidablePledgeNotFound(tokenId);
        }

        _voided[tokenId] = true;

        amounts.pledgeToken  = _getVoidablePledgeToken(tokenId);
        amounts.pledgeAmount = pledgeAmount;
        amounts.protocolFee  = _pledgeProtocolFee[tokenId];
        amounts.platformFee  = _pledgePlatformFee[tokenId];
        amounts.tip          = _getVoidablePledgeTip(tokenId);
        amounts.totalFee     = amounts.protocolFee + amounts.platformFee;

        s_tokenVoidedAmounts[amounts.pledgeToken] += pledgeAmount;

        // Clear module-owned per-pledge storage
        delete _pledgeProtocolFee[tokenId];
        delete _pledgePlatformFee[tokenId];
    }

    // ── Hooks: implementing treasury must override ────────────────────────────

    /**
     * @dev Returns the pledge amount for the given tokenId in the token's native decimals.
     *      Must return 0 if the pledge does not exist or has already been refunded
     *      (so that `_prepareVoid` can detect invalid void attempts).
     */
    function _getVoidablePledgeAmount(uint256 tokenId) internal view virtual returns (uint256);

    /**
     * @dev Returns the ERC20 token address used for the given pledge.
     */
    function _getVoidablePledgeToken(uint256 tokenId) internal view virtual returns (address);

    /**
     * @dev Returns the tip amount stored for the given pledge (in token's native decimals).
     *      Should return 0 if the tip was already forwarded immediately during pledging.
     */
    function _getVoidablePledgeTip(uint256 tokenId) internal view virtual returns (uint256);

    // ── Views ─────────────────────────────────────────────────────────────────

    /**
     * @notice Returns whether a pledge has been voided.
     * @param tokenId The NFT token ID to check.
     * @return True if the pledge was voided, false otherwise.
     */
    function isPledgeVoided(uint256 tokenId) public view returns (bool) {
        return _voided[tokenId];
    }

    /**
     * @notice Returns the total amount of voided pledges for a specific token.
     * @param token The ERC20 token address.
     * @return The cumulative voided pledge amount in the token's native decimals.
     */
    function getVoidedAmountPerToken(address token) public view returns (uint256) {
        return s_tokenVoidedAmounts[token];
    }
}
