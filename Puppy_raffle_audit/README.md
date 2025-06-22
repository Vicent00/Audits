# PuppyRaffle Smart Contract Security Audit

## Project Overview

PuppyRaffle is a decentralized raffle system built on Ethereum that allows participants to enter raffles to win NFT puppies. The protocol implements an ERC721-based raffle mechanism with automated winner selection and prize distribution.

## Contract Functionality

### Core Features
1. **Raffle Entry**: Users can enter raffles by calling `enterRaffle` with an array of participant addresses
2. **Duplicate Prevention**: The system prevents duplicate addresses from entering
3. **Refund System**: Participants can request refunds before winner selection
4. **Automated Winner Selection**: Winners are selected randomly after a specified duration
5. **NFT Minting**: Winners receive NFT puppies with different rarity levels (Common, Rare, Legendary)
6. **Fee Distribution**: 20% of collected funds go to the protocol owner, 80% to the winner

### Technical Specifications
- **Solidity Version**: 0.7.6
- **Network**: Ethereum Mainnet
- **Token Standard**: ERC721
- **Access Control**: Ownable pattern
- **Random Number Generation**: Block-based (vulnerable to manipulation)

## Getting Started

### Prerequisites
- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [Foundry](https://getfoundry.sh/)

### Installation
```bash
git clone https://github.com/Cyfrin/4-puppy-raffle-audit
cd 4-puppy-raffle-audit
make install
```

### Quick Start
```bash
# Install dependencies
make install

# Run tests
make test

# Run security analysis
make audit

# Generate PDF report
./generate_pdf.sh
```

## Security Audit

### Audit Scope
- **Contract**: `./src/PuppyRaffle.sol`
- **Commit Hash**: e30d199697bbc822b646d76533b66b7d529b8ef5
- **Audit Type**: Full Security Review
- **Audit Date**: May 2025

### Audit Methodology
1. **Static Analysis**: Automated vulnerability detection using Slither
2. **Manual Review**: In-depth code analysis and security assessment
3. **Dynamic Testing**: Proof-of-concept exploitation tests
4. **Gas Analysis**: Optimization and cost analysis
5. **Architecture Review**: Design pattern and best practices assessment

### Key Findings Summary
- **Critical Issues**: 2 vulnerabilities identified
- **High Severity**: 3 vulnerabilities identified  
- **Medium Severity**: 5 vulnerabilities identified
- **Low Severity**: 13 vulnerabilities identified
- **Informational**: 6 recommendations

### Critical Vulnerabilities
1. **Reentrancy Attack in `refund()` Function**: Funds can be drained through multiple refund calls
2. **Reentrancy Attack in `selectWinner()` Function**: Prize distribution can be manipulated

## Contract Architecture

### File Structure
```
./src/
└── PuppyRaffle.sol
```

### Dependencies
- OpenZeppelin Contracts v3.4.0
- Foundry Standard Library
- Base64 Library

### Key Functions
- `enterRaffle(address[] memory newPlayers)`: Enter raffle with participant addresses
- `refund(uint256 playerIndex)`: Request refund for raffle entry
- `selectWinner()`: Select winner and distribute prizes
- `withdrawFees()`: Withdraw accumulated protocol fees
- `changeFeeAddress(address newFeeAddress)`: Update fee collection address

## Testing

### Run All Tests
```bash
forge test
```

### Run Specific Test Categories
```bash
# Run vulnerability tests
forge test --match-contract PuppyRaffleVulnerabilities

# Run with verbose output
forge test -vvv

# Run with gas reporting
forge test --gas-report
```

### Test Coverage
```bash
# Generate coverage report
forge coverage

# Generate detailed coverage report
forge coverage --report debug
```

## Security Analysis

### Static Analysis
```bash
# Run Slither analysis
slither . --config-file slither.config.json

# Generate checklist report
slither . --config-file slither.config.json --checklist
```

### Dynamic Analysis
```bash
# Run proof-of-concept tests
forge test --match-test testReentrancyInRefund -vvv
forge test --match-test testWeakPRNGIsPredictable -vvv
```

## Roles and Permissions

### Owner
- Deployer of the protocol
- Can change fee collection address via `changeFeeAddress()`
- Can withdraw accumulated fees via `withdrawFees()`
- Has significant control over protocol parameters

### Player
- Raffle participants
- Can enter raffles via `enterRaffle()`
- Can request refunds via `refund()`
- Can win NFT puppies and prize pools

## Known Issues

### Critical Security Vulnerabilities
1. **Reentrancy Vulnerabilities**: Multiple functions vulnerable to reentrancy attacks
2. **Predictable Random Number Generation**: Winner selection can be manipulated
3. **Missing Access Controls**: Unauthorized fee withdrawals possible
4. **Denial of Service**: O(n²) complexity in duplicate detection
5. **Outdated Solidity Version**: Using vulnerable 0.7.6 version

### Recommendations
1. **DO NOT DEPLOY** current version to production
2. Implement proper reentrancy protection
3. Use Chainlink VRF for secure randomness
4. Add comprehensive access controls
5. Upgrade to Solidity 0.8.26
6. Optimize gas usage and complexity

## Report Generation

### Generate PDF Report
```bash
# Generate professional PDF audit report
./generate_pdf.sh

# Or use pandoc directly
pandoc notes_audits/real_report.md -o PuppyRaffle_Audit_Report.pdf
```

### Report Contents
- Executive Summary
- Detailed Vulnerability Analysis
- Proof of Concept Tests
- Remediation Recommendations
- Gas Analysis
- Architecture Review

## Contributing

This is an audit project for educational and security assessment purposes. For questions or issues related to the audit findings, please refer to the detailed audit report in `notes_audits/real_report.md`.

## License

This project is for educational purposes and security auditing. The original PuppyRaffle contract and this audit are provided as-is for learning and security assessment.

---

**Audit Team**: Vicente Aguilar  
**Report Date**: May 2025  
**Version**: 1.0
