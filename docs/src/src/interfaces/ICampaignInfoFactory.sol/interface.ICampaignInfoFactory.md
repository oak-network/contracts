# ICampaignInfoFactory
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/7ac353e6507e46c7ee7bc7cb49a3fb20dfde2b56/src/interfaces/ICampaignInfoFactory.sol)

**Inherits:**
[ICampaignData](/src/interfaces/ICampaignData.sol/interface.ICampaignData.md)

An interface for creating and managing campaign information contracts.


## Functions
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
) external;
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
function updateImplementation(address newImplementation) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|The address of the camapaignInfo implementation contract.|


## Events
### CampaignInfoFactoryCampaignCreated
Emitted when a campaign is successfully created.


```solidity
event CampaignInfoFactoryCampaignCreated(bytes32 indexed identifierHash, address indexed campaignInfoAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`identifierHash`|`bytes32`|The unique identifier hash of the campaign.|
|`campaignInfoAddress`|`address`|The address of the created campaign information contract.|

### CampaignInfoFactoryCampaignInitialized
Emitted when the campaign after creation is initialized.


```solidity
event CampaignInfoFactoryCampaignInitialized();
```

