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
 * ONE SOURCE, TWO SURFACES, DRIVEN BY capabilities.yaml
 *     The same knowledge has to reach two lookups. Hermes resolves a skill by its
 *     DIRECTORY name under hermes-skills/<category>/<name>/SKILL.md; Claude Code resolves
 *     it by the frontmatter `name` in a flat .claude/skills/<category>/<name>.md. Keeping
 *     two hand-maintained copies is what let the trees diverge to 78 skills against 31
 *     with nine names in common, and what left `local-desktop` and `hermes-orchestration`
 *     -- the two skills written so the local tier could take the handoff -- visible to
 *     Hermes and invisible to the model instructing it.
 *
 *     So this script no longer decides where a skill goes. capabilities.yaml does, through
 *     each entry's `surfaces`, and check-capabilities.py fails the build when disk stops
 *     matching that declaration. Flipping a skill onto the Claude surface is a one-line
 *     registry edit plus a re-run; no code change.
 *
 *     Hand-written skills under operations/ have no upstream, so their in-repo Hermes copy
 *     IS the canonical source: it is read and projected onto the Claude surface, never
 *     rewritten from itself.
 *
 * KEPT UP TO DATE
 *     Every ported skill used to be stamped `version: 1.0.0` and nothing recorded which
 *     upstream revision it came from, so "is this current?" had no answer. The port now
 *     writes hermes-skills/.port-lock.json -- upstream path, SHA-256 of the upstream
 *     SKILL.md, port date -- and `--check` re-hashes each source to name what has drifted.
 *     Drift is reported, never failed on: the sources live outside this repo and are
 *     absent on most machines, CI runners included.
 *
 * usage:
 *   node scripts/port-skills-to-hermes.js [--dry-run] [--out DIR] [--claude-out DIR]
 *   node scripts/port-skills-to-hermes.js --check     # drift report, writes nothing
 *   node scripts/port-skills-to-hermes.js --registry FILE   # drive it from another registry
 *
 * Output defaults to hermes-skills/ and .claude/skills/ in the repo root:
 *   hermes-skills/<category>/<name>/SKILL.md  (+ any supporting files copied verbatim)
 *   .claude/skills/<category>/<name>.md       (only where `surfaces` says claude)
 *
 * Install on a machine that has Hermes:
 *   cp -r hermes-skills/* ~/.hermes/skills/
 */

'use strict';

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const DRY_RUN = process.argv.includes('--dry-run');
const CHECK = process.argv.includes('--check');

function flagDir(flag, fallback) {
  const i = process.argv.indexOf(flag);
  return i !== -1 && process.argv[i + 1] ? path.resolve(process.argv[i + 1]) : fallback;
}

const OUT_DIR = flagDir('--out', path.join(REPO_ROOT, 'hermes-skills'));
const CLAUDE_OUT_DIR = flagDir('--claude-out', path.join(REPO_ROOT, '.claude', 'skills'));

// --registry exists so the assertions below can be driven against a deliberately broken
// registry. A check that has never been seen to fail is not yet a check, and two have
// shipped in this repo already.
const REGISTRY_PATH = (() => {
  const i = process.argv.indexOf('--registry');
  return i !== -1 && process.argv[i + 1]
    ? path.resolve(process.argv[i + 1])
    : path.join(REPO_ROOT, 'capabilities.yaml');
})();

// The lock lives beside the Hermes output, so a scratch --out run locks to scratch and
// cannot overwrite the real record while someone is testing.
const LOCK_PATH = path.join(OUT_DIR, '.port-lock.json');

// Stamped into every generated Claude-side file. Only a file carrying it is ever
// overwritten; see claudeTargetIsOurs.
const GENERATED_BY = 'scripts/port-skills-to-hermes.js';

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
};

