---
description: How MADHATs uses GitHub Agentic Workflows (gh-aw) to run Claude Code as PR/issue automation instead of only interactively
---

# GitHub Agentic Workflows (gh-aw)

## What this is

[`github/gh-aw`](https://github.com/github/gh-aw) is GitHub's own project
(technical preview) for defining repo automation in Markdown + YAML
frontmatter that compiles to a sandboxed GitHub Actions workflow. The
supported AI engines include GitHub Copilot, **Claude Code**, OpenAI
Codex, Google Gemini, and Pi. In practice: you write a `.md` prompt, `gh
aw compile` turns it into a `.lock.yml` Actions workflow, and Claude Code
runs that prompt against real PR/issue context with read-only permissions
by default — all writes (comments, issues, PRs) go through "safe-outputs",
validated and applied in a separate, narrowly-scoped job.

This lets the checks we already have as interactive slash commands
(`/security`, `/quality-gate`, `/harness-audit`) also run automatically on
PR/issue events, across repos, without a human invoking Claude each time.

## What's shipped so far

| Repo | Workflow | Trigger | Maps to |
|---|---|---|---|
| `MADHATs-Claude-Enhancement` (this repo) | `agentic-harness-audit.md` | PR touching `.claude/**`, weekly schedule, manual dispatch | `/harness-audit` |
| `MAD-MPP-2.23` | `agentic-security-review.md` | PR touching `app/**`, `backend-node/**`, `contracts/**` | `/security` |
| `MAD-MPP-2.23` | `agentic-quality-review.md` | PR touching `app/**`, `backend-node/**` | `/quality-gate` (qualitative half — lint/type-check stay in `ci.yml`) |

Each repo also has `agentic-compile.yml` — a plain (non-gh-aw) Actions
workflow that fails a PR if a `.md` workflow source was edited without
re-running `gh aw compile`, so the checked-in `.lock.yml` never silently
drifts from its source.

All three workflows are **advisory**: they post a PR comment, they don't
block merge. `MAD-MPP-2.23`'s deterministic gates (Slither, TruffleHog,
Dependency Review, type-check, lint, build — see its `SECURITY.md`) remain
the actual blocking gates. Treat these as a second, qualitative reader
sitting alongside them, not a replacement.

## One-time activation (per repo)

1. `gh extension install github/gh-aw` (once, on whatever machine/CI
   compiles workflows — this is a human/CI step, not something Claude
   Code does for itself; Claude Code in this org talks to GitHub through
   the GitHub MCP server, not the `gh` CLI).
2. `gh aw compile` from the repo root — generates/refreshes the
   `*.lock.yml` next to each `*.md` in `.github/workflows/`. **Do this
   before enabling any workflow shipped here** — the `.md` sources were
   hand-authored against gh-aw's documented schema but never run through
   the real compiler, since this session had no `gh` CLI access. Compile
   errors, if any, are schema-drift issues (technical preview software) —
   fix the flagged key and recompile; nothing executes until this step
   succeeds.
3. Add an `ANTHROPIC_API_KEY` repository secret (Settings → Secrets and
   variables → Actions). This is a credential — set it yourself rather
   than asking Claude Code to do it. `CLAUDE_CODE_OAUTH_TOKEN` is
   explicitly *not* used by gh-aw's Claude engine even if already set as a
   secret for something else.
4. Commit both the `.md` and the generated `.lock.yml`. Open a PR that
   touches the workflow's trigger paths to confirm it actually fires.

## Further enhancements worth doing next (not yet built)

- **On-demand slash-command triggers** (`/security-review` as a PR
  comment, not just automatic-on-PR). gh-aw supports a `slash_command`
  trigger, but it cannot be combined with a plain `pull_request` trigger
  in the same workflow — it would need its own workflow file. Worth
  adding once the automatic versions above have run cleanly for a while.
- **[`githubnext/agentics`](https://github.com/githubnext/agentics)** —
  GitHub's example workflow pack (`gh aw add-wizard
  githubnext/agentics/<name>`), e.g. a daily repo-status digest or issue
  triage bot. Good source of recipes beyond the three shipped here.
- **`scripts/harness-audit.js`** doesn't exist yet — `agentic-harness-audit.md`
  is written to report that honestly (see its NOTE) rather than invent a
  score. Someone needs to write the deterministic scorer described in
  `.claude/commands/harness-audit.md`'s rubric before that workflow does
  anything beyond flagging the gap.
- **Extending to more of the org's 100+ repos**: copy a `.md` workflow +
  `agentic-compile.yml` pattern into any repo that has its own
  `.claude/commands/` equivalents to wire up.

## Not part of this (your terminal, not Claude Code's)

These are `gh` CLI extensions worth installing locally if useful, but
they're human-terminal tools — Claude Code in this org uses the GitHub
MCP server, not the `gh` CLI, so there's nothing for Claude Code to
"install":

- **`gh-dash`** — TUI dashboard for PRs/issues across repos.
- **`gh-standup`** / **`gh-brag`** — AI-generated standup/impact reports
  from GitHub activity; could feed `internal-comms` or investor-update
  drafts if you paste the output in.
- **`gh-extension-atlas`** — curated, maintained list for vetting other
  extensions before installing them.

## Sources

- https://github.com/github/gh-aw
- https://github.github.io/gh-aw/reference/frontmatter/
- https://github.github.io/gh-aw/reference/engines/
- https://github.github.io/gh-aw/reference/safe-outputs/
- https://github.github.io/gh-aw/reference/command-triggers/
- https://github.github.io/gh-aw/reference/compilation-process/

Note on those sources: they could not be fetched directly from this
session (outbound web access to github.com and most other domains is
blocked in this sandboxed environment; only web search was available), so
the frontmatter above is reconstructed from search-result snippets of
those pages rather than the full pages. Re-verify against the live docs
— or just let `gh aw compile` be the check — before treating any of this
as gospel.
