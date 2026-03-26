---
name: build-contract
description: Scaffold or extend a MADHATs smart contract with full security review
allowed_tools: ["Bash", "Read", "Write"]
---
# /build-contract

## Goal
Create production-ready Solidity contract for MADHATs Gambit.

## Pre-execution
1. Read .claude/skills/madhats/smart-contracts.md
2. Read PROJECTS/smart-contracts/ for existing architecture
3. Use AskUserQuestion: contract type, chain target, upgrade pattern

## Execution Steps
1. Scaffold with OpenZeppelin base contracts
2. Implement core logic
3. Add events for all state changes
4. Write Foundry tests (unit + fuzz)
5. Run security checklist from smart-contracts.md
6. Generate deployment script

## Output (write to OUTPUTS/contracts/)
- ContractName.sol
- ContractName.t.sol (tests)
- Deploy_ContractName.s.sol (deployment script)
- audit-notes.md (security notes)
