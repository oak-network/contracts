# GlobalParams
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/08a57a0930f80d6f45ee44fa43ce6ad3e6c3c5c5/src/GlobalParams.sol)

**Inherits:**
Initializable, [IGlobalParams](/src/interfaces/IGlobalParams.sol/interface.IGlobalParams.md), OwnableUpgradeable, UUPSUpgradeable

Manages global parameters and platform information.

*UUPS Upgradeable contract with ERC-7201 namespaced storage*


## State Variables
### GLOBAL_PARAMS_STORAGE_LOCATION

```solidity
bytes32 private constant GLOBAL_PARAMS_STORAGE_LOCATION =
    0x83d0145f7c1378f10048390769ec94f999b3ba6d94904b8fd7251512962b1c00;
```


### ZERO_BYTES

```solidity
bytes32 private constant ZERO_BYTES = 0x0000000000000000000000000000000000000000000000000000000000000000;
```


## Functions
### _getGlobalParamsStorage


```solidity
function _getGlobalParamsStorage() private pure returns (GlobalParamsStorage storage $);
```

### notAddressZero

*Reverts if the input address is zero.*


```solidity
modifier notAddressZero(address account);
```

### onlyPlatformAdmin

*Modifier that restricts function access to platform administrators of a specific platform.
Users attempting to execute functions with this modifier must be the platform admin for the given platform.*


```solidity
modifier onlyPlatformAdmin(bytes32 platformHash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The unique identifier of the platform.|


### platformIsListed


```solidity
modifier platformIsListed(bytes32 platformHash);
```

### constructor

*Constructor that disables initializers to prevent implementation contract initialization*


```solidity
constructor();
```

### initialize

*Initializer function (replaces constructor)*


```solidity
function initialize(
    address protocolAdminAddress,
    uint256 protocolFeePercent,
    bytes32[] memory currencies,
    address[][] memory tokensPerCurrency
) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`protocolAdminAddress`|`address`|The address of the protocol admin.|
|`protocolFeePercent`|`uint256`|The protocol fee percentage.|
|`currencies`|`bytes32[]`|The array of currency identifiers.|
|`tokensPerCurrency`|`address[][]`|The array of token arrays for each currency.|


### _authorizeUpgrade

*Function that authorizes an upgrade to a new implementation*


```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|


### addToRegistry

Adds a key-value pair to the data registry.


```solidity
function addToRegistry(bytes32 key, bytes32 value) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`key`|`bytes32`|The registry key.|
|`value`|`bytes32`|The registry value.|


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


### getPlatformAdminAddress

Retrieves the admin address of a platform.


```solidity
function getPlatformAdminAddress(bytes32 platformHash)
    external
    view
    override
    platformIsListed(platformHash)
    returns (address account);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The admin address of the platform.|


### getNumberOfListedPlatforms

Retrieves the number of listed platforms in the protocol.


```solidity
function getNumberOfListedPlatforms() external view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The number of listed platforms.|


### getProtocolAdminAddress

Retrieves the admin address of the protocol.


```solidity
function getProtocolAdminAddress() external view override returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The admin address of the protocol.|


### getProtocolFeePercent

Retrieves the protocol fee percentage.


```solidity
function getProtocolFeePercent() external view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The protocol fee percentage as a uint256 value.|


### getPlatformFeePercent

Retrieves the platform fee percentage for a specific platform.


