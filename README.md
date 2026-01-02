# Oak Network Smart Contracts

## Overview

Oak Network is a decentralized crowdfunding protocol designed to help creators launch and manage campaigns across multiple platforms. By providing a standardized infrastructure, the protocol simplifies the process of creating, funding, and managing crowdfunding initiatives in web3 across different platforms.

## Features

- Cross-listable campaign creation
- Multiple treasury models
- Secure fund management
- Customizable protocol parameters
- Currency-based multi-token campaigns
- Campaign-level Pledge NFTs (one ERC721 collection per campaign)
- ERC-2771 meta-transactions for platform admin operations using multisig wallets
- UUPS upgradeability for core protocol contracts

## Prerequisites

- [Foundry](https://book.getfoundry.sh/)
- Solidity ^0.8.22

## Installation

1. Clone the repository:

```bash
git clone https://github.com/oak-network/contracts.git
cd contracts
```

2. Install dependencies:

```bash
forge install
```

3. Copy environment template:

```bash
cp .env.example .env
```

4. Configure your `.env` file following the template in `.env.example`

## Documentation

Comprehensive documentation is available in the `docs/` folder:

- Technical specifications
- Contract interfaces
- Deployment guides
- Development setup instructions

To view the documentation:

```bash
cd docs
```

## Development

### Compile Contracts

```bash
forge build
```

### Run Tests

```bash
# Run all tests
forge test

# Run specific test
forge test --match-test testFunctionName

# Run tests with more verbose output
forge test -vvv
```

### Deploy Contracts

#### Local Deployment

```bash
# Start local blockchain
anvil

# Deploy to local network
forge script script/DeployAll.s.sol:DeployAll --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY --broadcast
```

#### Network Deployment

```bash
# Deploy to any configured network
forge script script/DeployAll.s.sol:DeployAll --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

#### Deploy core + setup a specific treasury model

If you want a one-shot script that deploys the protocol (UUPS proxies), configures `GlobalParams`, and registers + approves a treasury implementation for a platform, you can run one of the `DeployAllAndSetup*.s.sol` scripts.

```bash
# Example: deploy and setup PaymentTreasury
forge script script/DeployAllAndSetupPaymentTreasury.s.sol:DeployAllAndSetupPaymentTreasury \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

> These scripts read configuration from `.env` (e.g. `PLATFORM_NAME`, `PROTOCOL_FEE_PERCENT`, `PLATFORM_FEE_PERCENT`, `CURRENCIES`/`TOKENS_PER_CURRENCY`, and optional `PLATFORM_ADAPTER_ADDRESS` for meta-txs).

## Contract Architecture

### Core Contracts

- `GlobalParams`: Protocol-wide parameter management
- `CampaignInfoFactory`: Campaign creation and management
- `TreasuryFactory`: Treasury contract deployment

### Treasury Models

- `AllOrNothing`: Funds refunded if campaign goal not met
- `KeepWhatsRaised`: Flexible treasury that keeps funds regardless of goal achievement (tips, configurable fees, withdrawal gating)
- `PaymentTreasury`: Payment-style treasury (off-chain payment creation + on-chain confirmation, line items, optional NFT mint)
- `TimeConstrainedPaymentTreasury`: PaymentTreasury variant gated by `launchTime → deadline + bufferTime`

### Notes on Mock Contracts

- `TestToken` is a mock ERC20 token used **only for testing and development purposes**.
- It is located in the `mocks/` directory and should **not be included in production deployments**.

## Deployment Workflow

At a high level:

1. Deploy `GlobalParams` (UUPS proxy + implementation)
2. Deploy `TreasuryFactory` (UUPS proxy + implementation)
3. Deploy `CampaignInfoFactory` (UUPS proxy + implementation)
4. Configure currencies/tokens + data registry keys + platforms (and optional platform adapters)
5. Register and approve treasury implementations per platform, then deploy treasuries per campaign

> For local testing or development, the `TestToken` mock token needs to be deployed before interacting with contracts requiring an ERC20 token.

## Environment Variables

Key environment variables to configure in `.env`:

- `PRIVATE_KEY`: Deployment wallet private key
- `RPC_URL`: Network RPC endpoint (can be configured for any network)
- `SIMULATE`: Toggle simulation mode
- Contract address variables for reuse

For a complete list of variables, refer to `.env.example`.

> Tip: `script/` contains deployment, setup, and upgrade scripts for each treasury type (including UUPS upgrade scripts).

## Security

### Audits

Security audit reports can be found in the [`audits/`](./audits/) folder. We regularly conduct security audits to ensure the safety and reliability of the protocol.

## Contributing

We welcome all contributions to the Oak Network. If you're interested in helping, here's how you can contribute:

- **Report bugs** by opening issues
- **Suggest enhancements** or new features
- **Submit pull requests** to improve the codebase
- **Improve documentation** to make the project more accessible

Before contributing, please read our detailed [Contributing Guidelines](./CONTRIBUTING.md) for comprehensive information on:
- Development workflow
- Coding standards
- Testing requirements
- Pull request process
- Smart contract security considerations

### Community

Join our community on [Discord](https://discord.gg/tnBhVxSDDS) for questions and discussions.

Read our [Code of Conduct](./CODE_OF_CONDUCT.md) to keep our community approachable and respectful.

## Contributors

<a href="https://github.com/oak-network/contracts/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=oak-network/contracts" />
</a>

Made with [contrib.rocks](https://contrib.rocks).

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).
