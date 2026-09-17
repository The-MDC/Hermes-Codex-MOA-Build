#!/usr/bin/env node
/**
 * port-skills-to-hermes.js — convert Claude / Cowork / Claude Code skills into Hermes skills.
 *
 * WHY A CONVERTER RATHER THAN HAND-WRITTEN FILES
 *     The two formats are close but not the same, and the difference is entirely in the
 *     frontmatter. A Claude skill declares `name`, `description` and sometimes `license`.
 *     A Hermes skill additionally needs `version`, `author`, `platforms`, and a
 *     `metadata.hermes` block carrying `tags`, `category` and `related_skills` — that
 *     block is what Hermes' skill index reads to decide when a skill is offered. Hand
 *     porting thirty skills means writing that block thirty times and getting it subtly
 *     wrong somewhere; the wrongness is invisible, because a skill with a bad tag list
 *     still loads, it just never triggers.
 *
 *     So the mapping lives here, once, as data. Re-running this after Anthropic ships new
 *     skills re-ports only what is new.
 *
 * WHY A CURATED MANIFEST RATHER THAN "PORT EVERYTHING"
 *     53 of the readable skills are absent from Hermes, but most should stay absent.
 *     Three kinds do not belong:
 *       - Claude-surface skills (chrome-browser, built-in-browser, docs, web-artifacts-
 *         builder, theme-factory, product-self-knowledge). They describe tools that exist
 *         only inside Claude's apps. Ported to Hermes they would instruct the agent to
 *         call tools it does not have.
 *       - Harness-configuration skills (update-config, keybindings-help, session-start-
 *         hook, fewer-permission-prompts). They configure Claude Code itself.
 *       - Anthropic's demo skills (grocery-shopping, meal-delivery, prescription-refill,
 *         return-refund, …). Example content, not capability.
 *     Everything in INCLUDE below was judged to carry knowledge that is useful to an agent
 *     regardless of which harness it runs in.
 *
 * usage:
 *   node scripts/port-skills-to-hermes.js [--dry-run] [--out DIR]
 *
 * Output defaults to hermes-skills/ in the repo root, laid out as Hermes expects:
 *   hermes-skills/<category>/<name>/SKILL.md  (+ any supporting files copied verbatim)
 *
 * Install on a machine that has Hermes:
 *   cp -r hermes-skills/* ~/.hermes/skills/
 */

'use strict';

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const DRY_RUN = process.argv.includes('--dry-run');
const outFlag = process.argv.indexOf('--out');
const OUT_DIR = outFlag !== -1 && process.argv[outFlag + 1]
  ? path.resolve(process.argv[outFlag + 1])
  : path.join(REPO_ROOT, 'hermes-skills');

/**
 * Third-party skill repositories worth pulling in, with the clone that makes them
 * readable. Recorded here so the port is reproducible on another machine rather than
 * depending on whatever happens to be checked out.
 */
const EXTERNAL = [
  {
    repo: 'https://github.com/cloudflare/security-audit-skill',
    license: 'MIT',
    clonePath: '/home/user/cloudflare/security-audit-skill',
    skillsSubdir: 'skills',
    note: 'Seeded Cloudflare\'s vulnerability discovery harness. Defensive, source-first.',
  },
];

/** Where readable skill sources live in a Claude Code environment. */
const SOURCE_ROOTS = [
  '/root/.claude/skills/synced',
  '/mnt/skills/public',
  '/mnt/skills/examples',
  ...EXTERNAL.map((e) => path.join(e.clonePath, e.skillsSubdir)),
];

/**
 * The curated set: skill name -> { category, tags }.
 * category must be a directory Hermes already understands, so the skill lands beside
 * its peers in the index rather than inventing a new taxonomy.
 */
