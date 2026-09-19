#!/usr/bin/env bash
# madhats-doctor, check whether this machine and this checkout can actually do the work.
#
# WHY THIS EXISTS
#     Answers three questions before you spend an hour finding out the hard way:
#       1. Is the toolchain present, and is the Claude Code harness actually wired?
#       2. Can this environment reach the hosts our tooling needs?
#       3. Do the canonical numbers still agree across every file that states them?
#
#     The failure mode this is built for is the invisible one. A hook that points at a
#     path which does not exist does not crash — it silently never runs, and the session
#     looks normal. A network egress allowlist does not announce itself — installs just
#     fail deep into a build. Both cost a whole session to discover by hand.
#
#     Exits non-zero when something is genuinely broken, so CI and pre-flight can gate.
#
# Portable across macOS and Linux: no /proc, no GNU-only stat/df flags.
#
# usage: scripts/madhats-doctor.sh [--quiet]

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; DIM=$'\033[2m'; RST=$'\033[0m'
[ -t 1 ] || { RED=""; GRN=""; YLW=""; DIM=""; RST=""; }

FAILED=0
WARNED=0
QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

ok()   { [ "$QUIET" = 1 ] || printf '  %sok%s    %s\n'  "$GRN" "$RST" "$*"; }
warn() { printf '  %swarn%s  %s\n' "$YLW" "$RST" "$*"; WARNED=$((WARNED+1)); }
bad()  { printf '  %sFAIL%s  %s\n' "$RED" "$RST" "$*"; FAILED=$((FAILED+1)); }
hdr()  { [ "$QUIET" = 1 ] || printf '\n%s%s%s\n' "$DIM" "$*" "$RST"; }

printf 'MADHATs Gambit, environment check\n'

# ---------------------------------------------------------------- toolchain --
hdr "toolchain"
for tool in git node npm; do
    if command -v "$tool" >/dev/null 2>&1; then
        ok "$tool: $("$tool" --version 2>&1 | head -1)"
    else
        bad "$tool not found (required)"
    fi
done
if command -v python3 >/dev/null 2>&1; then
    ok "python3: $(python3 --version 2>&1)"
else
    warn "python3 not found (some tooling needs it)"
fi

# ------------------------------------------------------------ claude harness --
hdr "claude code harness"

if [ -f .claude/settings.json ]; then
    if node -e 'JSON.parse(require("fs").readFileSync(".claude/settings.json","utf8"))' 2>/dev/null; then
        ok ".claude/settings.json: valid JSON"
    else
        bad ".claude/settings.json: INVALID JSON — the harness will ignore it"
    fi
else
    bad ".claude/settings.json missing"
fi

CMD_COUNT=$(find .claude/commands -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
[ "$CMD_COUNT" -gt 0 ] && ok "slash commands: $CMD_COUNT" || warn "no slash commands found in .claude/commands/"

RULE_COUNT=$(find .claude/rules -type f 2>/dev/null | wc -l | tr -d ' ')
[ "$RULE_COUNT" -gt 0 ] && ok "rules: $RULE_COUNT" || warn "no rules found in .claude/rules/"

# The check this script exists for: a hook whose command points at a file that is
# not there never runs, and never says so.
#
# Claude Code reads hooks from .claude/settings.json. It does NOT read
# .claude/hooks/hooks.json — that was a Cursor config (Cursor event names such as
# `afterFileEdit`, paths under a `.cursor/` directory that never existed here) and
# was removed. If it reappears, say so, because nothing will ever execute it.
if [ -f .claude/hooks/hooks.json ]; then
    warn ".claude/hooks/hooks.json is back — Claude Code never reads it; hooks belong in .claude/settings.json"
fi

if [ -f .claude/settings.json ]; then
    HOOK_REPORT=$(node - <<'NODE'
const fs = require('fs');
let cfg;
try { cfg = JSON.parse(fs.readFileSync('.claude/settings.json', 'utf8')); }
catch { process.exit(0); }
const missing = [];
let checked = 0, wired = 0;
for (const [event, entries] of Object.entries(cfg.hooks || {})) {
  for (const entry of (entries || [])) {
    for (const h of (entry.hooks || [])) {
      wired++;
      if (h.type !== 'command' || typeof h.command !== 'string') continue;
      // Pull a local script path out of the command. $CLAUDE_PROJECT_DIR resolves
      // to the repo root at run time, so strip it and test relative to cwd.
      const m = h.command.match(/["']?\$(?:\{)?CLAUDE_PROJECT_DIR\}?\/([\w.\-\/]+\.(?:js|mjs|cjs|sh|py))["']?/)
             || h.command.match(/(?:^|\s)["']?((?:\.\/)?[\w.\-\/]+\.(?:js|mjs|cjs|sh|py))["']?(?:\s|$)/);
      if (!m) continue;               // `npx foo` etc. resolve at run time
      checked++;
      if (!fs.existsSync(m[1])) missing.push(`${event}: ${m[1]}`);
    }
  }
}
console.log(JSON.stringify({ missing, checked, wired }));
NODE
)
    if [ -n "$HOOK_REPORT" ]; then
        HK_WIRED=$(printf '%s' "$HOOK_REPORT" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).wired))')
        HK_CHECKED=$(printf '%s' "$HOOK_REPORT" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).checked))')
        HK_MISSING=$(printf '%s' "$HOOK_REPORT" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).missing.join("\n")))')
        if [ -n "$HK_MISSING" ]; then
            COUNT=$(printf '%s\n' "$HK_MISSING" | grep -c . )
            bad "settings.json wires $COUNT hook script(s) that do not exist — these silently never run:"
            printf '%s\n' "$HK_MISSING" | while IFS= read -r p; do
                [ -n "$p" ] && printf '          %s\n' "$p"
            done
        elif [ "${HK_CHECKED:-0}" -eq 0 ]; then
            # A pass with nothing examined is not a pass. This repo has been bitten
            # by gates that scanned zero files; say so rather than printing green.
            warn "settings.json: $HK_WIRED hook(s) wired but none reference a local script — nothing to verify"
        else
            ok "settings.json: $HK_WIRED hook(s) wired, $HK_CHECKED local script(s) all resolve"
        fi
    fi
