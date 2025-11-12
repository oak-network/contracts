# KeepWhatsRaised
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/fbdbad195ebe6c636608bb8168723963b1f37dd9/src/treasuries/KeepWhatsRaised.sol)

**Inherits:**
[IReward](/Users/mahabubalahi/Documents/ccp/ccprotocol-contracts-internal/docs/src/src/interfaces/IReward.sol/interface.IReward.md), [BaseTreasury](/Users/mahabubalahi/Documents/ccp/ccprotocol-contracts-internal/docs/src/src/utils/BaseTreasury.sol/abstract.BaseTreasury.md), [TimestampChecker](/Users/mahabubalahi/Documents/ccp/ccprotocol-contracts-internal/docs/src/src/utils/TimestampChecker.sol/abstract.TimestampChecker.md), [ICampaignData](/Users/mahabubalahi/Documents/ccp/ccprotocol-contracts-internal/docs/src/src/interfaces/ICampaignData.sol/interface.ICampaignData.md), ReentrancyGuard

A contract that keeps all the funds raised, regardless of the success condition.


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
Tracks whether a pledge with a specific ID has already been processed


```solidity
mapping(bytes32 => bool) public s_processedPledges
```


### s_paymentGatewayFees
Mapping to store payment gateway fees by unique pledge ID


```solidity
mapping(bytes32 => uint256) public s_paymentGatewayFees
```


### s_feeValues
Mapping that stores fee values indexed by their corresponding fee keys.


```solidity
mapping(bytes32 => uint256) private s_feeValues
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


### s_cancellationTime

```solidity
uint256 private s_cancellationTime
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
function getRaisedAmount() external view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total raised amount as a uint256 value.|


### getLifetimeRaisedAmount

Retrieves the lifetime raised amount in the treasury (never decreases with refunds).


```solidity
function getLifetimeRaisedAmount() external view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The lifetime raised amount as a uint256 value.|


### getRefundedAmount

Retrieves the total refunded amount in the treasury.


```solidity
function getRefundedAmount() external view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total refunded amount as a uint256 value.|


### getAvailableRaisedAmount

Retrieves the currently available raised amount in the treasury.


```solidity
function getAvailableRaisedAmount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current available raised amount as a uint256 value.|


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


```solidity
function getFeeValue(bytes32 feeKey) public view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`feeKey`|`bytes32`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|{uint256} The fee value corresponding to the provided fee key.|


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
|`config`|`Config`|The configuration settings including withdrawal delay, refund delay, fee exemption threshold, and configuration lock period.|
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

Allows a backer to pledge for a reward.

The first element of the `reward` array must be a reward tier and the other elements can be either reward tiers or non-reward tiers.
The non-reward tiers cannot be pledged for without a reward.


