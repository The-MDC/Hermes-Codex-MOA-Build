/**
 * adapter.js — the module every hook in this directory requires, and which was missing.
 *
 * WHY THIS EXISTS
 *     All six scripts in .claude/hooks/ open with `require('./adapter')`. No adapter.js
 *     was ever committed, so every one of them died on its first line:
 *
 *         Error: Cannot find module './adapter'
 *
 *     That was the second of five independent defects in this repo's hook setup. It is
 *     also the invisible kind: a hook that crashes on require still exits, the session
 *     continues, and nothing reports that the hook did not run.
 *
 * WHAT IT PROVIDES, AND WHAT IT DELIBERATELY DOES NOT
 *     `readStdin` is real. It is the only thing the two hooks with actual logic —
 *     before-submit-prompt.js (secret scanning) and after-mcp-execution.js (MCP result
 *     logging) — ever needed.
 *
 *     `runExistingHook`, `transformToClaude` and `hookEnabled` are the Cursor bridge.
 *     The four scripts that call them (session-start, session-end, pre-compact, stop)
 *     contain no logic of their own; they exist only to forward to Cursor hooks such as
 *     `check-console-log.js`, `evaluate-session.js` and `cost-tracker.js` which are not
 *     in this repository and never have been. Those three are implemented here as
 *     honest, documented no-ops rather than invented behaviour: writing a plausible
 *     `evaluate-session` would be guessing at someone else's intent and shipping it as
 *     though it were restored.
 *
 *     Consequently only the two working hooks are wired in .claude/settings.json. See
 *     .claude/hooks/README.md for the full picture.
 */

'use strict';

/**
 * Read the hook payload from stdin.
 *
 * Claude Code writes a single JSON object to the hook's stdin and reads stdout back.
 * Resolves to the raw string so callers can both parse it and echo it through
 * unchanged — every hook here is pass-through and must not alter the payload.
 */
function readStdin() {
  return new Promise((resolve) => {
    let data = '';
    // A hook invoked with no stdin (a manual run, a smoke test) must not hang.
    if (process.stdin.isTTY) return resolve('');
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => { data += chunk; });
    process.stdin.on('end', () => resolve(data));
    process.stdin.on('error', () => resolve(data));
  });
}

/**
 * No-op. The Cursor hooks this would forward to are not in this repository.
 *
 * Returns false so a caller can tell nothing ran, rather than silently believing it did.
 */
function runExistingHook(name /* , input */) {
  if (process.env.HERMES_HOOK_DEBUG) {
    process.stderr.write(`[hooks] runExistingHook("${name}") is a no-op: no Cursor hook tree in this repo\n`);
  }
  return false;
}

/**
 * No-op passthrough. The Cursor payload shape and the Claude Code payload shape differ,
 * but with no Cursor hooks left to feed, there is nothing to translate into.
 */
function transformToClaude(input) {
  return input;
}

/**
 * No-op. Returns false so the four delegating hooks skip cleanly instead of attempting
 * a forward that cannot succeed.
 *
 * The profile names the callers pass ('minimal', 'standard', 'strict') correspond to
 * `hookProfile` in .claude/settings.json. Honouring them would mean first restoring the
 * hooks they gate, which is a design decision, not a repair.
 */
function hookEnabled(/* key, profiles */) {
  return false;
}

module.exports = { readStdin, runExistingHook, transformToClaude, hookEnabled };
