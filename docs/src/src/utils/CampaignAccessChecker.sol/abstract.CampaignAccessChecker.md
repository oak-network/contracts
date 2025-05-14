# CampaignAccessChecker
[Git Source](https://github.com/ccprotocol/reference-client-sc/blob/32b7b1617200d0c6f3248845ef972180411f1f65/src/utils/CampaignAccessChecker.sol)

*This abstract contract provides access control mechanisms to restrict the execution of specific functions
to authorized protocol administrators, platform administrators, and campaign owners.*


## State Variables
### INFO

```solidity
ICampaignInfo internal INFO;
```


## Functions
### __CampaignAccessChecker_init

*Constructor to initialize the contract with the address of the campaign information contract.*


```solidity
function __CampaignAccessChecker_init(address campaignInfo) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`campaignInfo`|`address`|The address of the ICampaignInfo contract.|


### onlyProtocolAdmin

*Modifier that restricts function access to protocol administrators only.
Users attempting to execute functions with this modifier must be the protocol admin.*


```solidity
modifier onlyProtocolAdmin();
```

### onlyPlatformAdmin

*Modifier that restricts function access to platform administrators of a specific platform.
Users attempting to execute functions with this modifier must be the platform admin for the given platform.*


```solidity
modifier onlyPlatformAdmin(bytes32 platformHash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The unique identifier of the platform.|


### onlyCampaignOwner

*Modifier that restricts function access to the owner of the campaign.
Users attempting to execute functions with this modifier must be the owner of the campaign.*


```solidity
modifier onlyCampaignOwner();
```

### _onlyProtocolAdmin

*Internal function to check if the sender is the protocol administrator.
If the sender is not the protocol admin, it reverts with AccessCheckerUnauthorized error.*


```solidity
function _onlyProtocolAdmin() private view;
```

### _onlyPlatformAdmin

*Internal function to check if the sender is the platform administrator for a specific platform.
If the sender is not the platform admin, it reverts with AccessCheckerUnauthorized error.*


```solidity
function _onlyPlatformAdmin(bytes32 platformHash) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The unique identifier of the platform.|


### _onlyCampaignOwner

*Internal function to check if the sender is the owner of the campaign.
If the sender is not the owner, it reverts with AccessCheckerUnauthorized error.*


```solidity
function _onlyCampaignOwner() private view;
```

## Errors
### AccessCheckerUnauthorized
*Throws when the caller is not authorized.*


```solidity
error AccessCheckerUnauthorized();
```

