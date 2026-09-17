## What this changes

<!-- One or two sentences. What behaviour is different after this PR? -->

## Why

<!-- The problem being solved. Link an issue if there is one. -->

## Verification

- [ ] `scripts/madhats-doctor.sh` passes (no FAIL lines)
- [ ] `node scripts/check-canonical-numbers.js` passes
- [ ] If a hook or `hooks.json` changed: the referenced script exists and the hook fired in a real session
- [ ] If a slash command changed: invoked it once end to end
- [ ] If `.mcp.json` changed: every server still connects
- [ ] If a smart contract changed: `/security` run, findings addressed

## Canonical numbers

<!-- Tick if untouched. If this PR CHANGES a canonical number, say who approved it —
     CLAUDE.md requires explicit approval, and the number is restated in several files. -->

- [ ] No canonical number changed (fee 1.88%, community 28.8%, creator 40%, pre-money $12M)
- [ ] A canonical number changed — approved by: ______ , and CLAUDE.md updated first

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
