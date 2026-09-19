#!/usr/bin/env node
/**
 * stop-audit.js — Stop. The end-of-session sweep.
 *
 * WHY THIS EXISTS
 *     `.claude/rules/typescript-hooks.md` specifies, under "Stop Hooks":
 *
 *         console.log audit: Check all modified files for console.log before
 *         session ends
 *
 *     `.claude/hooks/hooks.json` pointed its `stop` event at
 *     `.cursor/hooks/stop.js`, which does not exist, under an event name Claude
 *     Code does not emit. The existing `.claude/hooks/stop.js` is a forwarder to
 *     Cursor hooks (`check-console-log.js`, `cost-tracker.js`) that were never in
 *     this repository — see the note in adapter.js. So the rule was written down
 *     and never enforced. This enforces it.
 *
 * WHY A SECOND console.log CHECK
 *     post-edit-check.js catches one file at the moment it is written, which is
 *     easy to scroll past mid-turn. This one looks at the whole working tree at
 *     the end and reports what actually survived to the end of the session — the
 *     state you are about to commit. Different question, different moment.
 *
 * SCOPE
 *     Only files git reports as modified or untracked, so it stays proportional
 *     to the session rather than the repository. Outside a git work tree it does
 *     nothing at all rather than walking the filesystem.
 */

'use strict';

const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const CODE = /\.(js|jsx|ts|tsx|mjs|cjs)$/;
const MAX_REPORTED = 8;

function git(args) {
  return execFileSync('git', args, { encoding: 'utf8', timeout: 15000 });
}

function main() {
  // Outside a work tree there is nothing to audit.
  try {
    git(['rev-parse', '--is-inside-work-tree']);
  } catch {
    return;
  }

  // Modified-and-tracked plus untracked, deletions excluded.
  let files = [];
  try {
    const tracked = git(['diff', '--name-only', '--diff-filter=ACMR', 'HEAD'])
      .split('\n')
      .filter(Boolean);
    const untracked = git(['ls-files', '--others', '--exclude-standard'])
      .split('\n')
      .filter(Boolean);
    files = [...new Set([...tracked, ...untracked])].filter((f) => CODE.test(f));
  } catch {
    return;
  }
  if (!files.length) return;

  const findings = [];
  for (const f of files) {
    let text;
    try {
      if (!fs.existsSync(f)) continue;
      text = fs.readFileSync(f, 'utf8');
    } catch {
      continue;
    }
    const hits = [];
    text.split('\n').forEach((line, i) => {
      const trimmed = line.trim();
      if (trimmed.startsWith('//') || trimmed.startsWith('*')) return;
      if (/\bconsole\.log\s*\(/.test(line)) hits.push(i + 1);
    });
    if (hits.length) findings.push({ file: f, lines: hits });
  }
  if (!findings.length) return;

  const total = findings.reduce((n, x) => n + x.lines.length, 0);
  const shown = findings.slice(0, MAX_REPORTED);
  const lines = shown.map(
    (x) => `  ${x.file}: line ${x.lines.slice(0, 6).join(', ')}` +
           (x.lines.length > 6 ? ` (+${x.lines.length - 6})` : '')
  );
  const more =
    findings.length > MAX_REPORTED
      ? `\n  …and ${findings.length - MAX_REPORTED} more file(s)`
      : '';

  process.stdout.write(
    JSON.stringify({
      systemMessage:
        `console.log audit: ${total} call(s) across ${findings.length} changed file(s).\n` +
        lines.join('\n') +
        more +
        `\nThese are in the working tree you are about to commit.`,
    }) + '\n'
  );
}

try {
  main();
} catch {
  /* Never let the sweep take the session down on its way out. */
}
process.exit(0);