```solidity
function pledgeForAReward(
    bytes32 pledgeId,
    address backer,
    address pledgeToken,
    uint256 tip,
    bytes32[] calldata reward
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
|`backer`|`address`|The address of the backer making the pledge.|
|`pledgeToken`|`address`|The token to use for the pledge.|
|`tip`|`uint256`|An optional tip can be added during the process.|
|`reward`|`bytes32[]`|An array of reward names.|


### _pledgeForAReward

Internal function that allows a backer to pledge for a reward with tokens transferred from a specified source.

The first element of the `reward` array must be a reward tier and the other elements can be either reward tiers or non-reward tiers.
The non-reward tiers cannot be pledged for without a reward.
This function is called internally by both public pledgeForAReward (with backer as token source) and
setFeeAndPledge (with admin as token source).


```solidity
function _pledgeForAReward(
    bytes32 pledgeId,
    address backer,
    address pledgeToken,
    uint256 tip,
    bytes32[] calldata reward,
    address tokenSource
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
|`tokenSource`|`address`|The address from which tokens will be transferred (either backer for direct calls or admin for setFeeAndPledge calls).|


### pledgeWithoutAReward

Allows a backer to pledge without selecting a reward.


```solidity
function pledgeWithoutAReward(
    bytes32 pledgeId,
    address backer,
    address pledgeToken,
    uint256 pledgeAmount,
    uint256 tip
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
|`backer`|`address`|The address of the backer making the pledge.|
|`pledgeToken`|`address`|The token to use for the pledge.|
|`pledgeAmount`|`uint256`|The amount of the pledge.|
|`tip`|`uint256`|An optional tip can be added during the process.|


### _pledgeWithoutAReward

Internal function that allows a backer to pledge without selecting a reward with tokens transferred from a specified source.

This function is called internally by both public pledgeWithoutAReward (with backer as token source) and
setFeeAndPledge (with admin as token source).


```solidity
function _pledgeWithoutAReward(
    bytes32 pledgeId,
    address backer,
    address pledgeToken,
    uint256 pledgeAmount,
    uint256 tip,
    address tokenSource
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pledgeId`|`bytes32`|The unique identifier of the pledge.|
|`backer`|`address`|The address of the backer making the pledge (receives the NFT).|
|`pledgeToken`|`address`|The token to use for the pledge.|
|`pledgeAmount`|`uint256`|The amount of the pledge.|
|`tip`|`uint256`|An optional tip can be added during the process.|
|`tokenSource`|`address`|The address from which tokens will be transferred (either backer for direct calls or admin for setFeeAndPledge calls).|


### withdraw

Withdraws funds from the treasury.


```solidity
function withdraw() public view override whenNotPaused whenNotCancelled;
```

### withdraw

Allows the campaign owner or platform admin to withdraw funds, applying required fees and taxes.


```solidity
function withdraw(address token, uint256 amount)
    public
    onlyPlatformAdminOrCampaignOwner
    currentTimeIsLess(getDeadline() + s_config.withdrawalDelay)
    whenNotPaused
    whenNotCancelled
    withdrawalEnabled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The token to withdraw.|
|`amount`|`uint256`|The withdrawal amount (ignored for final withdrawals). Requirements: - Caller must be authorized. - Withdrawals must be enabled, not paused, and within the allowed time. - Token must be accepted for the campaign. - For partial withdrawals: - `amount` > 0 and `amount + fees` ≤ available balance. - For final withdrawals: - Available balance > 0 and fees ≤ available balance. Effects: - Deducts fees (flat, cumulative, and Colombian tax if applicable). - Updates available balance per token. - Transfers net funds to the recipient. Reverts: - If insufficient funds or invalid input. Emits: - `WithdrawalWithFeeSuccessful`.|


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
Requirements:
- Only callable when fees are available.


```solidity
function disburseFees() public override whenNotPaused whenNotCancelled;
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


```solidity
function _pledge(
    bytes32 pledgeId,
    address backer,
    address pledgeToken,
    bytes32 reward,
    uint256 pledgeAmount,
    uint256 tip,
    bytes32[] memory rewards,
    address tokenSource
) private;
```

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


### _checkRefundPeriodStatus

Refund period logic:
- If campaign is cancelled: refund period is active until s_cancellationTime + s_config.refundDelay
- If campaign is not cancelled: refund period is active until deadline + s_config.refundDelay
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
error KeepWhatsRaisedInvalidInput();
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

### KeepWhatsRaisedNotClaimable
Emitted when a token or pledge is not eligible for claiming (e.g., claim period not reached or not valid).


```solidity
error KeepWhatsRaisedNotClaimable(uint256 tokenId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The ID of the token that was attempted to be claimed.|

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

    /// @dev Time delay (in timestamp) enforced before a withdrawal can be completed.
    uint256 withdrawalDelay;

    /// @dev Time delay (in timestamp) before a refund becomes claimable or processed.
    uint256 refundDelay;

    /// @dev Duration (in timestamp) for which config changes are locked to prevent immediate updates.
    uint256 configLockPeriod;

    /// @dev True if the creator is Colombian, false otherwise.
    bool isColombianCreator;
}
```

