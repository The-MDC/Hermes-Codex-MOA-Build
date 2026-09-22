---
name: local-desktop
description: "Use this skill for ANY request that touches the machine Hermes is running on: running a command, inspecting or editing files, driving a CLI or an interactive terminal app, installing or checking software, reading logs, checking whether a port or service is up, or automating a multi-step local workflow. Also use it whenever a task would otherwise mean many small tool calls in a row over local data. It describes Hermes' OWN local tools — terminal, process and execute_code — not any Claude or IDE surface. Triggers on: run this, check the file, what is in, is it installed, start the server, is the port open, read the log, rename these, automate this locally, on my machine, on the box, desktop, shell, terminal, PowerShell, bash."
version: 1.0.0
author: "MADHATs — written for this Hermes build"
license: "MIT"
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Local, Desktop, Terminal, Process, CodeExecution, Automation]
    category: operations
    related_skills: [hermes-orchestration]
---

# Working on the local machine

You have three tools for this, and choosing the wrong one is the most common way a
local task goes slowly or gets stuck. Pick by the shape of the job, not by habit.

| Tool | Use it for | Do not use it for |
|---|---|---|
| `terminal` | One command whose output you need | A loop of commands feeding each other |
| `process` | Managing something `terminal` started in the background | Anything short-lived |
| `execute_code` | A pipeline: several steps where only the last answer matters | A single command |

---

## `terminal` — one command

```
terminal(
  command = "git status --short",
  workdir = "~/project",
)
```

**Two arguments decide whether it works or hangs.**

`pty = true` is required for any **interactive** terminal app — anything that draws a
UI, prompts, or expects a TTY. Without it the program blocks forever waiting for a
terminal that is not there, and you get no output and no error. If a command that
should be fast returns nothing, this is the first thing to check.

`background = true` is required for anything **long-running** — a server, a build, a
download, a model load. Without it you block until it finishes, which for a server is
never. Background returns a `session_id` you then drive with `process`.

```
terminal(
  command  = "llama-server -m model.gguf --mmproj mmproj.gguf --port 8080",
  background = true,
  pty        = true,
)
```

**Windows:** commands run through PowerShell. Backtick is the line-continuation, not
backslash. `$env:LOCALAPPDATA` not `%LOCALAPPDATA%` inside PowerShell expressions.
A command written for `cmd` will often half-work, which is worse than failing.

---

## `process` — managing what you started

```
process(action="poll",   session_id="<id>")   # is it still running?
process(action="log",    session_id="<id>")   # what has it printed so far?
process(action="submit", session_id="<id>", data="yes")   # answer a prompt
process(action="kill",   session_id="<id>")   # stop it
```

**Always `poll` before you `log`.** A process that died leaves its output behind, and
reading the log without checking the state is how you report success from the output
of something that crashed.

**Never leave a background process running when the task is done** unless it is meant
to be a service. Kill it. An orphaned process holds a port, and the next attempt to
start the same service fails with an error that looks like a config problem.

---

## `execute_code` — the one that changes what is possible

The agent writes a Python script that calls Hermes tools over an RPC socket.
**Intermediate results never enter your context. Only the script's final `print()`
comes back.**

That is not a convenience. A search → extract → filter → summarise pipeline is four
inference round trips if you do it with four tool calls, and **one** if you do it
here. On a metered or rate-limited tier that is the difference between a task
finishing and a task burning the bucket.

Reach for it whenever you catch yourself about to make several tool calls where you
only care about the last answer:

- Reading twenty files and reporting the three that match
- Walking a directory tree and summarising what is there
- Fetching several pages and extracting one table
- Any "check all of X and tell me which ones Y"

**Mode matters.** `project` runs in the session's working directory with the active
venv, so `import pandas` and relative paths behave as they do in `terminal`. `strict`
quarantines to a temp dir with Hermes' own interpreter — more reproducible, less
useful. This build runs `project`.

**What it cannot do**, by design: call `execute_code` recursively, call
`delegate_task`, or call any MCP tool. Credentials are scrubbed from its environment.
If you need an MCP tool, call it directly rather than trying to reach it from inside a
script.

---

## Before you change anything

The tools will happily destroy work. These four habits are the difference between a
useful agent and an expensive one.

1. **Look before you write.** `cat`, `ls`, `git status` first. Never overwrite a file
   you have not read.
2. **Narrow the `workdir`.** Scope every command to the directory the task is about.
   A command run from `~` that was meant for one project can reach everything.
3. **`git status` clean before, `git diff` after.** If the repo was dirty before you
   started, you cannot tell your changes from someone else's — say so and stop.
4. **Prefer the reversible form.** `-WhatIf` / `--dry-run` / `cp` before `mv`. Run the
   destructive version only after the preview matched what you expected.

## Credentials — the one hard rule

**Never print, echo, paste or write a key anywhere except the `.env` the build reads.**
That includes: `echo $env:HF_TOKEN`, a command line that carries a token as an
argument (it lands in shell history), a config file, a log, or a message back to the
user.

If a task needs a credential, reference it by **variable name**. If you must confirm
one is set, check its presence and length, never its value:

```
terminal(command = "if ($env:HF_TOKEN) { 'set, ' + $env:HF_TOKEN.Length + ' chars' } else { 'NOT SET' }")
```

If you ever see something key-shaped in output you are about to return, stop and say
where it appeared rather than reproducing it. `scripts/hermes-report.ps1` in this
repo does exactly this and is the pattern to copy.

---

## When a local task fails

Work the list in order. Most local failures are one of these five, and the error
message usually names the symptom rather than the cause.

1. **No output at all** → missing `pty = true` on an interactive program.
2. **Hangs forever** → missing `background = true` on a long-running one.
3. **"not recognized" / "command not found"** → the tool is not on PATH, or PATH was
   not refreshed. On Windows, `winget install` does **not** update PATH in a shell
   that is already open. Close and reopen it, then retry once before concluding
   anything.
4. **`ModuleNotFoundError` or a missing package** → check **which interpreter ran**
   before touching any package. A supervisor that substitutes its own runtime makes
   an installed package look absent, and the error names the module, which sends you
   to `pip` instead of to the interpreter. See the `hermes-orchestration` skill.
5. **Permission denied** → do not escalate privileges to get past it. Report what was
   denied and what you were trying to do.

**An error message names a symptom, not a cause.** Read the first error, not the last:
a cascade usually has one real fault at the top and noise underneath.
