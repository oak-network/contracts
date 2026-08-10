# BasePaymentTreasury
[Git Source](https://github.com/oak-network/contracts/blob/6c7f67f5ed14ef0f4f9444b95ac6770ae2af756a/src/utils/BasePaymentTreasury.sol)

**Inherits:**
Initializable, [ICampaignPaymentTreasury](/src/interfaces/ICampaignPaymentTreasury.sol/interface.ICampaignPaymentTreasury.md), [CampaignAccessChecker](/src/utils/CampaignAccessChecker.sol/abstract.CampaignAccessChecker.md), [PausableCancellable](/src/utils/PausableCancellable.sol/abstract.PausableCancellable.md), ReentrancyGuard

**Title:**
BasePaymentTreasury

Base contract for payment treasury implementations.

Supports ERC-2771 meta-transactions via adapter contracts for platform admin operations.


## Constants
### ZERO_BYTES

```solidity
bytes32 internal constant ZERO_BYTES = 0x0000000000000000000000000000000000000000000000000000000000000000
```


### PERCENT_DIVIDER

```solidity
uint256 internal constant PERCENT_DIVIDER = 10000
```


### STANDARD_DECIMALS

```solidity
uint256 internal constant STANDARD_DECIMALS = 18
```


### ZERO_ADDRESS

```solidity
address internal constant ZERO_ADDRESS = address(0)
```


### CRYPTO_PAYMENT_WITNESS_TYPEHASH

```solidity
bytes32 internal constant CRYPTO_PAYMENT_WITNESS_TYPEHASH = keccak256(
    "CryptoPaymentWitness(bytes32 paymentId,bytes32 itemId,address buyerAddress,uint256 amount,bytes32 lineItemsHash)"
)
```


### CRYPTO_PAYMENT_WITNESS_TYPE_STRING

```solidity
string internal constant CRYPTO_PAYMENT_WITNESS_TYPE_STRING =
    "CryptoPaymentWitness witness)CryptoPaymentWitness(bytes32 paymentId,bytes32 itemId,address buyerAddress,uint256 amount,bytes32 lineItemsHash)TokenPermissions(address token,uint256 amount)"
```


### MAX_LINE_ITEMS
Maximum number of line items per payment. Ensures confirmPayment can always succeed if createPayment did.


```solidity
uint256 internal constant MAX_LINE_ITEMS = 50
```


### MAX_EXTERNAL_FEES
Maximum number of external fee entries per payment.


```solidity
uint256 internal constant MAX_EXTERNAL_FEES = 50
```


### MAX_BATCH_SIZE
Maximum number of payments in a single batch call.


```solidity
uint256 internal constant MAX_BATCH_SIZE = 50
```


## State Variables
### PLATFORM_HASH

```solidity
bytes32 internal PLATFORM_HASH
```


### PLATFORM_FEE_PERCENT
Snapshot of the platform fee percent captured at treasury initialization via
INFO.getPlatformFeePercent(platformHash). This value is fixed for the lifetime of the
treasury and will not reflect any subsequent changes to the platform fee in GlobalParams.
The protocol fee accessed during fee calculations via INFO.getProtocolFeePercent() is also
a snapshot — it is stored in the campaign's CampaignInfo clone at creation time and is
likewise immutable for the campaign's lifecycle. Despite the asymmetry in how they are
accessed (cached field vs. getter call), both fees are effectively campaign-level snapshots.


```solidity
uint256 internal PLATFORM_FEE_PERCENT
```


### s_paymentIdToToken

```solidity
mapping(bytes32 => address) internal s_paymentIdToToken
```


### s_platformFeePerToken

```solidity
mapping(address => uint256) internal s_platformFeePerToken
```


### s_protocolFeePerToken

```solidity
mapping(address => uint256) internal s_protocolFeePerToken
```


### s_paymentIdToNFTId

```solidity
mapping(bytes32 => uint256) internal s_paymentIdToNFTId
```


### s_paymentIdToCreator

```solidity
mapping(bytes32 => address) internal s_paymentIdToCreator
```


### s_payment

```solidity
mapping(bytes32 => PaymentInfo) internal s_payment
```


### s_paymentLineItems

```solidity
mapping(bytes32 => ICampaignPaymentTreasury.PaymentLineItem[]) internal s_paymentLineItems
```


### s_paymentExternalFeeMetadata

```solidity
mapping(bytes32 => ICampaignPaymentTreasury.ExternalFees[]) internal s_paymentExternalFeeMetadata
```


### s_pendingPaymentPerToken

```solidity
mapping(address => uint256) internal s_pendingPaymentPerToken
```


### s_confirmedPaymentPerToken

```solidity
mapping(address => uint256) internal s_confirmedPaymentPerToken
```


### s_lifetimeConfirmedPaymentPerToken

```solidity
mapping(address => uint256) internal s_lifetimeConfirmedPaymentPerToken
```


### s_availableConfirmedPerToken

```solidity
mapping(address => uint256) internal s_availableConfirmedPerToken
```


### s_nonGoalLineItemPendingPerToken

```solidity
mapping(address => uint256) internal s_nonGoalLineItemPendingPerToken
```


### s_nonGoalLineItemConfirmedPerToken

```solidity
mapping(address => uint256) internal s_nonGoalLineItemConfirmedPerToken
```


### s_nonGoalLineItemClaimablePerToken

```solidity
mapping(address => uint256) internal s_nonGoalLineItemClaimablePerToken
```


### s_nonGoalRefundableLineItemPerToken

```solidity
mapping(address => uint256) internal s_nonGoalRefundableLineItemPerToken
```


## Functions
### constructor


```solidity
constructor() ;
```

### _getInternalPaymentIdForOffChain

Scopes a payment ID for off-chain payments (createPayment/createPaymentBatch).


```solidity
function _getInternalPaymentIdForOffChain(bytes32 paymentId) internal pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The external payment ID.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The scoped internal payment ID.|


### _scopePaymentIdForOnChain

Scopes a payment ID for on-chain crypto payments (processCryptoPayment).

Scoped by the buyer address (the Permit2 signer) rather than the tx sender,
so the payment can be looked up by anyone using the stored creator address.


```solidity
function _scopePaymentIdForOnChain(bytes32 paymentId, address owner) internal pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The external payment ID.|
|`owner`|`address`|    The buyer/signer address.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The scoped internal payment ID.|


### _findPaymentId

Tries to find a payment by checking both off-chain and on-chain scopes.
- Off-chain payments (createPayment) can be looked up by anyone (scoped with address(0))
- On-chain payments (processCryptoPayment) can be looked up by anyone using the stored creator address


```solidity
function _findPaymentId(bytes32 paymentId) internal view returns (bytes32 internalPaymentId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The external payment ID.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`internalPaymentId`|`bytes32`|The scoped internal payment ID if found, or ZERO_BYTES if not found.|


### _getMaxExpirationDuration

Retrieves the max expiration duration configured for the current platform or globally.


```solidity
function _getMaxExpirationDuration() internal view returns (bool hasLimit, uint256 duration);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`hasLimit`|`bool`|Indicates whether a max expiration duration is configured.|
|`duration`|`uint256`|The max expiration duration in seconds.|


### __BaseContract_init

Initializes the base payment treasury with platform and campaign context.


```solidity
function __BaseContract_init(bytes32 platformHash, address infoAddress) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The platform identifier used for fee lookup and access control.|
|`infoAddress`|`address`|The CampaignInfo contract address for campaign data and admin lookups.|


### _msgSender

Override _msgSender to support ERC-2771 meta-transactions.
When called by the trusted forwarder (adapter), extracts the actual sender from calldata.
The adapter address is read dynamically from GlobalParams via CampaignInfo so that
adapter rotations take effect immediately for all deployed treasuries.


```solidity
function _msgSender() internal view virtual override returns (address sender);
```

### whenCampaignNotPaused

Modifier that checks if the campaign is not paused.


```solidity
modifier whenCampaignNotPaused() ;
```

### whenCampaignNotCancelled


```solidity
modifier whenCampaignNotCancelled() ;
```

### onlyPlatformAdminOrCampaignOwner

Restricts access to only the platform admin or the campaign owner.

Checks if `_msgSender()` is either the platform admin (via `INFO.getPlatformAdminAddress`)
or the campaign owner (via `INFO.owner()`). Reverts with `AccessCheckerUnauthorized` if not authorized.


```solidity
modifier onlyPlatformAdminOrCampaignOwner() ;
```

### getplatformHash

Retrieves the platform identifier associated with the treasury.


```solidity
function getplatformHash() external view override returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The platform identifier as a bytes32 value.|


### getplatformFeePercent

Retrieves the platform fee percentage for the treasury.


```solidity
function getplatformFeePercent() external view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The platform fee percentage as a uint256 value.|


### getRaisedAmount

Retrieves the total raised amount in the treasury.


```solidity
function getRaisedAmount() public view virtual override returns (uint256 amount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Total confirmed payment amount across all tokens, normalized to 18 decimals.|


### getAvailableRaisedAmount

Retrieves the currently available raised amount in the treasury.


```solidity
function getAvailableRaisedAmount() external view returns (uint256 amount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Available confirmed amount across all tokens, normalized to 18 decimals.|


### getLifetimeRaisedAmount

Retrieves the lifetime raised amount in the treasury (never decreases with refunds).


```solidity
function getLifetimeRaisedAmount() external view returns (uint256 amount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Lifetime total confirmed payments across all tokens, normalized to 18 decimals.|


### getRefundedAmount

Retrieves the total refunded amount in the treasury.


```solidity
function getRefundedAmount() external view returns (uint256 amount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Total refunded amount across all tokens, normalized to 18 decimals.|


### getExpectedAmount

Retrieves the total expected (pending) amount in the treasury.

This represents payments that have been created but not yet confirmed.


```solidity
function getExpectedAmount() external view returns (uint256 amount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Total pending payment amount across all tokens, normalized to 18 decimals.|


### _normalizeAmount

Normalizes token amounts to 18 decimals for consistent comparisons.


```solidity
function _normalizeAmount(address token, uint256 amount) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The token address.|
|`amount`|`uint256`|The amount to normalize.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The normalized amount (scaled to 18 decimals).|


### _validateStoreAndTrackLineItems

Validates, stores, and tracks line items in a single loop for gas efficiency.


```solidity
function _validateStoreAndTrackLineItems(
    bytes32 paymentId,
    ICampaignPaymentTreasury.LineItem[] calldata lineItems,
    address paymentToken
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The payment ID to store line items for.|
|`lineItems`|`ICampaignPaymentTreasury.LineItem[]`|Array of line items to validate, store, and track.|
|`paymentToken`|`address`|The token used for the payment.|


### createPayment


```solidity
function createPayment(
    bytes32 paymentId,
    bytes32 buyerId,
    bytes32 itemId,
    address paymentToken,
    uint256 amount,
    uint256 expiration,
    ICampaignPaymentTreasury.LineItem[] calldata lineItems,
    ICampaignPaymentTreasury.ExternalFees[] calldata externalFees
) public virtual override onlyPlatformAdmin(PLATFORM_HASH) whenCampaignNotPaused whenCampaignNotCancelled;
```

### createPaymentBatch


```solidity
function createPaymentBatch(
    bytes32[] calldata paymentIds,
    bytes32[] calldata buyerIds,
    bytes32[] calldata itemIds,
    address[] calldata paymentTokens,
    uint256[] calldata amounts,
    uint256[] calldata expirations,
    ICampaignPaymentTreasury.LineItem[][] calldata lineItemsArray,
    ICampaignPaymentTreasury.ExternalFees[][] calldata externalFeesArray
) public virtual override onlyPlatformAdmin(PLATFORM_HASH) whenCampaignNotPaused whenCampaignNotCancelled;
```

### processCryptoPayment

Mints a pledge NFT to `buyerAddress` via `_safeMint`. Reverts if `buyerAddress` is
a contract that does not implement `IERC721Receiver`.


```solidity
function processCryptoPayment(
    bytes32 paymentId,
    bytes32 itemId,
    address buyerAddress,
    address paymentToken,
    uint256 amount,
    ICampaignPaymentTreasury.LineItem[] calldata lineItems,
    ICampaignPaymentTreasury.ExternalFees[] calldata externalFees,
    PermitData calldata permitData
) public virtual override nonReentrant whenCampaignNotPaused whenCampaignNotCancelled;
```

### cancelPayment

Cancels an existing payment with the given payment ID.


```solidity
function cancelPayment(bytes32 paymentId)
    public
    virtual
    override
    onlyPlatformAdmin(PLATFORM_HASH)
    whenCampaignNotPaused
    whenCampaignNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the payment to cancel.|


### _calculateLineItemTotals

Calculates line item totals for balance checking and state updates.


```solidity
function _calculateLineItemTotals(
    ICampaignPaymentTreasury.PaymentLineItem[] storage lineItems,
    uint256 protocolFeePercent
) internal view returns (LineItemTotals memory totals);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`lineItems`|`ICampaignPaymentTreasury.PaymentLineItem[]`|Array of line items to process.|
|`protocolFeePercent`|`uint256`|Protocol fee percentage.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totals`|`LineItemTotals`|Struct containing all calculated totals.|


### _checkBalanceForConfirmation

Checks if the treasury's actual token balance is sufficient to cover the total amount of the payment being confirmed, plus all previously committed funds (available for withdrawal, fees, and refundable items).


```solidity
function _checkBalanceForConfirmation(address paymentToken, uint256 paymentAmount, LineItemTotals memory totals)
    internal
    view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentToken`|`address`|The token address.|
|`paymentAmount`|`uint256`|The base payment amount.|
|`totals`|`LineItemTotals`|Line item totals struct.|


### _updateLineItemsForConfirmation

Updates state for line items during payment confirmation.


```solidity
function _updateLineItemsForConfirmation(
    address paymentToken,
    ICampaignPaymentTreasury.PaymentLineItem[] storage lineItems,
    uint256 protocolFeePercent
) internal returns (uint256 totalInstantTransferAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentToken`|`address`|The token address.|
|`lineItems`|`ICampaignPaymentTreasury.PaymentLineItem[]`|Array of line items to process.|
|`protocolFeePercent`|`uint256`|Protocol fee percentage.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalInstantTransferAmount`|`uint256`|Total amount to transfer instantly.|


### confirmPayment

Confirms and finalizes the payment associated with the given payment ID.

If `buyerAddress` is non-zero, mints a pledge NFT via `_safeMint`. Reverts if
`buyerAddress` is a contract that does not implement `IERC721Receiver`.


```solidity
function confirmPayment(bytes32 paymentId, address buyerAddress)
    public
    virtual
    override
    nonReentrant
    onlyPlatformAdmin(PLATFORM_HASH)
    whenCampaignNotPaused
    whenCampaignNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the payment to confirm.|
|`buyerAddress`|`address`|Optional buyer address to mint NFT to. Pass address(0) to skip NFT minting.|


### confirmPaymentBatch

Confirms and finalizes multiple payments in a single transaction.

For each non-zero `buyerAddress`, mints a pledge NFT via `_safeMint`. Reverts if
any such address is a contract that does not implement `IERC721Receiver`.


```solidity
function confirmPaymentBatch(bytes32[] calldata paymentIds, address[] calldata buyerAddresses)
    public
    virtual
    override
    nonReentrant
    onlyPlatformAdmin(PLATFORM_HASH)
    whenCampaignNotPaused
    whenCampaignNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentIds`|`bytes32[]`|An array of unique payment identifiers to be confirmed.|
|`buyerAddresses`|`address[]`|Array of buyer addresses to mint NFTs to. Must match paymentIds length. Pass address(0) to skip NFT minting for specific payments.|


### claimRefund

Claims a refund for non-NFT payments (payments without minted NFTs).

For non-NFT payments only. Verifies that no NFT exists for this payment.


```solidity
function claimRefund(bytes32 paymentId, address refundAddress)
    public
    virtual
    override
    onlyPlatformAdmin(PLATFORM_HASH)
    whenCampaignNotPaused
    whenCampaignNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the refundable payment (must NOT have an NFT).|
|`refundAddress`|`address`|The address where the refunded amount should be sent.|


### claimRefund

Claims a refund for NFT payments (payments with minted NFTs).

For NFT payments only. Requires an NFT exists and burns it. Refund is sent to current NFT owner.


```solidity
function claimRefund(bytes32 paymentId) public virtual override whenCampaignNotPaused whenCampaignNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the refundable payment (must have an NFT).|


### _executeRefund

Shared refund logic for both claimRefund overloads.
Calculates refund amounts from line item snapshots, validates balances,
updates state, removes common storage entries, and returns the total refund amount.


```solidity
function _executeRefund(
    bytes32 internalPaymentId,
    address paymentToken,
    uint256 amountToRefund,
    uint256 availablePaymentAmount,
    bytes32 revertId
) private returns (uint256 totalRefundAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`internalPaymentId`|`bytes32`|The scoped internal payment ID.|
|`paymentToken`|`address`|The token used for the payment.|
|`amountToRefund`|`uint256`|The base payment amount to refund.|
|`availablePaymentAmount`|`uint256`|The available confirmed amount for this token.|
|`revertId`|`bytes32`|The payment ID to use in revert messages (preserves original error context).|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalRefundAmount`|`uint256`|The total amount to transfer to the refund recipient.|


### disburseFees

Disburses fees collected by the treasury.


```solidity
function disburseFees() public virtual override whenCampaignNotPaused;
```

### claimNonGoalLineItems

Allows platform admin to claim non-goal line items that are available for claiming.


```solidity
function claimNonGoalLineItems(address token)
    public
    virtual
    onlyPlatformAdmin(PLATFORM_HASH)
    whenCampaignNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The token address to claim.|


### claimExpiredFunds

Allows the platform admin to claim all remaining funds once the claim window has opened.


```solidity
function claimExpiredFunds() public virtual onlyPlatformAdmin(PLATFORM_HASH) whenCampaignNotPaused;
```

### withdraw

Withdraws funds from the treasury.


```solidity
function withdraw()
    public
    virtual
    override
    onlyPlatformAdminOrCampaignOwner
    whenCampaignNotPaused
    whenCampaignNotCancelled;
```

### pauseTreasury

External function to pause the campaign.


```solidity
function pauseTreasury(bytes32 message) public virtual onlyPlatformAdmin(PLATFORM_HASH);
```

### unpauseTreasury

External function to unpause the campaign.


```solidity
function unpauseTreasury(bytes32 message) public virtual onlyPlatformAdmin(PLATFORM_HASH);
```

### cancelTreasury

External function to cancel the campaign.


```solidity
function cancelTreasury(bytes32 message) public virtual onlyPlatformAdmin(PLATFORM_HASH);
```

### _revertIfCampaignPaused

Internal function to check if the campaign is paused.
If the campaign is paused, it reverts with PaymentTreasuryCampaignInfoIsPaused error.


```solidity
function _revertIfCampaignPaused() internal view;
```

### _revertIfCampaignCancelled


```solidity
function _revertIfCampaignCancelled() internal view;
```

### _validatePaymentForAction

Validates the given payment ID to ensure it is eligible for further action.
Reverts if:
- The payment does not exist.
- The payment has already been confirmed.
- The payment has already expired.
- The payment is a crypto payment


```solidity
function _validatePaymentForAction(bytes32 internalPaymentId, bytes32 paymentId) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`internalPaymentId`|`bytes32`|The scoped internal payment ID used for storage lookup.|
|`paymentId`|`bytes32`|The external payment ID used in revert messages for caller clarity.|


### getPaymentData

Retrieves comprehensive payment data including payment info, token, line items, and external fees.

This function can look up payments created by anyone:
- Off-chain payments (created via createPayment): Scoped with address(0), anyone can look these up
- On-chain payments (created via processCryptoPayment): Uses stored creator address, anyone can look these up


```solidity
function getPaymentData(bytes32 paymentId)
    public
    view
    override
    returns (ICampaignPaymentTreasury.PaymentData memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the payment.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ICampaignPaymentTreasury.PaymentData`|A PaymentData struct containing all payment information.|


### _checkSuccessCondition

Internal function to check the success condition for fee disbursement.


```solidity
function _checkSuccessCondition() internal view virtual returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the success condition is met.|


## Events
### PaymentCreated
Emitted when a new payment is created.


```solidity
event PaymentCreated(
    address buyerAddress,
    bytes32 indexed paymentId,
    bytes32 buyerId,
    bytes32 indexed itemId,
    address indexed paymentToken,
    uint256 amount,
    uint256 expiration,
    bool isCryptoPayment
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`buyerAddress`|`address`|The address of the buyer making the payment.|
|`paymentId`|`bytes32`|The unique identifier of the payment.|
|`buyerId`|`bytes32`|The id of the buyer.|
|`itemId`|`bytes32`|The identifier of the item being purchased.|
|`paymentToken`|`address`|The token used for the payment.|
|`amount`|`uint256`|The amount to be paid for the item (in token's native decimals).|
|`expiration`|`uint256`|The timestamp after which the payment expires.|
|`isCryptoPayment`|`bool`|Boolean indicating whether the payment is made using direct crypto payment.|

### PaymentCancelled
Emitted when a payment is cancelled and removed from the treasury.


```solidity
event PaymentCancelled(bytes32 indexed paymentId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the cancelled payment.|

### PaymentConfirmed
Emitted when a payment is confirmed.


```solidity
event PaymentConfirmed(bytes32 indexed paymentId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the confirmed payment.|

### PaymentBatchConfirmed
Emitted when multiple payments are confirmed in a single batch operation.


```solidity
event PaymentBatchConfirmed(bytes32[] paymentIds);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentIds`|`bytes32[]`|An array of unique identifiers for the confirmed payments.|

### PaymentBatchCreated
Emitted when multiple payments are created in a single batch operation.


```solidity
event PaymentBatchCreated(bytes32[] paymentIds);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentIds`|`bytes32[]`|An array of unique identifiers for the created payments.|

### FeesDisbursed
Emitted when fees are successfully disbursed.


```solidity
event FeesDisbursed(address indexed token, uint256 protocolShare, uint256 platformShare);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The token in which fees were disbursed.|
|`protocolShare`|`uint256`|The amount of fees sent to the protocol.|
|`platformShare`|`uint256`|The amount of fees sent to the platform.|

### WithdrawalWithFeeSuccessful
Emitted when a withdrawal is successfully processed along with the applied fee.


```solidity
event WithdrawalWithFeeSuccessful(address indexed token, address indexed to, uint256 amount, uint256 fee);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The token that was withdrawn.|
|`to`|`address`|The recipient address receiving the funds.|
|`amount`|`uint256`|The total amount withdrawn (excluding fee).|
|`fee`|`uint256`|The fee amount deducted from the withdrawal.|

### RefundClaimed
Emitted when a refund is claimed.


```solidity
event RefundClaimed(bytes32 indexed paymentId, uint256 refundAmount, address indexed claimer);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the cancelled payment.|
|`refundAmount`|`uint256`|The refund amount claimed.|
|`claimer`|`address`|The address of the claimer.|

### NonGoalLineItemsClaimed
Emitted when non-goal line items are claimed by the platform admin.


```solidity
event NonGoalLineItemsClaimed(address indexed token, uint256 amount, address indexed platformAdmin);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The token that was claimed.|
|`amount`|`uint256`|The amount claimed.|
|`platformAdmin`|`address`|The address of the platform admin who claimed.|

### ExpiredFundsClaimed
Emitted when expired funds are claimed by the platform and protocol admins.


```solidity
event ExpiredFundsClaimed(address indexed token, uint256 platformAmount, uint256 protocolAmount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The token that was claimed.|
|`platformAmount`|`uint256`|The amount sent to the platform admin.|
|`protocolAmount`|`uint256`|The amount sent to the protocol admin.|

## Errors
### PaymentTreasuryInvalidInput
Reverts when one or more provided inputs to the payment treasury are invalid.


```solidity
error PaymentTreasuryInvalidInput(TreasuryErrors.InvalidInput code);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`code`|`TreasuryErrors.InvalidInput`|Error code defined in {TreasuryErrors.InvalidInput}.|

### PaymentTreasuryZeroPaymentId
Reverts when paymentId is zero.


```solidity
error PaymentTreasuryZeroPaymentId();
```

### PaymentTreasuryZeroBuyerId
Reverts when buyerId is zero.


```solidity
error PaymentTreasuryZeroBuyerId();
```

### PaymentTreasuryZeroAmount
Reverts when amount is zero.


```solidity
error PaymentTreasuryZeroAmount();
```

### PaymentTreasuryExpirationNotInFuture
Reverts when expiration is not in the future.


```solidity
error PaymentTreasuryExpirationNotInFuture();
```

### PaymentTreasuryZeroItemId
Reverts when itemId is zero.


```solidity
error PaymentTreasuryZeroItemId();
```

### PaymentTreasuryZeroPaymentToken
Reverts when paymentToken is the zero address.


```solidity
error PaymentTreasuryZeroPaymentToken();
```

### PaymentTreasuryZeroBuyerAddress
Reverts when buyerAddress is the zero address.


```solidity
error PaymentTreasuryZeroBuyerAddress();
```

### PaymentTreasuryBatchArrayLengthMismatch
Reverts when batch array lengths are inconsistent.


```solidity
error PaymentTreasuryBatchArrayLengthMismatch();
```

### PaymentTreasuryPaymentAlreadyExist
Throws an error indicating that the payment id already exists.


```solidity
error PaymentTreasuryPaymentAlreadyExist(bytes32 paymentId);
```

### PaymentTreasuryPaymentAlreadyConfirmed
Throws an error indicating that the payment id is already confirmed.


```solidity
error PaymentTreasuryPaymentAlreadyConfirmed(bytes32 paymentId);
```

### PaymentTreasuryPaymentAlreadyExpired
Throws an error indicating that the payment id is already expired.


```solidity
error PaymentTreasuryPaymentAlreadyExpired(bytes32 paymentId);
```

### PaymentTreasuryPaymentNotExist
Throws an error indicating that the payment id does not exist.


```solidity
error PaymentTreasuryPaymentNotExist(bytes32 paymentId);
```

### PaymentTreasuryCampaignInfoIsPaused
Throws an error indicating that the campaign is paused.


```solidity
error PaymentTreasuryCampaignInfoIsPaused();
```

### PaymentTreasuryTokenNotAccepted
Emitted when a token is not accepted for the campaign.


```solidity
error PaymentTreasuryTokenNotAccepted(address token);
```

### PaymentTreasurySuccessConditionNotFulfilled
Throws an error indicating that the success condition was not fulfilled.


```solidity
error PaymentTreasurySuccessConditionNotFulfilled();
```

### PaymentTreasuryFeeNotDisbursed
Throws an error indicating that fees have not been disbursed.


```solidity
error PaymentTreasuryFeeNotDisbursed();
```

### PaymentTreasuryPaymentNotConfirmed
Throws an error indicating that the payment id is not confirmed.


```solidity
error PaymentTreasuryPaymentNotConfirmed(bytes32 paymentId);
```

### PaymentTreasuryPaymentNotClaimable
Emitted when claiming an unclaimable refund.


```solidity
error PaymentTreasuryPaymentNotClaimable(bytes32 paymentId, TreasuryErrors.NotClaimable code);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the refundable payment.|
|`code`|`TreasuryErrors.NotClaimable`|Error code defined in {TreasuryErrors.NotClaimable}.|

### PaymentTreasuryAlreadyWithdrawn
Emitted when an attempt is made to withdraw funds from the treasury but the payment has already been withdrawn.


```solidity
error PaymentTreasuryAlreadyWithdrawn();
```

### PaymentTreasuryCryptoPayment
This error is thrown when an operation is attempted on a crypto payment that is only valid for non-crypto payments.


```solidity
error PaymentTreasuryCryptoPayment(bytes32 paymentId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the payment that caused the error.|

### PaymentTreasuryInsufficientFundsForFee
Emitted when the fee exceeds the requested withdrawal amount.


```solidity
error PaymentTreasuryInsufficientFundsForFee(uint256 withdrawalAmount, uint256 fee);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`withdrawalAmount`|`uint256`|The amount requested for withdrawal.|
|`fee`|`uint256`|The calculated fee, which is greater than the withdrawal amount.|

### PaymentTreasuryInsufficientBalance
Emitted when there are insufficient unallocated tokens for a payment confirmation.


```solidity
error PaymentTreasuryInsufficientBalance(uint256 required, uint256 available);
```

### PaymentTreasuryExpirationExceedsMax
Throws an error indicating that the payment expiration exceeds the maximum allowed expiration time.


```solidity
error PaymentTreasuryExpirationExceedsMax(uint256 expiration, uint256 maxExpiration);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`expiration`|`uint256`|The requested expiration timestamp.|
|`maxExpiration`|`uint256`|The maximum allowed expiration timestamp.|

### PaymentTreasuryClaimWindowNotReached
Throws when attempting to claim expired funds before the claim window opens.


```solidity
error PaymentTreasuryClaimWindowNotReached(uint256 claimableAt);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`claimableAt`|`uint256`|The timestamp when the claim window opens.|

### PaymentTreasuryNoFundsToClaim
Throws when there are no funds available to claim.


```solidity
error PaymentTreasuryNoFundsToClaim();
```

### PaymentTreasuryInvalidSender
Throws when the forwarder appends address(0) as the sender.


```solidity
error PaymentTreasuryInvalidSender();
```

### PaymentTreasuryArrayTooLong
Throws when an input array exceeds the maximum allowed length.


```solidity
error PaymentTreasuryArrayTooLong();
```

## Structs
### PaymentInfo
Stores information about a payment in the treasury.


```solidity
struct PaymentInfo {
    address buyerAddress;
    bytes32 buyerId;
    bytes32 itemId;
    uint256 amount;
    uint256 expiration;
    bool isConfirmed;
    bool isCryptoPayment;
    uint256 lineItemCount;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`buyerAddress`|`address`|The address of the buyer who made the payment.|
|`buyerId`|`bytes32`|The ID of the buyer.|
|`itemId`|`bytes32`|The identifier of the item being purchased.|
|`amount`|`uint256`|The amount to be paid for the item (in token's native decimals).|
|`expiration`|`uint256`|The timestamp after which the payment expires.|
|`isConfirmed`|`bool`|Boolean indicating whether the payment has been confirmed.|
|`isCryptoPayment`|`bool`|Boolean indicating whether the payment is made using direct crypto payment.|
|`lineItemCount`|`uint256`|The number of line items associated with this payment.|

### LineItemTotals
Struct to hold line item calculation totals to reduce stack depth.


```solidity
struct LineItemTotals {
    uint256 totalGoalLineItemAmount;
    uint256 totalProtocolFeeFromLineItems;
    uint256 totalNonGoalClaimableAmount;
    uint256 totalNonGoalRefundableAmount;
    uint256 totalInstantTransferAmountForCheck;
    uint256 totalInstantTransferAmount;
}
```

