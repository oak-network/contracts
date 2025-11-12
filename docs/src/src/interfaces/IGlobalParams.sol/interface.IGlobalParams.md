# IGlobalParams
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/fbdbad195ebe6c636608bb8168723963b1f37dd9/src/interfaces/IGlobalParams.sol)

An interface for accessing and managing global parameters of the protocol.


## Functions
### checkIfPlatformIsListed

Checks if a platform is listed in the protocol.


```solidity
function checkIfPlatformIsListed(bytes32 _platformHash) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_platformHash`|`bytes32`|The unique identifier of the platform.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the platform is listed; otherwise, false.|


### getPlatformAdminAddress

Retrieves the admin address of a platform.


```solidity
function getPlatformAdminAddress(bytes32 _platformHash) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_platformHash`|`bytes32`|The unique identifier of the platform.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The admin address of the platform.|


### getNumberOfListedPlatforms

Retrieves the number of listed platforms in the protocol.


```solidity
function getNumberOfListedPlatforms() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The number of listed platforms.|


### getProtocolAdminAddress

Retrieves the admin address of the protocol.


```solidity
function getProtocolAdminAddress() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The admin address of the protocol.|


### getProtocolFeePercent

Retrieves the protocol fee percentage.


```solidity
function getProtocolFeePercent() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The protocol fee percentage as a uint256 value.|


### getPlatformDataOwner

Retrieves the owner of platform-specific data.


```solidity
function getPlatformDataOwner(bytes32 platformDataKey) external view returns (bytes32 platformHash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformDataKey`|`bytes32`|The key of the platform-specific data.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The platform identifier associated with the data.|


### getPlatformFeePercent

Retrieves the platform fee percentage for a specific platform.


```solidity
function getPlatformFeePercent(bytes32 platformHash) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The unique identifier of the platform.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The platform fee percentage as a uint256 value.|


### getPlatformClaimDelay

Retrieves the claim delay (in seconds) for a specific platform.


```solidity
function getPlatformClaimDelay(bytes32 platformHash) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The unique identifier of the platform.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The claim delay in seconds.|


### checkIfPlatformDataKeyValid

Checks if a platform-specific data key is valid.


```solidity
function checkIfPlatformDataKeyValid(bytes32 platformDataKey) external view returns (bool isValid);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformDataKey`|`bytes32`|The key of the platform-specific data.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isValid`|`bool`|True if the data key is valid; otherwise, false.|


### updateProtocolAdminAddress

Updates the admin address of the protocol.


```solidity
function updateProtocolAdminAddress(address _protocolAdminAddress) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_protocolAdminAddress`|`address`|The new admin address of the protocol.|


### updateProtocolFeePercent

Updates the protocol fee percentage.


```solidity
function updateProtocolFeePercent(uint256 _protocolFeePercent) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_protocolFeePercent`|`uint256`|The new protocol fee percentage as a uint256 value.|


### updatePlatformAdminAddress

Updates the admin address of a platform.


```solidity
function updatePlatformAdminAddress(bytes32 _platformHash, address _platformAdminAddress) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_platformHash`|`bytes32`|The unique identifier of the platform.|
|`_platformAdminAddress`|`address`|The new admin address of the platform.|


### updatePlatformClaimDelay

Updates the claim delay for a specific platform.


```solidity
function updatePlatformClaimDelay(bytes32 platformHash, uint256 claimDelay) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The unique identifier of the platform.|
|`claimDelay`|`uint256`|The claim delay in seconds.|


### addTokenToCurrency

Adds a token to a currency.


```solidity
function addTokenToCurrency(bytes32 currency, address token) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currency`|`bytes32`|The currency identifier.|
|`token`|`address`|The token address to add.|


### removeTokenFromCurrency

Removes a token from a currency.


```solidity
function removeTokenFromCurrency(bytes32 currency, address token) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currency`|`bytes32`|The currency identifier.|
|`token`|`address`|The token address to remove.|


### getTokensForCurrency

Retrieves all tokens accepted for a specific currency.


```solidity
function getTokensForCurrency(bytes32 currency) external view returns (address[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currency`|`bytes32`|The currency identifier.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|An array of token addresses accepted for the currency.|


### getFromRegistry

Retrieves a value from the data registry.


```solidity
function getFromRegistry(bytes32 key) external view returns (bytes32 value);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`key`|`bytes32`|The registry key.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`value`|`bytes32`|The registry value.|


### setPlatformLineItemType

Sets or updates a platform-specific line item type configuration.


```solidity
function setPlatformLineItemType(
    bytes32 platformHash,
    bytes32 typeId,
    string calldata label,
    bool countsTowardGoal,
    bool applyProtocolFee,
    bool canRefund,
    bool instantTransfer
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The identifier of the platform.|
|`typeId`|`bytes32`|The identifier of the line item type.|
|`label`|`string`|The label identifier for the line item type.|
|`countsTowardGoal`|`bool`|Whether this line item counts toward the campaign goal.|
|`applyProtocolFee`|`bool`|Whether this line item is included in protocol fee calculation.|
|`canRefund`|`bool`|Whether this line item can be refunded.|
|`instantTransfer`|`bool`|Whether this line item amount can be instantly transferred.|


### removePlatformLineItemType

Removes a platform-specific line item type by setting its exists flag to false.


```solidity
function removePlatformLineItemType(bytes32 platformHash, bytes32 typeId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The identifier of the platform.|
|`typeId`|`bytes32`|The identifier of the line item type to remove.|


### getPlatformLineItemType

Retrieves a platform-specific line item type configuration.


```solidity
function getPlatformLineItemType(bytes32 platformHash, bytes32 typeId)
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