else
    warn ".claude/settings.json not found — no hooks are configured at all"
fi

if [ -f .mcp.json ]; then
    if node -e 'JSON.parse(require("fs").readFileSync(".mcp.json","utf8"))' 2>/dev/null; then
        SRV=$(node -e 'const c=JSON.parse(require("fs").readFileSync(".mcp.json","utf8"));console.log(Object.keys(c.mcpServers||{}).length)')
        ok ".mcp.json: valid JSON, $SRV server(s)"
    else
        bad ".mcp.json: INVALID JSON — no MCP servers will load"
    fi
else
    warn ".mcp.json not found"
fi

# ------------------------------------------------------------------- hermes --
hdr "hermes agent"
if command -v hermes >/dev/null 2>&1; then
    ok "hermes: $(hermes --version 2>&1 | head -1)"
    if node -e 'const c=JSON.parse(require("fs").readFileSync(".mcp.json","utf8"));process.exit(c.mcpServers&&c.mcpServers.hermes?0:1)' 2>/dev/null; then
        ok "hermes registered in .mcp.json"
    else
        warn "hermes installed but not registered in .mcp.json"
    fi
else
    warn "hermes not on PATH — the hermes MCP entry will fail to start"
fi

# ------------------------------------------------------------------ network --
hdr "network egress"
# An egress allowlist is silent: requests fail deep inside a build rather than at the
# boundary. Probe the boundary directly so a blocked host is named up front.
probe() {
    local host="$1" label="$2"
    if ! command -v curl >/dev/null 2>&1; then return; fi
    local code
    code=$(curl -o /dev/null -sS -w '%{http_code}' --max-time 10 -I "$host" 2>/dev/null)
    case "$code" in
        000|"") warn "$label unreachable ($host) — blocked or offline" ;;
        403)    warn "$label returned 403 ($host) — may be egress-blocked" ;;
        *)      ok "$label reachable ($code)" ;;
    esac
}
probe "https://github.com" "github.com"
probe "https://registry.npmjs.org" "npm registry"
probe "https://api.anthropic.com" "anthropic api"

# -------------------------------------------------------- canonical numbers --
hdr "canonical numbers"
if [ -f scripts/check-canonical-numbers.js ]; then
    if node scripts/check-canonical-numbers.js --quiet; then
        ok "canonical numbers agree across all files that state them"
    else
        bad "canonical numbers disagree — run: node scripts/check-canonical-numbers.js"
    fi
else
    warn "scripts/check-canonical-numbers.js not found"
fi

# ------------------------------------------------------------------ verdict --
printf '\n'
if [ "$FAILED" -gt 0 ]; then
    printf '%sFAILED%s  %d problem(s), %d warning(s)\n' "$RED" "$RST" "$FAILED" "$WARNED"
    exit 1
fi
if [ "$WARNED" -gt 0 ]; then
    printf '%sOK%s      no failures, %d warning(s)\n' "$GRN" "$RST" "$WARNED"
    exit 0
fi
printf '%sOK%s      everything checks out\n' "$GRN" "$RST"
exit 0
