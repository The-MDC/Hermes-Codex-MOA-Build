# MADHATs Gambit — Claude Code Master Context

## Project Identity
**MADHATs Gambit** — entertainment prediction market platform combining satirical NFT card gaming with Web3 mechanics.
- Founder/CEO: Nick (MADdegen) | 3x founder, 14+ yrs startup experience, 1 exit
- Stage: Seed — $1.24M–$2.48M at $12M pre-money. Two nearer-term tranches run separately:
  infrastructure $15K–$20K and a milestone-based bridge $300K–$500K.
- GitHub Org: The-MDC (github.com/The-MDC) | 100+ repos

## Canonical Numbers — Never Change Without Explicit Approval
> Reconciled 2026-08-19 against the published data room per Boardy's consolidated brief.
> Full reconciliation, deltas and open conflicts:
> `MAD-MPP-2.23/docs/boardy/CANONICAL_NUMBERS_2026-08-19.md`

- Platform fee: **1.88%** globally — **never 1.888%**
- Fee split *of the 1.88%*: creator **40%** · community **28.8%** · MAD Shield recovery **28.8%**
- Creator share applies to **creator-made markets only** — not the general community share
- MAD Shield: opt-in **2–4%** premium · **28.8%** standard recovery → 40% shielded → 60% VIP (gated)
- $MADx total supply: **888,888,888** · seed token allocation **10%**
- Seed: **$1.24M–$2.48M** | Pre-money: **$12M** | SAFE or equity
- Y3 revenue headline: **$139.6M gross, base case** ($177.7M is bull case ONLY — never the headline)
- Entity: **New Mexico LLC** (filed) — NOT Wyoming
- **Live surfaces** (verified 2026-08-20):
  - Data room (canonical): `https://mad-mpp-2-23-madgambit.vercel.app/pitch/index.html` — built from
    `The-MDC/MAD-MPP-2.23` → `verify/public/pitch/`. **Currently behind Vercel SSO**, so a link
    handed to an investor lands on a login page until Deployment Protection is turned off.
  - Three-Minute Room: `.../pitch/3min.html` · OV deck: `.../pitch/ov-pitch-deck.html`
  - Investor deck the app links out to: `https://o-vdeck26.vercel.app` — public, no SSO, **stale**
    (see open conflicts). Referenced from `verify/lib/node-registry.ts` and `portal-tab.tsx`.
  - ~~`https://maddegen.github.io/MADHATs-Gambit-Presentation/`~~ — **dead**. The repo 404s under
    both `MADdegen/` and `The-MDC/`. Do not hand this URL to anyone.
- **Canonical repo**: `The-MDC/MAD-MPP-2.23`. The MAD Gambit main has always lived in
  `MAD-MPP-2.23`; the repo now sits in the MDC enterprise org. GitHub redirects the old
  `MADdegen/` path, but Vercel's Git integration did **not** survive the move — see open conflicts.

### ⚠️ Open conflicts — do not state these publicly until resolved
- **Staking tiers**: code has 6 tiers (100/500/2,500/10,000/50,000/100,000 at 12/18/28/42/58/68%);
  the data room has 4 (88/888/8,888/88,888 at 8.8/18.8/28.8/38.8%). Do not pitch staking yields.
- **A second fee model is deployed somewhere**: a "1.888% RATE" schedule splitting burn 0.888% /
  staking 0.500% / protect 0.500%, with **no creator share**. Locate and reconcile to 1.88%.
- **Y3 stream split 51/31/12/6** derives from the retired $154.5M model — re-run before use.
- **The live investor deck says Wyoming.** `o-vdeck26.vercel.app` states "Manager-Managed Wyoming
  LLC", "Wyoming Legal Guardrails", "Wyoming tax filing" and "Wyoming Registered, SEC Compliant LLC
  Architecture" — 7 occurrences, checked 2026-08-20. Canon is **New Mexico LLC (filed)**, and
  "SEC Compliant" / "SEC-exempt token issuance" also breach the no-claim-without-evidence rule.
  `verify/public/pitch/ov-pitch-deck.html` in this repo is already corrected; the deployed bundle
  is built from a different source. **Find that source and rebuild before the deck is shown again.**
- **Vercel is not deploying `MAD-MPP-2.23`.** Last production build 2026-08-19 14:00 UTC; four
  pushes since produced zero deployments. Merging to `main` does not reach the live site. Deploy
  with `cd verify && npx vercel --prod` until the Git integration is reconnected to the MDC org.
- **GitHub Actions is queue-blocked.** Repo-owned runs from 2026-08-18 and 2026-08-19 are still
  `queued`; Dependabot's GitHub-hosted runs complete in seconds. Signature of an exhausted Actions
  minutes / spending limit at the org level. No PR in this repo can show a green check until it clears.

### Never claim without evidence
"15,000 users" (it is a **waitlist**) · measured retention · "industry's first" · "regulatory-safe" ·
"no counterparty risk" · "100% DeFi secured" · MAD Shield as **insurance**.

## Tech Stack
- Frontend: React 18, TypeScript, Hono/HonoX, TailwindCSS
- Backend: Neon (Postgres) + Drizzle ORM, Vercel (Next.js API routes), Node.js
- Blockchain: Solidity, Foundry, OpenZeppelin, Hardhat
- Chains: **Arbitrum Nova (primary gameplay, 42170)** · Arbitrum One (liquidity, Shield vaults,
  $MADx, 42161) · Ethereum L1 (governance anchor) · Base L2 (Phase 3) · HyperEVM (AI-agent settlement)
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
