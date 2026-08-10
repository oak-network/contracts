# ISignatureTransfer
[Git Source](https://github.com/oak-network/contracts/blob/6c7f67f5ed14ef0f4f9444b95ac6770ae2af756a/src/interfaces/IPermit2.sol)

**Inherits:**
[IEIP712](/src/interfaces/IPermit2.sol/interface.IEIP712.md)

**Title:**
ISignatureTransfer

Handles ERC20 token transfers through signature based actions

Requires user's token approval on the Permit2 contract


## Functions
### nonceBitmap

A map from token owner address and a caller specified word index to a bitmap.


```solidity
function nonceBitmap(address, uint256) external view returns (uint256);
```

### permitTransferFrom

Transfers a token using a signed permit message


```solidity
function permitTransferFrom(
    PermitTransferFrom memory permit,
    SignatureTransferDetails calldata transferDetails,
    address owner,
    bytes calldata signature
) external;
```

### permitWitnessTransferFrom

Transfers a token using a signed permit message with extra witness data


```solidity
function permitWitnessTransferFrom(
    PermitTransferFrom memory permit,
    SignatureTransferDetails calldata transferDetails,
    address owner,
    bytes32 witness,
    string calldata witnessTypeString,
    bytes calldata signature
) external;
```

### permitTransferFrom

Transfers multiple tokens using a signed permit message


```solidity
function permitTransferFrom(
    PermitBatchTransferFrom memory permit,
    SignatureTransferDetails[] calldata transferDetails,
    address owner,
    bytes calldata signature
) external;
```

### permitWitnessTransferFrom

Transfers multiple tokens using a signed permit message with extra witness data


```solidity
function permitWitnessTransferFrom(
    PermitBatchTransferFrom memory permit,
    SignatureTransferDetails[] calldata transferDetails,
    address owner,
    bytes32 witness,
    string calldata witnessTypeString,
    bytes calldata signature
) external;
```

### invalidateUnorderedNonces

Invalidates the bits specified in mask for the bitmap at the word position


```solidity
function invalidateUnorderedNonces(uint256 wordPos, uint256 mask) external;
```

## Events
### UnorderedNonceInvalidation
Emits an event when the owner successfully invalidates an unordered nonce.


```solidity
event UnorderedNonceInvalidation(address indexed owner, uint256 word, uint256 mask);
```

## Errors
### InvalidAmount
Thrown when the requested amount for a transfer is larger than the permissioned amount


```solidity
error InvalidAmount(uint256 maxAmount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`maxAmount`|`uint256`|The maximum amount a spender can request to transfer|

### LengthMismatch
Thrown when the number of tokens permissioned to a spender does not match the number of tokens being transferred


```solidity
error LengthMismatch();
```

## Structs
### TokenPermissions
The token and amount details for a transfer signed in the permit transfer signature


```solidity
struct TokenPermissions {
    address token;
    uint256 amount;
}
```

### PermitTransferFrom
The signed permit message for a single token transfer


```solidity
struct PermitTransferFrom {
    TokenPermissions permitted;
    uint256 nonce;
    uint256 deadline;
}
```

### SignatureTransferDetails
Specifies the recipient address and amount for batched transfers.


```solidity
struct SignatureTransferDetails {
    address to;
    uint256 requestedAmount;
}
```

### PermitBatchTransferFrom
Used to reconstruct the signed permit message for multiple token transfers


```solidity
struct PermitBatchTransferFrom {
    TokenPermissions[] permitted;
    uint256 nonce;
    uint256 deadline;
}
```

