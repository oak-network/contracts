# KeepWhatsRaised
[Git Source](https://github.com/oak-network/contracts/blob/6c7f67f5ed14ef0f4f9444b95ac6770ae2af756a/src/treasuries/KeepWhatsRaised.sol)

**Inherits:**
[IReward](/src/interfaces/IReward.sol/interface.IReward.md), [BaseTreasury](/src/utils/BaseTreasury.sol/abstract.BaseTreasury.md), [TimestampChecker](/src/utils/TimestampChecker.sol/abstract.TimestampChecker.md), [ICampaignData](/src/interfaces/ICampaignData.sol/interface.ICampaignData.md)

**Title:**
KeepWhatsRaised

A contract that keeps all the funds raised, regardless of the success condition.


## Constants
### KWR_PLEDGE_FOR_REWARD_WITNESS_TYPEHASH

```solidity
bytes32 internal constant KWR_PLEDGE_FOR_REWARD_WITNESS_TYPEHASH =
    keccak256("KWRPledgeForRewardWitness(bytes32 pledgeId,address backer,bytes32 rewardsHash,uint256 tip)")
```


### KWR_PLEDGE_FOR_REWARD_WITNESS_TYPE_STRING

```solidity
string internal constant KWR_PLEDGE_FOR_REWARD_WITNESS_TYPE_STRING =
    "KWRPledgeForRewardWitness witness)KWRPledgeForRewardWitness(bytes32 pledgeId,address backer,bytes32 rewardsHash,uint256 tip)TokenPermissions(address token,uint256 amount)"
```


### KWR_PLEDGE_WITHOUT_REWARD_WITNESS_TYPEHASH

```solidity
bytes32 internal constant KWR_PLEDGE_WITHOUT_REWARD_WITNESS_TYPEHASH =
    keccak256("KWRPledgeWithoutRewardWitness(bytes32 pledgeId,address backer,uint256 pledgeAmount,uint256 tip)")
```


### KWR_PLEDGE_WITHOUT_REWARD_WITNESS_TYPE_STRING

```solidity
string internal constant KWR_PLEDGE_WITHOUT_REWARD_WITNESS_TYPE_STRING =
    "KWRPledgeWithoutRewardWitness witness)KWRPledgeWithoutRewardWitness(bytes32 pledgeId,address backer,uint256 pledgeAmount,uint256 tip)TokenPermissions(address token,uint256 amount)"
```


## State Variables
### s_tokenToPledgedAmount

```solidity
mapping(uint256 => uint256) private s_tokenToPledgedAmount
```


### s_tokenToTippedAmount

```solidity
mapping(uint256 => uint256) private s_tokenToTippedAmount
```


### s_tokenToPaymentFee

```solidity
mapping(uint256 => uint256) private s_tokenToPaymentFee
```


### s_reward

```solidity
mapping(bytes32 => Reward) private s_reward
```


### s_processedPledges
Tracks whether an external pledge ID has already been processed.


```solidity
mapping(bytes32 => bool) public s_processedPledges
```


### s_paymentGatewayFees
Mapping to store payment gateway fees by unique pledge ID


```solidity
mapping(bytes32 => uint256) public s_paymentGatewayFees
```


### s_flatFeeValue
Flat fee values (token amounts, 18 decimals). Units are unambiguous.


```solidity
uint256 private s_flatFeeValue
```


### s_cumulativeFlatFeeValue

```solidity
uint256 private s_cumulativeFlatFeeValue
```


### s_grossPercentageFeeValues
Gross percentage fee values (basis points, 0 to PERCENT_DIVIDER - 1). Stored in same order as s_feeKeys.grossPercentageFeeKeys.


```solidity
uint256[] private s_grossPercentageFeeValues
```


### s_tokenIdToPledgeToken

```solidity
mapping(uint256 => address) private s_tokenIdToPledgeToken
```


### s_protocolFeePerToken

```solidity
mapping(address => uint256) private s_protocolFeePerToken
```


### s_platformFeePerToken

```solidity
mapping(address => uint256) private s_platformFeePerToken
```


### s_tipPerToken

```solidity
mapping(address => uint256) private s_tipPerToken
```


### s_availablePerToken

```solidity
mapping(address => uint256) private s_availablePerToken
```


### s_rewardCounter

```solidity
Counters.Counter private s_rewardCounter
```


### s_isWithdrawalApproved

```solidity
bool private s_isWithdrawalApproved
```


### s_tipClaimed

```solidity
bool private s_tipClaimed
```


### s_fundClaimed

```solidity
bool private s_fundClaimed
```


### s_configured

```solidity
bool private s_configured
```


### s_feeKeys

```solidity
FeeKeys private s_feeKeys
```


### s_config

```solidity
Config private s_config
```


### s_campaignData

```solidity
CampaignData private s_campaignData
```


## Functions
### withdrawalEnabled

Ensures that withdrawals are currently enabled.
Reverts with `KeepWhatsRaisedDisabled` if the withdrawal approval flag is not set.


```solidity
modifier withdrawalEnabled() ;
```

### onlyBeforeConfigLock

Restricts execution to only occur before the configuration lock period.
Reverts with `KeepWhatsRaisedConfigLocked` if called too close to or after the campaign deadline.
The lock period is defined as the duration before the deadline during which configuration changes are not allowed.


```solidity
modifier onlyBeforeConfigLock() ;
```

### onlyPlatformAdminOrCampaignOwner

Restricts access to only the platform admin or the campaign owner.

Checks if `_msgSender()` is either the platform admin (via `INFO.getPlatformAdminAddress`)
or the campaign owner (via `INFO.owner()`). Reverts with `KeepWhatsRaisedUnAuthorized` if not authorized.


```solidity
modifier onlyPlatformAdminOrCampaignOwner() ;
```

### constructor

Constructor for the KeepWhatsRaised contract.


```solidity
constructor() ;
```

### initialize


```solidity
function initialize(bytes32 _platformHash, address _infoAddress) external initializer;
```

### getWithdrawalApprovalStatus

Retrieves the withdrawal approval status.


```solidity
function getWithdrawalApprovalStatus() public view returns (bool);
```

### getReward

Retrieves the details of a reward.


```solidity
function getReward(bytes32 rewardName) external view returns (Reward memory reward);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardName`|`bytes32`|The name of the reward.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`reward`|`Reward`|The details of the reward as a `Reward` struct.|


### getRaisedAmount

Retrieves the total raised amount in the treasury.


```solidity
function getRaisedAmount() external view override returns (uint256 amount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Total raised amount across all tokens, normalized to 18 decimals.|


### getLifetimeRaisedAmount

Retrieves the lifetime raised amount in the treasury (never decreases with refunds).


```solidity
function getLifetimeRaisedAmount() external view override returns (uint256 amount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Lifetime total raised amount across all tokens, normalized to 18 decimals.|


### getRefundedAmount

Retrieves the total refunded amount in the treasury.


```solidity
function getRefundedAmount() external view override returns (uint256 amount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Total refunded amount across all tokens, normalized to 18 decimals.|


### getAvailableRaisedAmount

Retrieves the currently available raised amount in the treasury.


```solidity
function getAvailableRaisedAmount() external view returns (uint256 amount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Available raised amount across all tokens, normalized to 18 decimals.|


### getLaunchTime

Retrieves the campaign's launch time.


```solidity
function getLaunchTime() public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The timestamp when the campaign was launched.|


### getDeadline

Retrieves the campaign's deadline.


```solidity
function getDeadline() public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The timestamp when the campaign ends.|


### getGoalAmount

Retrieves the campaign's funding goal amount.


```solidity
function getGoalAmount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The funding goal amount of the campaign.|


### getPaymentGatewayFee

Retrieves the payment gateway fee for a given pledge ID.


```solidity
function getPaymentGatewayFee(bytes32 pledgeId) public view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pledgeId`|`bytes32`|The unique identifier of the pledge.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The fixed gateway fee amount associated with the pledge ID.|


### getFeeValue

Retrieves the fee value associated with a specific fee key from storage.
Flat fee keys return token amounts (18 decimals); percentage keys return basis points.


```solidity
function getFeeValue(bytes32 feeKey) public view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`feeKey`|`bytes32`|The unique identifier key used to reference a specific fee type.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The fee value corresponding to the provided fee key (0 if key is unknown).|


### setPaymentGatewayFee

Sets the fixed payment gateway fee for a specific pledge.


```solidity
function setPaymentGatewayFee(bytes32 pledgeId, uint256 fee)
    public
    onlyPlatformAdmin(PLATFORM_HASH)
    whenCampaignNotPaused
    whenNotPaused
    whenCampaignNotCancelled
    whenNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pledgeId`|`bytes32`|The unique identifier of the pledge.|
|`fee`|`uint256`|The gateway fee amount to be associated with the given pledge ID.|


### approveWithdrawal

Approves the withdrawal of the treasury by the platform admin.


```solidity
function approveWithdrawal()
    external
    onlyPlatformAdmin(PLATFORM_HASH)
    whenCampaignNotPaused
    whenNotPaused
    whenCampaignNotCancelled
    whenNotCancelled;
```

### configureTreasury

Configures the treasury for a campaign by setting the system parameters,
campaign-specific data, and fee configuration keys.


```solidity
function configureTreasury(
    Config memory config,
    CampaignData memory campaignData,
    FeeKeys memory feeKeys,
    FeeValues memory feeValues
)
    external
    onlyPlatformAdmin(PLATFORM_HASH)
    whenCampaignNotPaused
    whenNotPaused
    whenCampaignNotCancelled
    whenNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`config`|`Config`|The configuration settings including withdrawal delay, refund delay, fee exemption threshold, and configuration lock period. Must satisfy withdrawalDelay >= refundDelay so claimFund is only callable after the refund window ends.|
|`campaignData`|`CampaignData`|The campaign-related metadata such as deadlines and funding goals.|
|`feeKeys`|`FeeKeys`|The set of keys used to reference applicable flat and percentage-based fees.|
|`feeValues`|`FeeValues`|The fee values corresponding to the fee keys.|


### updateDeadline

Updates the campaign's deadline.


```solidity
function updateDeadline(uint256 deadline)
    external
    onlyPlatformAdminOrCampaignOwner
    onlyBeforeConfigLock
    whenNotPaused
    whenNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`deadline`|`uint256`|The new deadline timestamp for the campaign. Requirements: - Must be called before the configuration lock period (see `onlyBeforeConfigLock`). - The new deadline must be a future timestamp.|


### updateGoalAmount

Updates the funding goal amount for the campaign.


```solidity
function updateGoalAmount(uint256 goalAmount)
    external
    onlyPlatformAdminOrCampaignOwner
    onlyBeforeConfigLock
    whenNotPaused
    whenNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`goalAmount`|`uint256`|The new goal amount. Requirements: - Must be called before the configuration lock period (see `onlyBeforeConfigLock`).|


### addRewards

Adds multiple rewards in a batch.

This function allows for both reward tiers and non-reward tiers.
For both types, rewards must have non-zero value.
If items are specified (non-empty arrays), the itemId, itemValue, and itemQuantity arrays must match in length.
Empty arrays are allowed for both reward tiers and non-reward tiers.


```solidity
function addRewards(bytes32[] calldata rewardNames, Reward[] calldata rewards)
    external
    onlyCampaignOwner
    whenCampaignNotPaused
    whenNotPaused
    whenCampaignNotCancelled
    whenNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardNames`|`bytes32[]`|An array of reward names.|
|`rewards`|`Reward[]`|An array of `Reward` structs containing reward details.|


### removeReward

Removes a reward from the campaign.


```solidity
function removeReward(bytes32 rewardName)
    external
    onlyCampaignOwner
    currentTimeIsLess(getLaunchTime())
    whenCampaignNotPaused
    whenNotPaused
    whenCampaignNotCancelled
    whenNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardName`|`bytes32`|The name of the reward.|


### setFeeAndPledge

Sets the payment gateway fee and executes a pledge in a single transaction.


```solidity
function setFeeAndPledge(
    bytes32 pledgeId,
    address backer,
    address pledgeToken,
    uint256 pledgeAmount,
    uint256 tip,
    uint256 fee,
    bytes32[] calldata reward,
    bool isPledgeForAReward
)
    external
    nonReentrant
    onlyPlatformAdmin(PLATFORM_HASH)
    currentTimeIsWithinRange(getLaunchTime(), getDeadline())
    whenCampaignNotPaused
    whenNotPaused
    whenCampaignNotCancelled
    whenNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pledgeId`|`bytes32`|The unique identifier of the pledge.|
|`backer`|`address`|The address of the backer making the pledge.|
|`pledgeToken`|`address`||
|`pledgeAmount`|`uint256`|The amount of the pledge.|
|`tip`|`uint256`|An optional tip can be added during the process.|
|`fee`|`uint256`|The payment gateway fee to associate with this pledge.|
|`reward`|`bytes32[]`|An array of reward names.|
|`isPledgeForAReward`|`bool`|A boolean indicating whether this pledge is for a reward or without..|


### pledgeForAReward

Allows a backer to pledge for a reward using a Permit2 signature.

Tokens are transferred from `backer` via Permit2 `permitWitnessTransferFrom`.
The permit's witness commits to `pledgeId`, `backer`, the reward array hash, and
`tip`, so the caller cannot tamper with those parameters after the backer has signed.


```solidity
function pledgeForAReward(
    bytes32 pledgeId,
    address backer,
    address pledgeToken,
    uint256 tip,
    bytes32[] calldata reward,
    PermitData calldata permitData
)
    public
    nonReentrant
    currentTimeIsWithinRange(getLaunchTime(), getDeadline())
    whenCampaignNotPaused
    whenNotPaused
    whenCampaignNotCancelled
    whenNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pledgeId`|`bytes32`|The unique identifier of the pledge.|
|`backer`|`address`|The address of the backer making the pledge (must be the permit signer).|
|`pledgeToken`|`address`|The token to use for the pledge.|
|`tip`|`uint256`|An optional tip can be added during the process.|
|`reward`|`bytes32[]`|An array of reward names.|
|`permitData`|`PermitData`|Permit2 permit data (nonce, deadline, signature) signed by `backer`.|


### _pledgeForAReward

Internal function that allows a backer to pledge for a reward.

Called by both the public `pledgeForAReward` (Permit2 transfer) and
`setFeeAndPledge` (admin ERC20 transfer).


```solidity
function _pledgeForAReward(
    bytes32 pledgeId,
    address backer,
    address pledgeToken,
    uint256 tip,
    bytes32[] memory reward,
    address tokenSource,
    bool usePermit2,
    PermitData memory permitData
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pledgeId`|`bytes32`|The unique identifier of the pledge.|
|`backer`|`address`|The address of the backer making the pledge (receives the NFT).|
|`pledgeToken`|`address`|The token to use for the pledge.|
|`tip`|`uint256`|An optional tip can be added during the process.|
|`reward`|`bytes32[]`|An array of reward names.|
|`tokenSource`|`address`|Token source address for the admin (ERC20) path.|
|`usePermit2`|`bool`|Whether to transfer tokens via Permit2 or direct ERC20 transfer.|
|`permitData`|`PermitData`|Permit2 data for the direct user path.|


### pledgeWithoutAReward

Allows a backer to pledge without selecting a reward using a Permit2 signature.

Tokens are transferred from `backer` via Permit2 `permitWitnessTransferFrom`.
The permit's witness commits to `pledgeId`, `backer`, `pledgeAmount`, and `tip`.


```solidity
function pledgeWithoutAReward(
    bytes32 pledgeId,
    address backer,
    address pledgeToken,
    uint256 pledgeAmount,
    uint256 tip,
    PermitData calldata permitData
)
    public
    nonReentrant
    currentTimeIsWithinRange(getLaunchTime(), getDeadline())
    whenCampaignNotPaused
    whenNotPaused
    whenCampaignNotCancelled
    whenNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pledgeId`|`bytes32`|The unique identifier of the pledge.|
|`backer`|`address`|The address of the backer making the pledge (must be the permit signer).|
|`pledgeToken`|`address`|The token to use for the pledge.|
|`pledgeAmount`|`uint256`|The amount of the pledge (in token's native decimals).|
|`tip`|`uint256`|An optional tip (in token's native decimals).|
|`permitData`|`PermitData`|Permit2 permit data (nonce, deadline, signature) signed by `backer`.|


### _pledgeWithoutAReward

Internal function that allows a backer to pledge without a reward.

Called by both the public `pledgeWithoutAReward` (Permit2 transfer) and
`setFeeAndPledge` (admin ERC20 transfer).


```solidity
function _pledgeWithoutAReward(
    bytes32 pledgeId,
    address backer,
    address pledgeToken,
    uint256 pledgeAmount,
    uint256 tip,
    address tokenSource,
    bool usePermit2,
    PermitData memory permitData
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pledgeId`|`bytes32`|The unique identifier of the pledge.|
|`backer`|`address`|The address of the backer making the pledge (receives the NFT).|
|`pledgeToken`|`address`|The token to use for the pledge.|
|`pledgeAmount`|`uint256`|The amount of the pledge.|
|`tip`|`uint256`|An optional tip.|
|`tokenSource`|`address`|Token source address for the admin (ERC20) path.|
|`usePermit2`|`bool`|Whether to transfer tokens via Permit2 or direct ERC20 transfer.|
|`permitData`|`PermitData`|Permit2 data for the direct user path.|


### withdraw

Withdraws funds from the treasury.


```solidity
function withdraw()
    public
    view
    override
    whenCampaignNotPaused
    whenCampaignNotCancelled
    whenNotPaused
    whenNotCancelled;
```

### _colombianCreatorTax

Computes Colombian creator tax with a single accounting model to avoid double-counting.
- Partial withdrawal: `amount` is NET (what the creator receives). Tax is additive (fee on top).
Formula: tax = ceil(net * 40 / 10000). Rounded up per Colombian Peso precision requirements.
- Final withdrawal: `amount` is GROSS (full remaining balance). Tax is deducted from it.
Formula: tax = ceil(gross * 40 / 10040) (tax-inclusive rate). Rounded up per Colombian Peso.


```solidity
function _colombianCreatorTax(uint256 amount, bool isFromGross) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The net amount (partial) or gross amount (final) in token units.|
|`isFromGross`|`bool`|True for final withdrawal (amount = full balance), false for partial (amount = net to creator).|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Tax amount in token units (rounded up).|


### withdraw

Allows the campaign owner or platform admin to withdraw funds, applying required fees and taxes.
Accounting model (per product requirement):
- Partial withdrawal: Creator receives the full requested amount; fees (including Colombian tax) are additive
(deducted from the pool in addition). So: pool -= amount + totalFee, creator gets amount (net).
- Final withdrawal: Fees (including Colombian tax) are cut from the remaining balance; creator receives
the remainder. So: pool -= withdrawalAmount, creator gets withdrawalAmount - totalFee (net).


```solidity
function withdraw(address token, uint256 amount)
    public
    onlyPlatformAdminOrCampaignOwner
    currentTimeIsLess(getDeadline() + s_config.withdrawalDelay)
    whenCampaignNotPaused
    whenCampaignNotCancelled
    whenNotPaused
    whenNotCancelled
    withdrawalEnabled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The token to withdraw.|
|`amount`|`uint256`|The withdrawal amount (ignored for final withdrawals). For partial, this is the NET amount to transfer to the creator; fees are additive. Requirements: - Caller must be authorized. - Withdrawals must be enabled, not paused, and within the withdrawal window (current time < deadline + withdrawalDelay). - Token must be accepted for the campaign. - For partial withdrawals: - `amount` > 0 and `amount + fees` ≤ available balance. - For final withdrawals: - Available balance > 0 and fees ≤ available balance. Effects: - Deducts fees (flat, cumulative, and Colombian tax if applicable). - Updates available balance per token. - Transfers net funds to the recipient. Reverts: - If insufficient funds or invalid input. Emits: - `WithdrawalWithFeeSuccessful`.|


### claimRefund

Allows a backer to claim a refund associated with a specific pledge (token ID).


```solidity
function claimRefund(uint256 tokenId)
    external
    currentTimeIsGreater(getLaunchTime())
    whenCampaignNotPaused
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The ID of the token representing the backer's pledge. Requirements: - Refund delay must have passed. - The token must be eligible for a refund and not previously claimed.|


### disburseFees

Disburses all accumulated fees to the appropriate fee collector or treasury.
Callable before or after cancellation so that accrued fees are never trapped.
Requirements:
- Only callable when fees are available.


```solidity
function disburseFees() public override whenCampaignNotPaused whenNotPaused;
```

### claimTip

Allows an authorized claimer to collect tips contributed during the campaign.
Requirements:
- Caller must be authorized to claim tips.
- Tip amount must be non-zero.


```solidity
function claimTip() external onlyPlatformAdmin(PLATFORM_HASH) whenCampaignNotPaused whenNotPaused;
```

### claimFund

Allows the platform admin to claim the remaining funds from a campaign.
Requirements:
- Claim period must have started and funds must be available.
- Cannot be previously claimed.


```solidity
function claimFund() external onlyPlatformAdmin(PLATFORM_HASH) whenCampaignNotPaused whenNotPaused;
```

### cancelTreasury

This function is overridden to allow the platform admin and the campaign owner to cancel a treasury.


```solidity
function cancelTreasury(bytes32 message) public override onlyPlatformAdminOrCampaignOwner;
```

### _checkSuccessCondition

Internal function to check the success condition for fee disbursement.


```solidity
function _checkSuccessCondition() internal view virtual override returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the success condition is met.|


### _pledge

Processes a pledge: transfers tokens, mints NFT, and updates state.

Mints a pledge NFT via `_safeMint`; reverts if `backer` is a contract that does not implement `IERC721Receiver`.


```solidity
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
) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pledgeId`|`bytes32`|Unique identifier for the pledge.|
|`backer`|`address`|Recipient of the pledge NFT.|
|`pledgeToken`|`address`|Token used for the pledge.|
|`reward`|`bytes32`|First reward tier (ZERO_BYTES for non-reward pledges).|
|`pledgeAmount`|`uint256`|Pledge amount in the token's native decimals (must be denormalized by caller).|
|`tip`|`uint256`|Tip amount in the token's native decimals.|
|`rewards`|`bytes32[]`|Full reward selection (for event).|
|`tokenSource`|`address`|Address from which tokens are transferred.|
|`usePermit2`|`bool`||
|`permitData`|`PermitData`||


### _calculateNetAvailable

Calculates the net amount available from a pledge after deducting
all applicable fees.

The function performs the following:
- Applies all configured gross percentage-based fees
- Applies payment gateway fee for the given pledge
- Applies protocol fee based on protocol configuration
- Accumulates total platform and protocol fees per token
- Records the total deducted fee for the token


```solidity
function _calculateNetAvailable(bytes32 pledgeId, address pledgeToken, uint256 tokenId, uint256 pledgeAmount)
    internal
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pledgeId`|`bytes32`|The unique identifier of the pledge|
|`pledgeToken`|`address`|The token used for the pledge|
|`tokenId`|`uint256`|The token ID representing the pledge|
|`pledgeAmount`|`uint256`|The original pledged amount before deductions|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The net available amount after all fees are deducted|


### _getEffectiveCancellationTime

Returns the effective cancellation time by consulting both the treasury's own
cancellation state and the campaign's cancellation state. If both are cancelled,
returns the earlier timestamp so the refund window starts from the first cancellation event.
Returns 0 if neither is cancelled.


```solidity
function _getEffectiveCancellationTime() private view returns (uint256);
```

### _checkRefundPeriodStatus

Refund period logic:
- If cancelled (treasury or campaign): refund period is active until cancellationTime + s_config.refundDelay
- If not cancelled: refund period is active until deadline + s_config.refundDelay
- Before deadline (non-cancelled): not in refund period

Checks the refund period status based on campaign state

This function handles both cancelled and non-cancelled campaign scenarios


```solidity
function _checkRefundPeriodStatus(bool checkIfOver) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`checkIfOver`|`bool`|If true, returns whether refund period is over; if false, returns whether currently within refund period|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool Status based on checkIfOver parameter|


## Events
### Receipt
Emitted when a backer makes a pledge.


```solidity
event Receipt(
    address indexed backer,
    address indexed pledgeToken,
    bytes32 reward,
    uint256 pledgeAmount,
    uint256 tip,
    uint256 tokenId,
    bytes32[] rewards
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`backer`|`address`|The address of the backer making the pledge.|
|`pledgeToken`|`address`|The token used for the pledge.|
|`reward`|`bytes32`|The name of the reward.|
|`pledgeAmount`|`uint256`|The amount pledged.|
|`tip`|`uint256`|An optional tip can be added during the process.|
|`tokenId`|`uint256`|The ID of the token representing the pledge.|
|`rewards`|`bytes32[]`|An array of reward names.|

### RewardsAdded
Emitted when rewards are added to the campaign.


```solidity
event RewardsAdded(bytes32[] rewardNames, Reward[] rewards);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardNames`|`bytes32[]`|The names of the rewards.|
|`rewards`|`Reward[]`|The details of the rewards.|

### RewardRemoved
Emitted when a reward is removed from the campaign.


```solidity
event RewardRemoved(bytes32 indexed rewardName);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardName`|`bytes32`|The name of the reward.|

### WithdrawalApproved
Emitted when withdrawal functionality has been approved by the platform admin.


```solidity
event WithdrawalApproved();
```

### TreasuryConfigured
Emitted when the treasury configuration is updated.


```solidity
event TreasuryConfigured(Config config, CampaignData campaignData, FeeKeys feeKeys, FeeValues feeValues);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`config`|`Config`|The updated configuration parameters (e.g., delays, exemptions).|
|`campaignData`|`CampaignData`|The campaign-related data associated with the treasury setup.|
|`feeKeys`|`FeeKeys`|The set of keys used to determine applicable fees.|
|`feeValues`|`FeeValues`|The fee values corresponding to the fee keys.|

### WithdrawalWithFeeSuccessful
Emitted when a withdrawal is successfully processed along with the applied fee.


```solidity
event WithdrawalWithFeeSuccessful(address indexed to, uint256 amount, uint256 fee);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The recipient address receiving the funds.|
|`amount`|`uint256`|The total amount withdrawn (excluding fee).|
|`fee`|`uint256`|The fee amount deducted from the withdrawal.|

### TipClaimed
Emitted when a tip is claimed from the contract.


```solidity
event TipClaimed(uint256 amount, address indexed claimer);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of tip claimed.|
|`claimer`|`address`|The address that claimed the tip.|

### FundClaimed
Emitted when campaign or user's remaining funds are successfully claimed by the platform admin.


```solidity
event FundClaimed(uint256 amount, address indexed claimer);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of funds claimed.|
|`claimer`|`address`|The address that claimed the funds.|

### RefundClaimed
Emitted when a refund is claimed.


```solidity
event RefundClaimed(uint256 indexed tokenId, uint256 refundAmount, address indexed claimer);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The ID of the token representing the pledge.|
|`refundAmount`|`uint256`|The refund amount claimed.|
|`claimer`|`address`|The address of the claimer.|

### KeepWhatsRaisedDeadlineUpdated
Emitted when the deadline of the campaign is updated.


```solidity
event KeepWhatsRaisedDeadlineUpdated(uint256 newDeadline);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newDeadline`|`uint256`|The new deadline.|

### KeepWhatsRaisedGoalAmountUpdated
Emitted when the goal amount for a campaign is updated.


```solidity
event KeepWhatsRaisedGoalAmountUpdated(uint256 newGoalAmount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newGoalAmount`|`uint256`|The new goal amount set for the campaign.|

### KeepWhatsRaisedPaymentGatewayFeeSet
Emitted when a gateway fee is set for a specific pledge.


```solidity
event KeepWhatsRaisedPaymentGatewayFeeSet(bytes32 indexed pledgeId, uint256 fee);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pledgeId`|`bytes32`|The unique identifier of the pledge.|
|`fee`|`uint256`|The amount of the payment gateway fee set.|

## Errors
### KeepWhatsRaisedUnAuthorized
Emitted when an unauthorized action is attempted.


```solidity
error KeepWhatsRaisedUnAuthorized();
```

### KeepWhatsRaisedInvalidInput
Emitted when an invalid input is detected.


```solidity
error KeepWhatsRaisedInvalidInput(TreasuryErrors.InvalidInput code);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`code`|`TreasuryErrors.InvalidInput`|Error code defined in {TreasuryErrors.InvalidInput}.|

### KeepWhatsRaisedDuplicateFeeKey
Emitted when fee keys are not unique (duplicate or overlap between flat and percentage keys).


```solidity
error KeepWhatsRaisedDuplicateFeeKey();
```

### KeepWhatsRaisedPercentageFeeExceedsMax
Emitted when a percentage fee value is >= PERCENT_DIVIDER (100%).


```solidity
error KeepWhatsRaisedPercentageFeeExceedsMax();
```

### KeepWhatsRaisedAggregatePercentageExceedsMax
Emitted when the sum of gross percentage fees is >= PERCENT_DIVIDER (100%).


```solidity
error KeepWhatsRaisedAggregatePercentageExceedsMax();
```

### KeepWhatsRaisedLaunchTimeInPast
Reverts when campaign launch time is in the past.


```solidity
error KeepWhatsRaisedLaunchTimeInPast();
```

### KeepWhatsRaisedDeadlineNotAfterLaunch
Reverts when campaign deadline is not after launch time.


```solidity
error KeepWhatsRaisedDeadlineNotAfterLaunch();
```

### KeepWhatsRaisedZeroRewardName
Reverts when reward name is zero bytes.


```solidity
error KeepWhatsRaisedZeroRewardName();
```

### KeepWhatsRaisedZeroRewardValue
Reverts when reward value is zero.


```solidity
error KeepWhatsRaisedZeroRewardValue();
```

### KeepWhatsRaisedRewardItemArrayLengthMismatch
Reverts when reward item arrays have mismatched lengths.


```solidity
error KeepWhatsRaisedRewardItemArrayLengthMismatch();
```

### KeepWhatsRaisedZeroBacker
Reverts when backer address is zero.


```solidity
error KeepWhatsRaisedZeroBacker();
```

### KeepWhatsRaisedRewardSelectionLengthMismatch
Reverts when reward selection length exceeds number of rewards.


```solidity
error KeepWhatsRaisedRewardSelectionLengthMismatch();
```

### KeepWhatsRaisedFirstRewardNotTier
Reverts when first reward is not a reward tier.


```solidity
error KeepWhatsRaisedFirstRewardNotTier();
```

### KeepWhatsRaisedRefundAmountZero
Reverts when refund amount is zero.


```solidity
error KeepWhatsRaisedRefundAmountZero();
```

### KeepWhatsRaisedInsufficientAvailableForRefund
Reverts when insufficient available balance for refund.


```solidity
error KeepWhatsRaisedInsufficientAvailableForRefund(uint256 tokenId);
```

### KeepWhatsRaisedClaimFundWindowNotReached
Reverts when claimFund is called before refund delay (cancelled) or withdrawal delay (not cancelled).


```solidity
error KeepWhatsRaisedClaimFundWindowNotReached();
```

### KeepWhatsRaisedTokenNotAccepted
Emitted when a token is not accepted for the campaign.


```solidity
error KeepWhatsRaisedTokenNotAccepted(address token);
```

### KeepWhatsRaisedRewardExists
Emitted when a `Reward` already exists for given input.


```solidity
error KeepWhatsRaisedRewardExists();
```

### KeepWhatsRaisedDisabled
Emitted when anyone called a disabled function.


```solidity
error KeepWhatsRaisedDisabled();
```

### KeepWhatsRaisedAlreadyEnabled
Emitted when any functionality is already enabled and cannot be re-enabled.


```solidity
error KeepWhatsRaisedAlreadyEnabled();
```

### KeepWhatsRaisedInsufficientFundsForWithdrawalAndFee
Emitted when a withdrawal attempt exceeds the available funds after accounting for the fee.


```solidity
error KeepWhatsRaisedInsufficientFundsForWithdrawalAndFee(
    uint256 availableAmount, uint256 withdrawalAmount, uint256 fee
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`availableAmount`|`uint256`|The maximum amount that can be withdrawn.|
|`withdrawalAmount`|`uint256`|The attempted withdrawal amount.|
|`fee`|`uint256`|The fee that would be applied to the withdrawal.|

### KeepWhatsRaisedInsufficientFundsForFee
Emitted when the fee exceeds the requested withdrawal amount.


```solidity
error KeepWhatsRaisedInsufficientFundsForFee(uint256 withdrawalAmount, uint256 fee);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`withdrawalAmount`|`uint256`|The amount requested for withdrawal.|
|`fee`|`uint256`|The calculated fee, which is greater than the withdrawal amount.|

### KeepWhatsRaisedAlreadyWithdrawn
Emitted when a withdrawal has already been made and cannot be repeated.


```solidity
error KeepWhatsRaisedAlreadyWithdrawn();
```

### KeepWhatsRaisedAlreadyClaimed
Emitted when funds or rewards have already been claimed for the given context.


```solidity
error KeepWhatsRaisedAlreadyClaimed();
```

### KeepWhatsRaisedFundAlreadyClaimed
Emitted when an operation is attempted after the platform admin has already claimed the treasury funds.


```solidity
error KeepWhatsRaisedFundAlreadyClaimed();
```

### KeepWhatsRaisedNotClaimable
Emitted when a token or pledge is not eligible for claiming (e.g., claim period not reached or not valid).


```solidity
error KeepWhatsRaisedNotClaimable(uint256 tokenId, TreasuryErrors.NotClaimable code);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The ID of the token that was attempted to be claimed.|
|`code`|`TreasuryErrors.NotClaimable`|Error code defined in {TreasuryErrors.NotClaimable}.|

### KeepWhatsRaisedNotClaimableAdmin
Emitted when an admin attempts to claim funds that are not yet claimable according to the rules.


```solidity
error KeepWhatsRaisedNotClaimableAdmin();
```

### KeepWhatsRaisedConfigLocked
Emitted when a configuration change is attempted during the lock period.


```solidity
error KeepWhatsRaisedConfigLocked();
```

### KeepWhatsRaisedAlreadyConfigured
Thrown when configureTreasury is called after the treasury has already been configured.


```solidity
error KeepWhatsRaisedAlreadyConfigured();
```

### KeepWhatsRaisedWithdrawalBeforeRefundEnd
Reverts when withdrawalDelay is less than refundDelay, which would allow claimFund
to be callable before the refund window ends (refund window: (deadline, deadline + refundDelay]).


```solidity
error KeepWhatsRaisedWithdrawalBeforeRefundEnd(uint256 withdrawalDelay, uint256 refundDelay);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`withdrawalDelay`|`uint256`|The configured withdrawal delay.|
|`refundDelay`|`uint256`|The configured refund delay.|

### KeepWhatsRaisedDisbursementBlocked
Emitted when a disbursement is attempted before the refund period has ended.


```solidity
error KeepWhatsRaisedDisbursementBlocked();
```

### KeepWhatsRaisedPledgeAlreadyProcessed
Emitted when a pledge is submitted using a pledgeId that has already been processed.


```solidity
error KeepWhatsRaisedPledgeAlreadyProcessed(bytes32 pledgeId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pledgeId`|`bytes32`|The unique identifier of the pledge that was already used.|

## Structs
### FeeKeys
Represents keys used to reference different fee configurations.
These keys are typically used to look up fee values stored in `s_platformData`.


```solidity
struct FeeKeys {
    /// @dev Key for a flat fee applied to an operation.
    bytes32 flatFeeKey;
    /// @dev Key for a cumulative flat fee, potentially across multiple actions.
    bytes32 cumulativeFlatFeeKey;
    /// @dev Keys for gross percentage-based fees (calculated before deductions).
    bytes32[] grossPercentageFeeKeys;
}
```

### FeeValues
Represents the complete fee structure values for treasury operations.
These values correspond to the fees that will be applied to transactions
and are typically retrieved using keys from `FeeKeys` struct.


```solidity
struct FeeValues {
    /// @dev Value for a flat fee applied to an operation.
    uint256 flatFeeValue;
    /// @dev Value for a cumulative flat fee, potentially across multiple actions.
    uint256 cumulativeFlatFeeValue;
    /// @dev Values for gross percentage-based fees (calculated before deductions).
    uint256[] grossPercentageFeeValues;
}
```

### Config
System configuration parameters related to withdrawal and refund behavior.


```solidity
struct Config {
    /// @dev The minimum withdrawal amount required to qualify for fee exemption.
    uint256 minimumWithdrawalForFeeExemption;
    /// @dev Time delay (in timestamp) after the campaign deadline until which the campaign owner may withdraw.
    ///      Withdrawal is allowed only while current time is less than deadline + withdrawalDelay.
    ///      After deadline + withdrawalDelay, the withdrawal function is no longer callable.
    uint256 withdrawalDelay;
    /// @dev Time delay (in timestamp) before a refund becomes claimable or processed.
    uint256 refundDelay;
    /// @dev Duration (in timestamp) for which config changes are locked to prevent immediate updates.
    uint256 configLockPeriod;
    /// @dev True if the creator is Colombian, false otherwise.
    bool isColombianCreator;
}
```

