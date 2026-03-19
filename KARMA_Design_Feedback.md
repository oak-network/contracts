# KARMA Token — Design Feedback

Three suggestions. Each one addresses a concrete problem with a clear fix.

---

## 1. Use lifetime raised, not current raised

`claimTokens()` reads `getRaisedAmount()`, which **decreases on refunds** (`s_confirmedPaymentPerToken` is reduced in `claimRefund`). The watermark `_totalMintedAgainstRaised` only goes up. A refund after a claim creates a permanent gap: future deposits must first fill the hole before any new KARMA is minted.

Example: raised 300K → claim 300K KARMA → refund 100K → raised drops to 200K → next 100K of deposits produces zero KARMA.

**Fix:** Read `getLifetimeRaisedAmount()` instead. It uses `s_lifetimeConfirmedPaymentPerToken` which never decreases. Both sides of the delta become monotonically increasing, so the accounting is always consistent. Refund-driven point reduction can be handled off-chain or via explicit admin burn — which is the right layer for that decision.

---

## 2. Make the contract upgradeable

Every other contract in the protocol uses proxies (`Initializable` + factory). KARMA uses a plain constructor. The $OAK conversion mechanism is explicitly on the roadmap and will require new logic on this contract (conversion ratio, burn-for-claim, interaction with an OAK minter). Without upgradeability, that means deploying a new contract and migrating all balances — which is especially painful for a soulbound token since you can't transfer, only re-mint.

**Fix:** Switch to `ERC20Upgradeable` + `AccessControlUpgradeable` + `ERC20PausableUpgradeable` + `ERC20BurnableUpgradeable` with an `initialize()` function. The OpenZeppelin upgradeable variants are already in the project's dependencies.

---

## 3. Reset the watermark on treasury change

`setTreasury()` swaps the source but `_totalMintedAgainstRaised` carries over. If the new treasury has a lower lifetime raised, `claimTokens()` silently blocks until it catches up. If higher, it mints a delta that has nothing to do with this platform's actual activity.

**Fix:** Snapshot the new treasury's current value when switching:

```solidity
function setTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
    address previousTreasury = treasury;
    treasury = _treasury;
    if (_treasury != address(0)) {
        _totalMintedAgainstRaised = IKarmaTreasury(_treasury).getRaisedAmount();
    }
    emit TreasurySet(previousTreasury, _treasury);
}
```

This anchors the watermark to the new treasury's state so no phantom delta is minted and no silent blocking occurs.
