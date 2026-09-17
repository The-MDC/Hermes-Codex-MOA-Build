# MADHATs Gambit — Cowork Setup Guide
## Based on Ruben Hassid's system + ECC enhancements

## Step 1: Install Claude Desktop
- Download: https://claude.ai/download
- Plan required: Pro ($20/mo) or Max ($100/mo)
- Model: Always select **Opus 4.6 + Extended Thinking**

## Step 2: Clone This Repo as Your Cowork Folder
```bash
git clone https://github.com/The-MDC/MADHATs-Claude-Enhancement.git MADHATs-Cowork
```

## Step 3: Open Cowork in Claude Desktop
1. Open Claude Desktop
2. Click **Cowork** tab (top center, between Chat and Code)
3. Click **"Work in a folder"**
4. Select your `MADHATs-Cowork/` folder
5. Claude now reads every file before responding

## Step 4: Configure Global Instructions
1. Go to **Settings → Cowork → Edit Global Instructions**
2. Paste the contents of `ABOUT-ME/global-instructions.md`
3. Save

## Step 5: Install Connectors (Free)
Go to **Settings → Connectors → Browse** and add:
- GitHub (connect to The-MDC org)
- Google Drive (for shared docs)
- Notion (for project management)
- Slack (for team communication)
- Neon (for database access)

## Step 6: Install Plugins
Go to **claude.com/plugins** and install:
- **Marketing** — brand review, campaign planning, content creation
- **Sales** — account research, outreach drafting, pipeline review
- **Product Management** — specs, roadmap, sprint planning
- **Engineering** — architecture, code review, system design
- **Operations** — process docs, risk assessment, runbooks

Or install via CLI:
```bash
claude plugin marketplace add anthropics/knowledge-work-plugins
claude plugin install marketing@knowledge-work-plugins
claude plugin install sales@knowledge-work-plugins
claude plugin install product-management@knowledge-work-plugins
```

## Step 7: Install ECC (Everything Claude Code)
```bash
npx ecc-universal install
```
This activates all hooks, instincts, and commands from `.claude/` folder.

## Step 8: Set Up Claude Code
1. Open Claude Desktop → Click **Code** tab
2. Select your `MADHATs-Cowork/` folder
3. Select **Opus 4.6** + **Auto accept edits**
4. Connect GitHub in Settings → Connectors
5. First prompt: "Read CLAUDE.md and all files in ABOUT-ME/. Summarize what you know about this project."

## Step 9: Activate GitHub Agentic Workflows (gh-aw)
Runs `/security`, `/quality-gate`, and `/harness-audit` automatically on
PR/issue events via GitHub Actions, instead of only interactively. Full
detail in `.claude/skills/ecc/gh-aw-agentic-workflows.md` — short version:

1. `gh extension install github/gh-aw` (one time, needs the `gh` CLI —
   this is a step you or CI runs, not Claude Code).
2. `gh aw compile` from the repo root to generate/refresh each
   `.github/workflows/*.lock.yml` from its `.md` source. Do this before
   enabling anything — the shipped `.md` sources haven't been run through
   the real compiler yet.
3. Add an `ANTHROPIC_API_KEY` repo secret (Settings → Secrets and
   variables → Actions) — required for `engine: claude`.
4. Commit the compiled `.lock.yml` files, then open a PR touching the
   relevant paths to confirm the workflow fires.

These checks are advisory (PR comments), not blocking gates — they sit
alongside each repo's existing deterministic CI, not in place of it.

## Starter Prompt (use every session)
```
I want to [TASK] so that [SUCCESS CRITERIA].
First, explore my MADHATs-Cowork folder completely.
Then use AskUserQuestion to clarify before executing.
Apply the relevant skill from .claude/skills/ before starting.
```

## Step 10: Local and NVIDIA inference (optional)

Runs Hermes with Kimi-K3 on your NVIDIA NIM account and TripleTrouble-V3 on your own
machine, with subagents kept off the metered endpoint.

```bash
cp configs/hermes/config.yaml ~/.hermes/config.yaml   # back up yours first
printf 'NVIDIA_API_KEY=%s\n' 'nvapi-…' >> ~/.hermes/.env && chmod 600 ~/.hermes/.env
scripts/nim-preflight.sh          # proves the route before Hermes depends on it
scripts/nim-preflight.sh --list   # every model your key can reach
```

- `docs/models/running-the-stack.md` — install order, quant choice, the two traps,
  and the NVIDIA AI Workbench path
- `docs/models/kimi-k3-quants.md` — why Kimi-K3 is an API model and not a local one

The key is read from the environment. It never goes in `config.yaml`, and both the
preflight and CI fail if anything key-shaped is committed.

## Folder Reference
```
MADHATs-Cowork/
├── CLAUDE.md                    ← Claude Code reads this automatically
├── ABOUT-ME/
│   ├── about-me.md              ← Identity + canonical numbers
│   ├── anti-ai-writing-style.md ← Voice rules
│   ├── voice-profile.md         ← How Claude should respond
│   └── global-instructions.md  ← Cowork behavior rules
├── PROJECTS/
│   ├── platform/                ← MPP architecture work
│   ├── investors/               ← Pitch decks, VC outreach
│   ├── marketing/               ← Website, content, campaigns
│   ├── smart-contracts/         ← Solidity, Foundry, deployments
│   └── tokenomics/              ← $MADx design, modeling
├── TEMPLATES/
│   ├── pitch/                   ← Deck + hotsheet templates
│   ├── content/                 ← Blog, social, newsletter
│   └── outreach/                ← VC + partner email templates
├── OUTPUTS/                     ← All Claude-generated files land here
├── configs/
│   └── hermes/config.yaml       ← Hermes model routing (NIM + local)
├── docs/models/                 ← quant survey, stack setup
├── scripts/                     ← doctor, canonical-numbers, NIM preflight
└── .claude/
    ├── skills/                  ← 75+ skill files (Anthropic + ECC + MADHATs)
    ├── commands/                ← Slash commands
    ├── hooks/                   ← Session automation
    ├── rules/                   ← Behavior rules
    └── instincts/               ← ECC learned patterns
```