const INCLUDE = {
  // --- blockchain: Hermes ships only evm / hyperliquid / solana -------------
  'solidity-foundry':     { category: 'blockchain', tags: ['Solidity', 'Foundry', 'Smart-Contracts', 'EVM', 'Testing', 'Gas'] },
  'alchemy-api':          { category: 'blockchain', tags: ['Alchemy', 'RPC', 'NFT', 'Tokens', 'Base', 'Arbitrum', 'Solana'] },
  'agentic-gateway':      { category: 'blockchain', tags: ['x402', 'MPP', 'SIWE', 'SIWS', 'Payments', 'Web3', 'Agent-Auth'] },

  // --- software-development -------------------------------------------------
  'api-design':           { category: 'software-development', tags: ['REST', 'API', 'Pagination', 'Versioning', 'HTTP'] },
  'backend-patterns':     { category: 'software-development', tags: ['Backend', 'Hono', 'Node', 'Caching', 'Repository-Pattern'] },
  'frontend-design':      { category: 'software-development', tags: ['Frontend', 'UI', 'Design', 'CSS', 'Layout'] },
  'mcp-builder':          { category: 'software-development', tags: ['MCP', 'Tools', 'FastMCP', 'Integration'] },
  'mcp-server-patterns':  { category: 'software-development', tags: ['MCP', 'TypeScript', 'Zod', 'stdio', 'HTTP'] },
  'verification-loop':    { category: 'software-development', tags: ['Verification', 'Quality-Gate', 'CI', 'Testing'] },

  // --- security -------------------------------------------------------------
  // Hermes' security domain ships 1password, godmode, oss-forensics, sherlock,
  // unbroker and web-pentest — reconnaissance and tooling, but no systematic
  // source-level code audit. These two fill that.
  'security-review':      { category: 'security', tags: ['Security', 'Audit', 'Web3', 'RLS', 'ERC-4337', 'Review'] },
  'security-audit':       { category: 'security', tags: ['Security', 'Audit', 'Vulnerability', 'Trust-Boundary', 'Coverage-Ledger', 'Defensive'] },

  // --- research -------------------------------------------------------------
  'deep-research':        { category: 'research', tags: ['Research', 'Synthesis', 'Multi-Source', 'Report'] },
  'market-research':      { category: 'research', tags: ['Market', 'Competitive-Analysis', 'TAM', 'Diligence'] },

  // --- finance / fundraising ------------------------------------------------
  'investor-materials':   { category: 'finance', tags: ['Pitch-Deck', 'Investor', 'Financial-Model', 'Fundraising'] },
  'investor-outreach':    { category: 'finance', tags: ['Outreach', 'Cold-Email', 'Investor', 'Fundraising'] },

  // --- creative -------------------------------------------------------------
  'canvas-design':        { category: 'creative', tags: ['Design', 'Poster', 'PDF', 'PNG', 'Visual'] },
  'algorithmic-art':      { category: 'creative', tags: ['Generative-Art', 'p5js', 'Creative-Coding'] },
  'brand-guidelines':     { category: 'creative', tags: ['Brand', 'Typography', 'Color', 'Style'] },

  // --- devops ---------------------------------------------------------------
  'vercel-for-github':    { category: 'devops', tags: ['Vercel', 'GitHub-Actions', 'CI', 'Deploy'] },
  'vercel-git-deploys':   { category: 'devops', tags: ['Vercel', 'Deploy', 'Rollback', 'Preview'] },

  // --- productivity / writing ----------------------------------------------
  'doc-coauthoring':      { category: 'productivity', tags: ['Docs', 'Writing', 'Spec', 'Proposal'] },
  'internal-comms':       { category: 'productivity', tags: ['Comms', 'Status-Report', 'Update', 'Incident'] },
  'learn':                { category: 'productivity', tags: ['Learning', 'Explanation', 'Teaching'] },

  // --- media: Hermes has docx / pdf / xlsx but not pptx ---------------------
  'pptx':                 { category: 'media', tags: ['PowerPoint', 'Slides', 'Deck', 'Presentation'] },
  'file-reading':         { category: 'media', tags: ['Files', 'Parsing', 'Extraction'] },
  'pdf-reading':          { category: 'media', tags: ['PDF', 'OCR', 'Extraction'] },

  // --- meta -----------------------------------------------------------------
  'skill-creator':        { category: 'autonomous-ai-agents', tags: ['Skills', 'Authoring', 'Evals'] },

  // --- MADHATs project context ---------------------------------------------
  'mad-gambit-context':   { category: 'madhats', tags: ['MAD-Gambit', 'MADHATs', 'Canonical-Numbers', 'Context'] },
  'mad-gambit-ai-agents': { category: 'madhats', tags: ['MAD-Gambit', 'AI-Agents', 'Oracles', 'Architecture'] },
};

