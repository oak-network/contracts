# CampaignAccessChecker
[Git Source](https://github.com/oak-network/contracts/blob/0ce055a8ba31ca09404e9d09ecd2549534cbec61/src/utils/CampaignAccessChecker.sol)

**Inherits:**
Context

This abstract contract provides access control mechanisms to restrict the execution of specific functions
to authorized protocol administrators, platform administrators, and campaign owners.


## State Variables
### INFO

```solidity
ICampaignInfo internal INFO
```


### _trustedForwarder
Trusted forwarder address for ERC-2771 meta-transactions (set by derived contracts)


```solidity
address internal _trustedForwarder
```


## Functions
### __CampaignAccessChecker_init

Constructor to initialize the contract with the address of the campaign information contract.


```solidity
function __CampaignAccessChecker_init(address campaignInfo) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`campaignInfo`|`address`|The address of the ICampaignInfo contract.|


### onlyProtocolAdmin

Modifier that restricts function access to protocol administrators only.
Users attempting to execute functions with this modifier must be the protocol admin.


```solidity
modifier onlyProtocolAdmin() ;
```

### onlyPlatformAdmin

Modifier that restricts function access to platform administrators of a specific platform.
Users attempting to execute functions with this modifier must be the platform admin for the given platform.


```solidity
modifier onlyPlatformAdmin(bytes32 platformHash) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The unique identifier of the platform.|


### onlyCampaignOwner

Modifier that restricts function access to the owner of the campaign.
Users attempting to execute functions with this modifier must be the owner of the campaign.


```solidity
modifier onlyCampaignOwner() ;
```

### _onlyProtocolAdmin

Internal function to check if the sender is the protocol administrator.
If the sender is not the protocol admin, it reverts with AccessCheckerUnauthorized error.


```solidity
function _onlyProtocolAdmin() private view;
```

### _onlyPlatformAdmin

Internal function to check if the sender is the platform administrator for a specific platform.
If the sender is not the platform admin, it reverts with AccessCheckerUnauthorized error.


```solidity
function _onlyPlatformAdmin(bytes32 platformHash) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The unique identifier of the platform.|


### _onlyCampaignOwner

Internal function to check if the sender is the owner of the campaign.
If the sender is not the owner, it reverts with AccessCheckerUnauthorized error.


```solidity
function _onlyCampaignOwner() private view;
```

## Errors
### AccessCheckerUnauthorized
Throws when the caller is not authorized.


```solidity
error AccessCheckerUnauthorized();
```

