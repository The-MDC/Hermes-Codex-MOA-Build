# Codex: a delegate, not a fifth tier

Hermes config: `configs/hermes/config.yaml` (`excluded_providers`) · Codex config:
`configs/codex/config.toml` · Bundled skill this rides on:
`autonomous-ai-agents/codex` v1.0.1, shipped with Hermes — nothing to install or port.

## The design this corrects

The starting assumption was "wire Codex as an MCP server, let Hermes call it as a
tool." That is the clean answer and it is wrong, as of a change in the last month:

> `codex mcp-server` and the standalone `codex-mcp-server` binary **have been
> removed**. Use the Codex app server instead.
> — `developers.openai.com/codex/app-server`, deprecated 2026-08-24, removed 2026-09-05

One official page (`…/codex/mcp-server`) is still live and still documents the old
tool in full — `codex` (start session) and `codex-reply` (continue) — which makes it
easy to design against a surface that no longer exists. Treat that page as stale.

The replacement, `codex app-server`, is JSON-RPC 2.0 over stdio/websocket/unix
socket — a real embedding interface, but a second protocol client to build and
maintain for a repo that already has a database and does not need a second one. It
is worth revisiting if the handoff volume ever justifies it. It does not today.

What Hermes actually ships for this is simpler than either: the bundled `codex`
skill drives the CLI as a **subprocess**, over the `terminal`/`process` tools Hermes
already has. That is the path below.

## Two touchpoints, one path

Hermes has two separate things that mention Codex, and they do different jobs.
Conflating them is the mistake this section exists to prevent.

| | what it is | what it costs |
|---|---|---|
| `model.provider: openai-codex` | Hermes' own reasoning runs on a GPT-5.x model via ChatGPT/Codex OAuth, as an **inference provider** — a 5th entry next to nvidia-nim / hf-router / or-fallback / local | Draws the ChatGPT plan's rolling 5-hour usage window, from `~/.hermes/auth.json` |
| the `codex` skill (`terminal` + `process`, `pty=true`) | Hermes shells out to the **Codex CLI** to do a bounded coding task, then reads the result back | Draws the **same** ChatGPT window, independently, from `~/.codex/auth.json` |

Those two token files are not the same file, and neither side can see what the
other has spent. Turn both on and you have two silent consumers of one quota — a
compression pass or a title generation (routed to `custom:hf-router` for exactly
this reason elsewhere in this config) suddenly has a cousin, and it is invisible
until the plan's usage limit trips mid-task with no line in either transcript
explaining why.

**Decision: only the second one. `openai-codex` is excluded.**

```yaml
# configs/hermes/config.yaml
excluded_providers:
  - openai        # already here
  - openai-codex  # added — see docs/models/codex-handoff.md
```

This is the same mechanism the rest of the config already trusts — `excluded_providers`
hides a built-in catalog entry by name — applied to a new case: not "we don't want
this provider," but "this must never become a provider, because something else in
this same file already depends on its credentials meaning one thing." CI asserts
the entry stays present, the same way it asserts `or-fallback` never collides with
its own exclusion.

The trade being made explicitly: Hermes' main reasoning stays on its own parent tier (DeepSeek-V4-Pro as of 2026-09-22; Kimi-K3 when this was written), not GPT-5.x,
even though the ChatGPT plan's usage window is separately available and arguably
"free" at the margin. Revisit only if the request-budget picture changes enough to
justify a fifth entry in a picker this repo just fought to pin at four.

## When the handoff is the obvious sense

Hand off when the task is:

- **Bounded and git-repo-scoped** — implement, fix, or refactor something inside a
  checked-out repository, not "reason about a business decision" or "write investor
  copy." Codex has no context on MAD Gambit's canon, voice, or `CLAUDE.md` — that
  context lives in Hermes' system prompt and this repo, and shelling out to Codex
  does not carry it along.
- **Iterate-and-verify shaped** — needs edits, a test run, more edits, not a single
  one-shot patch. That loop is what a sandboxed coding agent is for; running it
  through Hermes' own generic tool calls means Hermes pays a request for every file
  read and every edit instead of one delegated run.
- **Matches a purpose-built Codex feature** — `codex review --base origin/main` for
  PR review, or parallel `git worktree` fan-out for independent changes across a
  large tree. Reimplementing either in Hermes' own tool-call loop is strictly worse:
  more requests, more tokens, no test-in-sandbox loop underneath.

Keep on Hermes: anything needing this repo's own canon (`CLAUDE.md`, `ABOUT-ME/`),
anything conversational, anything where the "iterate against a sandboxed checkout"
shape doesn't apply. A one-line edit is not obviously worth a subprocess handoff
either — the overhead of spawning and polling a background process costs more than
Hermes just making the edit.

## The invocation pattern

```
terminal(
  command = "codex exec --json --sandbox workspace-write "
          + "'Add a dark-mode toggle to settings; run the existing tests after'",
  workdir = "~/project",
  background = true,
  pty = true,          # Codex is an interactive terminal app; it hangs without one
)
process(action="poll",   session_id="<id>")
process(action="log",    session_id="<id>")
process(action="submit", session_id="<id>", data="yes")   # only if approval_policy prompts
process(action="kill",   session_id="<id>")
```

Three additions to what the bundled skill shows by default, all in service of the
same three constraints this whole config is built against:

- **`--json`** — stdout becomes a JSONL event stream (`item.completed`,
  `turn.completed` with a `usage` block, etc.) instead of narrative text. Hermes
  parses one `agent_message` item instead of reading Codex's own reasoning prose —
  fewer tokens land back in Hermes' context for the same result.
- **`--output-schema <file>`**, when the caller needs a specific shape back (a list
  of changed files, a pass/fail plus summary) rather than "read the diff and
  decide." Constrains the final message to JSON Schema; still one call.
