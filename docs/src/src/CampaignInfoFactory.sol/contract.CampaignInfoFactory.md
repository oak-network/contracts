# CampaignInfoFactory
[Git Source](https://github.com/ccprotocol/reference-client-sc/blob/13d9d746c7f79b76f03c178fe64b679ba803191a/src/CampaignInfoFactory.sol)

**Inherits:**
[ICampaignInfoFactory](/src/interfaces/ICampaignInfoFactory.sol/interface.ICampaignInfoFactory.md), Ownable

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
function _initialize(address treasuryFactoryAddress, address globalParams) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`treasuryFactoryAddress`|`address`|The address of the treasury factory contract.|
|`globalParams`|`address`|The address of the global parameters contract.|


### createCampaign


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

### CampaignInfoFactoryCampaignCreationFailed
*Emitted when campaign creation fails.*


```solidity
error CampaignInfoFactoryCampaignCreationFailed();
```

### CampaignInfoFactoryPlatformNotListed

```solidity
error CampaignInfoFactoryPlatformNotListed(bytes32 platformHash);
```

### CampaignInfoFactoryCampaignWithSameIdentifierExists

```solidity
error CampaignInfoFactoryCampaignWithSameIdentifierExists(bytes32 identifierHash, address cloneExists);
```

