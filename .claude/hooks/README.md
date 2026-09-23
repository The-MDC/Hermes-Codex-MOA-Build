# `.claude/hooks/`

## What was wrong

`.claude/hooks/hooks.json` was a **Cursor** hooks file living in a Claude Code
repository. Three independent defects, any one of which was fatal:

| Defect | Evidence |
|---|---|
| **Wrong paths** | Every command pointed at `.cursor/hooks/*.js`. There is no `.cursor/` directory in this repository and there never has been — `git ls-tree -r origin/The-MDC \| grep -i cursor` returns nothing. |
| **Wrong event names** | `beforeShellExecution`, `afterFileEdit`, `beforeReadFile`, `afterTabFileEdit`, `beforeTabFileRead`, `subagentStart` are Cursor events. Claude Code emits `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `Stop`, `SessionStart`, `PreCompact`. |
| **Wrong file** | Claude Code reads hooks from **`.claude/settings.json`**. It never reads `.claude/hooks/hooks.json`. Even with correct paths and correct event names, nothing in that file would have run. |

Ten of the fifteen scripts it referenced did not exist. The behaviour it described
was specified in two places — that file and `.claude/rules/typescript-hooks.md` —
and implemented in neither.

The file has been removed. `scripts/repo-doctor.sh` now validates
`.claude/settings.json` instead, and warns if `hooks.json` ever reappears.

## What runs now

All five are wired in `.claude/settings.json`.

| Hook | Event | Matcher | Does |
|---|---|---|---|
| `before-submit-prompt.js` | `UserPromptSubmit` | — | Secret scanning on the prompt. Pre-existing, worked already. |
| `after-mcp-execution.js` | `PostToolUse` | `mcp__.*` | MCP result logging. Pre-existing, worked already. |
| **`post-edit-check.js`** | `PostToolUse` | `Write\|Edit` | console.log warning · Prettier · `tsc --noEmit`. **New.** |
| **`pre-bash-guard.js`** | `PreToolUse` | `Bash` | Blocks `--no-verify` / `-n` / `--no-gpg-sign` on git. **New.** |
| **`stop-audit.js`** | `Stop` | — | console.log sweep across changed files. **New.** |

The three new ones implement what `.claude/rules/typescript-hooks.md` already
specified: Prettier auto-format, TypeScript check, console.log warning, and an
end-of-session console.log audit.

### Design rules they all follow

**Only `pre-bash-guard.js` can block.** Everything else is advisory and exits 0
regardless. A formatting opinion is not worth killing a turn over.

**No network, ever.** Prettier and `tsc` run only if a *local* `node_modules/.bin`
binary exists. The original config used `npx block-no-verify@1.1.2`, which reaches
the registry on every shell command — the agent container gets 403 from npm, and
nobody wants that latency on a laptop either. Absent tooling is skipped silently,
not treated as failure.

**They fail open.** Every one is wrapped so a bug in a hook cannot wedge a session.

**Zero dependencies.** The console.log checks are plain Node string work, so they
are the part that always functions regardless of what is installed.

## What was deliberately not restored

`before-shell-execution.js` also described a *"tmux dev server blocker, tmux
reminder"*. That encoded a workflow specific to another machine. Reconstructing it
would mean inventing behaviour and shipping it as though it were recovered, so it
was left out. The git-bypass half — the part with clear, checkable intent — is what
`pre-bash-guard.js` implements.

`session-start.js`, `session-end.js`, `pre-compact.js` and `stop.js` remain in this
directory but are **not wired** and do nothing. They are forwarders to Cursor hooks
(`check-console-log.js`, `evaluate-session.js`, `cost-tracker.js`) that are not in
this repository. See the note at the top of `adapter.js`. `stop-audit.js` supersedes
the only part of `stop.js` whose intent was documented.

## Verification

Both directions were exercised before this shipped, because a gate that can only
pass is not a gate:

- `post-edit-check.js` — flags `console.log` at the right line numbers, ignores
  commented-out ones, silent on clean files, ignores non-code extensions.
- `pre-bash-guard.js` — 4/4 bypass forms denied, 5/5 ordinary commands allowed.
- `stop-audit.js` — proven non-vacuous by planting a `console.log` in a changed
  file (detected, correct line), then removing it (silent again).
- `repo-doctor.sh` — exits **1** when a wired hook points at a missing script,
  exits **0** on the current tree, and warns if `hooks.json` returns.
