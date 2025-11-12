# CampaignInfo
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/e5024d64e3fbbb8a9ba5520b2280c0e3ebc75174/src/CampaignInfo.sol)

**Inherits:**
[ICampaignData](/Users/mahabubalahi/Documents/ccp/ccprotocol-contracts-internal/docs/src/src/interfaces/ICampaignData.sol/interface.ICampaignData.md), [ICampaignInfo](/Users/mahabubalahi/Documents/ccp/ccprotocol-contracts-internal/docs/src/src/interfaces/ICampaignInfo.sol/interface.ICampaignInfo.md), Ownable, [PausableCancellable](/Users/mahabubalahi/Documents/ccp/ccprotocol-contracts-internal/docs/src/src/utils/PausableCancellable.sol/abstract.PausableCancellable.md), [TimestampChecker](/Users/mahabubalahi/Documents/ccp/ccprotocol-contracts-internal/docs/src/src/utils/TimestampChecker.sol/abstract.TimestampChecker.md), [AdminAccessChecker](/Users/mahabubalahi/Documents/ccp/ccprotocol-contracts-internal/docs/src/src/utils/AdminAccessChecker.sol/abstract.AdminAccessChecker.md), [PledgeNFT](/Users/mahabubalahi/Documents/ccp/ccprotocol-contracts-internal/docs/src/src/utils/PledgeNFT.sol/abstract.PledgeNFT.md), Initializable

Manages campaign information and platform data.


## State Variables
### s_campaignData

```solidity
CampaignData private s_campaignData
```


### s_platformTreasuryAddress

```solidity
mapping(bytes32 => address) private s_platformTreasuryAddress
```


### s_platformFeePercent

```solidity
mapping(bytes32 => uint256) private s_platformFeePercent
```


### s_isSelectedPlatform

```solidity
mapping(bytes32 => bool) private s_isSelectedPlatform
```


### s_isApprovedPlatform

```solidity
mapping(bytes32 => bool) private s_isApprovedPlatform
```


### s_platformData

```solidity
mapping(bytes32 => bytes32) private s_platformData
```


### s_approvedPlatformHashes

```solidity
bytes32[] private s_approvedPlatformHashes
```


### s_acceptedTokens

```solidity
address[] private s_acceptedTokens
```


### s_isAcceptedToken

```solidity
mapping(address => bool) private s_isAcceptedToken
```


### s_isLocked

```solidity
bool private s_isLocked
```


## Functions
### getApprovedPlatformHashes


```solidity
function getApprovedPlatformHashes() external view returns (bytes32[] memory);
```

### isLocked

Returns whether the campaign is locked (after treasury deployment).


```solidity
function isLocked() external view override returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the campaign is locked, false otherwise.|


### whenNotLocked

Modifier that checks if the campaign is not locked.


```solidity
modifier whenNotLocked() ;
```

### constructor

Constructor passes empty strings to ERC721


```solidity
constructor() Ownable(_msgSender()) ERC721("", "");
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
    address[] calldata acceptedTokens,
    string calldata nftName,
    string calldata nftSymbol,
    string calldata nftImageURI,
    string calldata nftContractURI
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

Check if a platform is already approved


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

Retrieves the total amount raised across non-cancelled treasuries.

This excludes cancelled treasuries and is affected by refunds.


```solidity
function getTotalRaisedAmount() external view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total amount raised in the campaign.|


### getTotalLifetimeRaisedAmount

Retrieves the total lifetime raised amount across all treasuries.

This amount never decreases even when refunds are processed.
It represents the sum of all pledges/payments ever made to the campaign,
regardless of cancellations or refunds.


```solidity
function getTotalLifetimeRaisedAmount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total lifetime raised amount as a uint256 value.|


### getTotalRefundedAmount

Retrieves the total refunded amount across all treasuries.

This is calculated as the difference between lifetime raised amount
and current raised amount. It represents the sum of all refunds
that have been processed across all treasuries.


```solidity
function getTotalRefundedAmount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total refunded amount as a uint256 value.|


### getTotalAvailableRaisedAmount

Retrieves the total available raised amount across all treasuries.

This includes funds from both active and cancelled treasuries,
and is affected by refunds. It represents the actual current
balance of funds across all treasuries.


```solidity
function getTotalAvailableRaisedAmount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total available raised amount as a uint256 value.|


### getTotalCancelledAmount

Retrieves the total raised amount from cancelled treasuries only.

This is the opposite of getTotalRaisedAmount(), which only includes
non-cancelled treasuries. This function only sums up raised amounts
from treasuries that have been cancelled.


```solidity
function getTotalCancelledAmount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total raised amount from cancelled treasuries as a uint256 value.|


### getTotalExpectedAmount

Retrieves the total expected (pending) amount across payment treasuries.

This only applies to payment treasuries and represents payments that
have been created but not yet confirmed. Regular treasuries are skipped.


```solidity
function getTotalExpectedAmount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total expected amount as a uint256 value.|


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

Returns true if the campaign is paused, and false otherwise.


```solidity
function paused() public view override(ICampaignInfo, PausableCancellable) returns (bool);
```

### cancelled

Returns true if the campaign is cancelled, and false otherwise.


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


### getPlatformClaimDelay

Retrieves the claim delay (in seconds) configured for the given platform.


```solidity
function getPlatformClaimDelay(bytes32 platformHash) external view override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The identifier of the platform.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The claim delay in seconds.|


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


### getDataFromRegistry

Retrieves a value from the GlobalParams data registry.


```solidity
function getDataFromRegistry(bytes32 key) external view override returns (bytes32 value);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`key`|`bytes32`|The registry key.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`value`|`bytes32`|The registry value.|


### getBufferTime

