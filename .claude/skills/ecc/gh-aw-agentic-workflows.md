---
name: gh-aw-agentic-workflows
description: How to use GitHub Agentic Workflows (gh-aw) to run Claude Code as PR/issue automation instead of only interactively
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
| this repo | `agentic-harness-audit.md` | PR touching `.claude/**`, weekly schedule, manual dispatch | `/harness-audit` |
| `MAD-MPP-2.23` | `agentic-security-review.md` | PR touching `app/**`, `backend-node/**`, `contracts/**` | `/security` |
| `MAD-MPP-2.23` | `agentic-quality-review.md` | PR touching `app/**`, `backend-node/**` | `/quality-gate` (qualitative half — lint/type-check stay in `ci.yml`) |

Each repo also has `agentic-compile.yml`, a plain (non-gh-aw) Actions
workflow that compiles the `.md` sources and fails the PR if the compiled
output doesn't match what's committed. It does **not** auto-commit — see
"The GITHUB_TOKEN wall" below — it uploads the compiled `.lock.yml` files
as a downloadable build artifact instead.

All three workflows are **advisory**: they post a PR comment, they don't
block merge. `MAD-MPP-2.23`'s deterministic gates (Slither, TruffleHog,
Dependency Review, type-check, lint, build — see its `SECURITY.md`) remain
the actual blocking gates. Treat these as a second, qualitative reader
sitting alongside them, not a replacement.

## Status as of 2026-08-14

`compile-check` is **green on both open PRs** (`MAD-MPP-2.23` #83, this
repo's #2) — `gh aw compile` v0.37.18 runs clean, 0 errors, against every
`.md` file shipped so far. What's still open:

- **The `.lock.yml` files are not committed yet.** Compilation happens in
  CI (the sandboxed session that authored and last touched these files has
  no `gh` CLI, and separately no network path to anything outside GitHub's
  git-over-HTTPS protocol — not api.github.com, not Azure Blob Storage,
  where Actions artifacts are actually hosted, confirmed by testing both
  directly). The compiled output exists as a downloadable artifact
  ("compiled-workflows") on the latest `agentic-compile.yml` run on each
  branch — download it from the Actions run page and `git add` +
  `git commit` + `git push` the extracted `.lock.yml` files normally. A
  regular human push (or a live Claude Code session with real push access,
  as opposed to a CI run's GITHUB_TOKEN) has no trouble writing to
  `.github/workflows/` — only the automated token inside the Action run
  itself is restricted. That last step just hasn't happened yet.
- **`ANTHROPIC_API_KEY`** still needs to be added as a repo secret on both
  repos before the workflows can actually execute against a real PR.

## Confirmed schema fix (the actual bug, from a real compile run)

The original `.md` sources across all three workflows had one concrete
error, caught only once a real `gh aw compile` finally ran against them:

```yaml
tools:
  github:
    toolsets: [pull_requests, code_search]   # WRONG — code_search isn't a valid value
```

The compiler's own error names the full valid enum: `all`, `default`,
`action-friendly`, `context`, `repos`, `issues`, `pull_requests`,
`actions`, `code_security`, `dependabot`, `discussions`, `experiments`,
`gists`, `labels`, `notifications`, `orgs`, `projects`, `search`,
`secret_protection`, `security_advisories`, `stargazers`, `users`. The
correct value for "let the agent search code/PRs in this repo" is
**`search`**, not `code_search` (easy to guess wrong — `code_search` reads
as the obvious name and isn't one of the valid options). Fixed everywhere
it appeared. If a future compile run finds a different schema error
elsewhere in this file family, the fix method is the same: read the
compiler's own error message, don't guess from docs — it names the exact
bad value and the full valid set every time.

## The GITHUB_TOKEN wall (why auto-commit-from-CI doesn't work by default)

A first attempt made `agentic-compile.yml` auto-commit the compiled
`.lock.yml` back onto the PR branch. It compiled fine, committed fine
locally on the runner, then the push failed:

```
! [remote rejected] HEAD -> ... (refusing to allow a GitHub App to
  create or update workflow `.github/workflows/agentic-quality-review.lock.yml`
  without `workflows` permission)
```

This is GitHub deliberately refusing to let a workflow run's own
auto-generated `GITHUB_TOKEN` create or modify **anything under
`.github/workflows/`**, no matter what `permissions:` the workflow
declares — a supply-chain control (a workflow run can't use itself to
silently rewrite what workflows are allowed to do), not a misconfiguration.
It is not fixable via YAML.

The real fix, if fully hands-off auto-commit is wanted: add a repository
secret holding a **Personal Access Token with `workflow` scope** (classic
PAT, or fine-grained with "Workflows: write"), and use that secret instead
of `${{ github.token }}` for the push step specifically. That requires a
human to generate the PAT — not something to do without the account owner.
Until that exists, `agentic-compile.yml` stays a check-plus-artifact
design: it tells you the output is stale and hands you the exact bytes,
rather than pretending to fix it and failing silently.

## One-time activation (per repo)

1. `gh extension install github/gh-aw` (once, on whatever machine actually
   runs `gh aw compile` by hand — CI already runs it automatically via
   `agentic-compile.yml`; this step is only needed for compiling locally).
2. Either download the "compiled-workflows" artifact from the latest
   `agentic-compile.yml` run and commit the extracted `.lock.yml` files,
   or run `gh aw compile` locally yourself and commit the result — same
   output either way.
3. Add an `ANTHROPIC_API_KEY` repository secret (Settings → Secrets and
   variables → Actions). This is a credential — set it yourself rather
   than asking Claude Code to do it. `CLAUDE_CODE_OAUTH_TOKEN` is
   explicitly *not* used by gh-aw's Claude engine even if already set as a
   secret for something else.
4. Open a PR that touches the workflow's trigger paths to confirm it
   actually fires.

## Further enhancements worth doing next (not yet built)

- **A `workflow`-scoped PAT secret**, to make `agentic-compile.yml` fully
  auto-commit instead of check-plus-artifact (see "The GITHUB_TOKEN wall"
  above).
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
- **Bumping the pinned gh-aw version**: `v0.37.18` is confirmed working
  (2026-08-14) but stale — current latest is `v0.86.1` (2026-08-07).
  Bump deliberately and re-verify a real compile run after doing so
  rather than assuming newer is a drop-in.

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
most of the frontmatter above is reconstructed from search-result
snippets rather than the full pages. The `tools.github.toolsets` schema
fix and the GITHUB_TOKEN restriction above are the exceptions — those are
confirmed against a real `gh aw compile` / real Actions run, not snippets.
