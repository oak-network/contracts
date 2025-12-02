// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BasePaymentTreasury} from "../utils/BasePaymentTreasury.sol";
import {ICampaignPaymentTreasury} from "../interfaces/ICampaignPaymentTreasury.sol";

contract PaymentTreasury is BasePaymentTreasury {
    using SafeERC20 for IERC20;

    /**
     * @dev Emitted when an unauthorized action is attempted.
     */
    error PaymentTreasuryUnAuthorized();

    /**
     * @dev Constructor for the PaymentTreasury contract.
     */
    constructor() {}

    function initialize(bytes32 _platformHash, address _infoAddress, address _trustedForwarder) external initializer {
        __BaseContract_init(_platformHash, _infoAddress, _trustedForwarder);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function createPayment(
        bytes32 paymentId,
        bytes32 buyerId,
        bytes32 itemId,
        address paymentToken,
        uint256 amount,
        uint256 expiration,
        ICampaignPaymentTreasury.LineItem[] calldata lineItems,
        ICampaignPaymentTreasury.ExternalFees[] calldata externalFees
    ) public override whenNotPaused whenNotCancelled {
        super.createPayment(paymentId, buyerId, itemId, paymentToken, amount, expiration, lineItems, externalFees);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function createPaymentBatch(
        bytes32[] calldata paymentIds,
        bytes32[] calldata buyerIds,
        bytes32[] calldata itemIds,
        address[] calldata paymentTokens,
        uint256[] calldata amounts,
        uint256[] calldata expirations,
        ICampaignPaymentTreasury.LineItem[][] calldata lineItemsArray,
        ICampaignPaymentTreasury.ExternalFees[][] calldata externalFeesArray
    ) public override whenNotPaused whenNotCancelled {
        super.createPaymentBatch(
            paymentIds, buyerIds, itemIds, paymentTokens, amounts, expirations, lineItemsArray, externalFeesArray
        );
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function processCryptoPayment(
        bytes32 paymentId,
        bytes32 itemId,
        address buyerAddress,
        address paymentToken,
        uint256 amount,
        ICampaignPaymentTreasury.LineItem[] calldata lineItems,
        ICampaignPaymentTreasury.ExternalFees[] calldata externalFees
    ) public override whenNotPaused whenNotCancelled {
        super.processCryptoPayment(paymentId, itemId, buyerAddress, paymentToken, amount, lineItems, externalFees);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function cancelPayment(bytes32 paymentId) public override whenNotPaused whenNotCancelled {
        super.cancelPayment(paymentId);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function confirmPayment(bytes32 paymentId, address buyerAddress) public override whenNotPaused whenNotCancelled {
        super.confirmPayment(paymentId, buyerAddress);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function confirmPaymentBatch(bytes32[] calldata paymentIds, address[] calldata buyerAddresses)
        public
        override
        whenNotPaused
        whenNotCancelled
    {
        super.confirmPaymentBatch(paymentIds, buyerAddresses);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function claimRefund(bytes32 paymentId, address refundAddress) public override whenNotPaused whenNotCancelled {
        super.claimRefund(paymentId, refundAddress);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function claimRefund(bytes32 paymentId) public override whenNotPaused whenNotCancelled {
        super.claimRefund(paymentId);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function claimExpiredFunds() public override whenNotPaused {
        super.claimExpiredFunds();
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function disburseFees() public override whenNotPaused {
        super.disburseFees();
    }

    /**
     * @inheritdoc BasePaymentTreasury
     */
    function claimNonGoalLineItems(address token) public override whenNotPaused {
        super.claimNonGoalLineItems(token);
    }

    /**
     * @inheritdoc ICampaignPaymentTreasury
     */
    function withdraw() public override whenNotPaused whenNotCancelled {
        super.withdraw();
    }

    /**
     * @inheritdoc BasePaymentTreasury
     * @dev This function is overridden to allow the platform admin and the campaign owner to cancel a treasury.
     */
    function cancelTreasury(bytes32 message) public override {
        if (_msgSender() != INFO.getPlatformAdminAddress(PLATFORM_HASH) && _msgSender() != INFO.owner()) {
            revert PaymentTreasuryUnAuthorized();
        }
        _cancel(message);
    }

    /**
     * @inheritdoc BasePaymentTreasury
     */
    function _checkSuccessCondition() internal view virtual override returns (bool) {
        return true;
    }
}