/**
 * Product references scrubbed out of ported content.
 *
 * WHY THIS IS NEEDED AT ALL
 *     This build is the Hermes + Codex + Nemotron orchestration and carries no product
 *     content. But four of the upstream sources were written against a specific product
 *     and mention it in their EXAMPLES: an MCP server name, a SIWE login string, a stack
 *     summary line, and an example contract's fee constants. Deleting the generated files
 *     does not fix that -- the next port writes them straight back. The scrub has to live
 *     in the generator or it is not a fix.
 *
 * WHY SCRUB RATHER THAN DROP THE SKILLS
 *     Every one of those references is example content, not the substance. Dropping
 *     solidity-foundry, mcp-server-patterns, security-review and backend-patterns to
 *     remove four sample identifiers would cost four real capabilities to solve a naming
 *     problem. The numbers are replaced with DIFFERENT values on purpose: substituting a
 *     synonym would leave the figure itself in the tree, which is the thing being removed.
 *
 * ORDER MATTERS. Specific patterns run before the generic catch-alls, or the catch-alls
 * mangle the cases that have a better replacement.
 *
 * assertScrubbed() below re-reads everything this script writes and fails the run if any
 * term survives, so a new upstream mention cannot arrive unnoticed.
 */
const SCRUB = [
  // -- specific: an example gets a better replacement than the catch-all would give
  [/Smart contract development for MAD Gambit on Base L2/g, 'Smart contract development on Base L2'],
  [/Architecture patterns for the MAD Gambit Hono \+ Supabase stack/g, 'Architecture patterns for a Hono + Supabase stack'],
  [/PLATFORM_FEE_BPS = 188;\s*\/\/ 1\.88%/g, 'PLATFORM_FEE_BPS = 250; // 2.5%'],
  [/COMMUNITY_SHARE_BPS = 2880;\s*\/\/ 28\.8% \(display 28%\)/g, 'COMMUNITY_SHARE_BPS = 1000; // 10%'],
  [/MAD Gambit prediction market/g, 'prediction market'],
  [/MAD Gambit login/g, 'Example App login'],
  [/mad-gambit-mcp/g, 'example-mcp'],
  // -- generic catch-alls, last
  [/MADHATs Gambit/g, 'the platform'],
  [/MAD Gambit/g, 'the platform'],
  [/MADHATs/g, 'the project'],
  [/mad-gambit/g, 'example'],
  [/madhats/g, 'example'],
];

/** Terms that must not survive into the output tree. Checked after every write. */
const FORBIDDEN = /madhat|mad[ -]gambit|1\.88%|28\.8%/i;

function scrub(text) {
  let out = text;
  for (const [pattern, replacement] of SCRUB) out = out.replace(pattern, replacement);
  return out;
}

/**
 * Re-read the output tree and fail if any forbidden term survived.
 *
 * A scrub table is only as good as its coverage, and coverage silently decays: upstream
 * ships a new example next month, SCRUB does not match it, and the reference is back in
 * the tree with nobody looking. This reads what was actually written rather than trusting
 * that the substitution fired, which is the difference between a check and a hope.
 *
 * Binary support files (fonts, OOXML schemas) are skipped by extension -- they cannot
 * carry prose, and decoding 5.6 MB of .ttf as UTF-8 to prove it would be theatre.
 */
const TEXTUAL = /\.(md|txt|json|ya?ml|js|ts|tsx|py|sh|sol|toml|csv)$/i;

