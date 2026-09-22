# hermes-skills

Skills available to this Hermes build. Two origins, and the difference decides
whether editing one is safe.

**Ported** — Claude / Cowork / Claude Code skills converted to Hermes format by
`scripts/port-skills-to-hermes.js`. **Do not hand-edit these**: the next run of the
script rewrites `SKILL.md` in place and your change is gone.

**Hand-written** — everything under `operations/`. These have no upstream to port
from, because they describe Hermes' *own* tools and this repo's *own* build, so the copy
here **is** the canonical source. The port script reads it and never rewrites it — a
regeneration of a file from itself is a slow way to lose it — and it writes only the
skills in its manifest, never deleting. Both properties are now asserted rather than
assumed. Edit these directly; there is nowhere else to edit them.

## Why `operations/` exists

The port deliberately excludes Claude-surface skills — `chrome-browser`,
`built-in-browser`, `docs` — because they describe tools Hermes does not have, and a
ported one would instruct the agent to call something that is not there. That
reasoning is right, but nothing replaced them, which left this build with 29 skills
and **none** that taught it to use `terminal`, `process` or `execute_code`: its actual
local capabilities. `operations/local-desktop` closes that. `operations/hermes-orchestration`
covers maintaining the routing build itself, which no upstream skill knows about.

## Install

On a machine with Hermes installed:

```bash
cp -r hermes-skills/* ~/.hermes/skills/
hermes skills list          # confirm they registered
```

## What is here

31 skills across 12 categories, each laid out as Hermes expects —
`<category>/<name>/SKILL.md` plus any supporting files copied verbatim.

| Category | Skills |
|---|---|
| blockchain | `agentic-gateway` · `alchemy-api` · `solidity-foundry` |
| software-development | `api-design` · `backend-patterns` · `frontend-design` · `mcp-builder` · `mcp-server-patterns` · `verification-loop` |
| security | `security-audit` · `security-review` |
| research | `deep-research` · `market-research` |
| finance | `investor-materials` · `investor-outreach` |
| creative | `algorithmic-art` · `brand-guidelines` · `canvas-design` |
| devops | `vercel-for-github` · `vercel-git-deploys` |
| productivity | `doc-coauthoring` · `internal-comms` · `learn` |
| media | `file-reading` · `pdf-reading` · `pptx` |
| autonomous-ai-agents | `skill-creator` |
| madhats | `mad-gambit-ai-agents` · `mad-gambit-context` |
| **operations** (hand-written) | `local-desktop` · `hermes-orchestration` |

## Kept up to date

A ported skill used to be stamped `version: 1.0.0` with nothing recording which upstream
revision it came from, so "is this current?" had no answer. `.port-lock.json` answers it:
per skill, the source root it resolved from, the SHA-256 of the upstream `SKILL.md` at
port time, the port date, and the surfaces it was written to.

```bash
node scripts/port-skills-to-hermes.js --check     # writes nothing
```

| Line | Meaning | What to do |
|---|---|---|
| `current` | upstream `SKILL.md` unchanged since the port | nothing |
| `DRIFTED` | upstream changed | re-run the port |
| `RESURFACED` | `capabilities.yaml` changed surfaces since the port | re-run the port |
| `absent` | source root not on this machine | nothing; normal off the porting box |
| `unlocked` | in the manifest, never ported here | re-run the port where the source exists |

**Drift never fails a build.** The sources live outside this repo — `security-audit`
needs a Cloudflare clone no CI runner has — so gating on drift would be a check that can
never pass. The first real run of this machinery found one: upstream had rewritten
`media/pptx`'s routing guidance, and the ported copy had been stale with nothing
reporting it.

Entries are **merged**, not replaced. A port run on a machine missing one source root
must not erase that skill's record, so an entry it could not re-resolve is carried over.

## Two surfaces, one source

`capabilities.yaml` decides which surfaces carry a skill; the port script obeys it.
Hermes resolves a skill by its **directory** name, Claude Code by the frontmatter
**`name`** in a flat `.claude/skills/<category>/<name>.md`. A skill declaring
`surfaces: [claude, hermes]` is written to both from one source — that is how
`operations/local-desktop` and `operations/hermes-orchestration`, written so the local
tier could take the handoff, stopped being invisible to the model instructing it.

The Claude copy is stamped `generated_by:`, and **only a stamped file is ever
overwritten**. 76 of the 78 pre-existing files under `.claude/skills/` are Claude-native
with no upstream in this repo; replacing one would destroy the only copy. The nine that
share a name with a ported skill are reported as `NOT OVERWRITTEN` on every run, which is
the expected steady state rather than an error. To hand one over to generation, delete it
— the next run writes it stamped and owns it after.

## Why these and not the other 25

Of the skills readable in a Claude Code environment, 53 are absent from Hermes'
199-skill catalog. Most should stay absent, and `EXCLUDE` in the porting script records
the reason for each. Three kinds do not belong:

- **Claude-surface skills** — `chrome-browser`, `built-in-browser`, `docs`,
  `web-artifacts-builder`, `theme-factory`, `product-self-knowledge`. They describe tools
  that exist only inside Claude's own apps. Ported to Hermes they would instruct the agent
  to call tools it does not have, which is worse than the skill simply being missing.
- **Harness-configuration skills** — `update-config`, `keybindings-help`,
  `session-start-hook`. They configure Claude Code itself.
- **Anthropic demo skills** — `grocery-shopping`, `meal-delivery`, `prescription-refill`
  and friends. Example content, not capability.

## Gaps this does and does not close

Closed: Hermes' `security` domain had reconnaissance and tooling (`web-pentest`,
`oss-forensics`, `sherlock`) but no systematic source-level code audit. `security-audit`
fills that. Hermes shipped `docx`, `pdf` and `xlsx` but not `pptx`. Hermes' `blockchain`
domain had only `evm`, `hyperliquid` and `solana`.

Still open: **benchmarking**. Nothing in Hermes' catalog covers performance benchmarking
methodology, and nothing in the readable Claude skill set does either, so there was
nothing to port. It needs writing from scratch.

Already covered by Hermes, so nothing was ported: code checking and debugging
(`ast-grep`, `systematic-debugging`, `node-inspect-debugger`, `python-debugpy`,
`requesting-code-review`, `simplify-code`, `test-driven-development`) and containers
(`docker-management`, `hermes-s6-container-supervision`).

## Weight

This tree is **8.2 MB**, and two skills are 6.9 MB of it:

| Skill | Size | What the bulk is |
|---|---|---|
| `creative/canvas-design` | 5.6 MB | 54 `.ttf` font files |
| `media/pptx` | 1.3 MB | 39 OOXML `.xsd` schemas |

Both sets of assets are genuinely required — `canvas-design` renders with those exact
fonts, and `pptx` validates against those exact schemas — so they are copied verbatim
rather than stubbed. But if you would rather not carry binaries in this repo, drop those
two entries from `INCLUDE` in `scripts/port-skills-to-hermes.js` and re-run; the
remaining 27 skills total about 1.3 MB of text.

## Attribution

Each skill's frontmatter carries its upstream author and licence, not this repo's.
`security-audit` is Cloudflare's, MIT-licensed, from
<https://github.com/cloudflare/security-audit-skill>. The rest are Anthropic's, under
their own terms. Only the porting note is ours.
