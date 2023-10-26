# ITreasuryFactory
[Git Source](https://github.com/ccprotocol/campaign-utils-contracts-aggregator/blob/79d78188e565502f83e2c0309c9a4ea3b35cee91/src/interfaces/ITreasuryFactory.sol)

*Interface for the TreasuryFactory contract, which deploys campaign treasuries with specific bytecode.*


## Functions
### computeTreasuryAddress

*Function to compute the address of a treasury based on the identifier hash, platform, and bytecode index.*


```solidity
function computeTreasuryAddress(bytes32 identifierHash, bytes32 platformBytes, uint256 bytecodeIndex)
    external
    view
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
) external;
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
function removeBytecode(bytes32 platformBytes, uint256 bytecodeIndex) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformBytes`|`bytes32`|The platform identifier.|
|`bytecodeIndex`|`uint256`|The index of the bytecode template.|


### deploy

*Function to deploy a new treasury contract with a specified bytecode template.*


```solidity
function deploy(bytes32 platformBytes, uint256 bytecodeIndex, address infoAddress) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformBytes`|`bytes32`|The platform identifier.|
|`bytecodeIndex`|`uint256`|The index of the bytecode template to use for deployment.|
|`infoAddress`|`address`|The address of the associated campaign.|


