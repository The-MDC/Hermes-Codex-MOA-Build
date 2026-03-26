# MADHATs Gambit — Claude Code Master Context

## Project Identity
**MADHATs Gambit** — entertainment prediction market platform combining satirical NFT card gaming with Web3 mechanics.
- Founder/CEO: Nick (MADdegen) | 3x founder, 14+ yrs startup experience, 1 exit
- Stage: Seed — seeking $1–2M at $12M pre-money valuation
- GitHub Org: The-MDC (github.com/The-MDC) | 100+ repos

## Canonical Numbers — Never Change Without Explicit Approval
- Platform fee: **1.88%** globally
- Community profit share: **28.8%** (display as 28% in presentations)
- Creator market revenue share: **40%** (creators only — NOT general community share)
- Seed target: **$1–2M** | Pre-money: **$12M**
- Live deck: https://maddegen.github.io/MADHATs-Gambit-Presentation/

## Tech Stack
- Frontend: React 18, TypeScript, Hono/HonoX, TailwindCSS
- Backend: Supabase (Postgres + Edge Functions), Node.js
- Blockchain: Solidity, Foundry, OpenZeppelin, Hardhat
- Chains: Base L2 (primary), Arbitrum, HyperEVM
- Oracles: Chainlink VRF + Price Feeds, Pyth Network
- AA: Alchemy AA-SDK (ERC-4337), modular-account, light-account
- Prediction Markets: Polymarket CTF Exchange, UMA protocol, Gnosis conditional tokens
- AI/Agents: Claude Opus 4.6, MCP servers, GraphRAG, Instructor (structured outputs)

## Brand & Voice
- Bold, irreverent, technically credible — satire is our product
- Short sentences. No filler. Specific numbers over adjectives.
- Banned: "leverage," "synergy," "ecosystem play," "unlock value," "game-changing"

## Cowork Folder Protocol
Before every task:
1. Read ABOUT-ME/ completely — identity, voice, canonical numbers
2. If task relates to a project, read PROJECTS/{name}/ subfolder
3. If task has a matching template in TEMPLATES/, study structure (not content)
4. Use AskUserQuestion tool to gather context before executing
5. Write all outputs to OUTPUTS/ folder

## Skills Available
All skills are in `.claude/skills/` — organized by domain:
- marketing/ · sales/ · product/ · engineering/ · data/ · operations/ · legal/ · finance/
- productivity/ · cowork/ · ecc/ (everything-claude-code enhancements)

## Commands Available
All slash commands in `.claude/commands/`:
- /orchestrate · /quality-gate · /harness-audit · /learn · /evolve
- /skill-create · /model-route · /plan · /security · /checkpoint

## Global Behavior Rules
1. Always use Opus 4.6 + Extended Thinking for reasoning tasks
2. Read context files BEFORE generating — never assume
3. One deliverable per prompt — don't batch unrelated tasks
4. Create CLAUDE.md updates when patterns emerge from sessions
5. Output files to OUTPUTS/ — never modify ABOUT-ME/ or TEMPLATES/
6. Use AskUserQuestion when task needs clarification before execution
7. Apply security review skill before any smart contract changes
8. Apply verification-loop skill for all investor-facing documents

## Hooks Active (ECC)
- session-start.js — loads context, initializes memory
- session-end.js — saves session summary, extracts learnings
- pre-compact.js — preserves critical context before token compression
- before-submit-prompt.js — validates prompt quality
- after-mcp-execution.js — logs MCP tool results
- stop.js — final session checkpoint
