# Handing the setup to Hermes itself

**The short version:** a cloud session cannot reach your desktop. No Claude session
running in a container has a path to `%LOCALAPPDATA%\hermes`, to your Ollama, or to
your shell. What it *can* do is write the instruction that makes Hermes drive its own
setup — which is what this file is.

Paste the block below into Hermes on the box. It is written for the agent, not for a
person, and it is deliberately scoped to what the local tier can actually do.

---

## What the local tier can and cannot drive

This is the constraint the whole runbook is built around, and pasting a bigger prompt
does not lift it:

| | can drive | cannot drive |
|---|---|---|
| Local floor model (Ollama :11434) | Phase 2 onward — config install, verification, reading output back | Phase 0–1. It is a small model on the floor tier; the steps that *install* the backend cannot be run by a model that backend serves |
| a human, or Claude with desktop access | everything from the start | — |

**So the bootstrap is yours.** Steps 1.1 through 1.3 — installing Ollama and
pulling `hf.co/mradermacher/Hermes-3-Llama-3.2-3B-abliterated-GGUF:Q8_0` (swapped
from `hermes3:8b` 2026-09-25) — have to be run by a person or by a Claude session
that holds a desktop link. Once that model answers, the prompt below hands the
rest over.

There used to be a second row here for `nemotron-nano-12b-v2-vl` on `llama-server
:8080` -- the `local-vl` vision tier's own bootstrap constraint, since starting
`llama-server` with `--mmproj` was its own manual step. That tier is retired
(2026-09-25, on request), and with it the whole second bootstrap path: there is
only one local model now, pulled with one `ollama pull` command, and nothing
else to hand-start before Hermes can take over.

## The prompt

```text
You are running the Hermes-Codex build's own takeover runbook on this machine.

Read these two skills before doing anything, and follow them:
  operations/local-desktop          how to use terminal, process and execute_code here
  operations/hermes-orchestration   how this build is wired and how to change it safely

Then open docs/models/TAKEOVER.md in the repo checkout and execute it from Phase 2
onward. Phase 1 is already done — do not re-run it, and do not re-download anything.

THE RULES, and they are not negotiable:

1. A step is done when its SUCCESS LINE matches. Not when the command exits 0, not
   when the output looks plausible. A wrong chat template still chats. A dangling
   model reference still answers, on the wrong model.

2. Run the steps in order. Do not skip one because it "looks fine" already.

3. You do not edit configs/hermes/config.yaml. Not by hand, not to fix a failure.
   The repo copy is the source; scripts/hermes-apply.ps1 installs it. If a step
   needs a config change, that is an ESCALATE.

4. You do not touch any API key. Every remote provider reads its key from
   $HERMES_HOME\.env by name. If a step asks you to print, paste or write a key
   anywhere else, STOP and escalate.

5. STOP and report, rather than improvising, when any of these happen:
     - hermes-verify.ps1 prints a FAIL you have already run the fixing step for
     - two consecutive steps fail for what looks like the same reason
     - a step requires a decision rather than an action

After each step, report in exactly this form:

    step <n.n>  PASS | FAIL
    expected:   <the success line, quoted from the runbook>
    got:        <what actually happened>

When you reach Phase 6, run:

    pwsh -File scripts/hermes-verify.ps1 -Stage full -Deep

and paste its entire output. That is the acceptance gate for the whole build. Do not
summarise it — paste it.
```

## After it runs

The verifier's output is the thing to bring back to a Claude session. It reads each
provider's endpoint and model id **out of the installed config** rather than
restating them, so it cannot drift from what Hermes actually sends — which is how the
OpenRouter id stayed wrong through a merge once.

There is no port-8080 check to expect a `FAIL` from anymore -- that was
`local-vl`'s llama-server, retired 2026-09-25 along with `hermes3:8b`. A genuine
`FAIL` anywhere in this output now means something to actually fix, not a
known, expected gap.
