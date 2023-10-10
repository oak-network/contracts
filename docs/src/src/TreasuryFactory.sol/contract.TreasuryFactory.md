# TreasuryFactory
[Git Source](https://github.com/ccprotocol/campaign-utils-contracts-aggregator/blob/79d78188e565502f83e2c0309c9a4ea3b35cee91/src/TreasuryFactory.sol)

**Inherits:**
[ITreasuryFactory](/src/interfaces/ITreasuryFactory.sol/interface.ITreasuryFactory.md), [AdminAccessChecker](/src/utils/AdminAccessChecker.sol/abstract.AdminAccessChecker.md)


## State Variables
### s_platformBytecode

```solidity
mapping(bytes32 => mapping(uint256 => bytes[])) private s_platformBytecode;
```


### s_platformBytecodeStatus

```solidity
mapping(bytes32 => mapping(uint256 => bool)) private s_platformBytecodeStatus;
```


### s_approvedBytecode

```solidity
mapping(bytes32 => mapping(uint256 => bool)) private s_approvedBytecode;
```


### CAMPAIGN_INFO_FACTORY

```solidity
address private immutable CAMPAIGN_INFO_FACTORY;
```


### CAMPAIGNINFO_BYTECODEHASH

```solidity
bytes32 private immutable CAMPAIGNINFO_BYTECODEHASH;
```


## Functions
### constructor

Initializes the TreasuryFactory contract.

*This constructor sets the address of the GlobalParams contract as the admin.*


```solidity
constructor(IGlobalParams globalParams, address infoFactory, bytes32 bytecodeHash) AdminAccessChecker(globalParams);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`globalParams`|`IGlobalParams`|Address of the GlobalParams contract.|
|`infoFactory`|`address`|Address of the CampaignInfoFactory contract.|
|`bytecodeHash`|`bytes32`|Keccak256 hash of the CampaignInfo bytecode.|


### computeTreasuryAddress

*Function to compute the address of a treasury based on the identifier hash, platform, and bytecode index.*


```solidity
function computeTreasuryAddress(bytes32 identifierHash, bytes32 platformBytes, uint256 bytecodeIndex)
    external
    view
    override
    returns (address treasuryAddress, bool isDeployed);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`identifierHash`|`bytes32`|The unique hash identifier of the campaign.|
|`platformBytes`|`bytes32`|The platform identifier.|
|`bytecodeIndex`|`uint256`|The index of the bytecode template.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`treasuryAddress`|`address`|The computed treasury address.|
|`isDeployed`|`bool`|A boolean indicating whether the treasury is already deployed.|


### addBytecodeChunk

*Function to add a fragment of the full bytecode of treasury contract for a given platform.*


```solidity
function addBytecodeChunk(
    bytes32 platformBytes,
    uint256 bytecodeIndex,
    uint256 chunkIndex,
    bool isLastChunk,
    bytes memory bytecodeChunk
) external override onlyPlatformAdmin(platformBytes);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformBytes`|`bytes32`|The platform identifier.|
|`bytecodeIndex`|`uint256`|The index of the bytecode template.|
|`chunkIndex`|`uint256`|The index of the bytecode chunk.|
|`isLastChunk`|`bool`|The boolean to determine if this is the last chunk.|
|`bytecodeChunk`|`bytes`|The bytecode fragment to add.|


### removeBytecode

*Function to remove a bytecode template for a specific platform and index.*


```solidity
function removeBytecode(bytes32 platformBytes, uint256 bytecodeIndex)
    external
    override
    onlyPlatformAdmin(platformBytes);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformBytes`|`bytes32`|The platform identifier.|
|`bytecodeIndex`|`uint256`|The index of the bytecode template.|


### enlistBytecode

*Function to enlist a bytecode template for deployment.*


```solidity
function enlistBytecode(bytes32 platformBytes, uint256 bytecodeIndex) external onlyProtocolAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformBytes`|`bytes32`|The platform identifier.|
|`bytecodeIndex`|`uint256`|The index of the enlisted bytecode template.|


### delistBytecode

*Function to delist a bytecode template, making it unavailable for deployment.*


```solidity
function delistBytecode(bytes32 platformBytes, uint256 bytecodeIndex) external onlyProtocolAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformBytes`|`bytes32`|The platform identifier.|
|`bytecodeIndex`|`uint256`|The index of the delisted bytecode template.|


### deploy

*Function to deploy a new treasury contract with a specified bytecode template.*


```solidity
function deploy(bytes32 platformBytes, uint256 bytecodeIndex, address infoAddress)
    external
    override
    onlyPlatformAdmin(platformBytes);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformBytes`|`bytes32`|The platform identifier.|
|`bytecodeIndex`|`uint256`|The index of the bytecode template to use for deployment.|
|`infoAddress`|`address`|The address of the associated campaign.|


### _concatenateBytes

*Concatenates multiple byte arrays into one.*


```solidity
function _concatenateBytes(bytes[] memory chunks) private pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`chunks`|`bytes[]`|The byte arrays to concatenate.|


## Events
### TreasuryFactoryBytecodeChunkAdded
*Event emitted when a new bytecode is added for a specific platform and index.*


```solidity
event TreasuryFactoryBytecodeChunkAdded(
    bytes32 indexed platformBytes, uint256 indexed bytecodeIndex, uint256 indexed bytecodeChunk, bytes bytecode
);
```

### TreasuryFactoryBytecodeRemoved
*Event emitted when a bytecode is removed for a specific platform and index.*


```solidity
event TreasuryFactoryBytecodeRemoved(bytes32 indexed platformBytes, uint256 indexed bytecodeIndex);
```

### TreasuryFactoryBytecodeEnlisted
*Event emitted when a bytecode is enlisted for deployment.*


```solidity
event TreasuryFactoryBytecodeEnlisted(bytes32 indexed platformBytes, uint256 indexed bytecodeIndex);
```

### TreasuryFactoryBytecodeDelisted
*Event emitted when a bytecode is delisted and no longer available for deployment.*


```solidity
event TreasuryFactoryBytecodeDelisted(bytes32 indexed platformBytes, uint256 indexed bytecodeIndex);
```

### TreasuryFactoryTreasuryDeployed
*Event emitted when a new treasury is deployed.*


```solidity
event TreasuryFactoryTreasuryDeployed(
    bytes32 indexed platformBytes, uint256 indexed bytecodeIndex, address indexed infoAddress, address treasuryAddress
);
```

## Errors
### TreasuryFactoryUnauthorized

```solidity
error TreasuryFactoryUnauthorized();
```

### TreasuryFactoryInvalidKey

```solidity
error TreasuryFactoryInvalidKey();
```

### TreasuryFactoryIncorrectChunkIndex

```solidity
error TreasuryFactoryIncorrectChunkIndex();
```

### TreasuryFactoryBytecodeExists

```solidity
error TreasuryFactoryBytecodeExists();
```

### TreasuryFactoryBytecodeIsNotAdded

```solidity
error TreasuryFactoryBytecodeIsNotAdded();
```

### TreasuryFactoryBytecodeAlreadyApproved

```solidity
error TreasuryFactoryBytecodeAlreadyApproved();
```

### TreasuryFactoryBytecodeIncomplete

```solidity
error TreasuryFactoryBytecodeIncomplete();
```

### TreasuryFactoryBytecodeNotApproved

```solidity
error TreasuryFactoryBytecodeNotApproved();
```

### TreasuryFactoryTreasuryCreationFailed

```solidity
error TreasuryFactoryTreasuryCreationFailed();
```

### TreasuryFactoryInvalidAddress

```solidity
error TreasuryFactoryInvalidAddress();
```

