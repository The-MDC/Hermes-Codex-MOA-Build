#!/usr/bin/env node
/**
 * post-edit-check.js — PostToolUse on Write|Edit.
 *
 * WHY THIS EXISTS
 *     `.claude/hooks/hooks.json` asked for an `afterFileEdit` hook described as
 *     "Auto-format, TypeScript check, console.log warning", pointing at
 *     `.cursor/hooks/after-file-edit.js`. There is no `.cursor/` directory in this
 *     repository and there never has been, and `afterFileEdit` is a Cursor event
 *     name that Claude Code does not emit. The behaviour was specified twice —
 *     once there, once in `.claude/rules/typescript-hooks.md` — and implemented
 *     nowhere. This is the implementation, against events Claude Code really fires.
 *
 * THE THREE CHECKS, IN ORDER OF RELIABILITY
 *     1. console.log scan   — pure JS, zero dependencies, always runs.
 *     2. Prettier           — only if a LOCAL prettier binary exists.
 *     3. tsc --noEmit       — only if a LOCAL tsc and a tsconfig.json both exist.
 *
 *     2 and 3 are deliberately gated on a local binary rather than `npx`. `npx`
 *     reaches the network, the agent container gets 403 from the npm registry, and
 *     a hook that hangs on a failed fetch after every edit is worse than no hook.
 *     Absent tooling is reported once, not treated as a failure.
 *
 * IT NEVER BLOCKS
 *     A formatting opinion is not worth killing a turn over. Everything here is
 *     advisory: findings come back as `systemMessage`, and the exit code is always
 *     0. The one hook in this directory that can block is pre-bash-guard.js.
 */

'use strict';

const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const CODE_EXT = new Set(['.js', '.jsx', '.ts', '.tsx', '.mjs', '.cjs']);
const TS_EXT = new Set(['.ts', '.tsx']);

/** Read all of stdin. Returns '' if nothing arrives, rather than hanging forever. */
function readStdin() {
  try {
    return fs.readFileSync(0, 'utf8');
  } catch {
    return '';
  }
}

/** Walk up from `from` looking for `rel`. Returns the absolute path, or null. */
function findUp(rel, from) {
  let dir = from;
  for (let i = 0; i < 12; i++) {
    const candidate = path.join(dir, rel);
    if (fs.existsSync(candidate)) return candidate;
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return null;
}

function emit(message) {
  if (!message) return;
  process.stdout.write(JSON.stringify({ systemMessage: message }) + '\n');
}

function main() {
  const raw = readStdin();
  if (!raw.trim()) return;

  let payload;
  try {
    payload = JSON.parse(raw);
  } catch {
    return; // Malformed input is the harness's problem, not ours. Stay silent.
  }

  const file =
    payload?.tool_response?.filePath ||
    payload?.tool_input?.file_path ||
    payload?.tool_input?.filePath;
  if (!file) return;

  const ext = path.extname(file);
  if (!CODE_EXT.has(ext)) return; // Not code we have an opinion about.
  if (!fs.existsSync(file)) return; // Deleted or moved between edit and hook.

  const dir = path.dirname(path.resolve(file));
  const notes = [];

  // ---- 1. console.log scan. No dependencies, so this is the part that always works.
  try {
    const lines = fs.readFileSync(file, 'utf8').split('\n');
    const hits = [];
    lines.forEach((line, i) => {
      // Skip lines that are obviously commented out.
      const trimmed = line.trim();
      if (trimmed.startsWith('//') || trimmed.startsWith('*')) return;
      if (/\bconsole\.log\s*\(/.test(line)) hits.push(i + 1);
    });
    if (hits.length) {
      const where = hits.slice(0, 5).join(', ');
      const more = hits.length > 5 ? ` (+${hits.length - 5} more)` : '';
      notes.push(
        `console.log in ${path.basename(file)} at line ${where}${more} — ` +
          `remove before commit, or switch to the project logger.`
      );
    }
  } catch {
    /* unreadable file: nothing useful to say */
  }

  // ---- 2. Prettier, only if a local binary exists.
  const prettier = findUp(path.join('node_modules', '.bin', 'prettier'), dir);
  if (prettier) {
    try {
      execFileSync(prettier, ['--write', '--ignore-unknown', file], {
        stdio: 'ignore',
        timeout: 15000,
      });
    } catch {
      notes.push(`prettier could not format ${path.basename(file)} — likely a syntax error.`);
    }
  }

  // ---- 3. tsc --noEmit, only for TypeScript and only with local tooling.
  if (TS_EXT.has(ext)) {
    const tsc = findUp(path.join('node_modules', '.bin', 'tsc'), dir);
    const tsconfig = findUp('tsconfig.json', dir);
    if (tsc && tsconfig) {
      try {
        execFileSync(tsc, ['--noEmit', '-p', tsconfig], {
          stdio: 'pipe',
          timeout: 120000,
        });
      } catch (err) {
        // tsc reports project-wide errors, which may predate this edit. Surface
        // only the lines naming the file that was just written.
        const out = String(err.stdout || '') + String(err.stderr || '');
        const base = path.basename(file);
        const mine = out
          .split('\n')
          .filter((l) => l.includes(base))
          .slice(0, 4);
        if (mine.length) {
          notes.push(`tsc on ${base}:\n  ` + mine.join('\n  '));
        }
      }
    }
  }

  emit(notes.join('\n'));
}

try {
  main();
} catch {
  /* A hook must never take the session down with it. */
}
process.exit(0);
