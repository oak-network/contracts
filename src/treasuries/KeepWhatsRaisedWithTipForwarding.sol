// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {KeepWhatsRaised} from "./KeepWhatsRaised.sol";
import {IPermit2, ISignatureTransfer, PermitData} from "../interfaces/IPermit2.sol";
import {TreasuryErrors} from "../errors/TreasuryErrors.sol";

/**
 * @title KeepWhatsRaisedWithTipForwarding
 * @notice Extension of KeepWhatsRaised that forwards tips to the platform admin
 *         immediately during the pledge flow, rather than holding them in the treasury.
 *
 * @dev Two distinct paths:
 *      - Admin path (!usePermit2): PlatformAdmin is caller and tip recipient, so no
 *        tip tokens flow through the treasury. For non-reward pledges the tip is
 *        deducted from pledgeAmount; for reward pledges the pledge amount is determined
 *        by reward values and is unaffected.
 *      - Permit2 path (usePermit2): Backer sends pledgeAmount + tip via Permit2 to the
 *        treasury, then after all state updates the tip is forwarded to platformAdmin.
 */
contract KeepWhatsRaisedWithTipForwarding is KeepWhatsRaised {
    using SafeERC20 for IERC20;

    /// @notice Emitted when a tip is forwarded from the treasury to the platform admin.
    event TipForwarded(address indexed token, uint256 amount, address indexed recipient, uint256 indexed tokenId);

    /// @notice Thrown when the tip exceeds the pledge amount on the admin path for non-reward pledges.
    error TipExceedsPledgeAmount(uint256 tip, uint256 pledgeAmount);

    /**
     * @dev Overrides the parent's _pledge to implement tip forwarding.
     *
     *      Admin path (!usePermit2, via setFeeAndPledge):
     *        - Non-reward (reward == ZERO_BYTES): pledgeAmount includes the tip.
     *          actualPledgeAmount = pledgeAmountInTokenDecimals - tip.
     *          Only actualPledgeAmount is transferred from admin.
     *        - Reward (reward != ZERO_BYTES): pledge amount is determined by reward
     *          values. Only pledgeAmountInTokenDecimals is transferred from admin.
     *          actualPledgeAmount = pledgeAmountInTokenDecimals.
     *        - In both cases tip is recorded in state/NFT metadata but never enters the treasury.
     *
     *      Permit2 path (usePermit2, via pledgeForAReward/pledgeWithoutAReward):
     *        - Backer sends totalAmount = pledgeAmountInTokenDecimals + tip via Permit2.
     *        - After all state updates and Receipt event (CEI), forward tip to platformAdmin.
     */
    function _pledge(
        bytes32 pledgeId,
        address backer,
        address pledgeToken,
        bytes32 reward,
        uint256 pledgeAmount,
        uint256 tip,
        bytes32[] memory rewards,
        address tokenSource,
        bool usePermit2,
        PermitData memory permitData
    ) internal virtual override {
        // --- validation (identical to parent) ---
        if (!INFO.isTokenAccepted(pledgeToken)) {
            revert KeepWhatsRaisedTokenNotAccepted(pledgeToken);
        }
        if (tokenSource == address(this) || backer == address(this)) {
            revert KeepWhatsRaisedInvalidInput(TreasuryErrors.InvalidInput.INVALID_BACKER);
        }
        if (usePermit2 && permitData.signature.length == 0) {
            revert KeepWhatsRaisedInvalidInput(TreasuryErrors.InvalidInput.EMPTY_SIGNATURE);
        }
        if (!usePermit2 && tokenSource == address(0)) {
            revert KeepWhatsRaisedInvalidInput(TreasuryErrors.InvalidInput.ZERO_TOKEN_SOURCE);
        }

        // --- amount resolution ---
        uint256 pledgeAmountInTokenDecimals;
        if (reward != ZERO_BYTES) {
            pledgeAmountInTokenDecimals = _denormalizeAmount(pledgeToken, pledgeAmount);
        } else {
            pledgeAmountInTokenDecimals = pledgeAmount;
        }

        uint256 actualPledgeAmount;

        if (usePermit2) {
            // ----- Permit2 path -----
            // Backer sends pledgeAmountInTokenDecimals + tip to the treasury via Permit2.
            uint256 totalAmount = pledgeAmountInTokenDecimals + tip;

            bytes32 witness;
            string memory witnessTypeString;

            if (reward != ZERO_BYTES) {
                bytes32 rewardsHash = keccak256(abi.encodePacked(rewards));
                witness = keccak256(
                    abi.encode(KWR_PLEDGE_FOR_REWARD_WITNESS_TYPEHASH, pledgeId, backer, rewardsHash, tip)
                );
                witnessTypeString = KWR_PLEDGE_FOR_REWARD_WITNESS_TYPE_STRING;
            } else {
                witness = keccak256(
                    abi.encode(
                        KWR_PLEDGE_WITHOUT_REWARD_WITNESS_TYPEHASH,
                        pledgeId,
                        backer,
                        pledgeAmountInTokenDecimals,
                        tip
                    )
                );
                witnessTypeString = KWR_PLEDGE_WITHOUT_REWARD_WITNESS_TYPE_STRING;
            }

            IPermit2(INFO.getPermit2Address()).permitWitnessTransferFrom(
                ISignatureTransfer.PermitTransferFrom({
                    permitted: ISignatureTransfer.TokenPermissions({token: pledgeToken, amount: totalAmount}),
                    nonce: permitData.nonce,
                    deadline: permitData.deadline
                }),
                ISignatureTransfer.SignatureTransferDetails({to: address(this), requestedAmount: totalAmount}),
                backer,
                witness,
                witnessTypeString,
                permitData.signature
            );
            actualPledgeAmount = pledgeAmountInTokenDecimals;
        } else {
            // ----- Admin path -----
            if (reward == ZERO_BYTES) {
                // Non-reward pledge: pledgeAmount includes the tip.
                if (tip > pledgeAmountInTokenDecimals) {
                    revert TipExceedsPledgeAmount(tip, pledgeAmountInTokenDecimals);
                }
                actualPledgeAmount = pledgeAmountInTokenDecimals - tip;
                // Only transfer the actual pledge amount (tip stays with admin).
                IERC20(pledgeToken).safeTransferFrom(tokenSource, address(this), actualPledgeAmount);
            } else {
                // Reward pledge: pledge amount is determined by reward values, tip is separate.
                actualPledgeAmount = pledgeAmountInTokenDecimals;
                // Only transfer the pledge amount (tip stays with admin).
                IERC20(pledgeToken).safeTransferFrom(tokenSource, address(this), pledgeAmountInTokenDecimals);
            }
        }

        // --- state updates (identical to parent) ---
        uint256 tokenId = INFO.mintNFTForPledge(backer, reward, pledgeToken, actualPledgeAmount, 0, tip);

        s_tokenToPledgedAmount[tokenId] = actualPledgeAmount;
        s_tokenToTippedAmount[tokenId] = tip;
        s_tokenIdToPledgeToken[tokenId] = pledgeToken;
        s_tipPerToken[pledgeToken] += tip;
        s_tokenRaisedAmounts[pledgeToken] += actualPledgeAmount;
        s_tokenLifetimeRaisedAmounts[pledgeToken] += actualPledgeAmount;

        uint256 netAvailable = _calculateNetAvailable(pledgeId, pledgeToken, tokenId, actualPledgeAmount);
        s_availablePerToken[pledgeToken] += netAvailable;

        emit Receipt(backer, pledgeToken, reward, pledgeAmount, tip, tokenId, rewards);

        // --- tip forwarding (Permit2 path only, after all state updates — CEI) ---
        if (usePermit2 && tip > 0) {
            address platformAdmin = INFO.getPlatformAdminAddress(PLATFORM_HASH);
            IERC20(pledgeToken).safeTransfer(platformAdmin, tip);
            emit TipForwarded(pledgeToken, tip, platformAdmin, tokenId);
        }
    }
}
