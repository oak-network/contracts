# AllOrNothing
[Git Source](https://github.com/oak-network/ccprotocol-contracts-internal/blob/be3636c015d0f78c20f6d8f0de7b678aaf6d8428/src/treasuries/AllOrNothing.sol)

**Inherits:**
[IReward](/src/interfaces/IReward.sol/interface.IReward.md), [BaseTreasury](/src/utils/BaseTreasury.sol/abstract.BaseTreasury.md), [TimestampChecker](/src/utils/TimestampChecker.sol/abstract.TimestampChecker.md), ReentrancyGuard

A contract for handling crowdfunding campaigns with rewards.


## State Variables
### s_tokenToTotalCollectedAmount

```solidity
mapping(uint256 => uint256) private s_tokenToTotalCollectedAmount;
```


### s_tokenToPledgedAmount

```solidity
mapping(uint256 => uint256) private s_tokenToPledgedAmount;
```


### s_reward

```solidity
mapping(bytes32 => Reward) private s_reward;
```


### s_tokenIdToPledgeToken

```solidity
mapping(uint256 => address) private s_tokenIdToPledgeToken;
```


### s_rewardCounter

```solidity
Counters.Counter private s_rewardCounter;
```


## Functions
### constructor

*Constructor for the AllOrNothing contract.*


```solidity
constructor();
```

### initialize


```solidity
function initialize(bytes32 _platformHash, address _infoAddress, address _trustedForwarder) external initializer;
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


### addRewards

Adds multiple rewards in a batch.

*This function allows for both reward tiers and non-reward tiers.
For both types, rewards must have non-zero value.
If items are specified (non-empty arrays), the itemId, itemValue, and itemQuantity arrays must match in length.
Empty arrays are allowed for both reward tiers and non-reward tiers.*


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


### pledgeForAReward

Allows a backer to pledge for a reward.

*The first element of the `reward` array must be a reward tier and the other elements can be either reward tiers or non-reward tiers.
The non-reward tiers cannot be pledged for without a reward.*


```solidity
function pledgeForAReward(address backer, address pledgeToken, uint256 shippingFee, bytes32[] calldata reward)
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
|`backer`|`address`|The address of the backer making the pledge.|
|`pledgeToken`|`address`|The token address to use for the pledge.|
|`shippingFee`|`uint256`|The shipping fee amount.|
|`reward`|`bytes32[]`|An array of reward names.|


### pledgeWithoutAReward

Allows a backer to pledge without selecting a reward.


```solidity
function pledgeWithoutAReward(address backer, address pledgeToken, uint256 pledgeAmount)
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
|`backer`|`address`|The address of the backer making the pledge.|
|`pledgeToken`|`address`|The token address to use for the pledge.|
|`pledgeAmount`|`uint256`|The amount of the pledge.|


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

*This function is overridden to allow the platform admin and the campaign owner to cancel a treasury.*


```solidity
function cancelTreasury(bytes32 message) public override;
```

### _checkSuccessCondition

*Internal function to check the success condition for fee disbursement.*


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
    address backer,
    address pledgeToken,
    bytes32 reward,
    uint256 pledgeAmount,
    uint256 shippingFee,
    bytes32[] memory rewards
) private;
```

## Events
### Receipt
*Emitted when a backer makes a pledge.*


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
*Emitted when rewards are added to the campaign.*


```solidity
event RewardsAdded(bytes32[] rewardNames, Reward[] rewards);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardNames`|`bytes32[]`|The names of the rewards.|
|`rewards`|`Reward[]`|The details of the rewards.|

### RewardRemoved
*Emitted when a reward is removed from the campaign.*


```solidity
event RewardRemoved(bytes32 indexed rewardName);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardName`|`bytes32`|The name of the reward.|

### RefundClaimed
*Emitted when a refund is claimed.*


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
*Emitted when an unauthorized action is attempted.*


```solidity
error AllOrNothingUnAuthorized();
```

### AllOrNothingInvalidInput
*Emitted when an invalid input is detected.*


```solidity
error AllOrNothingInvalidInput();
```

### AllOrNothingTransferFailed
*Emitted when a token transfer fails.*


```solidity
error AllOrNothingTransferFailed();
```

### AllOrNothingNotSuccessful
*Emitted when the campaign is not successful.*


```solidity
error AllOrNothingNotSuccessful();
```

### AllOrNothingFeeNotDisbursed
*Emitted when fees are not disbursed.*


```solidity
error AllOrNothingFeeNotDisbursed();
```

### AllOrNothingFeeAlreadyDisbursed
*Emitted when `disburseFees` after fee is disbursed already.*


```solidity
error AllOrNothingFeeAlreadyDisbursed();
```

### AllOrNothingRewardExists
*Emitted when a `Reward` already exists for given input.*


```solidity
error AllOrNothingRewardExists();
```

### AllOrNothingTokenNotAccepted
*Emitted when a token is not accepted for the campaign.*


```solidity
error AllOrNothingTokenNotAccepted(address token);
```

### AllOrNothingNotClaimable
*Emitted when claiming an unclaimable refund.*


```solidity
error AllOrNothingNotClaimable(uint256 tokenId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The ID of the token representing the pledge.|

