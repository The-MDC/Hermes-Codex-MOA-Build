# Doctor Command

Check whether this machine and this checkout can actually do the work — before spending an hour finding out the hard way.

## Run it

```bash
bash scripts/repo-doctor.sh
```

Add `--quiet` to print only warnings and failures (useful in CI or a hook).

## What it checks

| Group | Checks |
|---|---|
| **toolchain** | `git`, `node`, `npm` present; `python3` advisory |
| **claude harness** | `.claude/settings.json` parses; slash commands and rules counted; **every script referenced by `hooks.json` actually exists**; `.mcp.json` parses |
| **hermes agent** | `hermes` on PATH; registered in `.mcp.json` |
| **network egress** | github.com, npm registry, Anthropic API reachable — an egress allowlist is otherwise silent until a build fails deep inside |

The doctor no longer checks canonical numbers. That group, its script and its two CI
steps were removed with the owner's explicit approval. The numbers are still canonical
and `CLAUDE.md` is still their declaration — agreement is now a reviewer's checkbox in
`.github/PULL_REQUEST_TEMPLATE.md` rather than an automated comparison.

## Why it exists

Two failure modes here are **invisible**, and both cost a full session to find by hand:

1. **A hook pointing at a path that does not exist never runs, and never says so.** The session looks completely normal. Nothing errors. The hook is simply absent. This was a live bug in this repo: `hooks.json` referenced `.cursor/hooks/*.js`, a directory that does not exist, while the actual scripts sat in `.claude/hooks/`.

2. **An egress allowlist does not announce itself.** Requests do not fail at the boundary with a clear message — they fail deep inside an install or a build, minutes later, looking like a broken package.

The doctor makes both loud and immediate.

## Exit codes

- `0` — no failures (warnings may be present)
- `1` — at least one FAIL; the environment is broken in a way that will bite

## When to run it

- First thing in a new clone or a new environment
- After changing `hooks.json`, `.mcp.json`, or `settings.json`
- Before a PR — it is the first box in the PR template
- Whenever something "should be working" but silently isn't
