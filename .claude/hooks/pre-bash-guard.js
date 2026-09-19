#!/usr/bin/env node
/**
 * pre-bash-guard.js — PreToolUse on Bash. The one hook here that can block.
 *
 * WHY THIS EXISTS
 *     `.claude/hooks/hooks.json` wired two things to Cursor's `beforeShellExecution`:
 *
 *         npx block-no-verify@1.1.2
 *             "Block git hook-bypass flag to protect pre-commit, commit-msg, and
 *              pre-push hooks from being skipped"
 *         node .cursor/hooks/before-shell-execution.js
 *             "Tmux dev server blocker, tmux reminder, git push review"
 *
 *     Neither ran. `beforeShellExecution` is a Cursor event Claude Code never emits,
 *     `.cursor/` does not exist, and the npx form would reach the network on every
 *     single shell command — which the agent container cannot do at all (the npm
 *     registry returns 403) and which nobody should want on a laptop either.
 *
 *     The bypass check is the half worth keeping, so it is reimplemented here with
 *     no dependencies and no network. The tmux half is deliberately not carried
 *     over: it encoded another machine's workflow, and guessing at it would mean
 *     shipping invented behaviour as though it were restored.
 *
 * WHAT IT BLOCKS
 *     --no-verify / -n on git commit and git push, and --no-gpg-sign, because each
 *     silently skips a hook the repository installed on purpose. The block is
 *     advisory in the sense that you can still run the command yourself in a
 *     terminal; what it prevents is an agent skipping the gate without saying so.
 *
 * WHAT IT DOES NOT DO
 *     It does not parse shell grammar. A sufficiently creative command can evade
 *     it. This is a guardrail against absent-mindedness, not an adversary.
 */

'use strict';

const fs = require('fs');

/** git commit -n / --no-verify, git push --no-verify, and unsigned commits. */
const PATTERNS = [
  {
    re: /\bgit\b[^\n;|&]*\b(commit|push|merge|rebase)\b[^\n;|&]*\s--no-verify\b/,
    why: '--no-verify skips the pre-commit, commit-msg and pre-push hooks this repository installs on purpose.',
  },
  {
    re: /\bgit\b[^\n;|&]*\bcommit\b[^\n;|&]*\s-n(?=\s|$)/,
    why: '`git commit -n` is --no-verify in short form; it skips the commit hooks.',
  },
  {
    re: /\bgit\b[^\n;|&]*\s--no-gpg-sign\b/,
    why: '--no-gpg-sign drops commit signing.',
  },
];

function readStdin() {
  try {
    return fs.readFileSync(0, 'utf8');
  } catch {
    return '';
  }
}

function allow() {
  process.exit(0); // Silence is consent. No output means "no opinion".
}

function deny(reason) {
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        permissionDecision: 'deny',
        permissionDecisionReason: reason,
      },
    }) + '\n'
  );
  process.exit(0);
}

function main() {
  const raw = readStdin();
  if (!raw.trim()) return allow();

  let payload;
  try {
    payload = JSON.parse(raw);
  } catch {
    return allow();
  }

  const command = payload?.tool_input?.command;
  if (typeof command !== 'string' || !command) return allow();

  for (const { re, why } of PATTERNS) {
    if (re.test(command)) {
      return deny(
        `Blocked by pre-bash-guard: ${why}\n\n` +
          `If the hook is genuinely wrong — a generated lockfile it cannot parse, ` +
          `say — fix the hook or run the command yourself. Do not route around the ` +
          `gate silently; that is the failure this guard exists to prevent.`
      );
    }
  }
  allow();
}

try {
  main();
} catch {
  allow(); // A broken guard must fail open, never wedge the session.
}
