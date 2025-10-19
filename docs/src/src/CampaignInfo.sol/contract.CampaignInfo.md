# CampaignInfo
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/08a57a0930f80d6f45ee44fa43ce6ad3e6c3c5c5/src/CampaignInfo.sol)

**Inherits:**
[ICampaignData](/src/interfaces/ICampaignData.sol/interface.ICampaignData.md), [ICampaignInfo](/src/interfaces/ICampaignInfo.sol/interface.ICampaignInfo.md), Ownable, [PausableCancellable](/src/utils/PausableCancellable.sol/abstract.PausableCancellable.md), [TimestampChecker](/src/utils/TimestampChecker.sol/abstract.TimestampChecker.md), [AdminAccessChecker](/src/utils/AdminAccessChecker.sol/abstract.AdminAccessChecker.md), Initializable

Manages campaign information and platform data.


## State Variables
### s_campaignData

```solidity
CampaignData private s_campaignData;
```


### s_platformTreasuryAddress

```solidity
mapping(bytes32 => address) private s_platformTreasuryAddress;
```


### s_platformFeePercent

```solidity
mapping(bytes32 => uint256) private s_platformFeePercent;
```


### s_isSelectedPlatform

```solidity
mapping(bytes32 => bool) private s_isSelectedPlatform;
```


### s_isApprovedPlatform

```solidity
mapping(bytes32 => bool) private s_isApprovedPlatform;
```


### s_platformData

```solidity
mapping(bytes32 => bytes32) private s_platformData;
```


### s_approvedPlatformHashes

```solidity
bytes32[] private s_approvedPlatformHashes;
```


### s_acceptedTokens

```solidity
address[] private s_acceptedTokens;
```


### s_isAcceptedToken

```solidity
mapping(address => bool) private s_isAcceptedToken;
```


## Functions
### getApprovedPlatformHashes


```solidity
function getApprovedPlatformHashes() external view returns (bytes32[] memory);
```

### constructor


```solidity
constructor() Ownable(_msgSender());
```

### initialize


```solidity
function initialize(
    address creator,
    IGlobalParams globalParams,
    bytes32[] calldata selectedPlatformHash,
    bytes32[] calldata platformDataKey,
    bytes32[] calldata platformDataValue,
    CampaignData calldata campaignData,
    address[] calldata acceptedTokens
) external initializer;
```

### getCampaignConfig


```solidity
function getCampaignConfig() public view returns (Config memory config);
```

### checkIfPlatformSelected

Checks if a platform has been selected for the campaign.


```solidity
function checkIfPlatformSelected(bytes32 platformHash) public view override returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The bytes32 identifier of the platform to check.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the platform is selected, false otherwise.|


### checkIfPlatformApproved

*Check if a platform is already approved*


```solidity
function checkIfPlatformApproved(bytes32 platformHash) public view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The bytes32 identifier of the platform.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the platform is already approved, false otherwise.|


### owner

Returns the owner of the contract.


```solidity
function owner() public view override(ICampaignInfo, Ownable) returns (address account);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The address of the contract owner.|


### getProtocolAdminAddress

Retrieves the address of the protocol administrator.


```solidity
function getProtocolAdminAddress() public view override returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the protocol administrator.|


### getTotalRaisedAmount

Retrieves the total amount raised in the campaign.


```solidity
function getTotalRaisedAmount() external view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total amount raised in the campaign.|


### getPlatformAdminAddress

Retrieves the address of the platform administrator for a specific platform.


```solidity
function getPlatformAdminAddress(bytes32 platformHash) external view override returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The bytes32 identifier of the platform.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the platform administrator.|


### getLaunchTime

Retrieves the campaign's launch time.


```solidity
function getLaunchTime() public view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The timestamp when the campaign was launched.|


### getDeadline

Retrieves the campaign's deadline.


```solidity
function getDeadline() public view override returns (uint256);
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


### getProtocolFeePercent

Retrieves the protocol fee percentage for the campaign.


```solidity
function getProtocolFeePercent() external view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The protocol fee percentage applied to the campaign.|


### getCampaignCurrency

Retrieves the campaign's currency identifier.


```solidity
function getCampaignCurrency() external view override returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The bytes32 currency identifier for the campaign.|


### getAcceptedTokens

Retrieves the cached accepted tokens for the campaign.


```solidity
function getAcceptedTokens() external view override returns (address[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|An array of token addresses accepted for the campaign.|


### isTokenAccepted

Checks if a token is accepted for the campaign.


```solidity
function isTokenAccepted(address token) external view override returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The token address to check.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the token is accepted; otherwise, false.|


### paused

*Returns true if the campaign is paused, and false otherwise.*


```solidity
function paused() public view override(ICampaignInfo, PausableCancellable) returns (bool);
```

### cancelled

