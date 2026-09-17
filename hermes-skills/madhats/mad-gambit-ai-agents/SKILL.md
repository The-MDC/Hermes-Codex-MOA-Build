---
name: mad-gambit-ai-agents
description: "> AI Agent architecture, tier system, and implementation scope for MAD Gambit. ALWAYS activate when discussing smart agents, LLM integration, AI oracles, autonomous trading agents, AI-assisted market resolution, sentiment analysis, agent tiers, or any AI/ML feature for the MAD Gambit platform. Triggers on: \"smart agents\", \"AI agents\", \"LLM\", \"agent tier\", \"AI oracle\", \"sentiment\", \"market resolution AI\", \"Claude agent\", \"autonomous\", \"GraphRAG\", \"agent architecture\", \"AI features\", \"intelligence layer\", \"AI for MAD Gambit\", \"prediction AI\", \"agent framework\", \"MCP agent\", or any AI/ML discussion related to the platform."
version: 1.0.0
author: "Anthropic — ported for Hermes Agent by MADHATs"
license: "Anthropic skill licence; see upstream"
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [MAD-Gambit, AI-Agents, Oracles, Architecture]
    category: madhats
    related_skills: [mad-gambit-context]
---

# MAD Gambit — AI Agent Architecture & Tier System

## STATUS: SCOPE DOCUMENT (Ready to Build)
This document defines the full architecture. Implementation begins when explicitly requested.

---

## Part 1: Agent Tier System — "MAD Minds"

### Tier Overview

| Tier | Name | Access | Capability | Tech |
|---|---|---|---|---|
| 0 | **Lurker** | Free, no wallet | Read-only market sentiment, basic search | Public API, cached results |
| 1 | **Scout** | Free + wallet connected | Market alerts, basic predictions, portfolio tracking | Claude Haiku 4.5 via API, lightweight inference |
| 2 | **Analyst** | $MADx staker (min 1,000) | Deep research, multi-source analysis, creator tools | Claude Sonnet 4.6, GraphRAG, Instructor |
| 3 | **Oracle** | $MADx staker (min 10,000) OR NFT card holder (Rare+) | Autonomous trading agent, custom strategies, AI market creation | Claude Opus 4.6, full MCP stack, agent memory |
| 4 | **MAD Mind** | Founder's Golden Ticket (2,488 ERC-1155) | Full platform AI access, priority inference, custom model fine-tuning, governance proposals via AI | Dedicated inference, priority queue, custom system prompts |

### Tier Unlock Mechanics

```
Wallet connect → Tier 0 (default)
$MADx stake ≥ 1,000 → Tier 1 auto-unlock
$MADx stake ≥ 5,000 → Tier 2 auto-unlock  
$MADx stake ≥ 10,000 OR Rare+ NFT card → Tier 3 auto-unlock
Founder's Golden Ticket ERC-1155 held → Tier 4 auto-unlock
```

Tier checks happen on-chain via `read_contract` — no centralized auth needed.

---

## Part 2: Agent Capabilities by Tier

### Tier 0 — Lurker (Free)
- View market sentiment dashboards (cached, updated hourly)
- Basic search across active markets
- Read public prediction analytics
- No personalization, no history

### Tier 1 — Scout
- **Market Alerts**: AI-generated notifications when market odds shift >5% in 1hr
- **Portfolio Tracker**: On-chain position monitoring with P&L
- **Basic Predictions**: Single-source analysis (news headline → probability estimate)
- **Market Explainer**: "What is this market about?" plain-language summaries
- Rate limit: 50 queries/day

### Tier 2 — Analyst
- **Deep Research Agent**: Multi-source synthesis (news, on-chain data, social, oracle feeds)
- **Creator Assistant**: AI helps draft market descriptions, set parameters, suggest oracle configs
- **Sentiment Analysis**: Real-time social sentiment scoring per market (X, Reddit, Discord)
- **Historical Analysis**: "How did similar markets resolve?" pattern matching
- **Card Strategy Advisor**: Optimal card play recommendations based on market positions
- **GraphRAG Integration**: Knowledge graph over all historical markets, resolutions, and creator performance
- Rate limit: 500 queries/day

### Tier 3 — Oracle
- **Autonomous Trading Agent**: Define strategy → agent executes (with configurable guardrails)
  - Strategy types: momentum, contrarian, sentiment-following, mean-reversion
  - Max position size configurable per-market
  - Stop-loss and take-profit automation
  - Portfolio rebalancing on schedule
- **AI Market Creator**: Natural language → fully configured market with oracle selection, fee structure, resolution criteria
- **Multi-Agent Debate**: 3 AI agents argue for/against a market outcome, synthesize final probability
- **Custom MCP Tools**: User can define custom data sources (private APIs, custom oracles) via MCP server patterns
- **Agent Memory**: Persistent memory across sessions (via mem0 or Supabase vector store)
- Rate limit: 2,000 queries/day

