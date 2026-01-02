// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {ICampaignTreasury} from "../interfaces/ICampaignTreasury.sol";
import {CampaignAccessChecker} from "./CampaignAccessChecker.sol";
import {PausableCancellable} from "./PausableCancellable.sol";

/**
 * @title BaseTreasury
 * @notice A base contract for creating and managing treasuries in crowdfunding campaigns.
 * @dev This contract defines common functionality and storage for campaign treasuries.
 * @dev Supports ERC-2771 meta-transactions via adapter contracts for platform admin operations.
 * @dev Contracts implementing this base contract should provide specific success conditions.
 */
abstract contract BaseTreasury is Initializable, ICampaignTreasury, CampaignAccessChecker, PausableCancellable {
    using SafeERC20 for IERC20;

    bytes32 internal constant ZERO_BYTES = 0x0000000000000000000000000000000000000000000000000000000000000000;
    uint256 internal constant PERCENT_DIVIDER = 10000;
    uint256 internal constant STANDARD_DECIMALS = 18;

    bytes32 internal PLATFORM_HASH;
    uint256 internal PLATFORM_FEE_PERCENT;

    bool internal s_feesDisbursed;

    // Multi-token support
    mapping(address => uint256) internal s_tokenRaisedAmounts; // Amount raised per token (decreases on refunds)
    mapping(address => uint256) internal s_tokenLifetimeRaisedAmounts; // Lifetime raised amount per token (never decreases)

    /**
     * @notice Emitted when fees are successfully disbursed for a specific token.
     * @param token The token address.
     * @param protocolShare The amount of fees sent to the protocol.
     * @param platformShare The amount of fees sent to the platform.
     */
    event FeesDisbursed(address indexed token, uint256 protocolShare, uint256 platformShare);

    /**
     * @notice Emitted when a withdrawal is successful for a specific token.
     * @param token The token address.
     * @param to The recipient of the withdrawal.
     * @param amount The amount withdrawn.
     */
    event WithdrawalSuccessful(address indexed token, address to, uint256 amount);

    /**
     * @notice Emitted when the success condition is not fulfilled during fee disbursement.
     */
    event SuccessConditionNotFulfilled();

    /**
     * @dev Throws an error indicating a failed treasury transfer.
     */
    error TreasuryTransferFailed();

    /**
     * @dev Throws an error indicating that the success condition was not fulfilled.
     */
    error TreasurySuccessConditionNotFulfilled();

    /**
     * @dev Throws an error indicating that fees have not been disbursed.
     */
    error TreasuryFeeNotDisbursed();

    /**
     * @dev Throws an error indicating that the campaign is paused.
     */
    error TreasuryCampaignInfoIsPaused();

    function __BaseContract_init(bytes32 platformHash, address infoAddress, address trustedForwarder_) internal {
        __CampaignAccessChecker_init(infoAddress);
        PLATFORM_HASH = platformHash;
        PLATFORM_FEE_PERCENT = INFO.getPlatformFeePercent(platformHash);
        _trustedForwarder = trustedForwarder_;
    }

    /**
     * @dev Override _msgSender to support ERC-2771 meta-transactions.
     * When called by the trusted forwarder (adapter), extracts the actual sender from calldata.
     */
    function _msgSender() internal view virtual override returns (address sender) {
        if (msg.sender == _trustedForwarder && msg.data.length >= 20) {
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            sender = msg.sender;
        }
    }

    /**
     * @dev Modifier that checks if the campaign is not paused.
     */
    modifier whenCampaignNotPaused() {
        _revertIfCampaignPaused();
        _;
    }

    modifier whenCampaignNotCancelled() {
        _revertIfCampaignCancelled();
        _;
    }

    /**
     * @inheritdoc ICampaignTreasury
     */
    function getPlatformHash() external view override returns (bytes32) {
        return PLATFORM_HASH;
    }

    /**
     * @inheritdoc ICampaignTreasury
     */
    function getPlatformFeePercent() external view override returns (uint256) {
        return PLATFORM_FEE_PERCENT;
    }

    /**
     * @dev Normalizes token amount to 18 decimals for consistent comparison.
     * @param token The token address to normalize.
     * @param amount The amount to normalize.
     * @return The normalized amount in 18 decimals.
     */
    function _normalizeAmount(address token, uint256 amount) internal view returns (uint256) {
        uint8 decimals = IERC20Metadata(token).decimals();

        if (decimals == STANDARD_DECIMALS) {
            return amount;
        } else if (decimals < STANDARD_DECIMALS) {
            // Scale up for tokens with fewer decimals
            return amount * (10 ** (STANDARD_DECIMALS - decimals));
        } else {
            // Scale down for tokens with more decimals (rare but possible)
            return amount / (10 ** (decimals - STANDARD_DECIMALS));
        }
    }

    /**
     * @dev Denormalizes an amount from 18 decimals to the token's actual decimals.
     * @param token The token address to denormalize for.
     * @param amount The amount in 18 decimals to denormalize.
     * @return The denormalized amount in token's native decimals.
     */
    function _denormalizeAmount(address token, uint256 amount) internal view returns (uint256) {
        uint8 decimals = IERC20Metadata(token).decimals();

        if (decimals == STANDARD_DECIMALS) {
            return amount;
        } else if (decimals < STANDARD_DECIMALS) {
            // Scale down for tokens with fewer decimals (e.g., USDC 6 decimals)
            uint256 divisor = 10 ** (STANDARD_DECIMALS - decimals);
            return (amount + divisor - 1) / divisor;
        } else {
            // Scale up for tokens with more decimals (rare but possible)
            return amount * (10 ** (decimals - STANDARD_DECIMALS));
        }
    }

    /**
     * @inheritdoc ICampaignTreasury
     */
    function disburseFees() public virtual override whenCampaignNotPaused whenCampaignNotCancelled {
        if (!_checkSuccessCondition()) {
            revert TreasurySuccessConditionNotFulfilled();
        }

        address[] memory acceptedTokens = INFO.getAcceptedTokens();

        // Disburse fees for each token
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            address token = acceptedTokens[i];
            uint256 balance = s_tokenRaisedAmounts[token];

            if (balance > 0) {
                uint256 protocolShare = (balance * INFO.getProtocolFeePercent()) / PERCENT_DIVIDER;
                uint256 platformShare = (balance * PLATFORM_FEE_PERCENT) / PERCENT_DIVIDER;

                if (protocolShare > 0) {
                    IERC20(token).safeTransfer(INFO.getProtocolAdminAddress(), protocolShare);
                }

                if (platformShare > 0) {
                    IERC20(token).safeTransfer(INFO.getPlatformAdminAddress(PLATFORM_HASH), platformShare);
                }

                emit FeesDisbursed(token, protocolShare, platformShare);
            }
        }

        s_feesDisbursed = true;
    }

    /**
     * @inheritdoc ICampaignTreasury
     */
    function withdraw() public virtual override whenCampaignNotPaused whenCampaignNotCancelled {
        if (!s_feesDisbursed) {
            revert TreasuryFeeNotDisbursed();
        }

        address[] memory acceptedTokens = INFO.getAcceptedTokens();
        address recipient = INFO.owner();

        // Withdraw remaining balance for each token
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            address token = acceptedTokens[i];
            uint256 balance = IERC20(token).balanceOf(address(this));

            if (balance > 0) {
                IERC20(token).safeTransfer(recipient, balance);
                emit WithdrawalSuccessful(token, recipient, balance);
            }
        }
    }

    /**
     * @dev External function to pause the campaign.
     */
    function pauseTreasury(bytes32 message) public virtual onlyPlatformAdmin(PLATFORM_HASH) {
        _pause(message);
    }

    /**
     * @dev External function to unpause the campaign.
     */
    function unpauseTreasury(bytes32 message) public virtual onlyPlatformAdmin(PLATFORM_HASH) {
        _unpause(message);
    }

    /**
     * @dev External function to cancel the campaign.
     */
    function cancelTreasury(bytes32 message) public virtual onlyPlatformAdmin(PLATFORM_HASH) {
        _cancel(message);
    }

    /**
     * @notice Returns true if the treasury has been cancelled.
     * @return True if cancelled, false otherwise.
     */
    function cancelled() public view virtual override(ICampaignTreasury, PausableCancellable) returns (bool) {
        return super.cancelled();
    }

    /**
     * @dev Internal function to check if the campaign is paused.
     * If the campaign is paused, it reverts with TreasuryCampaignInfoIsPaused error.
     */
    function _revertIfCampaignPaused() internal view {
        if (INFO.paused()) {
            revert TreasuryCampaignInfoIsPaused();
        }
    }

    function _revertIfCampaignCancelled() internal view {
        if (INFO.cancelled()) {
            revert TreasuryCampaignInfoIsPaused();
        }
    }

    /**
     * @dev Internal function to check the success condition for fee disbursement.
     * @return Whether the success condition is met.
     */
    function _checkSuccessCondition() internal view virtual returns (bool);
}