*Returns true if the campaign is cancelled, and false otherwise.*


```solidity
function cancelled() public view override(ICampaignInfo, PausableCancellable) returns (bool);
```

### getPlatformFeePercent

Retrieves the platform fee percentage for a specific platform.


```solidity
function getPlatformFeePercent(bytes32 platformHash) external view override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The bytes32 identifier of the platform.|

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

*Transfers ownership of the contract to a new account (`newOwner`).
Can only be called by the current owner.*


```solidity
function transferOwnership(address newOwner)
    public
    override(ICampaignInfo, Ownable)
    onlyOwner
    whenNotPaused
    whenNotCancelled;
```

### updateLaunchTime

Updates the campaign's launch time.


```solidity
function updateLaunchTime(uint256 launchTime)
    external
    override
    onlyOwner
    currentTimeIsLess(getLaunchTime())
    whenNotPaused
    whenNotCancelled;
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
    currentTimeIsLess(getLaunchTime())
    whenNotPaused
    whenNotCancelled;
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
    currentTimeIsLess(getLaunchTime())
    whenNotPaused
    whenNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`goalAmount`|`uint256`|The new funding goal amount.|


### updateSelectedPlatform

Updates the selection status of a platform for the campaign.

*It can only be called for a platform if its not approved i.e. the platform treasury is not deployed*


```solidity
function updateSelectedPlatform(
    bytes32 platformHash,
    bool selection,
    bytes32[] calldata platformDataKey,
    bytes32[] calldata platformDataValue
) external override onlyOwner currentTimeIsLess(getLaunchTime()) whenNotPaused whenNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The bytes32 identifier of the platform.|
|`selection`|`bool`|The new selection status (true or false).|
|`platformDataKey`|`bytes32[]`|An array of platform-specific data keys.|
|`platformDataValue`|`bytes32[]`|An array of platform-specific data values.|


### _pauseCampaign

*External function to pause the campaign.*


```solidity
function _pauseCampaign(bytes32 message) external onlyProtocolAdmin;
```

### _unpauseCampaign

*External function to unpause the campaign.*


```solidity
function _unpauseCampaign(bytes32 message) external onlyProtocolAdmin;
```

### _cancelCampaign

*External function to cancel the campaign.*


```solidity
function _cancelCampaign(bytes32 message) external;
```

### _setPlatformInfo

*Sets platform information for the campaign.*


```solidity
function _setPlatformInfo(bytes32 platformHash, address platformTreasuryAddress) external whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The bytes32 identifier of the platform.|
|`platformTreasuryAddress`|`address`|The address of the platform's treasury.|


## Events
### CampaignInfoLaunchTimeUpdated
*Emitted when the launch time of the campaign is updated.*


```solidity
event CampaignInfoLaunchTimeUpdated(uint256 newLaunchTime);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newLaunchTime`|`uint256`|The new launch time.|

### CampaignInfoDeadlineUpdated
*Emitted when the deadline of the campaign is updated.*


```solidity
event CampaignInfoDeadlineUpdated(uint256 newDeadline);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newDeadline`|`uint256`|The new deadline.|

### CampaignInfoGoalAmountUpdated
*Emitted when the goal amount of the campaign is updated.*


```solidity
event CampaignInfoGoalAmountUpdated(uint256 newGoalAmount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newGoalAmount`|`uint256`|The new goal amount.|

### CampaignInfoSelectedPlatformUpdated
*Emitted when the selection state of a platform is updated.*


```solidity
event CampaignInfoSelectedPlatformUpdated(bytes32 indexed platformHash, bool selection);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The bytes32 identifier of the platform.|
|`selection`|`bool`|The new selection state.|

### CampaignInfoPlatformInfoUpdated
*Emitted when platform information is updated for the campaign.*


```solidity
event CampaignInfoPlatformInfoUpdated(bytes32 indexed platformHash, address indexed platformTreasury);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The bytes32 identifier of the platform.|
|`platformTreasury`|`address`|The address of the platform's treasury.|

## Errors
### CampaignInfoInvalidPlatformUpdate
*Emitted when an invalid platform update is attempted.*


```solidity
error CampaignInfoInvalidPlatformUpdate(bytes32 platformHash, bool selection);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The bytes32 identifier of the platform.|
|`selection`|`bool`|The selection state (true/false).|

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
error CampaignInfoPlatformNotSelected(bytes32 platformHash);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The bytes32 identifier of the platform.|

### CampaignInfoPlatformAlreadyApproved
*Emitted when a platform is already approved for the campaign.*


```solidity
error CampaignInfoPlatformAlreadyApproved(bytes32 platformHash);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The bytes32 identifier of the platform.|

## Structs
### Config

```solidity
struct Config {
    address treasuryFactory;
    uint256 protocolFeePercent;
    bytes32 identifierHash;
}
```

