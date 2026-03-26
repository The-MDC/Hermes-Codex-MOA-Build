# Skill: Smart Contract Development — MADHATs Gambit

## When to Use This Skill
Trigger for: Solidity contracts, Foundry tests, contract deployment, gas optimization,
ERC standards implementation, oracle integration, NFT mechanics, prediction market resolution.

## Stack
- Language: Solidity ^0.8.20
- Framework: Foundry (forge, cast, anvil)
- Libraries: OpenZeppelin Contracts v5, solmate (gas optimization)
- Testing: Foundry test suite, fuzzing enabled
- Chains: Base L2 (primary), Arbitrum (secondary), HyperEVM

## Contract Architecture Patterns
### NFT Cards
- ERC-1155 for card collections (gas efficient, batch transfers)
- ERC-721 for legendary/unique cards
- Dutch auction mechanics: price decreases over time blocks
- Card evolution: burn-to-upgrade pattern

### Prediction Markets
- Gnosis conditional tokens as base primitive
- UMA/Optimistic Oracle for resolution
- Chainlink VRF for randomness (scandal pack reveals)
- Pyth Network for price feeds
- Platform fee: exactly 1.88% — hardcoded, immutable

### $MADx Token
- ERC-20 with governance extension
- Community profit share: 28.8% of platform fees
- Creator market share: 40% to creator address only
- Staking module: separate contract

## Security Checklist (run before every deployment)
- [ ] Reentrancy guards on all external calls
- [ ] Access control via OpenZeppelin Ownable2Step
- [ ] Integer overflow: use checked math (Solidity 0.8+ default)
- [ ] Chainlink VRF: request/fulfill pattern with commit-reveal
- [ ] Fee calculation: use basis points (188 bps = 1.88%)
- [ ] Upgrade pattern: UUPS or transparent proxy if upgradeable
- [ ] Run: `forge test --fuzz-runs 10000`
- [ ] Run: slither analysis

## Testing Standards
- Unit tests: every public function
- Integration tests: full user journey
- Fuzz tests: all arithmetic and access control
- Fork tests: Base + Arbitrum mainnet forks
