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

## Starter Prompt (use every session)
```
I want to [TASK] so that [SUCCESS CRITERIA].
First, explore my MADHATs-Cowork folder completely.
Then use AskUserQuestion to clarify before executing.
Apply the relevant skill from .claude/skills/ before starting.
```

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
│   ├── specs/                   ← Technical spec templates
│   └── outreach/                ← VC + partner email templates
├── OUTPUTS/                     ← All Claude-generated files land here
└── .claude/
    ├── skills/                  ← 75+ skill files (Anthropic + ECC + MADHATs)
    ├── commands/                ← Slash commands
    ├── hooks/                   ← Session automation
    ├── rules/                   ← Behavior rules
    └── instincts/               ← ECC learned patterns
```
