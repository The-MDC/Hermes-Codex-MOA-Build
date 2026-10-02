---
name: market-research
description: """"
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


# Market Research

Produce research that supports decisions, not research theater.

## Research Standards

1. Every important claim needs a source.
2. Prefer recent data — call out stale data explicitly.
3. Include contrarian evidence and downside cases.
4. Translate findings into a decision, not just a summary.
5. Separate fact, inference, and recommendation clearly.

## Common Research Modes

### Investor / Fund Diligence
Collect:
- Fund size, stage, and typical check size
- Relevant portfolio companies and thesis alignment
- Recent activity and deal velocity
- Reasons the fund is or is not a fit
- Any obvious red flags or thesis mismatches

### Competitive Analysis
Collect:
- Product reality, not marketing copy — what does it actually do
- Funding and investor history (Crunchbase, PitchBook)
- Traction metrics if public (users, volume, revenue)
- Distribution and pricing clues
- Strengths, weaknesses, and positioning gaps

### Market Sizing
Use:
- Top-down from reports or public datasets
- Bottom-up sanity check from realistic customer acquisition assumptions
- Explicit assumptions for every leap in logic
- TAM / SAM / SOM with clear definitions for each layer

### Technology / Vendor Research
Collect:
- How it works (mechanism, not marketing)
- Trade-offs and adoption signals
- Integration complexity and lock-in
- Security, compliance, and operational risk

## Output Format

```
1. Executive Summary
2. Key Findings
3. Implications
4. Risks and Caveats
5. Recommendation
6. Sources
```

## Quality Gate

Before delivering:
- All numbers sourced or labeled as estimates
- Old data flagged with date
- Recommendation follows from the evidence
- Risks and counterarguments included
- Output makes a specific decision easier to make
