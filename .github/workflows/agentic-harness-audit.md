---
description: Weekly + PR-triggered audit of the ECC harness (hooks, skills, commands, agents) using the /harness-audit rubric
on:
  pull_request:
    types: [opened, synchronize, reopened]
    paths:
      - ".claude/**"
      - "hooks/**"
      - "scripts/**"
  schedule:
    - cron: "0 14 * * 1"
  workflow_dispatch: {}
permissions:
  contents: read
  pull-requests: read
  issues: read
engine: claude
network:
  allowed:
    - defaults
    - api.anthropic.com
tools:
  github:
    toolsets: [pull_requests, issues, search]
  edit:
  bash:
    - "node scripts/harness-audit.js*"
safe-outputs:
  add-comment:
    max: 1
  create-issue:
    max: 1
---

<!--
  `.lock.yml` is generated and kept in sync automatically by
  agentic-compile.yml (runs in GitHub Actions on every push to this file).
  Still requires an ANTHROPIC_API_KEY repo secret to actually run — see
  `.claude/skills/ecc/gh-aw-agentic-workflows.md` for the activation
  runbook. If a future compile run finds another schema error (the `bash:`
  command-pattern block in particular was never separately verified),
  fix it the same way this one was found: read the actual compile-check
  job log, not the schema docs — the compiler's own error message names
  the exact bad value.
-->

# Harness Audit — ECC Agent Harness

You are auditing **this repository's own Claude Code harness** — its
hooks, skills, commands, and agents — using the deterministic rubric
defined in `.claude/commands/harness-audit.md`. This workflow does not
touch product code; it audits the tooling this repo is built
with.

## Steps

1. Check whether `scripts/harness-audit.js` exists in this repository at
   the commit you're running against.
2. **If it exists:** run `node scripts/harness-audit.js repo --format
   json` and treat its output as the sole source of truth. Do not invent
   additional dimensions, adjust scores, or override its numbers.
   Reproduce `.claude/commands/harness-audit.md`'s output contract
   exactly: overall score out of 70, the 7 category scores (Tool
   Coverage, Context Efficiency, Quality Gates, Memory Persistence, Eval
   Coverage, Security Guardrails, Cost Efficiency), failed checks with
   exact file paths, and `top_actions`.
3. **If it does NOT exist:** do not fabricate a score or approximate the
   rubric by hand. State plainly that the deterministic engine
   (`scripts/harness-audit.js`) referenced by
   `.claude/commands/harness-audit.md` is missing from the repo, quote
   the expected invocation (`node scripts/harness-audit.js <scope>
   --format <text|json>`), and stop there. A missing engine is a real gap
   worth surfacing, not something to paper over with a guessed number.

## Reporting

- **On a pull request**: post exactly one summary comment (`add-comment`)
  with either the scorecard or the "script missing" notice.
- **On the weekly schedule**: only open an issue (`create-issue`) if
  either (a) the script is missing, or (b) `overall_score` is below
  50/70. A clean weekly run at or above that bar should produce no
  output at all — silence is the expected steady state.
- **On manual dispatch**: same as the pull request case, but there is no
  PR to comment on, so open an issue instead if there's anything to
  report; otherwise produce no output.

Keep any comment/issue body concise: the score line, failing checks with
exact paths, and the top 3 actions. Do not restate the full rubric or
pad the report to look thorough.
