#!/usr/bin/env node
/**
 * check-canonical-numbers.js — verify the canonical numbers agree everywhere they appear.
 *
 * WHY MEASURE RATHER THAN ASSERT
 *     CLAUDE.md declares the canonical numbers and says they never change without
 *     explicit approval. Nothing enforced that. The numbers are restated in the skills,
 *     in the commands, in the deck copy and in investor material — every restatement is
 *     an independent copy that can drift, and a drifted copy is invisible: "1.8% platform
 *     fee" reads exactly as plausibly as "1.88%". The reader has no way to know which is
 *     canonical, and a wrong fee in a deck is a wrong fee in front of an investor.
 *
 *     So this does not trust any restatement. It reads the declaration out of CLAUDE.md,
 *     then finds every labelled restatement in the repo and compares. CLAUDE.md is the
 *     only source of truth; everything else is measured against it.
 *
 * WHAT COUNTS AS A MATCH
 *     A finding is reported only when a line names one of the tracked concepts AND
 *     carries a number of the right shape that differs from canonical. A line that
 *     mentions "platform fee" with no number is ignored — this looks for contradiction,
 *     not for missing mentions.
 *
 * usage: node scripts/check-canonical-numbers.js [--quiet]
 * exits: 0 = all restatements agree (or abstain), 1 = at least one contradiction
 */

'use strict';

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const QUIET = process.argv.includes('--quiet');

const SKIP_DIRS = new Set(['.git', 'node_modules', 'dist', 'build', '.next', 'OUTPUTS', 'coverage']);
const SCAN_EXT = new Set(['.md', '.mdx', '.js', '.jsx', '.ts', '.tsx', '.json', '.sol', '.yaml', '.yml', '.txt', '.html']);

/**
 * Each concept: how to recognise a line that is talking about it, the canonical value,
 * how to pull a candidate number out of the line, and any value that is explicitly
 * allowed to differ (CLAUDE.md sanctions "display as 28% in presentations").
 */
function canonicalSpec(declared) {
  return [
    {
      key: 'platform fee',
      label: /platform\s+fee|protocol\s+fee|fee\s+is\s|global\s+fee/i,
      canonical: declared.platformFee,
      extract: /(\d+(?:\.\d+)?)\s*%/,
      allowed: [],
    },
    {
      key: 'community profit share',
      label: /community\s+(?:profit\s+)?share|profit\s+share/i,
      canonical: declared.communityShare,
      extract: /(\d+(?:\.\d+)?)\s*%/,
      // CLAUDE.md: "28.8% (display as 28% in presentations)"
      allowed: ['28'],
    },
    {
      key: 'creator revenue share',
      label: /creator\s+(?:market\s+)?(?:revenue\s+)?share/i,
      canonical: declared.creatorShare,
      extract: /(\d+(?:\.\d+)?)\s*%/,
      allowed: [],
    },
    {
      key: 'pre-money valuation',
      label: /pre-?money/i,
      canonical: declared.preMoney,
      extract: /\$\s?(\d+(?:\.\d+)?)\s*M/i,
      allowed: [],
    },
    // Present only once CLAUDE.md declares it; absent before the 2026-08-19 reconciliation.
    ...(declared.shieldRecovery ? [{
      key: 'MAD Shield recovery',
      label: /mad\s*shield\s+(?:standard\s+)?recovery|shield\s+recovery/i,
      canonical: declared.shieldRecovery,
      extract: /(\d+(?:\.\d+)?)\s*%/,
      allowed: [],
    }] : []),
  ];
}

/**
 * How each declared value is read out of CLAUDE.md's Canonical Numbers block.
 *
 * Several patterns per concept, tried in order, because the block has been rewritten
 * before and will be again. The 2026-08-19 data-room reconciliation restated the split
 * as one line — "Fee split *of the 1.88%*: creator **40%** · community **28.8%** ·
 * MAD Shield recovery **28.8%**" — where it had previously been three separate
 * "Community profit share: **28.8%**" bullets. A parser written against only the older
 * shape reports the section as unreadable, which is what CI caught. Keeping both shapes
 * means a future rewording degrades to a loud failure rather than a silent pass.
 */
const DECLARATION_PATTERNS = {
  platformFee: {
    label: 'platform fee',
    required: true,
    patterns: [/Platform fee:\s*\*\*(\d+(?:\.\d+)?)\s*%/i],
  },
  creatorShare: {
    label: 'creator share',
    required: true,
    patterns: [
      /creator\s+\*\*(\d+(?:\.\d+)?)\s*%/i,                          // 2026-08-19 fee-split line
      /Creator market revenue share:\s*\*\*(\d+(?:\.\d+)?)\s*%/i,    // pre-reconciliation
    ],
  },
  communityShare: {
    label: 'community share',
    required: true,
    patterns: [
      /community\s+\*\*(\d+(?:\.\d+)?)\s*%/i,
      /Community profit share:\s*\*\*(\d+(?:\.\d+)?)\s*%/i,
    ],
  },
  shieldRecovery: {
    label: 'MAD Shield recovery',
    required: false, // absent before the 2026-08-19 reconciliation
    patterns: [/MAD Shield recovery\s+\*\*(\d+(?:\.\d+)?)\s*%/i],
  },
  preMoney: {
    label: 'pre-money',
    required: true,
    patterns: [/Pre-money:\s*\*\*\$\s?(\d+(?:\.\d+)?)\s*M/i],
  },
};

