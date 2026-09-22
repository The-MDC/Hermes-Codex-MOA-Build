#!/usr/bin/env node
/**
 * codex-mcp/server.js — expose the Codex CLI to Hermes as MCP tools.
 *
 * WHY THIS EXISTS
 *     Codex 0.154.0 removed the `codex mcp-server` entry point on 2026-09-05. Codex
 *     is an MCP *client* now, and `codex app-server` speaks its own JSON-RPC dialect
 *     that is not MCP. So `codex mcp list` reports `Unsupported` and always will --
 *     the interface has to be rebuilt locally or it does not exist.
 *
 *     Hermes can already reach Codex as a subprocess through the bundled `codex`
 *     skill, and that path works. What it lacks is a SCHEMA. The skill hands the
 *     model a shell string to assemble, which means quoting bugs, a `--sandbox` value
 *     invented from memory, and a forgotten `pty=true` that hangs with no output.
 *     This puts typed arguments in front of the same subprocess.
 *
 * WHAT IT IS NOT
 *     It does not make Codex an inference provider. `openai-codex` stays in
 *     `excluded_providers`, because Hermes' own provider and the Codex CLI read
 *     different token files against the SAME ChatGPT 5-hour window, and turning both
 *     on makes that window's spend invisible to itself. This wraps the CLI the skill
 *     already drives; it adds no second consumer.
 *
 * NO DEPENDENCIES, ON PURPOSE
 *     This repo has no package.json and no node_modules, and it gets copied onto a
 *     Windows box by a runbook. Taking @modelcontextprotocol/sdk would add an
 *     `npm install` step to that bring-up and a lockfile to maintain. MCP over stdio
 *     is newline-delimited JSON-RPC 2.0, and the three methods a tool server needs --
 *     initialize, tools/list, tools/call -- are implemented below against stdlib.
 *
 * LAUNCH IT THROUGH scripts/codex-mcp-launch.cmd, NOT AS A BARE `node` COMMAND.
 *     The Hermes supervisor substitutes its own runtime for a `command:` entry. That
 *     is the documented fault behind this build's ModuleNotFoundError, and
 *     config.yaml names `atomicmemory` and `hermes-skills` as still carrying the same
 *     exposure. The launcher pins the interpreter and refuses rather than guessing.
 */

'use strict';

const { spawn } = require('child_process');
const fs = require('fs');

const PROTOCOL_VERSION = '2024-11-05';
const DEFAULT_TIMEOUT_MS = 300000; // 5 min; a Codex run is not a quick call.
const MAX_OUTPUT_CHARS = 200000;   // Bound the reply: a JSONL stream can be large,
                                   // and an unbounded one lands in the model's context.

const TOOLS = [
  {
    name: 'codex_exec',
    description:
      'Run a one-shot Codex task in a directory and return its JSONL event stream. ' +
      'Codex edits files on disk, so scope `workdir` to the project the task is about ' +
      'and confirm the tree is clean first. Returns when the run completes or the ' +
      'timeout expires.',
    inputSchema: {
      type: 'object',
      properties: {
        prompt: {
          type: 'string',
          description: 'What Codex should do. Be specific about the file scope.',
        },
        workdir: {
          type: 'string',
          description: 'Directory to run in. Required — Codex writes files, and a ' +
            'wrong directory is not recoverable from the transcript.',
        },
        sandbox: {
          type: 'string',
          enum: ['read-only', 'workspace-write', 'danger-full-access'],
          default: 'workspace-write',
          description:
            'workspace-write is the default and the right answer almost always. ' +
            'danger-full-access is for the documented gateway case where ' +
            'workspace-write fails with a uid-map permission error — per call, never ' +
            'as a standing default.',
        },
        timeout_ms: {
          type: 'integer',
          description: `Milliseconds before the run is killed. Default ${DEFAULT_TIMEOUT_MS}.`,
        },
      },
      required: ['prompt', 'workdir'],
    },
  },
  {
    name: 'codex_status',
    description:
      'Report whether Codex is installed and holds credentials. Call this before ' +
      'codex_exec when a run fails for a reason that might be auth rather than the task.',
    inputSchema: { type: 'object', properties: {} },
  },
];

