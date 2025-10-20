# TestUSD
[Git Source](https://github.com/ccprotocol/reference-client-sc/blob/32b7b1617200d0c6f3248845ef972180411f1f65/src/TestUSD.sol)

**Inherits:**
ERC20, Ownable

A test token `tUSD` which is used in the tests.


## Functions
### constructor


```solidity
constructor() ERC20("testUSD", "tUSD") Ownable(msg.sender);
```

### mint

Mints testUSD token.


```solidity
function mint(address to, uint256 amount) public onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The token receivers address.|
|`amount`|`uint256`|The amount of tokens to mint.|


