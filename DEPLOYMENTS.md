# Deployments

Canonical record of Oak Network contract deployments per network.

> **Integrators:** always use the proxy addresses. Implementation addresses change on upgrades; the proxies are the stable entry points.

## Celo Mainnet (chain ID 42220)

Deployed from commit [`8280e7e`](https://github.com/oak-network/contracts/commit/8280e7e).

### Core Contracts

Upgradeable via UUPS — the proxy is the address you interact with; the implementation sits behind it.

| Contract | Proxy | Current implementation |
| --- | --- | --- |
| `GlobalParams` | [`0xA92F7fd92c562a3B1Db45EF15B388C11b5b89975`](https://celoscan.io/address/0xA92F7fd92c562a3B1Db45EF15B388C11b5b89975) | [`0x109635d81914b3b6F763f63c85f14d7C44b9bb31`](https://celoscan.io/address/0x109635d81914b3b6F763f63c85f14d7C44b9bb31) |
| `TreasuryFactory` | [`0xf18D315bc26c3dcaaD20ba2723AA6A9A774fc68b`](https://celoscan.io/address/0xf18D315bc26c3dcaaD20ba2723AA6A9A774fc68b) | [`0x48172EB631febc990c33D9F6111ccc48F5601e27`](https://celoscan.io/address/0x48172EB631febc990c33D9F6111ccc48F5601e27) |
| `CampaignInfoFactory` | [`0x82921bdd594E56ddC2722a0a1d6FC13F5c15eEf4`](https://celoscan.io/address/0x82921bdd594E56ddC2722a0a1d6FC13F5c15eEf4) | [`0x5bFEdc8151a99BD6F82A266d6d79AC5FB4BbA5DB`](https://celoscan.io/address/0x5bFEdc8151a99BD6F82A266d6d79AC5FB4BbA5DB) |

### Implementation Contracts

Master copies deployed as clones per campaign; individual campaign and treasury clones are not listed here — they are discoverable through factory events.

| Contract | Address | Notes |
| --- | --- | --- |
| `CampaignInfo` | [`0x7092D62d094305d58900aE339557DDBc892411a5`](https://celoscan.io/address/0x7092D62d094305d58900aE339557DDBc892411a5) | cloned per campaign via `CampaignInfoFactory` |
| `PaymentTreasury` | [`0x871BF839e48fD91cBA7ccF37a3119F84adb54584`](https://celoscan.io/address/0x871BF839e48fD91cBA7ccF37a3119F84adb54584) | treasury model; registered and approved per platform in `TreasuryFactory` |

### Enlisted Platforms

| Platform | Platform hash | Platform admin |
| --- | --- | --- |
| Oak Client | `0x380d02de444b5e73657867182cb87a6a68439ff83f5861ee08812ad27b97ac07` | [`0x08D59f5C0c2e6923fFcA216F3A1941b87E283b67`](https://celoscan.io/address/0x08D59f5C0c2e6923fFcA216F3A1941b87E283b67) |

### Roles

| Role | Address |
| --- | --- |
| Protocol admin | [`0xeAF297815Ec765eecdA15E3fD3509D5B2aCAA272`](https://celoscan.io/address/0xeAF297815Ec765eecdA15E3fD3509D5B2aCAA272) |

### Supported Tokens

| Token | Address |
| --- | --- |
| USDC | [`0xcebA9300f2b948710d2653dD7B07f33A8B32118C`](https://celoscan.io/address/0xcebA9300f2b948710d2653dD7B07f33A8B32118C) |
| USDT | [`0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e`](https://celoscan.io/address/0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e) |

## Celo Sepolia (chain ID 11142220)

Testnet deployment. Deployed from commit [`8280e7e`](https://github.com/oak-network/contracts/commit/8280e7e), built with `via_ir` disabled — so the on-chain `CampaignInfo` runtime bytecode differs from a default build (the repo's `foundry.toml` sets `via_ir = true`), though the source and compiler metadata are identical to mainnet.

### Core Contracts

Upgradeable via UUPS — the proxy is the address you interact with; the implementation sits behind it.

| Contract | Proxy | Current implementation |
| --- | --- | --- |
| `GlobalParams` | [`0x11D9CdF0634Fd278922024C9addd93C7aE85748a`](https://sepolia.celoscan.io/address/0x11D9CdF0634Fd278922024C9addd93C7aE85748a) | [`0x28fe5C5E5A9A0156Aa3bADbd3844eD646bF5791f`](https://sepolia.celoscan.io/address/0x28fe5C5E5A9A0156Aa3bADbd3844eD646bF5791f) |
| `TreasuryFactory` | [`0x982DA9430A62907c38483C5d24F929729D515688`](https://sepolia.celoscan.io/address/0x982DA9430A62907c38483C5d24F929729D515688) | [`0x7f705d7cda588013b15e4a59Ec7B116f68d17bC3`](https://sepolia.celoscan.io/address/0x7f705d7cda588013b15e4a59Ec7B116f68d17bC3) |
| `CampaignInfoFactory` | [`0xFd1cD536876E382F8405Cce5A42525Ce9E37f2d3`](https://sepolia.celoscan.io/address/0xFd1cD536876E382F8405Cce5A42525Ce9E37f2d3) | [`0x1024cbBDd2367c073014A09FceB5Ef8859A0eC18`](https://sepolia.celoscan.io/address/0x1024cbBDd2367c073014A09FceB5Ef8859A0eC18) |

### Implementation Contracts

Master copies cloned per campaign / per treasury; individual clones are discoverable through factory events. The ID column is the implementation's registration index in `TreasuryFactory`.

| Contract | ID | Address |
| --- | --- | --- |
| `CampaignInfo` | – | [`0xdBaEf75a3447237eF83f85206D31e459D88Ad5F5`](https://sepolia.celoscan.io/address/0xdBaEf75a3447237eF83f85206D31e459D88Ad5F5) |
| `PaymentTreasury` | 0 | [`0x7A408ffDcA74ff10D24dbDA887422EE276f40154`](https://sepolia.celoscan.io/address/0x7A408ffDcA74ff10D24dbDA887422EE276f40154) |
| `AllOrNothing` | 1 | [`0xB3593319cE75577b4AD96194413e20CBa49bFECb`](https://sepolia.celoscan.io/address/0xB3593319cE75577b4AD96194413e20CBa49bFECb) |
| `KeepWhatsRaised` | 2 | [`0x325f96E96a12129554A9e02BC7B25CB6071ecC95`](https://sepolia.celoscan.io/address/0x325f96E96a12129554A9e02BC7B25CB6071ecC95) |

### Enlisted Platforms

| Platform | Platform hash | Platform admin |
| --- | --- | --- |
| Test Platform | `0x99888fd9c3c0b13fb80891dd6fa3fa47dd3cbaec59b30606d472475963977e11` | [`0x115bA891fB8F455873a6A89D5d495503f7328F5E`](https://sepolia.celoscan.io/address/0x115bA891fB8F455873a6A89D5d495503f7328F5E) |

No platform adapter (trusted forwarder) is configured on this deployment — ERC-2771 meta-transactions are disabled.

### Roles

| Role | Address |
| --- | --- |
| Protocol admin | [`0x115bA891fB8F455873a6A89D5d495503f7328F5E`](https://sepolia.celoscan.io/address/0x115bA891fB8F455873a6A89D5d495503f7328F5E) |

### Supported Tokens

| Token | Address |
| --- | --- |
| USD (`TestToken` — testnet mock, **not** a real stablecoin) | [`0x7b46288d8A6349710Da17c3c913B188053ee06f3`](https://sepolia.celoscan.io/address/0x7b46288d8A6349710Da17c3c913B188053ee06f3) |

## Upgrade History

| Date | Network | Contract | Old implementation | New implementation | Notes |
| --- | --- | --- | --- | --- | --- |
| – | – | – | – | – | no upgrades yet |
