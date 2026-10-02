---
name: six-perspectives
description: "name: six-perspectives
description: Stress-test an architecture document (or any high-stakes design decision) with six supporting perspectives and six opposing perspectives, then synthesize a verdict. Transposed from Nick's Claude/Cowork six-perspectives method.
version: 1.0.0
author: Nick McLeod (transposed to Hermes by Claude, 2026-09-21)
license: MIT"""
version: 1.0.0
author: "unknown"
license: "MIT"
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [automatically-portled]
    category: general
    related_skills: []
---
  hermes:
    tags: [Council, Architecture-Review, Critical-Thinking, Decision-Support]
    related_skills: [multi-perspective-analysis, adversarial-critique, bayesian-synthesis]

# Six Perspectives

Stress-tests an architecture document, technical design, or high-stakes
decision by running twelve distinct viewpoints against it — six that build
the strongest supporting case (and find the flaws that would sink it even
if you believe it), and six that build the strongest *opposing* case (why
you might be solving the wrong problem, or solving it the wrong way).

This is a transposition of the six-perspectives method Nick uses with
Claude/Cowork for architecture review — rebuilt on Hermes' own primitives
rather than copied as a prompt template, so it degrades gracefully and
gets sharper when `hermes-council` is installed.

## When to Use

- A new architecture doc, RFC, or design proposal needs review before it's
  treated as decided
- A "should we do X" decision has real cost if wrong (migration, vendor
  choice, schema change, security model)
- You want the disagreement made explicit rather than smoothed over by a
  single pass

Not for: quick factual questions, code review of an already-agreed design
(use `adversarial-critique` instead), or anything where there's no real
decision at stake.

## The Twelve Perspectives

### Six supporting (stress-test the case FOR the design)

| # | Perspective | Finds |
|---|---|---|
| 1 | **Scalability & Performance** | Where this breaks at 10x / 100x current load |
| 2 | **Security & Attack Surface** | What's exploitable, and the blast radius if it is |
| 3 | **Operability & Failure Modes** | What breaks at 3am, how it's detected, how it's recovered |
| 4 | **Cost & Efficiency** | What this costs at scale, and whether it's the cheapest way to get the property you actually need |
| 5 | **Maintainability & Team Velocity** | Whether the team can actually build, extend, and debug this in six months |
| 6 | **Correctness & Data Integrity** | Whether the data model, invariants, and edge cases actually hold |

### Six opposing (steelman the case AGAINST — or for a different design)

| # | Perspective | Finds |
|---|---|---|
| 7 | **Status Quo** | Why the current approach might already be good enough |
| 8 | **Simpler Alternative** | A boring design that gets 80% of the value at 20% of the cost |
| 9 | **Buy vs. Build** | Why an off-the-shelf or managed service beats the custom build |
| 10 | **Premature Optimization** | Why solving this now, instead of later, is wasted effort |
| 11 | **Lock-in & Strategic Risk** | Why the proposed dependency is a risk independent of technical merit |
| 12 | **Second-Order Consequences** | What this change breaks elsewhere, and the opportunity cost of building it at all |

Each perspective argues its case as strongly as it honestly can — this is
steelmanning, not a strawman exercise. The synthesis step is where the
tension gets resolved, not the individual perspectives.

## How to Run It

### If `hermes-council` is installed (preferred — richer output)

Drop `config/hermes-council-personas.yaml` from this bundle into
`~/.hermes-council/config.yaml` (merge, don't overwrite) to register all
twelve personas by name, then:

```
council_query(
    question="<the architecture decision or claim to stress-test>",
    context="<paste the architecture doc, or a summary + link>",
    personas=["scalability","security","operability","cost","maintainability",
              "correctness","status_quo","simpler_alternative","buy_vs_build",
              "premature_optimization","lock_in_risk","second_order"],
    mode="deep"
)
```

`mode="deep"` runs a second Arbiter pass — worth the extra cost for
anything you'd actually call "high-stakes." Read `confidence_score` and
`conflict_detected` first: a wide spread across the twelve means real,
unresolved disagreement — don't round that off in the summary you give
Nick.

### If `hermes-council` is not installed (fallback — no extra dependency)

Use Hermes' native `delegate_task` to spawn up to `delegation.max_concurrent_children`
subagents (default 3, so this runs in batches of 3), one per perspective,
each with a short, focused brief:

```
delegate_task(tasks=[
  {"goal": "Argue the SCALABILITY case on: <decision>. Cite specific numbers from the doc where possible. End with a one-line verdict: holds / breaks / unclear, and why.", "agent": "hermes"},
  {"goal": "Argue the SECURITY case on: <decision>. ...", "agent": "hermes"},
  ... (all twelve)
])
```

Collect all twelve verdicts, then run one final synthesis pass yourself
(or via a 13th `delegate_task` call) that:

1. Lists where the six supporting and six opposing perspectives agree
2. Lists where they conflict, and which side has the stronger evidence
3. Gives a single recommendation with explicit confidence and the top 2-3
   risks that don't go away even if you proceed

## Output Format

Always end with a compact verdict block, not just twelve essays:

```
VERDICT: <proceed / proceed-with-changes / do-not-proceed / needs-more-evidence>
CONFIDENCE: <0-100>
STRONGEST SUPPORTING ARGUMENT: <one line>
STRONGEST OPPOSING ARGUMENT: <one line>
TOP RISKS IF YOU PROCEED ANYWAY: <1-3 bullets, each one line>
```

This mirrors how Nick and Claude use the method today — the twelve-way
debate is the work, but what gets acted on is the four-line verdict at
the end.
