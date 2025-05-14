# CampaignInfoFactory
[Git Source](https://github.com/ccprotocol/reference-client-sc/blob/32b7b1617200d0c6f3248845ef972180411f1f65/src/CampaignInfoFactory.sol)

**Inherits:**
Initializable, [ICampaignInfoFactory](/src/interfaces/ICampaignInfoFactory.sol/interface.ICampaignInfoFactory.md), Ownable

Factory contract for creating campaign information contracts.


## State Variables
### GLOBAL_PARAMS

```solidity
IGlobalParams private GLOBAL_PARAMS;
```


### s_treasuryFactoryAddress

```solidity
address private s_treasuryFactoryAddress;
```


### s_initialized

```solidity
bool private s_initialized;
```


### s_implementation

```solidity
address private s_implementation;
```


### isValidCampaignInfo

```solidity
mapping(address => bool) public isValidCampaignInfo;
```


### identifierToCampaignInfo

```solidity
mapping(bytes32 => address) public identifierToCampaignInfo;
```


## Functions
### constructor


```solidity
constructor(IGlobalParams globalParams, address campaignImplementation) Ownable(msg.sender);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`globalParams`|`IGlobalParams`|The address of the global parameters contract.|
|`campaignImplementation`|`address`||


### _initialize

*Initializes the factory with treasury factory address.*


```solidity
function _initialize(address treasuryFactoryAddress, address globalParams) external onlyOwner initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`treasuryFactoryAddress`|`address`|The address of the treasury factory contract.|
|`globalParams`|`address`|The address of the global parameters contract.|


### createCampaign

Creates a new campaign information contract.


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
|`campaignData`|`CampaignData`|The struct containing campaign launch details.|


### updateImplementation

Updates the campaign implementation address.


```solidity
function updateImplementation(address newImplementation) external override onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|The address of the camapaignInfo implementation contract.|


## Errors
### CampaignInfoFactoryAlreadyInitialized
*Emitted when the factory is initialized.*


```solidity
error CampaignInfoFactoryAlreadyInitialized();
```

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