### Tier 4 — MAD Mind (Founder's Golden Ticket)
- Everything in Tier 3 plus:
- **Priority Inference Queue**: Guaranteed <2s response time during high load
- **Custom System Prompts**: Personalized AI personality and analysis style
- **Governance Proposals via AI**: Draft, simulate impact, and submit $MADx governance proposals
- **Cross-Market Arbitrage Scanner**: Identify mispricing across MAD Gambit + external platforms
- **Fine-Tuned Models**: Access to MAD Gambit-specific fine-tuned models trained on platform data
- **White-Glove Support**: Direct escalation channel
- Rate limit: Unlimited

---

## Part 3: Technical Architecture

### Stack

```
┌─────────────────────────────────────────────┐
│           Frontend (React 18 + TypeScript)    │
│           User tier UI, agent chat interface  │
├─────────────────────────────────────────────┤
│           API Gateway (Hono/HonoX)            │
│           Rate limiting, tier auth, routing   │
├─────────────────────────────────────────────┤
│           Agent Orchestrator                  │
│           ┌──────────┐  ┌──────────┐         │
│           │ Claude    │  │ GraphRAG │         │
│           │ API       │  │ Engine   │         │
│           └──────────┘  └──────────┘         │
│           ┌──────────┐  ┌──────────┐         │
│           │ MCP       │  │ Instructor│        │
│           │ Servers   │  │ (struct) │         │
│           └──────────┘  └──────────┘         │
├─────────────────────────────────────────────┤
│           Data Layer                          │
│           Supabase (Postgres + pgvector)      │
│           mem0 (agent memory)                 │
│           Chainlink/Pyth (oracle feeds)       │
├─────────────────────────────────────────────┤
│           On-Chain (Arbitrum One/Nova)         │
│           Tier verification via $MADx stake   │
│           Agent execution via ERC-4337 AA     │
│           Market creation via smart contract  │
└─────────────────────────────────────────────┘
```

### Model Selection by Tier

| Tier | Model | Max Tokens | System Prompt |
|---|---|---|---|
| 0 | None (cached) | — | — |
| 1 | Claude Haiku 4.5 | 1,000 | Standard market analyst |
| 2 | Claude Sonnet 4.6 | 4,000 | Deep researcher + creator assistant |
| 3 | Claude Opus 4.6 | 8,000 | Autonomous agent + strategy executor |
| 4 | Claude Opus 4.6 (priority) | 16,000 | Custom user-defined personality |

### MCP Server Architecture

Each agent tier unlocks additional MCP servers:

```
Tier 1: [blockscout-mcp, price-feeds]
Tier 2: [+ dune-analytics, messari-api, social-sentiment]
Tier 3: [+ kaito-api, trading-execution, market-creation, custom-user-mcp]
Tier 4: [+ cross-platform-arb, governance-engine, fine-tune-api]
```

### Agent Memory Design

```sql
-- Supabase schema for agent memory
CREATE TABLE agent_memories (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_address TEXT NOT NULL,
  agent_tier INT NOT NULL,
  memory_type TEXT CHECK (memory_type IN ('strategy', 'preference', 'analysis', 'conversation')),
  content JSONB NOT NULL,
  embedding VECTOR(1536),  -- pgvector for semantic search
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,  -- NULL = permanent
  market_id TEXT,           -- optional market association
  CONSTRAINT fk_tier CHECK (agent_tier BETWEEN 1 AND 4)
);

-- RLS: users can only see their own memories
ALTER TABLE agent_memories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users_own_memories" ON agent_memories
  FOR ALL USING (user_address = current_setting('app.user_address'));
```

### Autonomous Agent Execution (Tier 3+)

```typescript
// Agent strategy definition (user-configurable)
interface AgentStrategy {
  name: string;
  markets: MarketFilter;      // which markets to watch
  entryConditions: Condition[];  // when to enter
  exitConditions: Condition[];   // when to exit
  maxPositionSize: bigint;     // max per market (in USDC)
  maxTotalExposure: bigint;    // max across all markets
  stopLoss: number;            // % loss trigger
  takeProfit: number;          // % gain trigger
  rebalanceInterval: number;   // seconds between rebalance checks
  guardrails: {
    requireConfirmation: boolean;  // human-in-the-loop for large trades
    confirmationThreshold: bigint; // above this amount, require confirm
    maxDailyTrades: number;
    blockedMarketTypes: string[];  // e.g., ["political"] if user prefers
  };
}
```

### AI Oracle Resolution (Subjective Markets)

For markets that can't be resolved by Chainlink/Pyth (subjective outcomes):

```
Step 1: 3 independent Claude Opus 4.6 agents analyze evidence
Step 2: Each produces structured JSON verdict via Instructor
Step 3: Consensus engine: 2/3 agreement = provisional resolution
Step 4: 24hr challenge window (any Tier 2+ user can dispute with evidence)
Step 5: If disputed: escalated to 5-agent panel + human arbitrator
Step 6: Final resolution committed on-chain
```

