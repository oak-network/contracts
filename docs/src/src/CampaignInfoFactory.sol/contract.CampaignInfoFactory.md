# CampaignInfoFactory
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/e5024d64e3fbbb8a9ba5520b2280c0e3ebc75174/src/CampaignInfoFactory.sol)

**Inherits:**
Initializable, [ICampaignInfoFactory](/Users/mahabubalahi/Documents/ccp/ccprotocol-contracts-internal/docs/src/src/interfaces/ICampaignInfoFactory.sol/interface.ICampaignInfoFactory.md), OwnableUpgradeable, UUPSUpgradeable

Factory contract for creating campaign information contracts.

UUPS Upgradeable contract with ERC-7201 namespaced storage


## Functions
### constructor

Constructor that disables initializers to prevent implementation contract initialization


```solidity
constructor() ;
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

Function that authorizes an upgrade to a new implementation


```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|


### createCampaign

Creates a new campaign with NFT

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
) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`creator`|`address`|The campaign creator address|
|`identifierHash`|`bytes32`|The unique identifier hash for the campaign|
|`selectedPlatformHash`|`bytes32[]`|Array of selected platform hashes|
|`platformDataKey`|`bytes32[]`|Array of platform data keys|
|`platformDataValue`|`bytes32[]`|Array of platform data values|
|`campaignData`|`CampaignData`|The campaign data|
|`nftName`|`string`|NFT collection name|
|`nftSymbol`|`string`|NFT collection symbol|
|`nftImageURI`|`string`|NFT image URI for individual tokens|
|`contractURI`|`string`|IPFS URI for contract-level metadata (constructed off-chain)|


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
Emitted when invalid input is provided.


```solidity
error CampaignInfoFactoryInvalidInput();
```

### CampaignInfoFactoryCampaignInitializationFailed
Emitted when campaign creation fails.


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
Emitted when the campaign currency has no tokens.


```solidity
error CampaignInfoInvalidTokenList();
```

