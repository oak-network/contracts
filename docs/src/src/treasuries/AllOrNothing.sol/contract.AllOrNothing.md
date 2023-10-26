# AllOrNothing
[Git Source](https://github.com/ccprotocol/campaign-utils-contracts-aggregator/blob/79d78188e565502f83e2c0309c9a4ea3b35cee91/src/treasuries/AllOrNothing.sol)

**Inherits:**
[BaseTreasury](/src/utils/BaseTreasury.sol/abstract.BaseTreasury.md), [TimestampChecker](/src/utils/TimestampChecker.sol/abstract.TimestampChecker.md), [FiatEnabled](/src/utils/FiatEnabled.sol/abstract.FiatEnabled.md), ERC721Burnable

A contract for handling crowdfunding campaigns with rewards.


## State Variables
### PRELAUNCH_PLEDGE

```solidity
uint256 private constant PRELAUNCH_PLEDGE = 1 ether;
```


### s_tokenToPledgedAmount

```solidity
mapping(uint256 => uint256) private s_tokenToPledgedAmount;
```


### s_reward

```solidity
mapping(bytes32 => Reward) private s_reward;
```


### s_tokenIdCounter

```solidity
Counters.Counter private s_tokenIdCounter;
```


### s_rewardCounter

```solidity
Counters.Counter private s_rewardCounter;
```


## Functions
### constructor

*Constructor for the AllOrNothing contract.*


```solidity
constructor(bytes32 platformBytes, address infoAddress) ERC721("", "") BaseTreasury(platformBytes, infoAddress);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformBytes`|`bytes32`|The unique identifier of the platform.|
|`infoAddress`|`address`|The address of the campaign information contract.|


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


### addReward

Adds a reward to the campaign.


```solidity
function addReward(bytes32 rewardName, Reward calldata reward)
    external
    onlyCampaignOwner
    whenCampaignNotPaused
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardName`|`bytes32`|The name of the reward.|
|`reward`|`Reward`|The details of the reward as a `Reward` struct.|


### removeReward

Removes a reward from the campaign.


```solidity
function removeReward(bytes32 rewardName) external onlyCampaignOwner whenCampaignNotPaused whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardName`|`bytes32`|The name of the reward.|


### updateFiatPledge

Updates the fiat pledge transaction.


```solidity
function updateFiatPledge(bytes32 fiatPledgeId, uint256 fiatPledgeAmount)
    external
    onlyPlatformAdmin(PLATFORM_BYTES)
    whenCampaignNotPaused
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fiatPledgeId`|`bytes32`|The unique identifier of the fiat pledge.|
|`fiatPledgeAmount`|`uint256`|The amount of the fiat pledge.|


### updateFiatFeeDisbursementState

Updates the state of fiat fee disbursement.


```solidity
function updateFiatFeeDisbursementState(bool isDisbursed, uint256 protocolFeeAmount, uint256 platformFeeAmount)
    external
    onlyPlatformAdmin(PLATFORM_BYTES)
    whenCampaignNotPaused
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`isDisbursed`|`bool`|Whether fiat fees are disbursed.|
|`protocolFeeAmount`|`uint256`|The protocol fee amount.|
|`platformFeeAmount`|`uint256`|The platform fee amount.|


### pledgeOnPreLaunch

Allows a backer to make a pre-launch pledge.


```solidity
function pledgeOnPreLaunch(address backer)
    external
    currentTimeIsLess(INFO.getLaunchTime())
    whenCampaignNotPaused
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`backer`|`address`|The address of the backer making the pledge.|


### pledgeForAReward

Allows a backer to pledge for a reward.


```solidity
function pledgeForAReward(address backer, bytes32[] calldata reward)
    external
    currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
    whenCampaignNotPaused
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`backer`|`address`|The address of the backer making the pledge.|
|`reward`|`bytes32[]`|An array of reward names.|


### pledgeWithoutAReward

Allows a backer to pledge without selecting a reward.


```solidity
function pledgeWithoutAReward(address backer, uint256 pledgeAmount)
    external
    currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
    whenCampaignNotPaused
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`backer`|`address`|The address of the backer making the pledge.|
|`pledgeAmount`|`uint256`|The amount of the pledge.|


### claimRefund

Allows a backer to claim a refund.


```solidity
function claimRefund(uint256 tokenId)
    external
    currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
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
function disburseFees() public override currentTimeIsGreater(INFO.getDeadline());
```

### _checkIfPlatformAdmin

*Checks if the caller is the platform admin.*


```solidity
function _checkIfPlatformAdmin() internal view;
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


### supportsInterface


```solidity
function supportsInterface(bytes4 interfaceId) public view override returns (bool);
```

## Events
### Receipt
*Emitted when a backer makes a pledge.*


```solidity
event Receipt(
    address indexed backer,
    bytes32 indexed reward,
    uint256 pledgeAmount,
    uint256 tokenId,
    bool isPreLaunchPledge,
    bytes32[] rewards
);
```

### RewardAdded
*Emitted when a reward is added to the campaign.*


```solidity
event RewardAdded(bytes32 indexed rewardName, Reward reward);
```

### RewardRemoved
*Emitted when a reward is removed from the campaign.*


```solidity
event RewardRemoved(bytes32 indexed rewardName);
```

### RefundClaimed
*Emitted when a refund is claimed.*


```solidity
event RefundClaimed(uint256 tokenId, uint256 refundAmount, address claimer);
```

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

### AllOrNothingRewardExists
*Emitted when a `Reward` already exists for given input.*


```solidity
error AllOrNothingRewardExists();
```

### AllOrNothingNotClaimable
*Emitted when claiming an unclaimable refund.*


```solidity
error AllOrNothingNotClaimable(uint256 tokenId);
```

## Structs
### Reward

```solidity
struct Reward {
    uint256 rewardValue;
    bool isRewardTier;
    bytes32[] itemId;
    uint256[] itemValue;
    uint256[] itemQuantity;
}
```

