# TestUSD
[Git Source](https://github.com/ccprotocol/reference-client-sc/blob/13d9d746c7f79b76f03c178fe64b679ba803191a/src/TestUSD.sol)

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