/** Deliberately not ported, with the reason. Printed in the report so the choice is auditable. */
const EXCLUDE = {
  'chrome-browser': 'Claude-surface: describes the Claude in Chrome extension',
  'built-in-browser': 'Claude-surface: describes the Claude desktop browser pane',
  'docs': 'Claude-surface: claude.ai docs connector',
  'web-artifacts-builder': 'Claude-surface: claude.ai Artifacts',
  'theme-factory': 'Claude-surface: claude.ai Artifacts theming',
  'product-self-knowledge': 'Claude-surface: Claude product knowledge',
  'import-memory': 'Claude-surface: Claude memory import',
  'setup-writing-style': 'Claude-surface: Claude style configuration',
  'every-new-chat': 'User-specific session trigger, not a capability',
  'new-chat-superagent': 'User-specific session trigger, not a capability',
  'morning': 'Depends on Claude connectors for calendar and mail',
  'benepass-reimbursement': 'Anthropic demo skill',
  'call-to-book': 'Anthropic demo skill',
  'cancel-unsubscribe': 'Anthropic demo skill',
  'event-planning': 'Anthropic demo skill',
  'file-expenses': 'Anthropic demo skill',
  'file-form': 'Anthropic demo skill',
  'financial-calculator': 'Anthropic demo skill',
  'grocery-shopping': 'Anthropic demo skill',
  'hire-help': 'Anthropic demo skill',
  'meal-delivery': 'Anthropic demo skill',
  'paint': 'Anthropic demo skill',
  'prescription-refill': 'Anthropic demo skill',
  'return-refund': 'Anthropic demo skill',
  'slack-gif-creator': 'Anthropic demo skill',
};

/** Split YAML-ish frontmatter off a SKILL.md without pulling in a YAML dependency. */
function splitFrontmatter(text) {
  if (!text.startsWith('---')) return { front: {}, body: text };
  const end = text.indexOf('\n---', 3);
  if (end === -1) return { front: {}, body: text };
  const raw = text.slice(3, end).trim();
  const body = text.slice(end + 4).replace(/^\n/, '');

  // Only scalar top-level keys are needed here; nested blocks are regenerated anyway.
  const front = {};
  let key = null;
  for (const line of raw.split('\n')) {
    const m = line.match(/^([a-zA-Z_][\w-]*):\s*(.*)$/);
    if (m) {
      key = m[1];
      front[key] = m[2].trim();
    } else if (key && /^\s+/.test(line)) {
      front[key] += ' ' + line.trim();
    }
  }
  return { front, body };
}

function unquote(s) {
  if (!s) return s;
  return s.replace(/^["']/, '').replace(/["']$/, '');
}

/** Escape a description for a double-quoted YAML scalar. */
function yamlQuote(s) {
  return '"' + String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
}

function findSource(name) {
  for (const root of SOURCE_ROOTS) {
    if (!fs.existsSync(root)) continue;
    // synced/ nests one level deeper under an opaque sync id
    const direct = path.join(root, name);
    if (fs.existsSync(path.join(direct, 'SKILL.md'))) return direct;
    let entries = [];
    try { entries = fs.readdirSync(root, { withFileTypes: true }); } catch { continue; }
    for (const e of entries) {
      if (!e.isDirectory()) continue;
      const nested = path.join(root, e.name, name);
      if (fs.existsSync(path.join(nested, 'SKILL.md'))) return nested;
    }
  }
  return null;
}

/**
 * Attribution follows the source, never the porter.
 *
 * Getting this wrong is not cosmetic: stamping "Anthropic" and "See source" onto
 * Cloudflare's MIT-licensed security-audit skill misattributes someone else's work and
 * drops the licence that permits redistributing it at all. A ported skill carries the
 * upstream author and licence; only the porting note is ours.
 */
function attributionFor(srcPath, front) {
  const external = EXTERNAL.find((e) => srcPath.startsWith(e.clonePath));
  if (external) {
    const owner = external.repo.split('/').slice(-2, -1)[0];
    const pretty = owner.charAt(0).toUpperCase() + owner.slice(1);
    return {
      author: `${pretty} (${external.repo}) — ported for Hermes Agent by MADHATs`,
      license: external.license,
    };
  }
  return {
    author: 'Anthropic — ported for Hermes Agent by MADHATs',
    license: unquote(front.license) || 'Anthropic skill licence; see upstream',
  };
}

function copyDirExcept(src, dest, exceptFile) {
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    if (entry.name === exceptFile) continue;
    const s = path.join(src, entry.name);
    const d = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      fs.mkdirSync(d, { recursive: true });
      copyDirExcept(s, d, null);
    } else {
      fs.copyFileSync(s, d);
    }
  }
}

