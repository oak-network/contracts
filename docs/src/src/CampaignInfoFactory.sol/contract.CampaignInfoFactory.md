# CampaignInfoFactory
[Git Source](https://github.com/ccprotocol/campaign-utils-contracts-aggregator/blob/79d78188e565502f83e2c0309c9a4ea3b35cee91/src/CampaignInfoFactory.sol)

**Inherits:**
[ICampaignInfoFactory](/src/interfaces/ICampaignInfoFactory.sol/interface.ICampaignInfoFactory.md), Ownable

Factory contract for creating campaign information contracts.


## State Variables
### bytecode

```solidity
bytes private constant bytecode = type(CampaignInfo).creationCode;
```


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


## Functions
### constructor


```solidity
constructor(IGlobalParams globalParams);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`globalParams`|`IGlobalParams`|The address of the global parameters contract.|


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

Creates a new campaign information contract.


```solidity
function createCampaign(
    address creator,
    bytes32 identifierHash,
    bytes32[] calldata selectedPlatformBytes,
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
|`selectedPlatformBytes`|`bytes32[]`|An array of platform identifiers selected for the campaign.|
|`platformDataKey`|`bytes32[]`|An array of platform-specific data keys.|
|`platformDataValue`|`bytes32[]`|An array of platform-specific data values.|
|`campaignData`|`CampaignData`|The struct containing campaign launch details.|


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

