# CampaignInfoFactory
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/08a57a0930f80d6f45ee44fa43ce6ad3e6c3c5c5/src/CampaignInfoFactory.sol)

**Inherits:**
Initializable, [ICampaignInfoFactory](/src/interfaces/ICampaignInfoFactory.sol/interface.ICampaignInfoFactory.md), OwnableUpgradeable, UUPSUpgradeable

Factory contract for creating campaign information contracts.

*UUPS Upgradeable contract with ERC-7201 namespaced storage*


## State Variables
### CAMPAIGN_INFO_FACTORY_STORAGE_LOCATION

```solidity
bytes32 private constant CAMPAIGN_INFO_FACTORY_STORAGE_LOCATION =
    0x2857858a392b093e1f8b3f368c2276ce911f27cef445605a2932ebe945968d00;
```


## Functions
### _getCampaignInfoFactoryStorage


```solidity
function _getCampaignInfoFactoryStorage() private pure returns (CampaignInfoFactoryStorage storage $);
```

### constructor

*Constructor that disables initializers to prevent implementation contract initialization*


```solidity
constructor();
```

### initialize

Initializes the CampaignInfoFactory contract.


```solidity
function initialize(
    address initialOwner,
    IGlobalParams globalParams,
    address campaignImplementation,
    address treasuryFactoryAddress
) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`initialOwner`|`address`|The address that will own the factory|
|`globalParams`|`IGlobalParams`|The address of the global parameters contract.|
|`campaignImplementation`|`address`|The address of the campaign implementation contract.|
|`treasuryFactoryAddress`|`address`|The address of the treasury factory contract.|


### _authorizeUpgrade

*Function that authorizes an upgrade to a new implementation*


```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|


### createCampaign

Creates a new campaign information contract.

*IMPORTANT: Protocol and platform fees are retrieved at execution time and locked
permanently in the campaign contract. Users should verify current fees before
calling this function or using intermediate contracts that check fees haven't
changed from expected values. The protocol fee is stored as immutable in the cloned
contract and platform fees are stored during initialization.*


```solidity
function createCampaign(
    address creator,
    bytes32 identifierHash,
    bytes32[] calldata selectedPlatformHash,
    bytes32[] calldata platformDataKey,
    bytes32[] calldata platformDataValue,
    CampaignData calldata campaignData
) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`creator`|`address`|The address of the creator of the campaign.|
|`identifierHash`|`bytes32`|The unique identifier hash of the campaign.|
|`selectedPlatformHash`|`bytes32[]`|An array of platform identifiers selected for the campaign.|
|`platformDataKey`|`bytes32[]`|An array of platform-specific data keys.|
|`platformDataValue`|`bytes32[]`|An array of platform-specific data values.|
|`campaignData`|`CampaignData`|The struct containing campaign launch details (including currency).|


### updateImplementation

Updates the campaign implementation address.


```solidity
function updateImplementation(address newImplementation) external override onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|The address of the camapaignInfo implementation contract.|


### isValidCampaignInfo

Check if a campaign info address is valid


```solidity
function isValidCampaignInfo(address campaignInfo) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`campaignInfo`|`address`|The campaign info address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if valid, false otherwise|


### identifierToCampaignInfo

Get campaign info address from identifier


```solidity
function identifierToCampaignInfo(bytes32 identifierHash) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`identifierHash`|`bytes32`|The identifier hash|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|address The campaign info address|


## Errors
### CampaignInfoFactoryInvalidInput
*Emitted when invalid input is provided.*


```solidity
error CampaignInfoFactoryInvalidInput();
```

### CampaignInfoFactoryCampaignInitializationFailed
*Emitted when campaign creation fails.*


```solidity
error CampaignInfoFactoryCampaignInitializationFailed();
```

### CampaignInfoFactoryPlatformNotListed

```solidity
error CampaignInfoFactoryPlatformNotListed(bytes32 platformHash);
```

### CampaignInfoFactoryCampaignWithSameIdentifierExists

```solidity
error CampaignInfoFactoryCampaignWithSameIdentifierExists(bytes32 identifierHash, address cloneExists);
```

### CampaignInfoInvalidTokenList
*Emitted when the campaign currency has no tokens.*


```solidity
error CampaignInfoInvalidTokenList();
```

## Structs
### CampaignInfoFactoryStorage
**Note:**
storage-location: erc7201:ccprotocol.storage.CampaignInfoFactory


```solidity
struct CampaignInfoFactoryStorage {
    IGlobalParams globalParams;
    address treasuryFactoryAddress;
    address implementation;
    mapping(address => bool) isValidCampaignInfo;
    mapping(bytes32 => address) identifierToCampaignInfo;
}
```

