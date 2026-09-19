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

Runs Hermes with Kimi-K3 on your NVIDIA NIM account, and keeps subagents off that
metered endpoint by putting them on a different provider. Nothing runs on your laptop.

```bash
cp configs/hermes/config.yaml ~/.hermes/config.yaml   # back up yours first
touch ~/.hermes/.env && chmod 600 ~/.hermes/.env
printf 'NVIDIA_API_KEY=%s\n'     'nvapi-…'    >> ~/.hermes/.env   # required
printf 'HF_TOKEN=%s\n'           'hf_…'       >> ~/.hermes/.env   # subagent tier
printf 'OPENROUTER_API_KEY=%s\n' 'sk-or-v1-…' >> ~/.hermes/.env   # 429 fallback

scripts/nim-preflight.sh          # proves all three buckets before Hermes needs them
scripts/nim-preflight.sh --list   # every model your NVIDIA key can reach
```

Only the NVIDIA key is required. The other two each enable one tier, and the preflight
warns rather than fails when they are absent — NIM-only is a legitimate choice.

- `docs/models/running-the-stack.md` — install order, the two model choices, the two
  traps, and the NVIDIA AI Workbench path
- `docs/models/kimi-k3-quants.md` — why Kimi-K3 is an API model and not a local one
- `docs/models/local-floor.md` — the offline tier (Hermes-4-14B) and the research browser

The key is read from the environment. It never goes in `config.yaml`, and both the
preflight and CI fail if anything key-shaped is committed.

## Step 11: Codex delegate (optional)

Lets Hermes hand off bounded, git-repo-scoped coding tasks to the Codex CLI as a
subprocess — implement/fix/refactor loops, `codex review`, parallel worktree fan-out.
Nothing to port: the bundled `autonomous-ai-agents/codex` skill ships with Hermes.

```bash
npm install -g @openai/codex     # or: brew install --cask codex
codex login                      # browser OAuth against your ChatGPT plan
cp configs/codex/config.toml ~/.codex/config.toml   # back up yours first
```

Full design — why this is a delegate and never a 5th Hermes model provider, the two
credential paths that must not both be on, and the exact invocation pattern — is in
`docs/models/codex-handoff.md`. CI asserts the two configs stay consistent with each
other on this point.

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
│   ├── hermes/config.yaml       ← Hermes model routing (NIM + local)
│   └── codex/config.toml        ← Codex CLI defaults for delegated coding tasks
├── docs/models/                 ← quant survey, stack setup
├── scripts/                     ← doctor, canonical-numbers, NIM preflight
└── .claude/
    ├── skills/                  ← 75+ skill files (Anthropic + ECC + MADHATs)
    ├── commands/                ← Slash commands
    ├── hooks/                   ← Session automation
    ├── rules/                   ← Behavior rules
    └── instincts/               ← ECC learned patterns
```
