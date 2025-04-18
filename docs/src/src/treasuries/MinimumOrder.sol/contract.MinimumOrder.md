# MinimumOrder

[Git Source](https://github.com/ccprotocol/campaign-utils-contracts-aggregator/blob/79d78188e565502f83e2c0309c9a4ea3b35cee91/src/treasuries/MinimumOrder.sol)

**Inherits:**
[BaseTreasury](/src/utils/BaseTreasury.sol/abstract.BaseTreasury.md), ERC721Burnable, [TimestampChecker](/src/utils/TimestampChecker.sol/abstract.TimestampChecker.md)

A Solidity contract for managing minimum order-based campaigns.
Users can pre-order items or rewards, and when a predefined success metric is reached,
the campaign succeeds, and backers receive their rewards.

## State Variables

### SUCCESS_METRIC

```solidity
uint256 internal immutable SUCCESS_METRIC;
```

### s_preOrderValueAmount

```solidity
uint256 private s_preOrderValueAmount;
```

### s_platformFeePercent

```solidity
uint256 private s_platformFeePercent;
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

### s_numberOfPreOrders

```solidity
Counters.Counter internal s_numberOfPreOrders;
```

## Functions

### constructor

_Constructor for the MinimumOrder contract._

```solidity
constructor(bytes32 platformHash, address infoAddress) ERC721("", "") BaseTreasury(platformHash, infoAddress);
```

**Parameters**

| Name           | Type      | Description                                                          |
| -------------- | --------- | -------------------------------------------------------------------- |
| `platformHash` | `bytes32` | The unique identifier of the platform.                               |
| `infoAddress`  | `address` | The address of the CampaignInfo contract providing campaign details. |

### getNumberOfOrders

bytes32 of `PreOrder0MinimumOrder(uint256)`

Function to get the number of pre-orders made.

```solidity
function getNumberOfOrders() internal view returns (uint256);
```

**Returns**

| Name     | Type      | Description               |
| -------- | --------- | ------------------------- |
| `<none>` | `uint256` | The number of pre-orders. |

### getReward

Function to get reward details by name.

```solidity
function getReward(bytes32 rewardName) external view returns (Reward memory);
```

**Parameters**

| Name         | Type      | Description             |
| ------------ | --------- | ----------------------- |
| `rewardName` | `bytes32` | The name of the reward. |

**Returns**

| Name     | Type     | Description                                                            |
| -------- | -------- | ---------------------------------------------------------------------- |
| `<none>` | `Reward` | The reward details, including value, item IDs, values, and quantities. |

### getRaisedAmount

Function to get the total raised amount during the campaign.

```solidity
function getRaisedAmount() external view returns (uint256);
```

**Returns**

| Name     | Type      | Description              |
| -------- | --------- | ------------------------ |
| `<none>` | `uint256` | The total raised amount. |

### addReward

Function to add a new reward to the campaign.
Only the campaign owner can add rewards.

```solidity
function addReward(bytes32 rewardName, Reward calldata reward)
    external
    onlyCampaignOwner
    whenCampaignNotPaused
    whenNotPaused;
```

**Parameters**

| Name         | Type      | Description                                                            |
| ------------ | --------- | ---------------------------------------------------------------------- |
| `rewardName` | `bytes32` | The name of the reward.                                                |
| `reward`     | `Reward`  | The reward details, including value, item IDs, values, and quantities. |

### removeReward

Function to remove a reward from the campaign.
Only the campaign owner can remove rewards.

```solidity
function removeReward(bytes32 rewardName) external onlyCampaignOwner whenCampaignNotPaused whenNotPaused;
```

**Parameters**

| Name         | Type      | Description                           |
| ------------ | --------- | ------------------------------------- |
| `rewardName` | `bytes32` | The name of the reward to be removed. |

### preOrderForAReward

Function for backers to pre-order a reward.
The pre-order can only be made within the specified campaign timeframe.

```solidity
function preOrderForAReward(address backer, bytes32 rewardName)
    public
    virtual
    currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
    whenCampaignNotPaused
    whenNotPaused;
```

**Parameters**

| Name         | Type      | Description                                     |
| ------------ | --------- | ----------------------------------------------- |
| `backer`     | `address` | The address of the backer making the pre-order. |
| `rewardName` | `bytes32` | The name of the reward to pre-order.            |

### claimRefund

Function for backers to claim a refund if the campaign has not met the success metric.

```solidity
function claimRefund(uint256 tokenId) external whenCampaignNotPaused whenNotPaused;
```

**Parameters**

| Name      | Type      | Description                                     |
| --------- | --------- | ----------------------------------------------- |
| `tokenId` | `uint256` | The unique token ID associated with the refund. |

### \_checkSuccessCondition

_Internal function to check the success condition for fee disbursement._

```solidity
function _checkSuccessCondition() internal view virtual override returns (bool);
```

**Returns**

| Name     | Type   | Description                           |
| -------- | ------ | ------------------------------------- |
| `<none>` | `bool` | Whether the success condition is met. |

### supportsInterface

Function to check if an address is supported by the ERC721 contract.

```solidity
function supportsInterface(bytes4 interfaceId) public view override returns (bool);
```

**Parameters**

| Name          | Type     | Description                       |
| ------------- | -------- | --------------------------------- |
| `interfaceId` | `bytes4` | The ERC721 interface ID to check. |

**Returns**

| Name     | Type   | Description                                          |
| -------- | ------ | ---------------------------------------------------- |
| `<none>` | `bool` | True if the interface is supported, false otherwise. |

## Events

### Receipt

_Event emitted when a backer makes a pledge._

```solidity
event Receipt(address indexed backer, bytes32 indexed reward, uint256 pledgeAmount, uint256 tokenId);
```

### RewardAdded

_Event emitted when a reward is added to the campaign._

```solidity
event RewardAdded(bytes32 indexed rewardName, Reward reward);
```

### RewardRemoved

_Event emitted when a reward is removed from the campaign._

```solidity
event RewardRemoved(bytes32 indexed rewardName);
```

### RefundClaimed

_Event emitted when a refund is claimed by a backer._

```solidity
event RefundClaimed(uint256 tokenId, uint256 refundAmount, address claimer);
```

## Errors

### PreOrderTransferFailed

_Throws an error indicating that the pre-order transfer failed._

```solidity
error PreOrderTransferFailed();
```

### PreOrderInvalidInput

_Throws an error indicating that the pre-order input is invalid._

```solidity
error PreOrderInvalidInput();
```

## Structs

### Reward

```solidity
struct Reward {
    uint256 rewardValue;
    bytes32[] itemId;
    uint256[] itemValue;
    uint256[] itemQuantity;
}
```
