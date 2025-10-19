# UUPS Upgradeable Contracts Guide

## Overview

The core protocol contracts (`GlobalParams`, `TreasuryFactory`, and `CampaignInfoFactory`) have been converted to UUPS (Universal Upgradeable Proxy Standard) upgradeable contracts with ERC-7201 namespaced storage. This document provides a comprehensive guide on the implementation and usage.

## Architecture

### UUPS Pattern

The UUPS proxy pattern was chosen for the following benefits:
- **Gas Efficiency**: Upgrade logic is in the implementation contract, reducing proxy contract complexity
- **Self-Contained**: Each implementation contains its own upgrade authorization logic
- **ERC-1967 Compatible**: Uses standardized storage slots for implementation addresses

### ERC-7201 Namespaced Storage

All upgradeable contracts use ERC-7201 namespaced storage to prevent storage collisions:
- Storage variables are grouped into structs
- Each contract has a unique storage namespace calculated using `keccak256`
- Storage slots are deterministically calculated to avoid collisions

## Contracts Converted

### 1. GlobalParams

**Storage Namespace**: `ccprotocol.storage.GlobalParams`

**Key Changes**:
- Converted from regular contract to UUPS upgradeable
- Constructor logic moved to `initialize()` function
- All state variables moved to `GlobalParamsStorage` struct
- Added `_authorizeUpgrade()` function restricted to owner

**Upgrade Authorization**: Only the contract owner can upgrade

### 2. TreasuryFactory

**Storage Namespace**: `ccprotocol.storage.TreasuryFactory`

**Key Changes**:
- Converted from regular contract to UUPS upgradeable
- Constructor logic moved to `initialize()` function
- All state variables moved to `TreasuryFactoryStorage` struct
- Added `_authorizeUpgrade()` function restricted to protocol admin

**Upgrade Authorization**: Only the protocol admin can upgrade

### 3. CampaignInfoFactory

**Storage Namespace**: `ccprotocol.storage.CampaignInfoFactory`

**Key Changes**:
- Converted from regular contract to UUPS upgradeable
- Constructor logic moved to `initialize()` function
- All state variables moved to `CampaignInfoFactoryStorage` struct
- Added `_authorizeUpgrade()` function restricted to owner
- Removed legacy `_initialize()` function

**Upgrade Authorization**: Only the contract owner can upgrade

### 4. AdminAccessChecker

**Storage Namespace**: `ccprotocol.storage.AdminAccessChecker`

**Key Changes**:
- Converted to use namespaced storage
- `GLOBAL_PARAMS` moved to `AdminAccessCheckerStorage` struct
- Compatible with upgradeable contracts inheriting from it

## Security Considerations

### Initialization Protection

All upgradeable contracts implement the following security measures:

1. **Constructor Disabling**: Implementation contracts call `_disableInitializers()` in their constructor to prevent direct initialization
2. **Single Initialization**: The `initializer` modifier ensures `initialize()` can only be called once
3. **Upgrade Authorization**: Each contract restricts upgrades to authorized addresses

### Storage Safety

1. **Namespaced Storage**: Prevents storage collisions between upgrades
2. **Storage Layout Preservation**: Existing storage variables maintain their positions
3. **Gap Variables**: Not used as namespaced storage makes them unnecessary

### Upgrade Best Practices

When creating new implementation versions:

1. ✅ **DO**:
   - Add new state variables to the storage struct
   - Add new functions
   - Fix bugs in existing functions
   - Test thoroughly before upgrading

2. ❌ **DON'T**:
   - Change the order of existing storage variables
   - Remove existing storage variables
   - Change the namespace location constant
   - Modify the inheritance hierarchy

## Deployment

### Initial Deployment

1. Deploy the implementation contract
2. Deploy an ERC1967Proxy pointing to the implementation
3. Call the proxy with initialization data

Example:
```solidity
// 1. Deploy implementation
GlobalParams implementation = new GlobalParams();

// 2. Prepare initialization data
bytes memory initData = abi.encodeWithSelector(
    GlobalParams.initialize.selector,
    protocolAdmin,
    protocolFeePercent,
    currencies,
    tokensPerCurrency
);

// 3. Deploy proxy
ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

// 4. Use proxy address as the contract address
GlobalParams globalParams = GlobalParams(address(proxy));
```

### Upgrading

To upgrade an existing proxy:

```solidity
// 1. Deploy new implementation
GlobalParams newImplementation = new GlobalParams();

// 2. Call upgradeToAndCall on the proxy (through the current implementation)
GlobalParams(proxyAddress).upgradeToAndCall(address(newImplementation), "");
```

## Scripts

### Deployment Scripts

- `DeployGlobalParams.s.sol` - Deploys GlobalParams with UUPS proxy
- `DeployTreasuryFactory.s.sol` - Deploys TreasuryFactory with UUPS proxy
- `DeployCampaignInfoFactory.s.sol` - Deploys CampaignInfoFactory with UUPS proxy
- `DeployAll.s.sol` - Deploys all contracts with proxies

### Upgrade Scripts

- `UpgradeGlobalParams.s.sol` - Upgrades GlobalParams implementation
- `UpgradeTreasuryFactory.s.sol` - Upgrades TreasuryFactory implementation
- `UpgradeCampaignInfoFactory.s.sol` - Upgrades CampaignInfoFactory implementation

### Usage

Deploy all contracts:
```bash
forge script script/DeployAll.s.sol:DeployAll --rpc-url $RPC_URL --broadcast
```