/** Run a command, capture output, never throw. Bounded and timed. */
function run(cmd, args, opts = {}) {
  return new Promise((resolve) => {
    // Check the working directory FIRST. spawn() raises ENOENT both when the command
    // is missing and when cwd does not exist, and reporting the second as the first
    // sends the reader to install a tool they already have. An error message names a
    // symptom, not a cause -- this repo has paid for that lesson once already.
    if (opts.cwd && !fs.existsSync(opts.cwd)) {
      resolve({ ok: false, code: null, out: '',
                err: `workdir does not exist: ${opts.cwd}`, badCwd: true });
      return;
    }

    let child;
    try {
      child = spawn(cmd, args, {
        cwd: opts.cwd || process.cwd(),
        env: process.env,
        shell: false, // No shell: arguments are passed as a vector, so a prompt
                      // containing quotes or semicolons cannot become shell syntax.
      });
    } catch (err) {
      resolve({ ok: false, code: null, out: '', err: `could not start ${cmd}: ${err.message}` });
      return;
    }

    let out = '';
    let errOut = '';
    let truncated = false;
    let finished = false;

    const timer = setTimeout(() => {
      if (!finished) {
        errOut += `\n[timed out after ${opts.timeoutMs}ms — process killed]`;
        child.kill('SIGKILL');
      }
    }, opts.timeoutMs || DEFAULT_TIMEOUT_MS);

    const append = (bufName, chunk) => {
      const target = bufName === 'out' ? out : errOut;
      if (target.length >= MAX_OUTPUT_CHARS) { truncated = true; return; }
      const room = MAX_OUTPUT_CHARS - target.length;
      const text = chunk.toString().slice(0, room);
      if (bufName === 'out') out += text; else errOut += text;
      if (chunk.length > room) truncated = true;
    };

    child.stdout.on('data', (c) => append('out', c));
    child.stderr.on('data', (c) => append('err', c));

    child.on('error', (err) => {
      if (finished) return;
      finished = true;
      clearTimeout(timer);
      resolve({ ok: false, code: null, out, err: `${err.message}`, truncated });
    });

    child.on('close', (code) => {
      if (finished) return;
      finished = true;
      clearTimeout(timer);
      resolve({ ok: code === 0, code, out, err: errOut, truncated });
    });
  });
}

async function callTool(name, args) {
  if (name === 'codex_status') {
    const r = await run('codex', ['login', 'status'], { timeoutMs: 20000 });
    if (r.err && /ENOENT|could not start/i.test(r.err)) {
      // isError, not informational: a caller asking for status is deciding whether
      // to proceed, and 'not installed' is a state it must not proceed from.
      return text('codex is NOT on PATH. Install with: npm install -g @openai/codex', true);
    }
    return text(
      r.ok
        ? `codex present and authenticated (exit 0)\n${r.out}`.trim()
        : `codex present but NOT authenticated (exit ${r.code}).\n` +
          'Run `codex login` for ChatGPT-plan auth, or set CODEX_API_KEY for metered use.\n' +
          `${r.out}${r.err}`.trim(),
      !r.ok
    );
  }

  if (name === 'codex_exec') {
    const prompt = (args && args.prompt) || '';
    const workdir = (args && args.workdir) || '';
    const sandbox = (args && args.sandbox) || 'workspace-write';
    const timeoutMs = (args && args.timeout_ms) || DEFAULT_TIMEOUT_MS;

    if (!prompt.trim()) return text('codex_exec: `prompt` is required and was empty.', true);
    if (!workdir.trim()) {
      // Refuse rather than defaulting to cwd. Codex writes files; guessing the
      // directory is the one mistake that is not recoverable from the transcript.
      return text('codex_exec: `workdir` is required. Refusing to guess — Codex edits files.', true);
    }

    const r = await run('codex', ['exec', '--json', '--sandbox', sandbox, prompt],
                        { cwd: workdir, timeoutMs });

    if (r.badCwd) return text(`codex_exec: ${r.err}`, true);
    if (r.err && /ENOENT|could not start/i.test(r.err)) {
      return text('codex is NOT on PATH. Install with: npm install -g @openai/codex', true);
    }

    let body = r.out || '';
    if (r.err) body += `\n--- stderr ---\n${r.err}`;
    if (r.truncated) body += `\n[output truncated at ${MAX_OUTPUT_CHARS} characters]`;

    // Surface the documented sandbox failure as guidance rather than a raw errno:
    // it reads like a Codex bug and is not one.
    if (/uid map|Permission denied|RTM_NEWADDR/i.test(r.err || '')) {
      body += '\n\n[hint] The sandbox could not be set up in this context. ' +
              'Retry this ONE call with sandbox="danger-full-access"; do not make that the default.';
    }

    return text(`exit ${r.code}\n${body}`.trim(), !r.ok);
  }

  return text(`unknown tool: ${name}`, true);
}

