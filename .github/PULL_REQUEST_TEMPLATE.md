## What this changes

<!-- One or two sentences. What behaviour is different after this PR? -->

## Why

<!-- The problem being solved. Link an issue if there is one. -->

## Verification

- [ ] `scripts/repo-doctor.sh` passes (no FAIL lines)
- [ ] If a hook changed: the referenced script exists and the hook fired in a real session
- [ ] If a slash command changed: invoked it once end to end
- [ ] If `.mcp.json` or `configs/hermes/config.yaml` changed: every server still connects, and the Hermes config assertion block prints `hermes config: OK`
- [ ] If a skill or MCP server was added or removed: `python3 scripts/check-capabilities.py` passes
- [ ] If a model id changed: checked against **that gateway's** catalog, not another's

## No product content

<!-- This repo is the Hermes + Codex orchestration build and carries no product
     content. Four upstream skill sources mention a product in their code examples;
     SCRUB in scripts/port-skills-to-hermes.js removes those on the way through, and
     the port fails if any survives. If you added a skill, run the port and check the
     `scrub: clean` line rather than assuming. -->

- [ ] No product name, branding or figure was introduced

## Numbers, if this is a performance or cost change

<!-- Claims need a noise floor. Report at least 3 runs of each arm, or say explicitly
     that the effect was not measured against variance. One run is an anecdote. -->

| arm | run 1 | run 2 | run 3 | mean |
|-----|-------|-------|-------|------|
|     |       |       |       |      |

## Risk

<!-- What could this break that the checks above would NOT catch?
     A hook that silently stops firing, a number that is still plausible but wrong,
     an MCP server that loads but returns nothing. Name the invisible failure. -->
