# PledgeNFT
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/e5024d64e3fbbb8a9ba5520b2280c0e3ebc75174/src/utils/PledgeNFT.sol)

**Inherits:**
ERC721Burnable, AccessControl

Abstract contract for NFTs representing pledges with on-chain metadata

Contains counter logic and NFT metadata storage


## State Variables
### MINTER_ROLE

```solidity
bytes32 public constant MINTER_ROLE = 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6
```


### s_nftName

```solidity
string internal s_nftName
```


### s_nftSymbol

```solidity
string internal s_nftSymbol
```


### s_imageURI

```solidity
string internal s_imageURI
```


### s_contractURI

```solidity
string internal s_contractURI
```


### s_tokenIdCounter

```solidity
Counters.Counter internal s_tokenIdCounter
```


### s_pledgeData

```solidity
mapping(uint256 => PledgeData) internal s_pledgeData
```


## Functions
### _initializeNFT

Initialize NFT metadata

Called by CampaignInfo during initialization


```solidity
function _initializeNFT(
    string calldata _nftName,
    string calldata _nftSymbol,
    string calldata _imageURI,
    string calldata _contractURI
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_nftName`|`string`|NFT collection name|
|`_nftSymbol`|`string`|NFT collection symbol|
|`_imageURI`|`string`|NFT image URI for individual tokens|
|`_contractURI`|`string`|IPFS URI for contract-level metadata|


### mintNFTForPledge

Mints a pledge NFT (auto-increments counter)

Called by treasuries - returns the new token ID to use as pledge ID


```solidity
function mintNFTForPledge(
    address backer,
    bytes32 reward,
    address tokenAddress,
    uint256 amount,
    uint256 shippingFee,
    uint256 tipAmount
) public virtual onlyRole(MINTER_ROLE) returns (uint256 tokenId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`backer`|`address`|The backer address|
|`reward`|`bytes32`|The reward identifier|
|`tokenAddress`|`address`|The address of the token used for the pledge|
|`amount`|`uint256`|The pledge amount|
|`shippingFee`|`uint256`|The shipping fee|
|`tipAmount`|`uint256`|The tip amount|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The minted token ID (to be used as pledge ID in treasury)|


### burn

Burns a pledge NFT


```solidity
function burn(uint256 tokenId) public virtual override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The token ID to burn|


### name

Override name to return initialized name


```solidity
function name() public view virtual override returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The NFT collection name|


### symbol

Override symbol to return initialized symbol


```solidity
function symbol() public view virtual override returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The NFT collection symbol|


### setImageURI

Sets the image URI for all NFTs

Must be overridden by inheriting contracts to implement access control


```solidity
function setImageURI(string calldata newImageURI) external virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImageURI`|`string`|The new image URI|


### contractURI

Returns contract-level metadata URI


```solidity
function contractURI() external view virtual returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The contract URI|


### updateContractURI

Update contract-level metadata URI

Must be overridden by inheriting contracts to implement access control


```solidity
function updateContractURI(string calldata newContractURI) external virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newContractURI`|`string`|The new contract URI|


### getPledgeCount

Gets current total number of pledges


```solidity
function getPledgeCount() external view virtual returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current pledge count|


### tokenURI

Returns the token URI with on-chain metadata


```solidity
function tokenURI(uint256 tokenId) public view virtual override returns (string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The token ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The base64 encoded JSON metadata|


### getImageURI

Gets the image URI


```solidity
function getImageURI() external view returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The current image URI|


### getPledgeData

Gets the pledge data for a token


```solidity
function getPledgeData(uint256 tokenId) external view returns (PledgeData memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The token ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`PledgeData`|The pledge data|


### supportsInterface

Override supportsInterface for multiple inheritance

Internal function to set pledge data for a token


```solidity
function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`interfaceId`|`bytes4`|The interface ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the interface is supported|


## Events
### ImageURIUpdated
Emitted when the image URI is updated


```solidity
event ImageURIUpdated(string newImageURI);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImageURI`|`string`|The new image URI|

### ContractURIUpdated
Emitted when the contract URI is updated


```solidity
event ContractURIUpdated(string newContractURI);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newContractURI`|`string`|The new contract URI|

### PledgeNFTMinted
Emitted when a pledge NFT is minted


```solidity
event PledgeNFTMinted(uint256 indexed tokenId, address indexed backer, address indexed treasury, bytes32 reward);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The token ID|
|`backer`|`address`|The backer address|
|`treasury`|`address`|The treasury address|
|`reward`|`bytes32`|The reward identifier|

## Errors
### PledgeNFTUnAuthorized
Emitted when unauthorized access is attempted


```solidity
error PledgeNFTUnAuthorized();
```

## Structs
### PledgeData
Struct to store pledge data for each token


```solidity
struct PledgeData {
    address backer;
    bytes32 reward;
    address treasury;
    address tokenAddress;
    uint256 amount;
    uint256 shippingFee;
    uint256 tipAmount;
}
```

