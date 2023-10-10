# TestUSD
[Git Source](https://github.com/ccprotocol/campaign-utils-contracts-aggregator/blob/79d78188e565502f83e2c0309c9a4ea3b35cee91/src/TestUSD.sol)

**Inherits:**
ERC20, ERC20Permit, Ownable

A test token `tUSD` which is used in the tests.


## Functions
### constructor


```solidity
constructor() ERC20("testUSD", "tUSD") ERC20Permit("testUSD");
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


