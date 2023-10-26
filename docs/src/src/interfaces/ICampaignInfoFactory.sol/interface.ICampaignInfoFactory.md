# ICampaignInfoFactory
[Git Source](https://github.com/ccprotocol/campaign-utils-contracts-aggregator/blob/79d78188e565502f83e2c0309c9a4ea3b35cee91/src/interfaces/ICampaignInfoFactory.sol)

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
    bytes32[] calldata selectedPlatformBytes,
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
|`selectedPlatformBytes`|`bytes32[]`|An array of platform identifiers selected for the campaign.|
|`platformDataKey`|`bytes32[]`|An array of platform-specific data keys.|
|`platformDataValue`|`bytes32[]`|An array of platform-specific data values.|
|`campaignData`|`CampaignData`|The struct containing campaign launch details.|


## Events
### CampaignInfoFactoryCampaignCreated
Emitted when a campaign is successfully created.


```solidity
event CampaignInfoFactoryCampaignCreated(bytes32 indexed identifierHash, address indexed campaignInfoAddress);
```

