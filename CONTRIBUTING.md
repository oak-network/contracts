# Contributing to CC Protocol

Thank you for your interest in contributing to the Creative Crowdfunding Protocol! This document provides detailed guidelines to help you contribute effectively.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
  - [Issues](#issues)
  - [Development Environment](#development-environment)
- [Development Workflow](#development-workflow)
  - [Branching Strategy](#branching-strategy)
  - [Making Changes](#making-changes)
  - [Testing](#testing)
  - [Documentation](#documentation)
- [Smart Contract Development Guidelines](#smart-contract-development-guidelines)
  - [Security Best Practices](#security-best-practices)
  - [Gas Optimization](#gas-optimization)
  - [Code Style](#code-style)
- [Pull Request Process](#pull-request-process)
  - [PR Requirements](#pr-requirements)
  - [Review Process](#review-process)
- [Community](#community)

## Code of Conduct

Please read our [Code of Conduct](./CODE_OF_CONDUCT.md) to understand the behavior we expect from all contributors.

## Getting Started

### Issues

#### Create a New Issue

If you want to add or modify the content of this project:

1. [Search if an issue already exists](https://github.com/ccprotocol/ccprotocol-contracts/issues)
2. If a related issue doesn't exist, create a new issue using the appropriate template
3. Discuss the proposed changes with the community before starting work
4. Wait for issue assignment or approval before submitting a PR

#### Solve an Issue

Scan through our [existing issues](https://github.com/ccprotocol/ccprotocol-contracts/issues) to find one that interests you. You can use labels to filter issues:

- `good first issue`: Suitable for newcomers
- `bug`: Issues with the existing code
- `enhancement`: New features or improvements
- `documentation`: Documentation improvements
- `help wanted`: Issues where help is particularly needed

### Development Environment

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/ccprotocol-contracts.git
   cd ccprotocol-contracts
   ```
3. Add the original repository as upstream:
   ```bash
   git remote add upstream https://github.com/ccprotocol/ccprotocol-contracts.git
   ```
4. Install development dependencies:
   ```bash
   forge install
   ```
5. Copy and configure environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   ```

## Development Workflow

### Branching Strategy

- `main`: Production-ready code
- `develop`: Integration branch for features
- Feature branches: Named as `feature/your-feature-name`
- Bug fix branches: Named as `fix/bug-name`

Always create your working branch from `develop`:

```bash
git checkout develop
git pull upstream develop
git checkout -b feature/your-feature-name
```

### Making Changes

1. Ensure your changes address a specific issue
2. Make commits with clear, descriptive messages
3. Keep changes focused and atomic
4. Rebase your branch regularly to incorporate upstream changes:
   ```bash
   git fetch upstream
   git rebase upstream/develop
   ```

### Testing

All code changes must include appropriate tests:

1. Write unit tests for new functionality
2. Run the test suite to ensure all tests pass:
   ```bash
   forge test
   ```
3. For more detailed test output:
   ```bash
   forge test -vvv
   ```
4. Run gas reports to ensure efficiency:
   ```bash
   forge test --gas-report
   ```

### Documentation

1. Update or add NatSpec comments for all public functions:
   ```solidity
    /**
    * @notice Brief explanation of the function
    * @param paramName Description of the parameter
    * @return Description of the return value
    */
    function exampleFunction(uint256 paramName) public returns (bool) {
       // Function implementation
   }
   ```
2. Update relevant documentation in the `docs/` directory
3. Include a summary of documentation changes in your PR

## Smart Contract Development Guidelines

### Security Best Practices

1. Follow established security patterns
2. Use OpenZeppelin contracts where appropriate
3. Be aware of common vulnerabilities (reentrancy, frontrunning, etc.)
4. Avoid complex control flows that are difficult to audit
5. Consider formal verification for critical functions

### Gas Optimization

1. Be mindful of storage vs. memory usage
2. Batch operations when possible
3. Use appropriate data types (uint256 is often most gas-efficient)
4. Consider gas costs in loops and data structures
5. Include gas reports in PRs for significant changes

### Code Style

1. Follow Solidity style guides
2. Use meaningful variable and function names
3. Format your code using the prettier
4. Keep functions small and focused
5. Use appropriate visibility modifiers (public, external, internal, private)

## Pull Request Process

1. Update the README or documentation if needed
2. Ensure all CI checks pass
3. Create a pull request to the `develop` branch
4. Fill in the PR template with all required information
5. Request review from relevant team members

### PR Requirements

- PR title should be descriptive and reference the issue (e.g., "Fix #123: Add timestamp validation")
- All tests must pass
- Code must be properly formatted
- New code should be covered by tests
- Changes should be well-documented
- Commit history should be clean and logical

### Review Process

1. At least one core contributor must review and approve the changes
2. Address all review comments promptly
3. CI checks must pass
4. Changes may require revision based on feedback
5. Once approved, a maintainer will merge the PR

## Community

- **GitHub Issues**: For bugs and feature requests
- **Discord**: For quick questions and community discussions
- **Pull Requests**: For code review discussions

Join our community on [Discord](https://discord.gg/4tR9rWc3QE).

## License

By contributing to CC Protocol, you agree that your contributions will be licensed under the project's [MIT License](./LICENSE).
