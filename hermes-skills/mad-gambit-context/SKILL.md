---
name: mad-gambit-context
description: """"
version: 1.0.0
author: "unknown"
license: "MIT"
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [automatically-portled]
    category: general
    related_skills: []
---


# MAD Gambit — Canonical Context

## Brand Rules (CRITICAL)

| Term | Usage |
|---|---|
| **MAD Gambit** | The platform. Always. No exceptions. |
| **MADHATs** | The NFT card game product line within MAD Gambit only |
| **MADHATs Gambit** | OLD branding — never use |

---

## Canonical Numbers (NEVER CHANGE WITHOUT EXPLICIT INSTRUCTION)

| Metric | Value | Notes |
|---|---|---|
| Platform fee | **1.88%** | Global, all markets |
| Community profit share | **28.8%** | Display as 28% in presentations |
| Creator revenue share | **40%** | Creator-made markets only — not general community |
| Seed raise | **$1–2M** | At $12M pre-money valuation |
| Instrument | TBD / SAFE likely | Confirm before investor materials |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | React 18, TypeScript, Hono/HonoX, TailwindCSS |
| Backend | Supabase (Postgres + Edge Functions), Node.js |
| Primary chain | Base L2 |
| Secondary chains | Arbitrum, HyperEVM |
| Smart contracts | Solidity, Foundry, OpenZeppelin |
| Oracles | Chainlink VRF + Price Feeds, Pyth Network |
| Account Abstraction | Alchemy AA-SDK (ERC-4337), modular-account, light-account |
| AI layer | Claude Opus 4.6, MCP servers, GraphRAG, Instructor |
| Blockchain infra | Alchemy (RPC, NFT API, AA Bundler, Gas Manager) |

---

## Product Architecture

### Prediction Markets
- Platform fee: 1.88% on all markets
- Creator markets: 40% revenue share to creator
- Community pool: 28.8% of platform fees
- Oracle resolution: Chainlink (price feeds), Pyth (real-time), UMA (optimistic oracle for subjective)
- Market types: Binary, categorical, scalar
- Settlement: On-chain via smart contract + oracle

### MADHATs NFT Card Game
- Dutch auction scandal packs
- Card evolution system
- Cards as prediction market positions (NFT-gated)
- Multi-chain NFT: Base L2 primary

### $MADx Token
- Governance + staking
- Fee discount tier
- Community profit share distribution mechanism

### Account Abstraction
- ERC-4337 via Alchemy AA-SDK
- Gasless onboarding for new users (sponsored via Alchemy Gas Manager)
- Smart accounts: modular-account (advanced), light-account (standard)

---

## Key Repos

| Repo | Org | Purpose |
|---|---|---|
| MADHATs-Gambit-Presentation | MADdegen | Live investor deck |
| The-MDC (100+ repos) | The-MDC | Core org |
| MADdegen | MADdegen | Personal — forks + experiments |

Live deck: https://maddegen.github.io/MADHATs-Gambit-Presentation/

---

## Forked Infrastructure (Available for Implementation)

### Prediction Market Contracts
- `augur` — Augur v2 protocol (binary/categorical markets)
- `conditional-tokens-contracts` — Gnosis conditional tokens (Polymarket base)
- `ctf-exchange` — Polymarket CTF exchange
- `clob-client` / `py-clob-client` — CLOB orderbook clients
- `protocol` — UMA optimistic oracle

### Oracle Integration
- `chainlink-vrf` — Verifiable random (card packs, randomness)
- `pyth-sdk-solidity` — Real-time price feeds
- `pyth-client-js` — JS oracle client

### Account Abstraction Stack
- `aa-sdk` — Alchemy AA SDK (ERC-4337)
- `modular-account` — Advanced smart account
- `light-account` — Standard smart account
- `rundler` — ERC-4337 bundler (Rust)
- `sponsoring-userops` — Paymaster patterns

### NFT + Marketplace
- `seaport` — OpenSea marketplace protocol
- `opensea-js` — TypeScript SDK
- `openzeppelin-contracts` — Standard contracts
- `permit2` — Token approvals

### AI / Agent Stack
- `graphrag` — Graph-based RAG (for MAD Gambit AI oracle reasoning)
- `instructor` — Structured LLM outputs
- `mcp-agent` — MCP workflow patterns
- `mem0` — Agent memory layer

---

## Open Decisions (as of 2026-03-26)

1. Token launch timing — TGE before or after seed close?
2. Market resolution mechanism for subjective markets — UMA vs custom multisig
3. HyperEVM deployment priority vs. Arbitrum
4. Creator onboarding flow — wallet-required vs. AA gasless from day 1