- **`background=true` + `process.poll`**, always. `codex exec` on a real change can
  run for minutes. Blocking Hermes' loop on it spends a request doing nothing but
  waiting; polling in the background does not.

**Safety layer, since `approval_policy = "never"` means nothing is there to ask:**
narrow `workdir` to the actual project, confirm `git status` is clean before
starting, review `git diff` after, run targeted tests in between. This is what the
bundled skill itself prescribes, and it is the same discipline `codex review` exists
to formalize for anything larger than one change.

**The gateway sandbox caveat.** Hermes' own docs for this skill warn that when
Codex is invoked from a gateway/service context (a Telegram-driven session, for
example — anything that is not an interactive shell), `workspace-write` can fail
outright: `setting up uid map: Permission denied`,
`loopback: Failed RTM_NEWADDR: Operation not permitted`. Codex's sandbox is
bubblewrap-based and nests badly inside a jail Hermes' own service context may
already be running in. The documented workaround is `--sandbox danger-full-access`
with the process-discipline safety layer above standing in for the sandbox. Try
`workspace-write` first; only escalate per-call when it actually fails this way —
`configs/codex/config.toml` deliberately defaults to `workspace-write`, not
`danger-full-access`, so the escalation is a conscious per-task choice, not a
standing default.

## Auth — two paths, pick by context

```bash
# Interactive machine, human present, ChatGPT plan already paid for:
codex login                      # browser OAuth, ChatGPT sign-in — no separate billing

# Nothing local to open a browser on, or no ChatGPT plan:
CODEX_API_KEY=<api-key> codex exec --json "…"    # exec-scoped, metered per token
```

`codex login status` exits 0 once credentials are present; `codex logout` clears
both credential types. Credentials land in `~/.codex/auth.json` or the OS keychain,
per `cli_auth_credentials_store` in `configs/codex/config.toml` — set to `auto`
there, matching the repo's existing "no plaintext secret if the platform offers
better" instinct.

**Do not also run `hermes auth add openai-codex`.** That command exists and works —
Hermes' provider wizard documents Codex OAuth via device code, and can even *import*
an existing `~/.codex/auth.json` — but doing so is exactly the second-consumer
problem above. One credential store, one consumer: the CLI's own.

## Money, requests, tokens — the same three constraints, a different meter

This repo's Hermes config optimizes NVIDIA NIM's ~40 RPM bucket and the HF/OpenRouter
buckets behind it. None of that spending touches Codex. Codex has its own, separate
constraint:

- **If billed on the ChatGPT plan** (recommended default — `codex login`): cost is
  already sunk in the subscription; the live constraint is the **rolling 5-hour
  message window**, shared with any human interactive use of ChatGPT or Codex on the
  same account. A heavy delegated task competes with Nick's own Codex/ChatGPT use in
  that window, the same shape of problem the NIM 40 RPM split exists to avoid on the
  Hermes side — just a different bucket, unfixed by anything in `config.yaml`.
- **If billed via `CODEX_API_KEY`**: no fixed request ceiling, but every token is
  metered (published per-1M-token pricing runs from $0.75/$4.50 in/out on the
  smallest current model up to $5.00/$30.00 on the largest — see
  `platform.openai.com/docs/pricing`). `--json` and `--output-schema` reduce what
  comes *back*; they do not reduce what the delegated run itself spends reasoning
  and editing.

Neither meter is visible to `scripts/nim-preflight.sh` or the Hermes CI gate — they
watch the NIM/HF/OpenRouter buckets only. There is no Codex-side preflight here yet;
`codex login status` before a delegated run is the closest available check, and it
only confirms credentials exist, not that quota remains.

## What is verified here, and what is not

This container's egress proxy denies `developers.openai.com`, `github.com`,
`raw.githubusercontent.com` and `hermes-agent.nousresearch.com` at the CONNECT
level. Every fact above came from a research pass through MCP-based fetch tools
(Exa, Firecrawl) that reach those hosts from outside this container — not from
training-data recall, and not from anything run live in this environment. Flagged
explicitly rather than silently assumed:

- Codex is not installed here and the install command was never run in this
  environment. `npm install -g @openai/codex` is the documented path; untested here.
- No live `codex exec` call, sandboxed or otherwise, has been made from this repo.
  The gateway-sandbox failure mode above is Hermes' own documentation, not something
  reproduced in this container.
- Whether the `openai-codex` Hermes provider's wire protocol is Chat Completions or
  the Responses API is **unconfirmed** — the Hermes providers page documents this
  explicitly for GitHub Copilot and other entries but not for `openai-codex`. Does
  not affect the decision above (the provider is excluded either way), but would
  matter if that decision is ever revisited.
- The exact CLI flag spelling for API-key sign-in (`--with-api-key` vs. a bare
  `--api-key`) could not be confirmed against an official page — only third-party
  guides give it. `CODEX_API_KEY` as a `codex exec`-scoped environment variable IS
  confirmed against the official auth page and is the form used above.

## Corrections against the assumption this design started from

Recorded because this doc set's own discipline is to write down a wrong assumption
once it is caught, not quietly ship the fix.

| assumed | actual |
|---|---|
| `hermes auth add codex --type oauth` | `hermes auth add openai-codex` — the provider id is `openai-codex`, not a generic `codex --type oauth` invocation |
| Hermes → Codex over MCP (Hermes as client, Codex as server) | `codex mcp-server` is removed (2026-09-05). No MCP path exists today; the subprocess skill is the supported one |
| "Codex OAuth" and "the Codex CLI's own login" are the same credential | They are not — `~/.hermes/auth.json` (Hermes' `openai-codex` provider) and `~/.codex/auth.json` (the CLI) are separate files against the same usage window |