function main() {
  const ported = [];
  const missing = [];
  let supportFiles = 0;

  for (const [name, spec] of Object.entries(INCLUDE)) {
    const src = findSource(name);
    if (!src) { missing.push(name); continue; }

    const text = fs.readFileSync(path.join(src, 'SKILL.md'), 'utf8');
    const { front, body } = splitFrontmatter(text);
    const description = unquote(front.description) || `${name} skill ported from Claude.`;
    const { author, license } = attributionFor(src, front);

    const related = Object.entries(INCLUDE)
      .filter(([n, s]) => n !== name && s.category === spec.category)
      .map(([n]) => n);

    const out = [
      '---',
      `name: ${name}`,
      `description: ${yamlQuote(description)}`,
      'version: 1.0.0',
      `author: ${yamlQuote(author)}`,
      `license: ${yamlQuote(license)}`,
      'platforms: [linux, macos, windows]',
      'metadata:',
      '  hermes:',
      `    tags: [${spec.tags.join(', ')}]`,
      `    category: ${spec.category}`,
      `    related_skills: [${related.join(', ')}]`,
      '---',
      '',
      body.trimStart(),
    ].join('\n');

    const destDir = path.join(OUT_DIR, spec.category, name);
    if (!DRY_RUN) {
      fs.mkdirSync(destDir, { recursive: true });
      fs.writeFileSync(path.join(destDir, 'SKILL.md'), out.endsWith('\n') ? out : out + '\n');
      const before = supportFiles;
      copyDirExcept(src, destDir, 'SKILL.md');
      supportFiles = before; // counted below from disk instead
    }
    ported.push({ name, category: spec.category, src });
  }

  // Report
  const byCategory = {};
  for (const p of ported) (byCategory[p.category] ||= []).push(p.name);

  console.log(`port-skills-to-hermes${DRY_RUN ? ' (dry run)' : ''}`);
  console.log(`  output: ${path.relative(REPO_ROOT, OUT_DIR) || OUT_DIR}`);
  console.log(`  ported: ${ported.length} of ${Object.keys(INCLUDE).length} curated`);
  console.log('');
  for (const [cat, names] of Object.entries(byCategory).sort()) {
    console.log(`  ${cat} (${names.length})`);
    for (const n of names.sort()) console.log(`    ${n}`);
  }
  if (missing.length) {
    console.log('');
    console.log(`  NOT FOUND on this machine (${missing.length}) — source roots differ per environment:`);
    for (const n of missing) console.log(`    ${n}`);
  }
  console.log('');
  console.log(`  deliberately excluded: ${Object.keys(EXCLUDE).length} (see EXCLUDE in this file for each reason)`);

  // A port that silently produced nothing is worse than one that fails.
  if (ported.length === 0) {
    console.error('');
    console.error('port-skills-to-hermes: ported nothing. Source roots checked:');
    for (const r of SOURCE_ROOTS) console.error(`  ${r} ${fs.existsSync(r) ? '(exists)' : '(missing)'}`);
    process.exit(1);
  }
  process.exit(0);
}

main();
