---
name: alchemy-api
description: "name: alchemy-api
description: >
  Integrates Alchemy blockchain APIs using an API key for EVM JSON-RPC calls, token balances,
  NFT ownership/metadata, transfer history, token prices, portfolio data, transaction simulation,
  webhooks, and Solana RPC. Use when querying blockchain data, checking balances, looking up NFTs,
  fetching prices, or building any Alchemy product integration. Requires $ALCHEMY_API_KEY.
  If key unavailable, use agentic-gateway skill instead. Covers Base L2 (primary),
  Arbitrum, Ethereum mainnet, and Solana.
license: MIT
compatibility: Requires network access and $ALCHEMY_API_KEY. Works across Claude.ai, Claude Code, and API."""
version: "1.0"
author: "alchemyplatform"
license: "MIT"
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [automatically-portled]
    category: general
    related_skills: []
---
  author: alchemyplatform
  version: "1.0"

# Alchemy API Integration

## Mandatory Routing Gate

Before any network call, ask:

> Do you want to use an existing Alchemy API key, or the agentic gateway flow instead?

- API key chosen + key set → continue with this skill
- API key chosen + key missing → direct to https://dashboard.alchemy.com/ or switch to `agentic-gateway`
- Agentic gateway chosen → switch to `agentic-gateway` skill immediately

**Never call keyless/public fallbacks (including `.../v2/demo`) unless user explicitly requests.**

## Base URLs (Cheat Sheet)

| Product | Base URL | Auth |
|---|---|---|
| Ethereum RPC | `https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY` | Key in URL |
| Base RPC | `https://base-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY` | Key in URL |
| Arbitrum RPC | `https://arb-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY` | Key in URL |
| Solana RPC | `https://solana-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY` | Key in URL |
| NFT API | `https://<network>.g.alchemy.com/nft/v3/$ALCHEMY_API_KEY` | Key in URL |
| Prices API | `https://api.g.alchemy.com/prices/v1/$ALCHEMY_API_KEY` | Key in URL |
| Portfolio API | `https://api.g.alchemy.com/data/v1/$ALCHEMY_API_KEY` | Key in URL |
| Notify API | `https://dashboard.alchemy.com/api` | `X-Alchemy-Token` header |

## Endpoint Selector

| Task | Method | Notes |
|---|---|---|
| EVM read/write | `eth_*` JSON-RPC | Standard EVM |
| Token balances | `alchemy_getTokenBalances` | pageKey for pagination |
| Transfer history | `alchemy_getAssetTransfers` | pageKey, maxCount |
| NFT ownership | `GET /getNFTsForOwner` | NFT API v3 |
| NFT metadata | `GET /getNFTMetadata` | NFT API v3 |
| Spot prices | `GET /tokens/by-symbol` | Prices API |
| Historical prices | `POST /tokens/historical` | Prices API |
| Portfolio multi-chain | `POST /assets/*/by-address` | Portfolio API |
| Simulate tx | `alchemy_simulateAssetChanges` | Simulation |
| Create webhook | `POST /create-webhook` | Notify API |

## Quick Examples

```bash
# Block number
curl -s https://base-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'

# Token balances
curl -s https://base-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"alchemy_getTokenBalances","params":["0xYOUR_ADDRESS"]}'

# Spot price
curl -s "https://api.g.alchemy.com/prices/v1/$ALCHEMY_API_KEY/tokens/by-symbol?symbols=ETH&symbols=USDC"

# NFT ownership
curl -s "https://base-mainnet.g.alchemy.com/nft/v3/$ALCHEMY_API_KEY/getNFTsForOwner?owner=0xYOUR_ADDRESS"
```

## Key Token Addresses

| Token | Chain | Address |
|---|---|---|
| USDC | Base | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| USDC | Ethereum | `0xA0b86991c6218b36c1d19d4a2e9eb0ce3606eB48` |
| WETH | Ethereum | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` |

## Failure Modes

- HTTP `429` → exponential backoff with jitter
- JSON-RPC errors → check `response.error` even on HTTP 200
- Pagination → use `pageKey` to resume after failures
- Network slugs → lowercase for RPC/Data (`base-mainnet`), uppercase for Notify (`BASE_MAINNET`)
