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
if [ -f .claude/hooks/hooks.json ]; then
    if node -e 'JSON.parse(require("fs").readFileSync(".claude/hooks/hooks.json","utf8"))' 2>/dev/null; then
        ok ".claude/hooks/hooks.json: valid JSON"
    else
        bad ".claude/hooks/hooks.json: INVALID JSON"
    fi

    MISSING_HOOKS=$(node - <<'NODE'
const fs = require('fs');
let cfg;
try { cfg = JSON.parse(fs.readFileSync('.claude/hooks/hooks.json', 'utf8')); }
catch { process.exit(0); }
const missing = [];
const walk = (node) => {
  if (Array.isArray(node)) return node.forEach(walk);
  if (node && typeof node === 'object') {
    if (typeof node.command === 'string') {
      // Only local script references are checkable; `npx foo` is resolved at run time.
      const m = node.command.match(/(?:^|\s)((?:\.\/)?[\w.\-/]+\.(?:js|mjs|cjs|sh|py))(?:\s|$)/);
      if (m && !fs.existsSync(m[1])) missing.push(m[1]);
    }
    Object.values(node).forEach(walk);
  }
};
walk(cfg);
console.log([...new Set(missing)].join('\n'));
NODE
)
    if [ -n "$MISSING_HOOKS" ]; then
        COUNT=$(printf '%s\n' "$MISSING_HOOKS" | grep -c . )
        bad "hooks.json references $COUNT script(s) that do not exist — these hooks silently never run:"
        printf '%s\n' "$MISSING_HOOKS" | while IFS= read -r p; do
            [ -n "$p" ] && printf '          %s\n' "$p"
        done
        HOOK_DIR_HINT=$(printf '%s\n' "$MISSING_HOOKS" | head -1 | sed 's#/[^/]*$##')
        printf '        %shint: hook scripts present in .claude/hooks/ — referenced path is %s%s\n' \
            "$DIM" "${HOOK_DIR_HINT:-?}" "$RST"
    else
        ok "hooks.json: every referenced script resolves"
    fi
else
    warn ".claude/hooks/hooks.json not found"
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
