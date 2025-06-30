# TSwap Smart Contract Audit

## Overview
Security audit of the TSwap protocol, a decentralized exchange (DEX) implementation featuring automated market making (AMM) functionality.

## Project Details
- **Protocol**: TSwap DEX
- **Technology**: Solidity 0.8.20
- **Files Audited**: 2 contracts (350 nSLOC)
- **Audit Date**: 2024

## Contracts Analyzed
- `PoolFactory.sol` - Factory contract for creating TSwap pools
- `TSwapPool.sol` - Core AMM pool implementation


## Files Included
- `report_official.pdf` - Complete audit report
- `src/` - Original smart contracts
- `test/` - Test files
- `script/` - Deployment scripts
- `audit-data/` - Detailed audit notes and findings

## Security Assessment
The audit identified critical reentrancy vulnerabilities that could allow attackers to manipulate pool state. Additional code quality improvements were recommended for production deployment.

## Tools Used
- Aderyn static analysis
- Manual code review
- Automated vulnerability scanning
