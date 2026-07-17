# AllOrNothing
[Git Source](https://github.com/oak-network/contracts/blob/6c7f67f5ed14ef0f4f9444b95ac6770ae2af756a/src/treasuries/AllOrNothing.sol)

**Inherits:**
[IReward](/src/interfaces/IReward.sol/interface.IReward.md), [BaseTreasury](/src/utils/BaseTreasury.sol/abstract.BaseTreasury.md), [TimestampChecker](/src/utils/TimestampChecker.sol/abstract.TimestampChecker.md)

**Title:**
AllOrNothing

A contract for handling "all-or-nothing" crowdfunding campaigns. Funds are only claimable by the campaign owner if the funding goal is met by the deadline; otherwise, backers can claim refunds.


## Constants
### AON_PLEDGE_FOR_REWARD_WITNESS_TYPEHASH

```solidity
bytes32 internal constant AON_PLEDGE_FOR_REWARD_WITNESS_TYPEHASH =
    keccak256("PledgeForRewardWitness(address backer,bytes32 rewardsHash,uint256 shippingFee)")
```


### AON_PLEDGE_FOR_REWARD_WITNESS_TYPE_STRING

```solidity
string internal constant AON_PLEDGE_FOR_REWARD_WITNESS_TYPE_STRING =
    "PledgeForRewardWitness witness)PledgeForRewardWitness(address backer,bytes32 rewardsHash,uint256 shippingFee)TokenPermissions(address token,uint256 amount)"
```


### AON_PLEDGE_WITHOUT_REWARD_WITNESS_TYPEHASH

```solidity
bytes32 internal constant AON_PLEDGE_WITHOUT_REWARD_WITNESS_TYPEHASH =
    keccak256("PledgeWithoutRewardWitness(address backer,uint256 pledgeAmount)")
```


### AON_PLEDGE_WITHOUT_REWARD_WITNESS_TYPE_STRING

```solidity
string internal constant AON_PLEDGE_WITHOUT_REWARD_WITNESS_TYPE_STRING =
    "PledgeWithoutRewardWitness witness)PledgeWithoutRewardWitness(address backer,uint256 pledgeAmount)TokenPermissions(address token,uint256 amount)"
```


## State Variables
### s_tokenToTotalCollectedAmount

```solidity
mapping(uint256 => uint256) private s_tokenToTotalCollectedAmount
```


### s_tokenToPledgedAmount

```solidity
mapping(uint256 => uint256) private s_tokenToPledgedAmount
```


### s_reward

```solidity
mapping(bytes32 => Reward) private s_reward
```


### s_tokenIdToPledgeToken

```solidity
mapping(uint256 => address) private s_tokenIdToPledgeToken
```


### s_rewardCounter

```solidity
Counters.Counter private s_rewardCounter
```


## Functions
### constructor

Constructor for the AllOrNothing contract.


```solidity
constructor() ;
```

### initialize


```solidity
function initialize(bytes32 _platformHash, address _infoAddress) external initializer;
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
    currentTimeIsLess(INFO.getLaunchTime())
    whenCampaignNotPaused
    whenNotPaused
    whenCampaignNotCancelled
    whenNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardName`|`bytes32`|The name of the reward.|


### pledgeForAReward

Allows a backer to pledge for a reward using a Permit2 signature.

Tokens are transferred from `backer` via Permit2 `permitWitnessTransferFrom`.
The permit's witness commits to `backer`, the reward array hash, and `shippingFee`,
so the caller cannot change those values after the backer has signed.


```solidity
function pledgeForAReward(
    address backer,
    address pledgeToken,
    uint256 shippingFee,
    bytes32[] calldata reward,
    PermitData calldata permitData
)
    external
    nonReentrant
    currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
    whenCampaignNotPaused
    whenNotPaused
    whenCampaignNotCancelled
    whenNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`backer`|`address`|The address of the backer making the pledge (must be the permit signer).|
|`pledgeToken`|`address`|The token address to use for the pledge.|
|`shippingFee`|`uint256`|The shipping fee amount.|
|`reward`|`bytes32[]`|An array of reward names.|
|`permitData`|`PermitData`|Permit2 permit data (nonce, deadline, signature) signed by `backer`.|


### pledgeWithoutAReward

Allows a backer to pledge without selecting a reward using a Permit2 signature.

Tokens are transferred from `backer` via Permit2 `permitWitnessTransferFrom`.
The permit's witness commits to `backer` and `pledgeAmount`.


```solidity
function pledgeWithoutAReward(
    address backer,
    address pledgeToken,
    uint256 pledgeAmount,
    PermitData calldata permitData
)
    external
    nonReentrant
    currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
    whenCampaignNotPaused
    whenNotPaused
    whenCampaignNotCancelled
    whenNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`backer`|`address`|The address of the backer making the pledge (must be the permit signer).|
|`pledgeToken`|`address`|The token address to use for the pledge.|
|`pledgeAmount`|`uint256`|The amount of the pledge (in token's native decimals).|
|`permitData`|`PermitData`|Permit2 permit data (nonce, deadline, signature) signed by `backer`.|


### claimRefund

Allows a backer to claim a refund.


```solidity
function claimRefund(uint256 tokenId)
    external
    currentTimeIsGreater(INFO.getLaunchTime())
    whenCampaignNotPaused
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The ID of the token representing the pledge.|


### disburseFees

Disburses fees collected by the treasury.


```solidity
function disburseFees() public override currentTimeIsGreater(INFO.getDeadline()) whenNotPaused whenNotCancelled;
```

### withdraw

Withdraws funds from the treasury.


```solidity
function withdraw() public override whenNotPaused whenNotCancelled;
```

### cancelTreasury

This function is overridden to allow the platform admin and the campaign owner to cancel a treasury.


```solidity
function cancelTreasury(bytes32 message) public override;
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
    address backer,
    address pledgeToken,
    bytes32 reward,
    uint256 pledgeAmount,
    uint256 shippingFee,
    bytes32[] memory rewards,
    PermitData calldata permitData
) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`backer`|`address`|Recipient of the pledge NFT.|
|`pledgeToken`|`address`|Token used for the pledge.|
|`reward`|`bytes32`|First reward tier (ZERO_BYTES for non-reward pledges).|
|`pledgeAmount`|`uint256`|Pledge amount in the token's native decimals (must be denormalized by caller).|
|`shippingFee`|`uint256`|Shipping fee in the token's native decimals (must be denormalized by caller; use 0 for non-reward).|
|`rewards`|`bytes32[]`|Full reward selection (for event).|
|`permitData`|`PermitData`||


## Events
### Receipt
Emitted when a backer makes a pledge.


```solidity
event Receipt(
    address indexed backer,
    address indexed pledgeToken,
    bytes32 reward,
    uint256 pledgeAmount,
    uint256 shippingFee,
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
|`shippingFee`|`uint256`||
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

### RefundClaimed
Emitted when a refund is claimed.


```solidity
event RefundClaimed(uint256 tokenId, uint256 refundAmount, address claimer);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The ID of the token representing the pledge.|
|`refundAmount`|`uint256`|The refund amount claimed.|
|`claimer`|`address`|The address of the claimer.|

## Errors
### AllOrNothingUnAuthorized
Emitted when an unauthorized action is attempted.


```solidity
error AllOrNothingUnAuthorized();
```

### AllOrNothingInvalidInput
Emitted when an invalid input is detected.


```solidity
error AllOrNothingInvalidInput(TreasuryErrors.InvalidInput code);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`code`|`TreasuryErrors.InvalidInput`|Error code defined in {TreasuryErrors.InvalidInput}.|

### AllOrNothingZeroRewardName
Reverts when reward name is zero bytes.


```solidity
error AllOrNothingZeroRewardName();
```

### AllOrNothingZeroRewardValue
Reverts when reward value is zero.


```solidity
error AllOrNothingZeroRewardValue();
```

### AllOrNothingRewardItemArrayLengthMismatch
Reverts when reward item arrays have mismatched lengths.


```solidity
error AllOrNothingRewardItemArrayLengthMismatch();
```

### AllOrNothingZeroBacker
Reverts when backer address is zero.


```solidity
error AllOrNothingZeroBacker();
```

### AllOrNothingRewardSelectionLengthMismatch
Reverts when reward selection length exceeds number of rewards.


```solidity
error AllOrNothingRewardSelectionLengthMismatch();
```

### AllOrNothingFirstRewardNotTier
Reverts when first reward is not a reward tier.


```solidity
error AllOrNothingFirstRewardNotTier();
```

### AllOrNothingTransferFailed
Emitted when a token transfer fails.


```solidity
error AllOrNothingTransferFailed();
```

### AllOrNothingNotSuccessful
Emitted when the campaign is not successful.


```solidity
error AllOrNothingNotSuccessful();
```

### AllOrNothingFeeNotDisbursed
Emitted when fees are not disbursed.


```solidity
error AllOrNothingFeeNotDisbursed();
```

### AllOrNothingRewardExists
Emitted when a `Reward` already exists for given input.


```solidity
error AllOrNothingRewardExists();
```

### AllOrNothingTokenNotAccepted
Emitted when a token is not accepted for the campaign.


```solidity
error AllOrNothingTokenNotAccepted(address token);
```

### AllOrNothingNotClaimable
Emitted when claiming an unclaimable refund.


```solidity
error AllOrNothingNotClaimable(uint256 tokenId, TreasuryErrors.NotClaimable code);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The ID of the token representing the pledge.|
|`code`|`TreasuryErrors.NotClaimable`|Error code defined in {TreasuryErrors.NotClaimable}.|

