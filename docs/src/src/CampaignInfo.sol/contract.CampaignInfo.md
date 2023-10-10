# CampaignInfo
[Git Source](https://github.com/ccprotocol/campaign-utils-contracts-aggregator/blob/79d78188e565502f83e2c0309c9a4ea3b35cee91/src/CampaignInfo.sol)

**Inherits:**
[ICampaignData](/src/interfaces/ICampaignData.sol/interface.ICampaignData.md), [ICampaignInfo](/src/interfaces/ICampaignInfo.sol/interface.ICampaignInfo.md), Ownable, [PausableWithMsg](/src/utils/PausableWithMsg.sol/abstract.PausableWithMsg.md), [TimestampChecker](/src/utils/TimestampChecker.sol/abstract.TimestampChecker.md), [AdminAccessChecker](/src/utils/AdminAccessChecker.sol/abstract.AdminAccessChecker.md)

Manages campaign information and platform data.


## State Variables
### TREASURY_FACTORY

```solidity
address private immutable TREASURY_FACTORY;
```


### TOKEN

```solidity
address private immutable TOKEN;
```


### PROTOCOL_FEE_PERCENT

```solidity
uint256 private immutable PROTOCOL_FEE_PERCENT;
```


### IDENTIFIER_HASH

```solidity
bytes32 private immutable IDENTIFIER_HASH;
```


### s_campaignData

```solidity
CampaignData private s_campaignData;
```


### s_selectedPlatformBytes

```solidity
mapping(bytes32 => bool) private s_selectedPlatformBytes;
```


### s_platformTreasuryAddress

```solidity
mapping(bytes32 => address) private s_platformTreasuryAddress;
```


### s_platformFeePercent

```solidity
mapping(bytes32 => uint256) private s_platformFeePercent;
```


### s_platformData

```solidity
mapping(bytes32 => bytes32) private s_platformData;
```


### s_approvedPlatformBytes

```solidity
bytes32[] private s_approvedPlatformBytes;
```


## Functions
### constructor


```solidity
constructor(
    IGlobalParams globalParams,
    address treasuryFactory,
    address token,
    address creator,
    uint256 protocolFeePercent,
    bytes32 identifierHash,
    bytes32[] memory selectedPlatformBytes,
    bytes32[] memory platformDataKey,
    bytes32[] memory platformDataValue,
    CampaignData memory campaignData
) AdminAccessChecker(globalParams);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`globalParams`|`IGlobalParams`|The address of the global parameters contract.|
|`treasuryFactory`|`address`|The address of the treasury factory contract.|
|`token`|`address`|The address of the campaign token contract.|
|`creator`|`address`|The address of the campaign creator.|
|`protocolFeePercent`|`uint256`|The protocol fee percentage.|
|`identifierHash`|`bytes32`|The hash identifier for the campaign.|
|`selectedPlatformBytes`|`bytes32[]`|The list of selected platform identifiers.|
|`platformDataKey`|`bytes32[]`|The list of platform data keys.|
|`platformDataValue`|`bytes32[]`|The list of platform data values.|
|`campaignData`|`CampaignData`|The initial campaign data.|


### checkIfPlatformSelected

Checks if a platform has been selected for the campaign.


```solidity
function checkIfPlatformSelected(bytes32 platformBytes) public view override returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformBytes`|`bytes32`|The bytes32 identifier of the platform to check.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the platform is selected, false otherwise.|


### owner

Returns the owner of the contract.


```solidity
function owner() public view override(ICampaignInfo, Ownable) returns (address account);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The address of the contract owner.|


### getTotalRaisedAmount

Retrieves the total amount raised in the campaign.


```solidity
function getTotalRaisedAmount() external view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total amount raised in the campaign.|


### getProtocolAdminAddress

Retrieves the address of the protocol administrator.


```solidity
function getProtocolAdminAddress() external view override returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the protocol administrator.|


### getPlatformAdminAddress

Retrieves the address of the platform administrator for a specific platform.


```solidity
function getPlatformAdminAddress(bytes32 platformBytes) external view override returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformBytes`|`bytes32`|The bytes32 identifier of the platform.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the platform administrator.|


### getLaunchTime

Retrieves the campaign's launch time.


```solidity
function getLaunchTime() external view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The timestamp when the campaign was launched.|


### getDeadline

Retrieves the campaign's deadline.


```solidity
function getDeadline() external view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The timestamp when the campaign ends.|


### getGoalAmount

Retrieves the campaign's funding goal amount.


```solidity
function getGoalAmount() external view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The funding goal amount of the campaign.|


### getTokenAddress

Retrieves the address of the token used in the campaign.


```solidity
function getTokenAddress() external view override returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the campaign's token.|


### getProtocolFeePercent

Retrieves the protocol fee percentage for the campaign.


```solidity
function getProtocolFeePercent() external view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The protocol fee percentage applied to the campaign.|


### paused

*Returns true if the contract is paused, and false otherwise.*


```solidity
function paused() public view override(ICampaignInfo, PausableWithMsg) returns (bool);
```

### getPlatformFeePercent

Retrieves the platform fee percentage for a specific platform.


```solidity
function getPlatformFeePercent(bytes32 platformBytes) external view override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformBytes`|`bytes32`|The bytes32 identifier of the platform.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The platform fee percentage applied to the campaign on the platform.|


### getPlatformData

Retrieves platform-specific data for the campaign.


```solidity
function getPlatformData(bytes32 platformDataKey) external view override returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformDataKey`|`bytes32`|The bytes32 identifier of the platform-specific data.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The platform-specific data associated with the given key.|


### getIdentifierHash

Retrieves the unique identifier hash of the campaign.


```solidity
function getIdentifierHash() external view override returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The bytes32 hash that uniquely identifies the campaign.|


### transferOwnership


```solidity
function transferOwnership(address newOwner) public override(ICampaignInfo, Ownable) onlyOwner whenNotPaused;
```

### updateLaunchTime

Updates the campaign's launch time.


```solidity
function updateLaunchTime(uint256 launchTime) external override onlyOwner currentTimeIsLess(launchTime) whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`launchTime`|`uint256`|The new launch timestamp.|


### updateDeadline

Updates the campaign's deadline.


```solidity
function updateDeadline(uint256 deadline)
    external
    override
    onlyOwner
    currentTimeIsLess(s_campaignData.launchTime)
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`deadline`|`uint256`|The new deadline timestamp.|


### updateGoalAmount

Updates the campaign's funding goal amount.


```solidity
function updateGoalAmount(uint256 goalAmount)
    external
    override
    onlyOwner
    currentTimeIsLess(s_campaignData.launchTime)
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`goalAmount`|`uint256`|The new funding goal amount.|


### updateSelectedPlatform

Updates the selection status of a platform for the campaign.


```solidity
function updateSelectedPlatform(bytes32 platformBytes, bool selection)
    external
    override
    onlyOwner
    currentTimeIsLess(s_campaignData.launchTime)
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformBytes`|`bytes32`|The bytes32 identifier of the platform.|
|`selection`|`bool`|The new selection status (true or false).|


### _setPlatformInfo

*Sets platform information for the campaign.*


```solidity
function _setPlatformInfo(bytes32 platformBytes, address platformTreasuryAddress) external whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformBytes`|`bytes32`|The bytes32 identifier of the platform.|
|`platformTreasuryAddress`|`address`|The address of the platform's treasury.|


### _pauseCampaign


```solidity
function _pauseCampaign(bytes32 message) external onlyProtocolAdmin;
```

### _unpauseCampaign


```solidity
function _unpauseCampaign(bytes32 message) external onlyProtocolAdmin;
```

## Events
### CampaignInfoPlatformSelected
*Emitted when a platform is selected for the campaign.*


```solidity
event CampaignInfoPlatformSelected(bytes32 indexed platformBytes, address indexed platformTreasury);
```

### CampaignInfoLaunchTimeUpdated
*Emitted when the launch time of the campaign is updated.*


```solidity
event CampaignInfoLaunchTimeUpdated(uint256 newLaunchTime);
```

### CampaignInfoDeadlineUpdated
*Emitted when the deadline of the campaign is updated.*


```solidity
event CampaignInfoDeadlineUpdated(uint256 newDeadline);
```

### CampaignInfoGoalAmountUpdated
*Emitted when the goal amount of the campaign is updated.*


```solidity
event CampaignInfoGoalAmountUpdated(uint256 newGoalAmount);
```

### CampaignInfoSelectedPlatformUpdated
*Emitted when the selection state of a platform is updated.*


```solidity
event CampaignInfoSelectedPlatformUpdated(bytes32 indexed platformBytes, bool selection);
```

### CampaignInfoPlatformInfoUpdated
*Emitted when platform information is updated for the campaign.*


```solidity
event CampaignInfoPlatformInfoUpdated(bytes32 indexed platformBytes, address indexed platformTreasury);
```

### CampaignInfoOwnershipTransferred
*Emitted when ownership of the contract is transferred.*


```solidity
event CampaignInfoOwnershipTransferred(address indexed previousOwner, address indexed newOwner);
```

## Errors
### CampaignInfoInvalidPlatformUpdate
*Emitted when an invalid platform update is attempted.*


```solidity
error CampaignInfoInvalidPlatformUpdate(bytes32 platformBytes, bool selection);
```

### CampaignInfoUnauthorized
*Emitted when an unauthorized action is attempted.*


```solidity
error CampaignInfoUnauthorized();
```

### CampaignInfoInvalidInput
*Emitted when an invalid input is detected.*


```solidity
error CampaignInfoInvalidInput();
```

### CampaignInfoPlatformNotSelected
*Emitted when a platform is not selected for the campaign.*


```solidity
error CampaignInfoPlatformNotSelected(bytes32 platformBytes);
```

