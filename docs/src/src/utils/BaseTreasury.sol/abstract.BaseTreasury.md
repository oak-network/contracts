# BaseTreasury
[Git Source](https://github.com/ccprotocol/campaign-utils-contracts-aggregator/blob/79d78188e565502f83e2c0309c9a4ea3b35cee91/src/utils/BaseTreasury.sol)

**Inherits:**
[ICampaignTreasury](/src/interfaces/ICampaignTreasury.sol/interface.ICampaignTreasury.md), [CampaignAccessChecker](/src/utils/CampaignAccessChecker.sol/abstract.CampaignAccessChecker.md), [PausableWithMsg](/src/utils/PausableWithMsg.sol/abstract.PausableWithMsg.md)

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


### PLATFORM_BYTES

```solidity
bytes32 internal immutable PLATFORM_BYTES;
```


### PLATFORM_FEE_PERCENT

```solidity
uint256 internal immutable PLATFORM_FEE_PERCENT;
```


### TOKEN

```solidity
IERC20 internal immutable TOKEN;
```


### CAMPAIGN_INFO

```solidity
ICampaignInfo internal immutable CAMPAIGN_INFO;
```


### s_pledgedAmountInCrypto

```solidity
uint256 internal s_pledgedAmountInCrypto;
```


### s_cryptoFeeDisbursed

```solidity
bool internal s_cryptoFeeDisbursed;
```


## Functions
### constructor

*Constructs a new BaseTreasury instance.*


```solidity
constructor(bytes32 platformBytes, address infoAddress) CampaignAccessChecker(infoAddress);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformBytes`|`bytes32`|The identifier for the platform associated with this treasury.|
|`infoAddress`|`address`|The address of the CampaignInfo contract.|


### whenCampaignNotPaused

*Modifier that checks if the campaign is not paused.*


```solidity
modifier whenCampaignNotPaused();
```

### getplatformBytes

Retrieves the platform identifier associated with the treasury.


```solidity
function getplatformBytes() external view override returns (bytes32);
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
function disburseFees() public virtual override whenCampaignNotPaused;
```

### withdraw

Withdraws funds from the treasury.


```solidity
function withdraw() public virtual override whenCampaignNotPaused;
```

### _pauseTreasury

*External function to pause the campaign.*


```solidity
function _pauseTreasury(bytes32 message) external onlyPlatformAdmin(PLATFORM_BYTES);
```

### _unpauseTreasury

*External function to unpause the campaign.*


```solidity
function _unpauseTreasury(bytes32 message) external onlyPlatformAdmin(PLATFORM_BYTES);
```

### _checkIfCampaignPaused

*Internal function to check if the campaign is paused.
If the campaign is paused, it reverts with TreasuryCampaignInfoIsPaused error.*


```solidity
function _checkIfCampaignPaused() internal view;
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

### WithdrawalSuccessful
Emitted when a withdrawal is successful.


```solidity
event WithdrawalSuccessful(address indexed to, uint256 amount);
```

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

