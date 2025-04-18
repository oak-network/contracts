# AddressCalculator
[Git Source](https://github.com/ccprotocol/reference-client-sc/blob/13d9d746c7f79b76f03c178fe64b679ba803191a/src/utils/AddressCalculator.sol)

A Solidity library for computing contract addresses and checking if a contract is deployed at a given address.


## Functions
### computeAddress

*Computes the contract address using CREATE2 and checks if the contract is deployed.*


```solidity
function computeAddress(bytes32 salt, bytes32 bytecodeHash, address deployer)
    internal
    view
    returns (address addr, bool isValid);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`salt`|`bytes32`|The salt value used for address computation.|
|`bytecodeHash`|`bytes32`|The keccak256 hash of the contract's bytecode.|
|`deployer`|`address`|The address that deploys the contract.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`addr`|`address`|The computed contract address.|
|`isValid`|`bool`|True if a contract is deployed at the address; otherwise, false.|


### checkIfContractDeployed

*Checks if a contract is deployed at the given address.*


```solidity
function checkIfContractDeployed(address addr) internal view returns (bool isValid);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`addr`|`address`|The address to check for contract deployment.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isValid`|`bool`|True if a contract is deployed at the address; otherwise, false.|