```solidity
function getPlatformFeePercent(bytes32 platformHash)
    external
    view
    override
    platformIsListed(platformHash)
    returns (uint256 platformFeePercent);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The unique identifier of the platform.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`platformFeePercent`|`uint256`|The platform fee percentage as a uint256 value.|


### getPlatformDataOwner

Retrieves the owner of platform-specific data.


```solidity
function getPlatformDataOwner(bytes32 platformDataKey) external view override returns (bytes32 platformHash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformDataKey`|`bytes32`|The key of the platform-specific data.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The platform identifier associated with the data.|


### checkIfPlatformIsListed

Checks if a platform is listed in the protocol.


```solidity
function checkIfPlatformIsListed(bytes32 platformHash) public view override returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the platform is listed; otherwise, false.|


### checkIfPlatformDataKeyValid

Checks if a platform-specific data key is valid.


```solidity
function checkIfPlatformDataKeyValid(bytes32 platformDataKey) external view override returns (bool isValid);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformDataKey`|`bytes32`|The key of the platform-specific data.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isValid`|`bool`|True if the data key is valid; otherwise, false.|


### enlistPlatform

Enlists a platform with its admin address and fee percentage.

*The platformFeePercent can be any value including zero.*


```solidity
function enlistPlatform(bytes32 platformHash, address platformAdminAddress, uint256 platformFeePercent)
    external
    onlyOwner
    notAddressZero(platformAdminAddress);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The platform's identifier.|
|`platformAdminAddress`|`address`|The platform's admin address.|
|`platformFeePercent`|`uint256`|The platform's fee percentage.|


### delistPlatform

Delists a platform.


```solidity
function delistPlatform(bytes32 platformHash) external onlyOwner platformIsListed(platformHash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The platform's identifier.|


### addPlatformData

Adds platform-specific data key.


```solidity
function addPlatformData(bytes32 platformHash, bytes32 platformDataKey)
    external
    platformIsListed(platformHash)
    onlyPlatformAdmin(platformHash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The platform's identifier.|
|`platformDataKey`|`bytes32`|The platform data key.|


### removePlatformData

Removes platform-specific data key.


```solidity
function removePlatformData(bytes32 platformHash, bytes32 platformDataKey)
    external
    platformIsListed(platformHash)
    onlyPlatformAdmin(platformHash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The platform's identifier.|
|`platformDataKey`|`bytes32`|The platform data key.|


### updateProtocolAdminAddress

Updates the admin address of the protocol.


```solidity
function updateProtocolAdminAddress(address protocolAdminAddress)
    external
    override
    onlyOwner
    notAddressZero(protocolAdminAddress);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`protocolAdminAddress`|`address`||


### updateProtocolFeePercent

Updates the protocol fee percentage.


```solidity
function updateProtocolFeePercent(uint256 protocolFeePercent) external override onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`protocolFeePercent`|`uint256`||


### updatePlatformAdminAddress

Updates the admin address of a platform.


```solidity
function updatePlatformAdminAddress(bytes32 platformHash, address platformAdminAddress)
    external
    override
    onlyOwner
    platformIsListed(platformHash)
    notAddressZero(platformAdminAddress);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`||
|`platformAdminAddress`|`address`||


### addTokenToCurrency

Adds a token to a currency.


```solidity
function addTokenToCurrency(bytes32 currency, address token) external override onlyOwner notAddressZero(token);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currency`|`bytes32`|The currency identifier.|
|`token`|`address`|The token address to add.|


### removeTokenFromCurrency

Removes a token from a currency.


```solidity
function removeTokenFromCurrency(bytes32 currency, address token) external override onlyOwner notAddressZero(token);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currency`|`bytes32`|The currency identifier.|
|`token`|`address`|The token address to remove.|


### getTokensForCurrency

Retrieves all tokens accepted for a specific currency.


```solidity
function getTokensForCurrency(bytes32 currency) external view override returns (address[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currency`|`bytes32`|The currency identifier.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|An array of token addresses accepted for the currency.|


### _revertIfAddressZero

*Reverts if the input address is zero.*


```solidity
function _revertIfAddressZero(address account) internal pure;
```

### _onlyPlatformAdmin

*Internal function to check if the sender is the platform administrator for a specific platform.
If the sender is not the platform admin, it reverts with AdminAccessCheckerUnauthorized error.*


```solidity
function _onlyPlatformAdmin(bytes32 platformHash) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The unique identifier of the platform.|


## Events
### PlatformEnlisted
*Emitted when a platform is enlisted.*


```solidity
event PlatformEnlisted(bytes32 indexed platformHash, address indexed platformAdminAddress, uint256 platformFeePercent);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The identifier of the enlisted platform.|
|`platformAdminAddress`|`address`|The admin address of the enlisted platform.|
|`platformFeePercent`|`uint256`|The fee percentage of the enlisted platform.|

### PlatformDelisted
*Emitted when a platform is delisted.*


```solidity
event PlatformDelisted(bytes32 indexed platformHash);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The identifier of the delisted platform.|

### ProtocolAdminAddressUpdated
*Emitted when the protocol admin address is updated.*


```solidity
event ProtocolAdminAddressUpdated(address indexed newAdminAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newAdminAddress`|`address`|The new protocol admin address.|

### TokenAddedToCurrency
*Emitted when a token is added to a currency.*


```solidity
event TokenAddedToCurrency(bytes32 indexed currency, address indexed token);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currency`|`bytes32`|The currency identifier.|
|`token`|`address`|The token address added.|

### TokenRemovedFromCurrency
*Emitted when a token is removed from a currency.*


```solidity
event TokenRemovedFromCurrency(bytes32 indexed currency, address indexed token);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currency`|`bytes32`|The currency identifier.|
|`token`|`address`|The token address removed.|

### ProtocolFeePercentUpdated
*Emitted when the protocol fee percent is updated.*


```solidity
event ProtocolFeePercentUpdated(uint256 newFeePercent);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newFeePercent`|`uint256`|The new protocol fee percentage.|

### PlatformAdminAddressUpdated
*Emitted when the platform admin address is updated.*


```solidity
event PlatformAdminAddressUpdated(bytes32 indexed platformHash, address indexed newAdminAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The identifier of the platform.|
|`newAdminAddress`|`address`|The new admin address of the platform.|

### PlatformDataAdded
*Emitted when platform data is added.*


```solidity
event PlatformDataAdded(bytes32 indexed platformHash, bytes32 indexed platformDataKey);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The identifier of the platform.|
|`platformDataKey`|`bytes32`|The data key added to the platform.|

### PlatformDataRemoved
*Emitted when platform data is removed.*


```solidity
event PlatformDataRemoved(bytes32 indexed platformHash, bytes32 platformDataKey);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The identifier of the platform.|
|`platformDataKey`|`bytes32`|The data key removed from the platform.|

### DataAddedToRegistry
*Emitted when data is added to the registry.*


```solidity
event DataAddedToRegistry(bytes32 indexed key, bytes32 value);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`key`|`bytes32`|The registry key.|
|`value`|`bytes32`|The registry value.|

## Errors
### GlobalParamsInvalidInput
*Throws when the input address is zero.*


```solidity
error GlobalParamsInvalidInput();
```

### GlobalParamsPlatformNotListed
*Throws when the platform is not listed.*


```solidity
error GlobalParamsPlatformNotListed(bytes32 platformHash);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The identifier of the platform.|

### GlobalParamsPlatformAlreadyListed
*Throws when the platform is already listed.*


```solidity
error GlobalParamsPlatformAlreadyListed(bytes32 platformHash);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The identifier of the platform.|

### GlobalParamsPlatformAdminNotSet
*Throws when the platform admin is not set.*


```solidity
error GlobalParamsPlatformAdminNotSet(bytes32 platformHash);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The identifier of the platform.|

### GlobalParamsPlatformFeePercentIsZero
*Throws when the platform fee percent is zero.*


```solidity
error GlobalParamsPlatformFeePercentIsZero(bytes32 platformHash);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The identifier of the platform.|

### GlobalParamsPlatformDataAlreadySet
*Throws when the platform data is already set.*


```solidity
error GlobalParamsPlatformDataAlreadySet();
```

### GlobalParamsPlatformDataNotSet
*Throws when the platform data is not set.*


```solidity
error GlobalParamsPlatformDataNotSet();
```

### GlobalParamsPlatformDataSlotTaken
*Throws when the platform data slot is already taken.*


```solidity
error GlobalParamsPlatformDataSlotTaken();
```

### GlobalParamsUnauthorized
*Throws when the caller is not authorized.*


```solidity
error GlobalParamsUnauthorized();
```

### GlobalParamsCurrencyTokenLengthMismatch
*Throws when currency and token arrays length mismatch.*


```solidity
error GlobalParamsCurrencyTokenLengthMismatch();
```

### GlobalParamsCurrencyHasNoTokens
*Throws when a currency has no tokens registered.*


```solidity
error GlobalParamsCurrencyHasNoTokens(bytes32 currency);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currency`|`bytes32`|The currency identifier.|

### GlobalParamsTokenNotInCurrency
*Throws when a token is not found in a currency.*


```solidity
error GlobalParamsTokenNotInCurrency(bytes32 currency, address token);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currency`|`bytes32`|The currency identifier.|
|`token`|`address`|The token address.|

## Structs
### GlobalParamsStorage
**Note:**
storage-location: erc7201:ccprotocol.storage.GlobalParams


```solidity
struct GlobalParamsStorage {
    address protocolAdminAddress;
    uint256 protocolFeePercent;
    mapping(bytes32 => bool) platformIsListed;
    mapping(bytes32 => address) platformAdminAddress;
    mapping(bytes32 => uint256) platformFeePercent;
    mapping(bytes32 => bytes32) platformDataOwner;
    mapping(bytes32 => bool) platformData;
    mapping(bytes32 => bytes32) dataRegistry;
    mapping(bytes32 => address[]) currencyToTokens;
    Counters.Counter numberOfListedPlatforms;
}
```

