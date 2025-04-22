# OutOfStock

[Git Source](https://github.com/ccprotocol/campaign-utils-contracts-aggregator/blob/79d78188e565502f83e2c0309c9a4ea3b35cee91/src/treasuries/OutOfStock.sol)

**Inherits:**
[MinimumOrder](/src/treasuries/MinimumOrder.sol/contract.MinimumOrder.md)

A Solidity contract for managing minimum order-based campaigns with an out-of-stock limit.
Users can pre-order items or rewards until the out-of-stock limit is reached.
When the predefined success metric is reached or the out-of-stock limit is reached, the campaign ends.

## Functions

### constructor

_Constructor for the OutOfStock contract._

```solidity
constructor(bytes32 platformHash, address infoAddress) MinimumOrder(platformHash, infoAddress);
```

**Parameters**

| Name           | Type      | Description                                                          |
| -------------- | --------- | -------------------------------------------------------------------- |
| `platformHash` | `bytes32` | The unique identifier of the platform.                               |
| `infoAddress`  | `address` | The address of the CampaignInfo contract providing campaign details. |

### preOrderForAReward

Function for backers to pre-order a reward, checking against the out-of-stock limit.
The pre-order can only be made within the specified campaign timeframe.

```solidity
function preOrderForAReward(address backer, bytes32 rewardName)
    public
    override
    currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
    whenCampaignNotPaused
    whenNotPaused;
```

**Parameters**

| Name         | Type      | Description                                     |
| ------------ | --------- | ----------------------------------------------- |
| `backer`     | `address` | The address of the backer making the pre-order. |
| `rewardName` | `bytes32` | The name of the reward to pre-order.            |

## Errors

### OutOfStockLimitReached

_Throws an error indicating the out-of-stock limit has been reached._

```solidity
error OutOfStockLimitReached();
```
