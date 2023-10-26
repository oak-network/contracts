# CCP Contracts
This repository contains the smart contracts source code and campaign configuration for Creative Crowdfunding Protocol - CCP. The repository uses Foundry as development environment for compilation, testing and deployment tasks.

## What is CCP?
CCP is a protocol for crowdfunding campaigns that allows creators to multilist campaigns across different crowdfunding platforms. It provides infrastructure tooling and support for platforms to create and manage campaigns in web3.

## Documentation
The detailed technical documentation for the protocol can be found in the [docs](./docs/src/SUMMARY.md) folder.

## Getting Started
### Prerequisites
The following tools are required to be installed in your system:
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/en/download/)

### Installation

```shell
$ npm install
```

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

## Deploy
### Environment Variables

Create an environment file named `.env`, fill the environment variables following the `.env.example` file and source the file using the following command:

```shell
$ source .env
```

### Local Deployment
To deploy the contracts locally, run the following command:

```shell
$ forge script script/Setup.s.sol:SetupScript
```

### Remote Deployment
To deploy the contracts to a remote network, run the following command:

```shell
$ forge script script/Setup.s.sol:SetupScript --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```