Retrieves the buffer time from the GlobalParams data registry.


```solidity
function getBufferTime() external view override returns (uint256 bufferTime);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`bufferTime`|`uint256`|The buffer time value.|


### getLineItemType

Retrieves a platform-specific line item type configuration from GlobalParams.


```solidity
function getLineItemType(bytes32 platformHash, bytes32 typeId)
    external
    view
    override
    returns (
        bool exists,
        string memory label,
        bool countsTowardGoal,
        bool applyProtocolFee,
        bool canRefund,
        bool instantTransfer
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The identifier of the platform.|
|`typeId`|`bytes32`|The identifier of the line item type.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`exists`|`bool`|Whether this line item type exists and is active.|
|`label`|`string`|The label identifier for the line item type.|
|`countsTowardGoal`|`bool`|Whether this line item counts toward the campaign goal.|
|`applyProtocolFee`|`bool`|Whether this line item is included in protocol fee calculation.|
|`canRefund`|`bool`|Whether this line item can be refunded.|
|`instantTransfer`|`bool`|Whether this line item amount can be instantly transferred.|


### transferOwnership

Transfers ownership of the contract to a new account (`newOwner`).
Can only be called by the current owner.


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
    whenNotPaused
    whenNotCancelled
    whenNotLocked;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`launchTime`|`uint256`|The new launch timestamp.|


### updateDeadline

Updates the campaign's deadline.


```solidity
function updateDeadline(uint256 deadline) external override onlyOwner whenNotPaused whenNotCancelled whenNotLocked;
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
    whenNotPaused
    whenNotCancelled
    whenNotLocked;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`goalAmount`|`uint256`|The new funding goal amount.|


### updateSelectedPlatform

Updates the selection status of a platform for the campaign.

It can only be called for a platform if its not approved i.e. the platform treasury is not deployed


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

External function to pause the campaign.


```solidity
function _pauseCampaign(bytes32 message) external onlyProtocolAdmin;
```

### _unpauseCampaign

External function to unpause the campaign.


```solidity
function _unpauseCampaign(bytes32 message) external onlyProtocolAdmin;
```

### _cancelCampaign

External function to cancel the campaign.


```solidity
function _cancelCampaign(bytes32 message) external;
```

### setImageURI

Sets the image URI for NFT metadata

Can only be updated before campaign launch


```solidity
function setImageURI(string calldata newImageURI)
    external
    override(ICampaignInfo, PledgeNFT)
    onlyOwner
    currentTimeIsLess(getLaunchTime());
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImageURI`|`string`|The new image URI|


### updateContractURI

Updates the contract-level metadata URI

Can only be updated before campaign launch


```solidity
function updateContractURI(string calldata newContractURI)
    external
    override(ICampaignInfo, PledgeNFT)
    onlyOwner
    currentTimeIsLess(getLaunchTime());
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newContractURI`|`string`|The new contract URI|


### mintNFTForPledge


```solidity
function mintNFTForPledge(
    address backer,
    bytes32 reward,
    address tokenAddress,
    uint256 amount,
    uint256 shippingFee,
    uint256 tipAmount
) public override(ICampaignInfo, PledgeNFT) returns (uint256 tokenId);
```

### burn


```solidity
function burn(uint256 tokenId) public override(ICampaignInfo, PledgeNFT);
```

### _setPlatformInfo

Sets platform information for the campaign and grants treasury role.


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
Emitted when the launch time of the campaign is updated.


```solidity
event CampaignInfoLaunchTimeUpdated(uint256 newLaunchTime);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newLaunchTime`|`uint256`|The new launch time.|

### CampaignInfoDeadlineUpdated
Emitted when the deadline of the campaign is updated.


```solidity
event CampaignInfoDeadlineUpdated(uint256 newDeadline);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newDeadline`|`uint256`|The new deadline.|

### CampaignInfoGoalAmountUpdated
Emitted when the goal amount of the campaign is updated.


```solidity
event CampaignInfoGoalAmountUpdated(uint256 newGoalAmount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newGoalAmount`|`uint256`|The new goal amount.|

### CampaignInfoSelectedPlatformUpdated
Emitted when the selection state of a platform is updated.


```solidity
event CampaignInfoSelectedPlatformUpdated(bytes32 indexed platformHash, bool selection);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The bytes32 identifier of the platform.|
|`selection`|`bool`|The new selection state.|

### CampaignInfoPlatformInfoUpdated
Emitted when platform information is updated for the campaign.


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
Emitted when an invalid platform update is attempted.


```solidity
error CampaignInfoInvalidPlatformUpdate(bytes32 platformHash, bool selection);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The bytes32 identifier of the platform.|
|`selection`|`bool`|The selection state (true/false).|

### CampaignInfoUnauthorized
Emitted when an unauthorized action is attempted.


```solidity
error CampaignInfoUnauthorized();
```

### CampaignInfoInvalidInput
Emitted when an invalid input is detected.


```solidity
error CampaignInfoInvalidInput();
```

### CampaignInfoPlatformNotSelected
Emitted when a platform is not selected for the campaign.


```solidity
error CampaignInfoPlatformNotSelected(bytes32 platformHash);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The bytes32 identifier of the platform.|

### CampaignInfoPlatformAlreadyApproved
Emitted when a platform is already approved for the campaign.


```solidity
error CampaignInfoPlatformAlreadyApproved(bytes32 platformHash);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The bytes32 identifier of the platform.|

### CampaignInfoIsLocked
Emitted when an operation is attempted on a locked campaign.


```solidity
error CampaignInfoIsLocked();
```

## Structs
### Config

```solidity
struct Config {
    address treasuryFactory;
    uint256 protocolFeePercent;
    bytes32 identifierHash;
}
```