Upgrade GlobalParams:
```bash
forge script script/UpgradeGlobalParams.s.sol:UpgradeGlobalParams --rpc-url $RPC_URL --broadcast
```

## Testing

### Unit Tests

All existing unit tests have been updated to work with the proxy pattern:
- `GlobalParams.t.sol` - Tests GlobalParams functionality and upgrades
- `TreasuryFactory.t.sol` - Tests TreasuryFactory functionality and upgrades
- `CampaignInfoFactory.t.sol` - Tests CampaignInfoFactory functionality and upgrades

### Upgrade Tests

`Upgrades.t.sol` contains comprehensive upgrade scenarios:
- Basic upgrade functionality
- Authorization checks
- Storage slot integrity
- Cross-contract upgrades
- Storage collision prevention
- Double initialization prevention

### Running Tests

Run all tests:
```bash
forge test
```

Run only upgrade tests:
```bash
forge test --match-path test/foundry/unit/Upgrades.t.sol
```

Run with verbosity:
```bash
forge test -vvv
```

## Important Notes

### Immutable Args Encoding

`CampaignInfo` contracts are created using `clones-with-immutable-args` library, which requires **`abi.encodePacked`** encoding:

```solidity
// CORRECT - in CampaignInfoFactory.sol
bytes memory args = abi.encodePacked(
    treasuryFactoryAddress,  // 20 bytes at offset 0
    protocolFeePercent,      // 32 bytes at offset 20
    identifierHash           // 32 bytes at offset 52
);
address clone = ClonesWithImmutableArgs.clone(implementation, args);
```

```solidity
// CORRECT - in CampaignInfo.sol (reading)
function getCampaignConfig() public view returns (Config memory config) {
    config.treasuryFactory = _getArgAddress(0);        // Read 20 bytes at offset 0
    config.protocolFeePercent = _getArgUint256(20);    // Read 32 bytes at offset 20
    config.identifierHash = bytes32(_getArgUint256(52)); // Read 32 bytes at offset 52
}
```

⚠️ **Do NOT use `abi.encode`** - it adds padding that breaks the offset calculations!

## Dependencies

### OpenZeppelin Contracts

The implementation uses OpenZeppelin's upgradeable contracts:
- `@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol`
- `@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol`
- `@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol`
- `@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol`

### Installation

The upgradeable contracts library is installed at:
```
lib/openzeppelin-contracts-upgradeable/
```

Remappings in `foundry.toml`:
```toml
remappings = [
  "@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/",
  "@openzeppelin/contracts-upgradeable/=lib/openzeppelin-contracts-upgradeable/contracts/"
]
```

## Storage Layouts

### GlobalParams Storage

```solidity
struct GlobalParamsStorage {
    address protocolAdminAddress;
    uint256 protocolFeePercent;
    mapping(bytes32 => bool) platformIsListed;
    mapping(bytes32 => address) platformAdminAddress;
    mapping(bytes32 => uint256) platformFeePercent;
    mapping(bytes32 => bytes32) platformDataOwner;
    mapping(bytes32 => bool) platformData;
    mapping(bytes32 => bytes32) dataRegistry;
    mapping(bytes32 => address[]) currencyToTokens;
    Counters.Counter numberOfListedPlatforms;
}
```

Storage Location: `0x8c8b3f8e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e00`

### TreasuryFactory Storage

```solidity
struct TreasuryFactoryStorage {
    mapping(bytes32 => mapping(uint256 => address)) implementationMap;
    mapping(address => bool) approvedImplementations;
}
```

Storage Location: `0x9c9c4f9e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e00`

### CampaignInfoFactory Storage

```solidity
struct CampaignInfoFactoryStorage {
    IGlobalParams globalParams;
    address treasuryFactoryAddress;
    address implementation;
    mapping(address => bool) isValidCampaignInfo;
    mapping(bytes32 => address) identifierToCampaignInfo;
}
```

Storage Location: `0xacac5f0e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e00`

## Upgrade Checklist

Before performing an upgrade in production:

- [ ] New implementation contract deployed and verified
- [ ] All tests passing (including upgrade tests)
- [ ] Storage layout verified for compatibility
- [ ] Authorization requirements met
- [ ] Upgrade transaction prepared and reviewed
- [ ] Rollback plan in place
- [ ] Monitor contract state after upgrade

## Common Issues and Solutions

### Issue: Initialization Failed

**Cause**: Trying to initialize an implementation contract directly

**Solution**: Always initialize through the proxy, not the implementation

### Issue: Unauthorized Upgrade

**Cause**: Attempting upgrade from non-authorized address

**Solution**: Ensure the caller is:
- GlobalParams: contract owner
- TreasuryFactory: protocol admin
- CampaignInfoFactory: contract owner

### Issue: Storage Collision

**Cause**: Modifying existing storage variables in upgrade

**Solution**: Only add new variables, never modify or remove existing ones

## References

- [EIP-1967: Proxy Storage Slots](https://eips.ethereum.org/EIPS/eip-1967)
- [EIP-1822: Universal Upgradeable Proxy Standard (UUPS)](https://eips.ethereum.org/EIPS/eip-1822)
- [ERC-7201: Namespaced Storage Layout](https://eips.ethereum.org/EIPS/eip-7201)
- [OpenZeppelin UUPS Proxies](https://docs.openzeppelin.com/contracts/5.x/api/proxy#UUPSUpgradeable)

## Support

For questions or issues related to upgrades, please refer to:
- Project documentation
- OpenZeppelin Upgrades documentation
- Foundry documentation for testing upgradeable contracts