/** Read the declared values out of CLAUDE.md. This file is the source of truth. */
function readDeclared() {
  const claudeMd = path.join(REPO_ROOT, 'CLAUDE.md');
  if (!fs.existsSync(claudeMd)) {
    console.error('check-canonical-numbers: CLAUDE.md not found — cannot establish source of truth');
    process.exit(1);
  }
  const text = fs.readFileSync(claudeMd, 'utf8');
  const section = text.split(/##\s*Canonical Numbers/i)[1];
  if (!section) {
    console.error('check-canonical-numbers: no "Canonical Numbers" section in CLAUDE.md');
    process.exit(1);
  }
  const block = section.split(/\n##\s/)[0];

  const out = {};
  for (const [key, spec] of Object.entries(DECLARATION_PATTERNS)) {
    let value = null;
    for (const re of spec.patterns) {
      const m = block.match(re);
      if (m) { value = m[1]; break; }
    }
    if (value === null && spec.required) {
      console.error(`check-canonical-numbers: could not read ${spec.label} from CLAUDE.md`);
      console.error('  The Canonical Numbers block was found but does not match any known shape.');
      console.error('  If the block was reworded, add the new shape to DECLARATION_PATTERNS.');
      process.exit(1);
    }
    out[key] = value;
  }
  return out;
}

function* walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name.startsWith('.') && entry.name !== '.github' && entry.name !== '.claude') continue;
    if (SKIP_DIRS.has(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) yield* walk(full);
    else if (SCAN_EXT.has(path.extname(entry.name))) yield full;
  }
}

function main() {
  const declared = readDeclared();
  const spec = canonicalSpec(declared);
  const findings = [];

  for (const file of walk(REPO_ROOT)) {
    const rel = path.relative(REPO_ROOT, file);
    // CLAUDE.md is the declaration; this script is the checker. Neither is a restatement.
    if (rel === 'CLAUDE.md' || rel === path.join('scripts', 'check-canonical-numbers.js')) continue;

    let lines;
    try { lines = fs.readFileSync(file, 'utf8').split('\n'); } catch { continue; }

    lines.forEach((line, i) => {
      // A single line often states several concepts at once:
      //   "platform fee = 1.88%, community share = 28%, creator share = 40%"
      // Matching a label anywhere in the line and then taking the first number ON the
      // line attributes 1.88% to all three and reports two phantom contradictions.
      // Split into clauses so each concept is scored against the number next to it.
      for (const clause of line.split(/[,;·]|\s—\s/)) {
        // When one clause names more than one concept — "Community profit share: 28.8%
        // of platform fees" — the first-named concept is the subject and the rest are
        // context for it. Scoring the number against the later label inverts the claim.
        let subject = null;
        let subjectAt = Infinity;
        for (const c of spec) {
          const at = clause.search(c.label);
          if (at !== -1 && at < subjectAt) { subject = c; subjectAt = at; }
        }
        if (!subject) continue;

        const m = clause.match(subject.extract);
        if (!m) continue;                              // names it, states no number — abstain
        const found = m[1];
        if (found === subject.canonical) continue;     // agrees
        if (subject.allowed.includes(found)) continue; // explicitly sanctioned variant
        findings.push({
          file: rel,
          line: i + 1,
          concept: subject.key,
          canonical: subject.canonical,
          found,
          text: clause.trim().slice(0, 100),
        });
      }
    });
  }

  if (findings.length === 0) {
    if (!QUIET) {
      console.log('canonical numbers: OK');
      console.log(`  platform fee            ${declared.platformFee}%`);
      console.log(`  community profit share  ${declared.communityShare}%  (28% allowed in presentations)`);
      console.log(`  creator revenue share   ${declared.creatorShare}%`);
      if (declared.shieldRecovery) {
        console.log(`  MAD Shield recovery     ${declared.shieldRecovery}%`);
      }
      console.log(`  pre-money valuation     $${declared.preMoney}M`);
      console.log('  every labelled restatement in the repo agrees with CLAUDE.md');
    }
    process.exit(0);
  }

  console.error(`canonical numbers: ${findings.length} contradiction(s) against CLAUDE.md\n`);
  for (const f of findings) {
    console.error(`  ${f.file}:${f.line}`);
    console.error(`    ${f.concept}: canonical ${f.canonical}, found ${f.found}`);
    console.error(`    > ${f.text}`);
    console.error('');
  }
  console.error('CLAUDE.md is the source of truth. Either fix the restatement, or change');
  console.error('CLAUDE.md deliberately — the canonical numbers need explicit approval.');
  process.exit(1);
}

main();
