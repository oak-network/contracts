# ICampaignInfo
[Git Source](https://github.com/oak-network/ccprotocol-contracts-internal/blob/be3636c015d0f78c20f6d8f0de7b678aaf6d8428/src/interfaces/ICampaignInfo.sol)

**Inherits:**
IERC721

An interface for managing campaign information in a crowdfunding system.

*Inherits from IERC721 as CampaignInfo is an ERC721 NFT collection*


## Functions
### owner

Returns the owner of the contract.


```solidity
function owner() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the contract owner.|


### checkIfPlatformSelected

Checks if a platform has been selected for the campaign.


```solidity
function checkIfPlatformSelected(bytes32 platformHash) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The bytes32 identifier of the platform to check.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the platform is selected, false otherwise.|


### getTotalRaisedAmount

Retrieves the total amount raised across non-cancelled treasuries.

*This excludes cancelled treasuries and is affected by refunds.*


```solidity
function getTotalRaisedAmount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total amount raised in the campaign.|


### getTotalLifetimeRaisedAmount

Retrieves the total lifetime raised amount across all treasuries.

*This amount never decreases even when refunds are processed.
It represents the sum of all pledges/payments ever made to the campaign,
regardless of cancellations or refunds.*


```solidity
function getTotalLifetimeRaisedAmount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total lifetime raised amount as a uint256 value.|


### getTotalRefundedAmount

Retrieves the total refunded amount across all treasuries.

*This is calculated as the difference between lifetime raised amount
and current raised amount. It represents the sum of all refunds
that have been processed across all treasuries.*


```solidity
function getTotalRefundedAmount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total refunded amount as a uint256 value.|


### getTotalAvailableRaisedAmount

Retrieves the total available raised amount across all treasuries.

*This includes funds from both active and cancelled treasuries,
and is affected by refunds. It represents the actual current
balance of funds across all treasuries.*


```solidity
function getTotalAvailableRaisedAmount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total available raised amount as a uint256 value.|


### getTotalCancelledAmount

Retrieves the total raised amount from cancelled treasuries only.

*This is the opposite of getTotalRaisedAmount(), which only includes
non-cancelled treasuries. This function only sums up raised amounts
from treasuries that have been cancelled.*


```solidity
function getTotalCancelledAmount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total raised amount from cancelled treasuries as a uint256 value.|


### getTotalExpectedAmount

Retrieves the total expected (pending) amount across payment treasuries.

*This only applies to payment treasuries and represents payments that
have been created but not yet confirmed. Regular treasuries are skipped.*


```solidity
function getTotalExpectedAmount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total expected amount as a uint256 value.|


### getProtocolAdminAddress

Retrieves the address of the protocol administrator.


```solidity
function getProtocolAdminAddress() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the protocol administrator.|


### getPlatformAdminAddress

Retrieves the address of the platform administrator for a specific platform.


```solidity
function getPlatformAdminAddress(bytes32 platformHash) external view returns (address);
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
function getLaunchTime() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The timestamp when the campaign was launched.|


### getDeadline

Retrieves the campaign's deadline.


```solidity
function getDeadline() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The timestamp when the campaign ends.|


### getGoalAmount

Retrieves the campaign's funding goal amount.


```solidity
function getGoalAmount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The funding goal amount of the campaign.|


### getProtocolFeePercent

Retrieves the protocol fee percentage for the campaign.


```solidity
function getProtocolFeePercent() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The protocol fee percentage applied to the campaign.|


### getCampaignCurrency

Retrieves the campaign's currency identifier.


```solidity
function getCampaignCurrency() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The bytes32 currency identifier for the campaign.|


### getAcceptedTokens

Retrieves the cached accepted tokens for the campaign.


```solidity
function getAcceptedTokens() external view returns (address[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|An array of token addresses accepted for the campaign.|


### isTokenAccepted

Checks if a token is accepted for the campaign.


```solidity
function isTokenAccepted(address token) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The token address to check.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the token is accepted; otherwise, false.|


### getPlatformFeePercent

Retrieves the platform fee percentage for a specific platform.


```solidity
function getPlatformFeePercent(bytes32 platformHash) external view returns (uint256);
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
function getPlatformClaimDelay(bytes32 platformHash) external view returns (uint256);
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
function getPlatformData(bytes32 platformDataKey) external view returns (bytes32);
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
function getIdentifierHash() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The bytes32 hash that uniquely identifies the campaign.|


### transferOwnership

Transfers ownership of the contract to a new owner.


```solidity
function transferOwnership(address newOwner) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newOwner`|`address`|The address of the new contract owner.|


### updateLaunchTime

Updates the campaign's launch time.


```solidity
function updateLaunchTime(uint256 launchTime) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`launchTime`|`uint256`|The new launch timestamp.|


### updateDeadline

Updates the campaign's deadline.


```solidity
function updateDeadline(uint256 deadline) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`deadline`|`uint256`|The new deadline timestamp.|


### updateGoalAmount

Updates the campaign's funding goal amount.


```solidity
function updateGoalAmount(uint256 goalAmount) external;
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
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The bytes32 identifier of the platform.|
|`selection`|`bool`|The new selection status (true or false).|
|`platformDataKey`|`bytes32[]`|An array of platform-specific data keys.|
|`platformDataValue`|`bytes32[]`|An array of platform-specific data values.|


### paused

*Returns true if the campaign is paused, and false otherwise.*


```solidity
function paused() external view returns (bool);
```

### cancelled

*Returns true if the campaign is cancelled, and false otherwise.*


```solidity
function cancelled() external view returns (bool);
```

### getDataFromRegistry

Retrieves a value from the GlobalParams data registry.


```solidity
function getDataFromRegistry(bytes32 key) external view returns (bytes32 value);
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
function getBufferTime() external view returns (uint256 bufferTime);
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


### mintNFTForPledge

Mints a pledge NFT for a backer

*Can only be called by treasuries with MINTER_ROLE*


```solidity
function mintNFTForPledge(
    address backer,
    bytes32 reward,
    address tokenAddress,
    uint256 amount,
    uint256 shippingFee,
    uint256 tipAmount
) external returns (uint256 tokenId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`backer`|`address`|The backer address|
|`reward`|`bytes32`|The reward identifier|
|`tokenAddress`|`address`|The address of the token used for the pledge|
|`amount`|`uint256`|The pledge amount|
|`shippingFee`|`uint256`|The shipping fee|
|`tipAmount`|`uint256`|The tip amount|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The minted token ID (pledge ID)|


### setImageURI

Sets the image URI for NFT metadata


```solidity
function setImageURI(string calldata newImageURI) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImageURI`|`string`|The new image URI|


### updateContractURI

Updates the contract-level metadata URI


```solidity
function updateContractURI(string calldata newContractURI) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newContractURI`|`string`|The new contract URI|


### burn

Burns a pledge NFT


```solidity
function burn(uint256 tokenId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The token ID to burn|


### isLocked

*Returns true if the campaign is locked (after treasury deployment), and false otherwise.*


```solidity
function isLocked() external view returns (bool);
```