function assertScrubbed(root) {
  const hits = [];
  const walk = (dir) => {
    let entries = [];
    try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
    for (const e of entries) {
      const full = path.join(dir, e.name);
      if (e.isDirectory()) { walk(full); continue; }
      if (!TEXTUAL.test(e.name)) continue;
      let text;
      try { text = fs.readFileSync(full, 'utf8'); } catch { continue; }
      text.split('\n').forEach((line, i) => {
        if (FORBIDDEN.test(line)) {
          hits.push(`${path.relative(REPO_ROOT, full)}:${i + 1}: ${line.trim().slice(0, 100)}`);
        }
      });
    }
  };
  walk(root);
  return hits;
}

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
      author: `${pretty} (${external.repo}) — ported for Hermes Agent`,
      license: external.license,
    };
  }
  return {
    author: 'Anthropic — ported for Hermes Agent',
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

// ---------------------------------------------------------------- the registry
/**
 * Read the `skills:` list out of capabilities.yaml.
 *
 * WHY A HAND-ROLLED READER
 *     This repo has no package.json and no node_modules on purpose — the tree gets
 *     copied onto a Windows box by a runbook, and taking a YAML dependency would add
 *     an `npm install` to that bring-up. The registry is machine-emitted by
 *     check-capabilities.py with a stable shape, so the subset that needs parsing is
 *     small: a block sequence of mappings, scalars and one-level lists.
 *
 * STRICT ON PURPOSE
 *     Every line inside the block must classify as one of five known shapes, and an
 *     unclassifiable line THROWS rather than being skipped. A lenient parser that
 *     silently drops an entry is the same failure this whole registry exists to
 *     prevent — it would report a skill as Hermes-only because it never saw the
 *     `claude` line. The entry count is cross-checked against a plain `- name:` grep
 *     of the same file for the same reason.
 */
function readRegistrySkills() {
  if (!fs.existsSync(REGISTRY_PATH)) {
    throw new Error(`capabilities.yaml not found at ${REGISTRY_PATH} — it drives which surfaces get written`);
  }
  const text = fs.readFileSync(REGISTRY_PATH, 'utf8');
  const lines = text.split('\n');
  const out = new Map();

  let inSkills = false;
  let entry = null;
  let listKey = null; // a block sequence is open under this key
  let lastKey = null; // last scalar key, so a wrapped value can be recognised

  const commit = () => {
    if (!entry) return;
    for (const required of ['name', 'surfaces', 'source', 'category']) {
      if (entry[required] === undefined) {
        throw new Error(`capabilities.yaml: skill entry ${entry.name || '(unnamed)'} has no ${required}`);
      }
    }
    if (!Array.isArray(entry.surfaces) || entry.surfaces.length === 0) {
      throw new Error(`capabilities.yaml: ${entry.name} declares no surfaces`);
    }
    out.set(entry.name, entry);
    entry = null;
  };

  for (const line of lines) {
    if (!inSkills) {
      if (/^skills:\s*$/.test(line)) inSkills = true;
      continue;
    }
    if (line.trim() === '' || /^\s*#/.test(line)) continue;

    // A column-0 KEY ends the skills block (mcp_servers:, datasets:, ...). It must not
    // match `- name:`, which is also at column 0 and starts every entry.
    if (/^[A-Za-z_]/.test(line)) { commit(); break; }

    let m;
    if ((m = line.match(/^- ([A-Za-z_][\w-]*): (.*)$/))) {          // new entry
      commit();
      entry = {}; listKey = null; lastKey = m[1];
      entry[m[1]] = unquoteScalar(m[2]);
      continue;
    }
    if ((m = line.match(/^ {2}- (.*)$/))) {                          // list item
      if (!entry || !listKey) {
        throw new Error(`capabilities.yaml: list item with no open key: ${line}`);
      }
      entry[listKey].push(unquoteScalar(m[1]));
      continue;
    }
    if ((m = line.match(/^ {2}([A-Za-z_][\w-]*):\s*$/))) {           // key opening a list
      if (!entry) throw new Error(`capabilities.yaml: key outside an entry: ${line}`);
      listKey = m[1]; lastKey = m[1];
      entry[listKey] = [];
      continue;
    }
    if ((m = line.match(/^ {2}([A-Za-z_][\w-]*): (.*)$/))) {         // scalar key
      if (!entry) throw new Error(`capabilities.yaml: key outside an entry: ${line}`);
      listKey = null; lastKey = m[1];
      entry[m[1]] = unquoteScalar(m[2]);
      continue;
    }
    if (/^ {4,}\S/.test(line) && lastKey) continue;                  // wrapped scalar

    throw new Error(`capabilities.yaml: cannot parse line: ${line}`);
  }
  commit();

  // Cross-check: a parser that silently lost entries is the failure mode that matters.
  // Count `- name:` lines in the skills block ONLY -- mcp_servers entries share the shape.
  let declaredCount = 0;
  let counting = false;
  for (const l of lines) {
    if (/^skills:\s*$/.test(l)) { counting = true; continue; }
    if (!counting) continue;
    if (/^[A-Za-z_]/.test(l)) break;
    if (/^- name: /.test(l)) declaredCount += 1;
  }
  if (out.size !== declaredCount) {
    throw new Error(`capabilities.yaml: parsed ${out.size} skills but the file declares ${declaredCount}`);
  }
  return out;
}

function unquoteScalar(s) {
  const t = String(s).trim();
  if (/^'.*'$/.test(t)) return t.slice(1, -1).replace(/''/g, "'");
  if (/^".*"$/.test(t)) return t.slice(1, -1).replace(/\\"/g, '"');
  return t;
}

// --------------------------------------------------------------- surface emit
function hermesSkillText(name, spec, description, author, license, body) {
  const related = Object.entries(INCLUDE)
    .filter(([n, s]) => n !== name && s.category === spec.category)
    .map(([n]) => n);

  return [
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
}

/**
 * The Claude surface is a FLAT file — .claude/skills/<category>/<name>.md — and Claude
 * Code resolves a skill by its frontmatter `name`, not by its path. Hermes resolves by
 * DIRECTORY name. Same knowledge, two lookups, so the projection keeps `name` identical
 * and drops the Hermes-only keys rather than carrying a `metadata.hermes` block onto a
 * surface that does not read it.
 */
function claudeSkillText(name, description, canonicalRel, body) {
  return [
    '---',
    `name: ${name}`,
    `description: ${yamlQuote(description)}`,
    `generated_by: ${GENERATED_BY}`,
    `canonical_source: ${canonicalRel}`,
    '---',
    '',
    body.trimStart(),
  ].join('\n');
}

/**
 * Index the Claude surface by FRONTMATTER name, which is how Claude Code itself resolves
 * a skill -- not by path.
 *
 * FOUND BY A DRY RUN, AND IT WOULD HAVE BEEN SILENT. The first version derived the Claude
 * target from the skill's HERMES category, and the two trees do not agree: all nine
 * dual-surface skills sit under .claude/skills/ecc/ while Hermes files them under
 * software-development, research, finance and security. Writing to the Hermes category
 * would have created a SECOND file with the same frontmatter `name` -- and because
 * check-capabilities.py keys the Claude surface by name, one copy would simply have
 * shadowed the other in the index with nothing reporting it.
 *
 * So an existing skill is written where it already lives. Only a genuinely new one falls
 * back to <category>/<name>.md.
 */
function indexClaudeSurface() {
  const index = new Map();
  const walk = (dir) => {
    let entries = [];
    try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
    for (const e of entries) {
      const full = path.join(dir, e.name);
      if (e.isDirectory()) { walk(full); continue; }
      if (!e.name.endsWith('.md')) continue;
      const { front } = splitFrontmatter(fs.readFileSync(full, 'utf8'));
      const name = unquote(front.name) || e.name.slice(0, -3);
      if (!index.has(name)) index.set(name, full);
    }
  };
  walk(CLAUDE_OUT_DIR);
  return index;
}

/**
 * Refuse to overwrite a Claude-side file this script did not write.
 *
 * 76 of the 78 files under .claude/skills/ are claude-native and have no upstream here.
 * Writing one would destroy it with no copy anywhere, so a generated file is stamped
 * and only a stamped file is ever replaced.
 */
function claudeTargetIsOurs(file) {
  if (!fs.existsSync(file)) return true;
  const { front } = splitFrontmatter(fs.readFileSync(file, 'utf8'));
  return unquote(front.generated_by) === GENERATED_BY;
}

function sha256File(file) {
  return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
}

function today() {
  return new Date().toISOString().slice(0, 10);
}

// ------------------------------------------------------------------- lockfile
const LOCK_NOTE =
  'Written by scripts/port-skills-to-hermes.js. `sha256` is of the UPSTREAM SKILL.md at ' +
  'port time, which is what `--check` re-hashes to report drift. Entries are MERGED, not ' +
  'replaced: source roots differ per machine, and a port run on a box that lacks one source ' +
  'must not erase that skill\'s record. Only the source ROOT is recorded, not the resolved ' +
  'path: under .claude/skills/synced the path carries an opaque per-install sync id, which ' +
  'would churn this file on every machine and put an account identifier in version control. ' +
  '--check re-resolves by name and prints the real path it found.';

function readLock() {
  if (!fs.existsSync(LOCK_PATH)) return null;
  const raw = fs.readFileSync(LOCK_PATH, 'utf8');
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (err) {
    throw new Error(`${path.relative(REPO_ROOT, LOCK_PATH)} is not valid JSON: ${err.message}`);
  }
  if (!parsed || typeof parsed !== 'object' || typeof parsed.skills !== 'object' || parsed.skills === null) {
    throw new Error(`${path.relative(REPO_ROOT, LOCK_PATH)} has no skills object`);
  }
  return parsed;
}

function writeLock(fresh, registry) {
  const prev = readLock();
  const merged = Object.assign({}, (prev && prev.skills) || {}, fresh);

  // Merge is for a source this MACHINE cannot see. It is not for a skill that was
  // REMOVED FROM THE MANIFEST -- carrying one of those forward leaves a record of
  // something the build no longer has, and the lock stops describing the build.
  // The two cases look identical in the lock and are told apart by the manifest.
  const dropped = [];
  for (const name of Object.keys(merged)) {
    if (fresh[name]) continue;
    const declared = registry && registry.get(name);
    const stillManaged = Boolean(INCLUDE[name]) || (declared && declared.source === 'hand-written');
    if (!stillManaged) { delete merged[name]; dropped.push(name); }
  }

  const ordered = {};
  for (const k of Object.keys(merged).sort()) ordered[k] = merged[k];
  const doc = {
    version: 1,
    generated: today(),
    note: LOCK_NOTE,
    skills: ordered,
  };
  fs.mkdirSync(path.dirname(LOCK_PATH), { recursive: true });
  fs.writeFileSync(LOCK_PATH, JSON.stringify(doc, null, 2) + '\n');
  return {
    carried: Object.keys(merged).length - Object.keys(fresh).length,
    total: Object.keys(merged).length,
    dropped,
  };
}

/**
 * --check: report which ported skills have drifted from their upstream, and write nothing.
 *
 * Drift is a REPORT, not a gate. The sources live outside this repo and are absent on most
 * machines — security-audit needs a Cloudflare clone that no CI runner has — so failing on
 * drift would fail the build for a condition the build cannot see or fix.
 */
function runCheck() {
  const lock = readLock();
  if (!lock) {
    console.log('port-skills-to-hermes --check');
    console.log(`  no lockfile at ${path.relative(REPO_ROOT, LOCK_PATH)} — run the port once to create it`);
    return 0;
  }

  const registry = readRegistrySkills();
  const current = [];
  const drifted = [];
  const absent = [];
  const handwritten = [];
  const stale = [];
  const unlocked = [];
  const resurfaced = [];

  for (const [name, rec] of Object.entries(lock.skills)) {
    // The registry can be edited without re-running the port, which leaves a skill
    // declared on a surface that was never written to. That is drift too, and unlike
    // upstream drift this repo CAN see it.
    const declared = registry.get(name);
    if (declared && JSON.stringify((rec.surfaces || []).slice().sort()) !==
                    JSON.stringify(declared.surfaces.slice().sort())) {
      resurfaced.push({ name, locked: rec.surfaces || [], declared: declared.surfaces });
    }

    if (rec.source === 'hand-written') {
      const canonical = path.join(REPO_ROOT, rec.upstream || '');
      handwritten.push({ name, present: rec.upstream ? fs.existsSync(canonical) : false });
      continue;
    }
    if (!INCLUDE[name]) { stale.push(name); continue; }
    const src = findSource(name);
    if (!src) { absent.push(name); continue; }
    const now = sha256File(path.join(src, 'SKILL.md'));
    if (now === rec.sha256) current.push(name);
    else drifted.push({ name, was: rec.sha256, now, src });
  }

  for (const name of Object.keys(INCLUDE)) {
    if (!lock.skills[name]) unlocked.push(name);
  }

  console.log('port-skills-to-hermes --check  (reports drift; writes nothing)');
  console.log(`  lockfile: ${path.relative(REPO_ROOT, LOCK_PATH)} — ${Object.keys(lock.skills).length} entries, written ${lock.generated}`);
  console.log('');
  console.log(`  current       ${current.length}  upstream SKILL.md unchanged since it was ported`);
  console.log(`  DRIFTED       ${drifted.length}  upstream changed — re-run the port to pick it up`);
  console.log(`  absent        ${absent.length}  source root not on this machine, nothing to compare`);
  console.log(`  hand-written  ${handwritten.length}  no upstream; drift does not apply`);
  if (unlocked.length) console.log(`  unlocked      ${unlocked.length}  in the manifest but never ported here`);
  if (stale.length) console.log(`  stale         ${stale.length}  locked but no longer in the manifest`);
  if (resurfaced.length) console.log(`  RESURFACED    ${resurfaced.length}  capabilities.yaml changed surfaces since the port`);

  if (drifted.length) {
    console.log('');
    console.log('  drifted:');
    for (const d of drifted) {
      console.log(`    ${d.name}`);
      console.log(`      was ${d.was.slice(0, 16)}…  now ${d.now.slice(0, 16)}…`);
      console.log(`      ${d.src}`);
    }
    console.log('');
    console.log('  Re-port with: node scripts/port-skills-to-hermes.js');
  }
  if (resurfaced.length) {
    console.log('');
    console.log('  resurfaced — re-run the port so disk matches the declaration:');
    for (const r of resurfaced) {
      console.log(`    ${r.name}: locked [${r.locked.join(', ')}] -> declared [${r.declared.join(', ')}]`);
    }
  }
  if (absent.length) {
    console.log('');
    console.log(`  absent: ${absent.join(', ')}`);
  }
  if (unlocked.length) {
    console.log('');
    console.log(`  unlocked: ${unlocked.join(', ')}`);
  }
  for (const h of handwritten) {
    if (!h.present) console.log(`  WARN  hand-written ${h.name}: canonical file is gone from the repo`);
  }

  // Exit 0 even with drift, deliberately. See this function's header.
  return 0;
}

// ----------------------------------------------------------------------- port
function main() {
  if (CHECK) {
    // exitCode rather than exit(): process.exit() can truncate a piped stdout, and this
    // report is the whole point of the mode.
    process.exitCode = runCheck();
    return;
  }

  // Read the lock FIRST. It throws on a corrupt file, and writeLock() runs last -- so
  // validating it there would abort the run *after* every skill had been rewritten,
  // leaving a half-done tree and an error that names the wrong step.
  readLock();

  const registry = readRegistrySkills();
  const claudeIndex = indexClaudeSurface();
  const ported = [];
  const missing = [];
  const claudeWritten = [];
  const refused = [];
  const undeclared = [];
  const lockEntries = {};

  const surfacesFor = (name, fallback) => {
    const entry = registry.get(name);
    if (entry) return entry.surfaces;
    undeclared.push(name);
    return fallback;
  };

  // --- ported skills: upstream is canonical -------------------------------
  for (const [name, spec] of Object.entries(INCLUDE)) {
    const src = findSource(name);
    if (!src) { missing.push(name); continue; }

    const srcFile = path.join(src, 'SKILL.md');
    const text = fs.readFileSync(srcFile, 'utf8');
    const { front, body: rawBody } = splitFrontmatter(text);
    // Scrub BOTH, not just the body: one source names the product in its summary line.
    const body = scrub(rawBody);
    const description = scrub(unquote(front.description) || `${name} skill ported from Claude.`);
    const { author, license } = attributionFor(src, front);
    const surfaces = surfacesFor(name, ['hermes']);

    const hermesRel = path.join(path.relative(REPO_ROOT, OUT_DIR) || OUT_DIR, spec.category, name, 'SKILL.md');

    if (surfaces.includes('hermes')) {
      const destDir = path.join(OUT_DIR, spec.category, name);
      if (!DRY_RUN) {
        const out = hermesSkillText(name, spec, description, author, license, body);
        fs.mkdirSync(destDir, { recursive: true });
        fs.writeFileSync(path.join(destDir, 'SKILL.md'), out.endsWith('\n') ? out : out + '\n');
        copyDirExcept(src, destDir, 'SKILL.md');
      }
    }

    if (surfaces.includes('claude')) {
      const file = claudeIndex.get(name) || path.join(CLAUDE_OUT_DIR, spec.category, `${name}.md`);
      if (!claudeTargetIsOurs(file)) {
        refused.push({ name, file: path.relative(REPO_ROOT, file) });
      } else if (!DRY_RUN) {
        const out = claudeSkillText(name, description, hermesRel, body);
        fs.mkdirSync(path.dirname(file), { recursive: true });
        fs.writeFileSync(file, out.endsWith('\n') ? out : out + '\n');
        claudeWritten.push(name);
      } else {
        claudeWritten.push(name);
      }
    }

    lockEntries[name] = {
      source: 'ported',
      upstream_root: SOURCE_ROOTS.find((r) => src.startsWith(r)) || path.dirname(src),
      sha256: sha256File(srcFile),
      ported: today(),
      surfaces,
    };
    ported.push({ name, category: spec.category, src, surfaces });
  }

  // --- hand-written skills: the in-repo Hermes copy is canonical -----------
  //
  // These have no upstream. The port must never rewrite them — that would replace the
  // only copy with a regeneration of itself — so the Hermes side is read, not written,
  // and only the Claude projection is generated.
  for (const [name, entry] of registry) {
    if (entry.source !== 'hand-written') continue;
    const canonical = path.join(REPO_ROOT, 'hermes-skills', entry.category, name, 'SKILL.md');
    if (!fs.existsSync(canonical)) continue;

    const canonicalRel = path.relative(REPO_ROOT, canonical);
    lockEntries[name] = {
      source: 'hand-written',
      upstream: canonicalRel,
      sha256: sha256File(canonical),
      ported: today(),
      surfaces: entry.surfaces,
    };

    if (!entry.surfaces.includes('claude')) continue;

    const { front, body } = splitFrontmatter(fs.readFileSync(canonical, 'utf8'));
    const description = unquote(front.description) || `${name} — see ${canonicalRel}`;
    const file = claudeIndex.get(name) || path.join(CLAUDE_OUT_DIR, entry.category, `${name}.md`);
    if (!claudeTargetIsOurs(file)) {
      refused.push({ name, file: path.relative(REPO_ROOT, file) });
      continue;
    }
    if (!DRY_RUN) {
      const out = claudeSkillText(name, description, canonicalRel, body);
      fs.mkdirSync(path.dirname(file), { recursive: true });
      fs.writeFileSync(file, out.endsWith('\n') ? out : out + '\n');
    }
    claudeWritten.push(name);
  }

  let lockSummary = null;
  if (!DRY_RUN) lockSummary = writeLock(lockEntries, registry);

  // Verify the scrub actually landed, rather than trusting that it fired.
  const survived = DRY_RUN ? [] : assertScrubbed(OUT_DIR);

  // ---------------------------------------------------------------- report
  const byCategory = {};
  for (const p of ported) (byCategory[p.category] ||= []).push(p.name);

  console.log(`port-skills-to-hermes${DRY_RUN ? ' (dry run)' : ''}`);
  console.log(`  hermes out: ${path.relative(REPO_ROOT, OUT_DIR) || OUT_DIR}`);
  console.log(`  claude out: ${path.relative(REPO_ROOT, CLAUDE_OUT_DIR) || CLAUDE_OUT_DIR}`);
  console.log(`  surfaces driven by capabilities.yaml (${registry.size} declared)`);
  console.log(`  ported: ${ported.length} of ${Object.keys(INCLUDE).length} curated`);
  console.log(`  claude copies written: ${claudeWritten.length}${claudeWritten.length ? ' — ' + claudeWritten.sort().join(', ') : ''}`);
  if (lockSummary) {
    console.log(`  lockfile: ${path.relative(REPO_ROOT, LOCK_PATH)} — ${lockSummary.total} entries` +
                (lockSummary.carried ? ` (${lockSummary.carried} carried over from a previous machine)` : '') +
                (lockSummary.dropped.length ? `, ${lockSummary.dropped.length} dropped: ${lockSummary.dropped.join(', ')}` : ''));
  }
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
  if (undeclared.length) {
    console.log('');
    console.log(`  NOT IN capabilities.yaml (${undeclared.length}) — defaulted to [hermes]. Declare them,`);
    console.log('  or check-capabilities.py will fail the build on the next push:');
    for (const n of undeclared) {
      console.log(`    - name: ${n}`);
      console.log('      surfaces:');
      console.log('      - hermes');
      console.log('      source: ported');
      console.log(`      category: ${INCLUDE[n] ? INCLUDE[n].category : '?'}`);
      console.log('      asymmetry_reason: ');
    }
  }
  if (refused.length) {
    console.log('');
    console.log(`  NOT OVERWRITTEN (${refused.length}) — these Claude-side files were hand-maintained,`);
    console.log('  not generated here, and this script does not own them:');
    for (const r of refused) console.log(`    ${r.name} -> ${r.file}`);
    console.log('');
    console.log('  This is the expected steady state, not an error. 76 of the 78 files under');
    console.log('  .claude/skills/ are claude-native with no upstream in this repo, and replacing');
    console.log('  one would destroy the only copy. To hand a skill over to generation, delete the');
    console.log('  file; the next run writes it stamped with `generated_by:` and adopts it after.');
  }
  console.log('');
  console.log(`  deliberately excluded: ${Object.keys(EXCLUDE).length} (see EXCLUDE in this file for each reason)`);
  if (!DRY_RUN) {
    console.log(`  scrub: ${survived.length === 0 ? 'clean — no product reference survived into the output tree'
                                                  : survived.length + ' SURVIVED'}`);
  }

  if (survived.length) {
    console.error('');
    console.error('port-skills-to-hermes: product references survived the scrub:');
    for (const h of survived) console.error(`  ${h}`);
    console.error('');
    console.error('Upstream almost certainly added a new mention. Add a pattern to SCRUB and re-run.');
    console.error('Do not edit the generated file: the next port writes the reference straight back.');
    process.exitCode = 1;
  }

  // A port that silently produced nothing is worse than one that fails.
  if (ported.length === 0 && claudeWritten.length === 0) {
    console.error('');
    console.error('port-skills-to-hermes: ported nothing. Source roots checked:');
    for (const r of SOURCE_ROOTS) console.error(`  ${r} ${fs.existsSync(r) ? '(exists)' : '(missing)'}`);
    process.exitCode = 1;
  }
}

try {
  main();
} catch (err) {
  console.error(`port-skills-to-hermes: ${err.message}`);
  process.exit(1);
}
