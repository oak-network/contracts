# PermitData
[Git Source](https://github.com/oak-network/contracts/blob/6c7f67f5ed14ef0f4f9444b95ac6770ae2af756a/src/interfaces/IPermit2.sol)

Application-specific struct bundling the Permit2 fields a caller must
supply alongside each signature-based token transfer.


```solidity
struct PermitData {
uint256 nonce;
uint256 deadline;
bytes signature;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`nonce`|`uint256`|    Unique nonce preventing signature replay (managed by Permit2).|
|`deadline`|`uint256`| Unix timestamp after which the permit is no longer valid.|
|`signature`|`bytes`|EIP-712 signature produced by the token owner.|

