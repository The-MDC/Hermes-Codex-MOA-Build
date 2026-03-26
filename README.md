# MADHATs Claude Enhancement Stack
**The-MDC/MADHATs-Claude-Enhancement**

Complete Claude + Claude Code enhancement system for MADHATs Gambit. Combines:
- **Ruben Hassid's Cowork system** (how-to-ai.guide)
- **Anthropic official knowledge-work plugins** (55 skills across 11 domains)
- **Everything Claude Code (ECC) v1.9.0** (affaan-m/everything-claude-code, 50K+ stars)
- **MADHATs-specific skills** (investor pitch, smart contracts, MPP platform)

## Quick Start
```bash
git clone https://github.com/The-MDC/MADHATs-Claude-Enhancement.git MADHATs-Cowork
```
Then open Claude Desktop → Cowork tab → Work in a folder → select `MADHATs-Cowork/`

**Full setup guide:** [SETUP.md](./SETUP.md)

## What's Inside

### Skills (75 total)
| Domain | Count | Source |
|--------|-------|--------|
| Marketing | 7 | Anthropic official |
| Sales | 7 | Anthropic official |
| Product Management | 8 | Anthropic official |
| Engineering | 9 | Anthropic official |
| Data & Analytics | 7 | Anthropic official |
| Operations | 7 | Anthropic official |
| Legal | 4 | Anthropic official |
| Finance | 2 | Anthropic official |
| Productivity | 3 | Anthropic official |
| Cowork Management | 2 | Anthropic official |
| ECC Agent Skills | 17 | everything-claude-code |
| MADHATs Specific | 3 | Custom (investor, contracts, MPP) |

### Commands (13 total)
`/orchestrate` `/quality-gate` `/harness-audit` `/learn` `/evolve` `/skill-create`
`/model-route` `/plan` `/security` `/checkpoint` `/vc-pitch` `/build-contract` `/market-brief`

### Hooks (7 active)
`session-start.js` `session-end.js` `pre-compact.js` `before-submit-prompt.js`
`after-mcp-execution.js` `stop.js` + `hooks.json` config

### Rules & Instincts
- `common-hooks.md` — hook behavior rules
- `common-security.md` — security protocols
- `typescript-hooks.md` — TS-specific rules
- `ecc-instincts.yaml` — learned patterns from ECC

### Context Files (Ruben Hassid System)
- `ABOUT-ME/about-me.md` — identity + canonical numbers
- `ABOUT-ME/anti-ai-writing-style.md` — voice rules
- `ABOUT-ME/voice-profile.md` — how Claude responds to Nick
- `ABOUT-ME/global-instructions.md` — Cowork behavior protocol

## Canonical Numbers (Never Change)
| Metric | Value |
|--------|-------|
| Platform fee | 1.88% |
| Community profit share | 28.8% (display as 28%) |
| Creator revenue share | 40% (creators only) |
| Seed raise | $1–2M |
| Pre-money valuation | $12M |

## Live Deck
https://maddegen.github.io/MADHATs-Gambit-Presentation/

## Sources
- Ruben Hassid: ruben.substack.com | @rubenhassid | how-to-ai.guide
- Anthropic plugins: github.com/anthropics/knowledge-work-plugins
- ECC: github.com/affaan-m/everything-claude-code (v1.9.0, Mar 2026)
- Org: github.com/The-MDC
