---
name: verification-loop
description: "> Comprehensive verification system for code sessions. Use after completing a feature, before creating a PR, after refactoring, or any time you want to confirm quality gates pass. Runs build, type check, lint, tests, security scan, and diff review in sequence. Always activate before any production deployment or merge."
version: 1.0.0
author: "Anthropic — ported for Hermes Agent by MADHATs"
license: "Anthropic skill licence; see upstream"
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Verification, Quality-Gate, CI, Testing]
    category: software-development
    related_skills: [api-design, backend-patterns, frontend-design, mcp-builder, mcp-server-patterns]
---

# Verification Loop

Run after completing any significant code change.

## When to Use
- After completing a feature or component
- Before creating a PR
- After refactoring
- After smart contract changes (always)
- Before production deployment

---

## Phase 1: Build

```bash
npm run build 2>&1 | tail -20
# or
pnpm build 2>&1 | tail -20
```

If build fails → STOP. Fix before continuing.

---

## Phase 2: Type Check

```bash
npx tsc --noEmit 2>&1 | head -30
```

Report all type errors. Fix critical ones before continuing.

---

## Phase 3: Lint

```bash
npm run lint 2>&1 | head -30
```

---

## Phase 4: Test Suite

```bash
npm run test -- --coverage 2>&1 | tail -50
```

Target: 80% coverage minimum. Report:
- Total tests: X
- Passed: X
- Failed: X
- Coverage: X%

---

## Phase 5: Smart Contract Verification (if Solidity changed)

```bash
# Run full Foundry test suite
forge test -vv 2>&1 | tail -40

# Check gas snapshots for regressions
forge snapshot --check 2>&1

# Slither static analysis (if installed)
slither . --filter-paths "lib/" 2>&1 | head -50
```

Checklist:
- [ ] All Foundry tests pass
- [ ] No new gas regressions
- [ ] No Slither high/medium findings unaddressed

---

## Phase 6: Security Scan

```bash
# Hardcoded secrets
grep -rn "sk-\|api_key\|private_key\|mnemonic" \
  --include="*.ts" --include="*.js" --include="*.sol" \
  --exclude-dir="node_modules" . | head -10

# Debug logs in production code
grep -rn "console.log" --include="*.ts" --include="*.tsx" src/ | head -10
```

---

## Phase 7: Diff Review

```bash
git diff --stat
git diff HEAD~1 --name-only
```

Review each changed file for:
- Unintended changes
- Missing error handling
- Edge cases in market logic or settlement

---

## Output Format

```
VERIFICATION REPORT
===================

Build:           [PASS/FAIL]
Types:           [PASS/FAIL] (X errors)
Lint:            [PASS/FAIL] (X warnings)
Tests:           [PASS/FAIL] (X/Y passed, Z% coverage)
Smart Contracts: [PASS/FAIL/N/A]
Security Scan:   [PASS/FAIL] (X issues)
Diff:            [X files changed]

Overall: [READY / NOT READY] for PR

Issues to Fix:
1. ...
```
