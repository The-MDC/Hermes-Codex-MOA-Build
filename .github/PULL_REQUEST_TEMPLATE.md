## What this changes

<!-- One or two sentences. What behaviour is different after this PR? -->

## Why

<!-- The problem being solved. Link an issue if there is one. -->

## Verification

- [ ] `scripts/madhats-doctor.sh` passes (no FAIL lines)
- [ ] If a hook or `hooks.json` changed: the referenced script exists and the hook fired in a real session
- [ ] If a slash command changed: invoked it once end to end
- [ ] If `.mcp.json` changed: every server still connects
- [ ] If a smart contract changed: `/security` run, findings addressed

## Canonical numbers

<!-- Tick if untouched. If this PR CHANGES a canonical number, say who approved it —
     CLAUDE.md requires explicit approval, and the number is restated in several files.

     READ THIS ONE PROPERLY. CI no longer checks it. The automated comparison against
     every restatement in the repo was removed, so a drifted copy — "1.8%" where the
     canonical figure is "1.88%" — will now reach main unless a human catches it here.
     Both read as equally plausible. CLAUDE.md is the only source of truth; check the
     restatement against it, not against memory. -->

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
