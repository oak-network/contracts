// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title VoidablePledge
 * @notice Abstract contract providing voided-pledge status tracking for treasury contracts.
 * @dev Tracks which pledges (by NFT token ID) have been voided. The treasury inheriting this
 *      contract is responsible for the actual accounting reversal and fund transfers.
 */
abstract contract VoidablePledge {
    /// @dev Mapping from tokenId to whether the pledge has been voided.
    mapping(uint256 => bool) private s_voidedPledges;

    /// @dev Reverts when an operation targets an already-voided pledge.
    error VoidablePledgeAlreadyVoided(uint256 tokenId);

    /// @notice Returns whether a pledge (by NFT token ID) has been voided.
    /// @param tokenId The NFT token ID representing the pledge.
    /// @return True if the pledge has been voided.
    function isVoided(uint256 tokenId) public view returns (bool) {
        return s_voidedPledges[tokenId];
    }

    /// @notice Modifier that reverts if the pledge is already voided.
    /// @param tokenId The NFT token ID to check.
    modifier notVoided(uint256 tokenId) {
        if (s_voidedPledges[tokenId]) {
            revert VoidablePledgeAlreadyVoided(tokenId);
        }
        _;
    }

    /// @dev Marks a pledge as voided. Reverts if already voided.
    /// @param tokenId The NFT token ID to mark as voided.
    function _markPledgeVoided(uint256 tokenId) internal {
        if (s_voidedPledges[tokenId]) {
            revert VoidablePledgeAlreadyVoided(tokenId);
        }
        s_voidedPledges[tokenId] = true;
    }
}
