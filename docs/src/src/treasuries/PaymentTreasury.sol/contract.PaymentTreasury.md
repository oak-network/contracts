# PaymentTreasury
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/4076c45194ab23360a65e56402b026ef44f70a42/src/treasuries/PaymentTreasury.sol)

**Inherits:**
[BasePaymentTreasury](/src/utils/BasePaymentTreasury.sol/abstract.BasePaymentTreasury.md)


## State Variables
### s_name

```solidity
string private s_name;
```


### s_symbol

```solidity
string private s_symbol;
```


## Functions
### constructor

*Constructor for the AllOrNothing contract.*


```solidity
constructor();
```

### initialize


```solidity
function initialize(bytes32 _platformHash, address _infoAddress, string calldata _name, string calldata _symbol)
    external
    initializer;
```

### name


```solidity
function name() public view returns (string memory);
```

### symbol


```solidity
function symbol() public view returns (string memory);
```

### claimRefund

Claims a refund for a specific payment ID.


```solidity
function claimRefund(bytes32 paymentId, address refundAddress) public override whenNotPaused whenNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the refundable payment.|
|`refundAddress`|`address`|The address where the refunded amount should be sent.|


### disburseFees

Disburses fees collected by the treasury.


```solidity
function disburseFees() public override whenNotPaused whenNotCancelled;
```

### withdraw

Withdraws funds from the treasury.


```solidity
function withdraw() public override whenNotPaused whenNotCancelled;
```

### cancelTreasury

*This function is overridden to allow the platform admin and the campaign owner to cancel a treasury.*


```solidity
function cancelTreasury(bytes32 message) public override;
```

### _checkSuccessCondition

*Internal function to check the success condition for fee disbursement.*


```solidity
function _checkSuccessCondition() internal view virtual override returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the success condition is met.|


## Errors
### PaymentTreasuryUnAuthorized
*Emitted when an unauthorized action is attempted.*


```solidity
error PaymentTreasuryUnAuthorized();
```

### PaymentTreasuryFeeAlreadyDisbursed
*Emitted when `disburseFees` after fee is disbursed already.*


```solidity
error PaymentTreasuryFeeAlreadyDisbursed();
```