---

## Part 4: Revenue & Cost Model

### AI Cost Estimation (per user/month)

| Tier | Est. Monthly AI Cost | Revenue Source | Margin |
|---|---|---|---|
| 0 | $0 | Ads/awareness | — |
| 1 | $0.50-$2 | Free (acquisition) | Negative (subsidy) |
| 2 | $5-$15 | 1,000 $MADx stake APY offset | Break-even |
| 3 | $20-$60 | 10,000 $MADx stake + trading fees | Positive |
| 4 | $50-$150 | Golden Ticket premium + trading fees | High positive |

### Key Insight
Tier 3-4 users generate the most trading volume (and thus platform fees at 1.88%), which funds the AI infrastructure. The agent system is a **retention and volume flywheel** — better agents → more trades → more fees → fund better agents.

---

## Part 5: Competitive Moat Analysis

| Feature | Polymarket | Kalshi | Azuro | MAD Gambit |
|---|---|---|---|---|
| AI Agents | `agents` repo (basic) | Grok-4 bot (3rd party) | None | ✅ Tiered, built-in |
| Autonomous Trading | 3rd party bots | 3rd party bots | None | ✅ Native, guardrailed |
| AI Market Creation | None | None | None | ✅ NL → market |
| Sentiment Analysis | None | None | None | ✅ Real-time social |
| AI Oracle Resolution | UMA (human-based) | Staff-resolved | Data provider | ✅ Multi-agent consensus |
| Agent Memory | None | None | None | ✅ Persistent, per-user |
| NFT-Gated AI | None | None | None | ✅ Card rarity → tier |

**No competitor has a built-in, tiered AI agent system.** This is differentiator #3 alongside the card game (entertainment retention) and creator economics (40% share + TeaBag insurance).

---

## Part 6: Implementation Phases

### Phase 1 — Foundation (Weeks 1-4)
- Tier verification smart contract (read $MADx stake + NFT holdings)
- Claude API integration with Hono middleware (rate limiting per tier)
- Basic Tier 0-1 features (market search, alerts, portfolio tracking)
- Supabase agent_memories table + pgvector setup

### Phase 2 — Intelligence (Weeks 5-8)
- GraphRAG engine over historical market data
- Instructor-based structured outputs for market analysis
- Tier 2 features (deep research, creator assistant, sentiment)
- MCP server integrations (Blockscout, price feeds)

### Phase 3 — Autonomy (Weeks 9-14)
- Autonomous trading agent framework (Tier 3)
- AI market creation pipeline (NL → smart contract params)
- Multi-agent debate system for subjective resolution
- Agent memory persistence with semantic search

### Phase 4 — Mastery (Weeks 15-20)
- Tier 4 features (priority queue, custom prompts, governance)
- Cross-platform arbitrage scanner
- Fine-tuned models on MAD Gambit historical data
- Full MCP ecosystem (Kaito, Dune, Messari integrations)

---

## Part 7: Key Open Questions

1. **Agent liability**: Who is responsible when an autonomous agent makes a bad trade? → Guardrails + explicit user consent + max loss limits
2. **Oracle gaming**: Can someone manipulate the multi-agent oracle? → Challenge window + escalation + economic disincentive (staked $MADx slashing)
3. **Cost scaling**: At 10K DAU with agents, monthly Claude API cost could hit $50-100K → Haiku for low tiers, Opus only for high tiers, aggressive caching
4. **Regulatory**: Are AI-executed trades considered algorithmic trading? → Legal review needed pre-launch
5. **Model freshness**: How often to retrain fine-tuned models? → Weekly on new market resolution data

---

## Forked Repos for AI Agent Implementation

| Repo | Source | Use |
|---|---|---|
| `graphrag` | Microsoft | Knowledge graph over market history |
| `instructor` | jxnl | Structured LLM outputs for market analysis |
| `mcp-agent` | lastmile-ai | MCP workflow orchestration |
| `mem0` | mem0ai | Persistent agent memory |
| `agents` | Polymarket | Reference: AI trading agent architecture |
| `plugin-messari-ai-toolkit` | Messari | AI agent toolkit for crypto data |
| `skills` | Dune Analytics | Dune AI skills/agent patterns |
| `hyperliquid-python-sdk` | Hyperliquid | HyperEVM integration for cross-platform |
| `pmxt` | pmxt-dev | Unified prediction market API (multi-platform arb) |

---

## Usage Notes

- This is a SCOPE DOCUMENT. Do not begin implementation until explicitly requested.
- When implementation begins, activate `mad-gambit-context`, `backend-patterns`, `api-design`, and `security-review` skills alongside this one.
- All agent actions involving real funds MUST have human-in-the-loop confirmation above configurable thresholds.
- Agent tier verification happens on-chain — no centralized user database for tier status.
