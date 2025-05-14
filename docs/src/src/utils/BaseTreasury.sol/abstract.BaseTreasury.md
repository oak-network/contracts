# BaseTreasury
[Git Source](https://github.com/ccprotocol/reference-client-sc/blob/32b7b1617200d0c6f3248845ef972180411f1f65/src/utils/BaseTreasury.sol)

**Inherits:**
Initializable, [ICampaignTreasury](/src/interfaces/ICampaignTreasury.sol/interface.ICampaignTreasury.md), [CampaignAccessChecker](/src/utils/CampaignAccessChecker.sol/abstract.CampaignAccessChecker.md), [PausableCancellable](/src/utils/PausableCancellable.sol/abstract.PausableCancellable.md)

A base contract for creating and managing treasuries in crowdfunding campaigns.

*This contract defines common functionality and storage for campaign treasuries.*

*Contracts implementing this base contract should provide specific success conditions.*


## State Variables
### ZERO_BYTES

```solidity
bytes32 internal constant ZERO_BYTES = 0x0000000000000000000000000000000000000000000000000000000000000000;
```


### PERCENT_DIVIDER

```solidity
uint256 internal constant PERCENT_DIVIDER = 10000;
```


### PLATFORM_HASH

```solidity
bytes32 internal PLATFORM_HASH;
```


### PLATFORM_FEE_PERCENT

```solidity
uint256 internal PLATFORM_FEE_PERCENT;
```


### TOKEN

```solidity
IERC20 internal TOKEN;
```


### s_pledgedAmount

```solidity
uint256 internal s_pledgedAmount;
```


### s_feesDisbursed

```solidity
bool internal s_feesDisbursed;
```


## Functions
### __BaseContract_init


```solidity
function __BaseContract_init(bytes32 platformHash, address infoAddress) internal;
```

### whenCampaignNotPaused

*Modifier that checks if the campaign is not paused.*


```solidity
modifier whenCampaignNotPaused();
```

### whenCampaignNotCancelled


```solidity
modifier whenCampaignNotCancelled();
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


### disburseFees

Disburses fees collected by the treasury.


```solidity
function disburseFees() public virtual override whenCampaignNotPaused whenCampaignNotCancelled;
```

### withdraw

Withdraws funds from the treasury.


```solidity
function withdraw() public virtual override whenCampaignNotPaused whenCampaignNotCancelled;
```

### pauseTreasury

*External function to pause the campaign.*


```solidity
function pauseTreasury(bytes32 message) public virtual onlyPlatformAdmin(PLATFORM_HASH);
```

### unpauseTreasury

*External function to unpause the campaign.*


```solidity
function unpauseTreasury(bytes32 message) public virtual onlyPlatformAdmin(PLATFORM_HASH);
```

### cancelTreasury

*External function to cancel the campaign.*


```solidity
function cancelTreasury(bytes32 message) public virtual onlyPlatformAdmin(PLATFORM_HASH);
```

### _revertIfCampaignPaused

*Internal function to check if the campaign is paused.
If the campaign is paused, it reverts with TreasuryCampaignInfoIsPaused error.*


```solidity
function _revertIfCampaignPaused() internal view;
```

### _revertIfCampaignCancelled


```solidity
function _revertIfCampaignCancelled() internal view;
```

### _checkSuccessCondition

*Internal function to check the success condition for fee disbursement.*


```solidity
function _checkSuccessCondition() internal view virtual returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the success condition is met.|


## Events
### FeesDisbursed
Emitted when fees are successfully disbursed.


```solidity
event FeesDisbursed(uint256 protocolShare, uint256 platformShare);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`protocolShare`|`uint256`|The amount of fees sent to the protocol.|
|`platformShare`|`uint256`|The amount of fees sent to the platform.|

### WithdrawalSuccessful
Emitted when a withdrawal is successful.


```solidity
event WithdrawalSuccessful(address to, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The recipient of the withdrawal.|
|`amount`|`uint256`|The amount withdrawn.|

### SuccessConditionNotFulfilled
Emitted when the success condition is not fulfilled during fee disbursement.


```solidity
event SuccessConditionNotFulfilled();
```

## Errors
### TreasuryTransferFailed
*Throws an error indicating a failed treasury transfer.*


```solidity
error TreasuryTransferFailed();
```

### TreasurySuccessConditionNotFulfilled
*Throws an error indicating that the success condition was not fulfilled.*


```solidity
error TreasurySuccessConditionNotFulfilled();
```

### TreasuryFeeNotDisbursed
*Throws an error indicating that fees have not been disbursed.*


```solidity
error TreasuryFeeNotDisbursed();
```

### TreasuryCampaignInfoIsPaused
*Throws an error indicating that the campaign is paused.*


```solidity
error TreasuryCampaignInfoIsPaused();
```

