# KeepWhatsRaised

[Git Source](https://github.com/ccprotocol/campaign-utils-contracts-aggregator/blob/79d78188e565502f83e2c0309c9a4ea3b35cee91/src/treasuries/KeepWhatsRaised.sol)

**Inherits:**
[IReward](/src/interfaces/IReward.sol/interface.IReward.md), [BaseTreasury](/src/utils/BaseTreasury.sol/abstract.BaseTreasury.md), [TimestampChecker](/src/utils/TimestampChecker.sol/abstract.TimestampChecker.md), ERC721Burnable, [ICampaignData](/src/interfaces/ICampaignData.sol/interface.ICampaignData.md)

A contract that keeps all the funds raised, regardless of the success condition.

_This contract inherits from the `AllOrNothing` contract and overrides the `_checkSuccessCondition` function to always return true._

## Functions

### constructor

_Initializes the KeepWhatsRaised contract._

```solidity
constructor(bytes32 platformHash, address infoAddress) AllOrNothing(platformHash, infoAddress);
```
**Parameters**

| Name           | Type      | Description                                                  |
| -------------- | --------- | ------------------------------------------------------------ |
| `platformHash` | `bytes32` | The unique identifier of the platform.                       |
| `infoAddress`  | `address` | The address of the associated campaign information contract. |

### \_checkSuccessCondition

_Internal function to check the success condition for fee disbursement._

```solidity
function _checkSuccessCondition() internal pure override returns (bool);
```

**Returns**

| Name     | Type   | Description                           |
| -------- | ------ | ------------------------------------- |
| `<none>` | `bool` | Whether the success condition is met. |