function text(s, isError = false) {
  return { content: [{ type: 'text', text: s }], isError };
}

// ------------------------------------------------------------------ transport
function send(msg) {
  process.stdout.write(JSON.stringify(msg) + '\n');
}

function reply(id, result) {
  send({ jsonrpc: '2.0', id, result });
}

function replyError(id, code, message) {
  send({ jsonrpc: '2.0', id, error: { code, message } });
}

async function handle(msg) {
  const { id, method, params } = msg;

  // Notifications carry no id and take no response. Replying to one is a protocol
  // error that some clients treat as fatal.
  const isNotification = id === undefined || id === null;

  if (method === 'initialize') {
    reply(id, {
      protocolVersion: PROTOCOL_VERSION,
      capabilities: { tools: {} },
      serverInfo: { name: 'codex-mcp', version: '1.0.0' },
    });
    return;
  }
  if (method === 'notifications/initialized' || method === 'initialized') return;
  if (method === 'ping') { if (!isNotification) reply(id, {}); return; }

  if (method === 'tools/list') { reply(id, { tools: TOOLS }); return; }

  if (method === 'tools/call') {
    const name = params && params.name;
    const args = (params && params.arguments) || {};
    pending += 1;
    try {
      reply(id, await callTool(name, args));
    } catch (err) {
      reply(id, text(`codex-mcp internal error in ${name}: ${err.message}`, true));
    } finally {
      pending -= 1;
      maybeExit();
    }
    return;
  }

  if (!isNotification) replyError(id, -32601, `method not found: ${method}`);
}

let buffer = '';
let pending = 0;
let stdinClosed = false;

function maybeExit() {
  if (stdinClosed && pending === 0) process.exit(0);
}

process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => {
  buffer += chunk;
  let nl;
  while ((nl = buffer.indexOf('\n')) !== -1) {
    const line = buffer.slice(0, nl).trim();
    buffer = buffer.slice(nl + 1);
    if (!line) continue;
    let msg;
    try {
      msg = JSON.parse(line);
    } catch {
      // A malformed line is not worth killing the server over, and there is no id
      // to attribute an error to.
      continue;
    }
    handle(msg);
  }
});

// BUG FOUND BY TESTING, and it would have shipped silently.
//
// This used to be `process.exit(0)` on 'end'. stdin closes as soon as the client has
// written its last request, but a tools/call is ASYNC -- it is waiting on a spawned
// Codex process. Exiting there killed the server mid-flight and the reply was never
// written. It looked fine in a no-codex test, because a failed spawn rejects almost
// immediately and beat the exit; with a real subprocess the reply is simply lost.
//
// So: only exit once nothing is outstanding.
process.stdin.on('end', () => {
  stdinClosed = true;
  maybeExit();
});
