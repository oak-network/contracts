# TestUSD
<<<<<<< Updated upstream
[Git Source](https://github.com/ccprotocol/reference-client-sc/blob/32b7b1617200d0c6f3248845ef972180411f1f65/src/TestUSD.sol)
=======
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/4245ef0ad7914158999986aa0d8b5d2614efc6c2/src/TestUSD.sol)
>>>>>>> Stashed changes

**Inherits:**
[ERC20](/src/.deps/npm/@openzeppelin/contracts/token/ERC20/ERC20.sol/abstract.ERC20.md), [Ownable](/src/.deps/npm/@openzeppelin/contracts/access/Ownable.sol/abstract.Ownable.md)

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


