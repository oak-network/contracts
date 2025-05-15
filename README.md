# Creative Crowdfunding Protocol (CC Protocol) Smart Contracts

## Overview

CC Protocol is a decentralized crowdfunding protocol designed to help creators launch and manage campaigns across multiple platforms. By providing a standardized infrastructure, the protocol simplifies the process of creating, funding, and managing crowdfunding initiatives in web3 across different platforms.

## Features

- Cross-listable campaign creation
- Multiple treasury models
- Secure fund management
- Customizable protocol parameters

## Prerequisites

- [Foundry](https://book.getfoundry.sh/)
- Solidity ^0.8.20
- Node.js (recommended)

## Installation

1. Clone the repository:

```bash
git clone https://github.com/ccprotocol/ccprotocol-contracts.git
cd ccprotocol-contracts
```

2. Install dependencies:

```bash
forge install
```

3. Copy environment template:

```bash
cp .env.example .env
```

4. Configure your `.env` file with:

- Private key
- RPC URL
- (Optional) Contract addresses for reuse

## Documentation

Comprehensive documentation is available in the `docs/` folder:

- Technical specifications
- Contract interfaces
- Deployment guides
- Development setup instructions

To view the documentation:

```bash
# Navigate to docs folder
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

#### Testnet Deployment

```bash
# Deploy to testnet
forge script script/DeployAll.s.sol:DeployAll --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv
```

## Contract Architecture

### Core Contracts

- `TestUSD`: Mock ERC20 token for testing
- `GlobalParams`: Protocol-wide parameter management
- `CampaignInfoFactory`: Campaign creation and management
- `TreasuryFactory`: Treasury contract deployment

### Treasury Models

- `AllOrNothing`: Funds refunded if campaign goal not met

## Deployment Workflow

1. Deploy `TestUSD`
2. Deploy `GlobalParams`
3. Deploy `TreasuryFactory`
4. Deploy `CampaignInfoFactory`

## Environment Variables

Key environment variables in `.env`:

- `PRIVATE_KEY`: Deployment wallet private key
- `RPC_URL`: Network RPC endpoint
- `SIMULATE`: Toggle simulation mode
- Contract address variables for reuse

## Troubleshooting

- Ensure sufficient network gas tokens
- Verify RPC URL connectivity
- Check contract dependencies

## License

[SPDX-License-Identifier: MIT]
