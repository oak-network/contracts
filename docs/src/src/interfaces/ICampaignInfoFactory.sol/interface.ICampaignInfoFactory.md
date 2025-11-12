# ICampaignInfoFactory
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/fbdbad195ebe6c636608bb8168723963b1f37dd9/src/interfaces/ICampaignInfoFactory.sol)

**Inherits:**
[ICampaignData](/Users/mahabubalahi/Documents/ccp/ccprotocol-contracts-internal/docs/src/src/interfaces/ICampaignData.sol/interface.ICampaignData.md)

An interface for creating and managing campaign information contracts.


## Functions
### createCampaign

Creates a new campaign information contract with NFT.

IMPORTANT: Protocol and platform fees are retrieved at execution time and locked
permanently in the campaign contract. Users should verify current fees before
calling this function or using intermediate contracts that check fees haven't
changed from expected values. The protocol fee is stored as immutable in the cloned
contract and platform fees are stored during initialization.


```solidity
function createCampaign(
    address creator,
    bytes32 identifierHash,
    bytes32[] calldata selectedPlatformHash,
    bytes32[] calldata platformDataKey,
    bytes32[] calldata platformDataValue,
    CampaignData calldata campaignData,
    string calldata nftName,
    string calldata nftSymbol,
    string calldata nftImageURI,
    string calldata contractURI
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
|`campaignData`|`CampaignData`|The struct containing campaign launch details (including currency).|
|`nftName`|`string`|NFT collection name|
|`nftSymbol`|`string`|NFT collection symbol|
|`nftImageURI`|`string`|NFT image URI for individual tokens|
|`contractURI`|`string`|IPFS URI for contract-level metadata|


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

