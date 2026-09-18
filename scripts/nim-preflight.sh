#!/usr/bin/env bash
# nim-preflight, prove the NVIDIA NIM route works before Hermes depends on it.
#
# WHY THIS EXISTS
#     configs/hermes/config.yaml points Hermes at build.nvidia.com. Three things can be
#     wrong in ways that do not announce themselves:
#
#       1. The key is absent, stale, or scoped to a different account. Hermes reports
#          this as a model error deep in a session, not as a config error at startup.
#       2. The traffic does not land on NVIDIA at all. `moonshotai/kimi-k3` is also an
#          OpenRouter catalog slug, and Hermes has an open bug (#39753) where a matching
#          model name overrides an explicit custom base_url. The symptom is a working
#          session billed to the wrong provider, with your NVIDIA key sent to a third
#          party. Nothing in the transcript says so.
#       3. The endpoint does not support what the config assumes — tool calling, the
#          context window, the reasoning_effort knob. Hermes finds out mid-task.
#
#     So this asks the endpoint directly and reports what it actually answers.
#
# THE KEY IS NEVER PRINTED, and never written anywhere. It is read from the
# environment only. If it is absent this fails rather than prompting for it.
#
# usage: scripts/nim-preflight.sh [--quiet] [--nim-only] [--list]
#        --list also prints every model id this key can reach, which is the same
#        catalog as build.nvidia.com/explore/discover but scoped to your account.
#        --nim-only skips the other two buckets (see below).
# exits: 0 = the route is usable, 1 = something is broken

set -u

RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; DIM=$'\033[2m'; RST=$'\033[0m'
[ -t 1 ] || { RED=""; GRN=""; YLW=""; DIM=""; RST=""; }

FAILED=0; WARNED=0; QUIET=0; NIM_ONLY=0; LIST=0
for arg in "$@"; do
    case "$arg" in
        --quiet)     QUIET=1 ;;
        --nim-only)  NIM_ONLY=1 ;;
        --list)      LIST=1 ;;
        *) printf 'unknown argument: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

ok()   { [ "$QUIET" = 1 ] || printf '  %sok%s    %s\n'  "$GRN" "$RST" "$*"; }
warn() { printf '  %swarn%s  %s\n' "$YLW" "$RST" "$*"; WARNED=$((WARNED+1)); }
bad()  { printf '  %sFAIL%s  %s\n' "$RED" "$RST" "$*"; FAILED=$((FAILED+1)); }
hdr()  { [ "$QUIET" = 1 ] || printf '\n%s%s%s\n' "$DIM" "$*" "$RST"; }

NIM_BASE="${NVIDIA_NIM_BASE_URL:-https://integrate.api.nvidia.com/v1}"
NIM_MODEL="${NVIDIA_NIM_MODEL:-moonshotai/kimi-k3}"
HF_BASE="${HF_ROUTER_BASE_URL:-https://router.huggingface.co/v1}"
OR_BASE="${OPENROUTER_BASE_URL:-https://openrouter.ai/api/v1}"
LOCAL_BASE="${LOCAL_MODEL_BASE_URL:-http://127.0.0.1:8080/v1}"
SEARXNG="${SEARXNG_URL:-}"
VOICEBOX="${VOICEBOX_BASE_URL:-http://127.0.0.1:17493}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

printf 'NVIDIA NIM preflight\n'
printf '  endpoint  %s\n' "$NIM_BASE"
printf '  model     %s\n' "$NIM_MODEL"

command -v curl >/dev/null 2>&1 || { printf '\n%sFAIL%s  curl not found\n' "$RED" "$RST"; exit 1; }

# ------------------------------------------------------------------ credential --
hdr "credential"

if [ -z "${NVIDIA_API_KEY:-}" ]; then
    bad "NVIDIA_API_KEY is not set"
    printf '        Get one at https://build.nvidia.com (Get API Key on any model page),\n'
    printf '        then put it in ~/.hermes/.env (chmod 600) or export it. Do not put it\n'
    printf '        in config.yaml and do not paste it into a chat.\n'
    exit 1
fi

# Shape only. Never the value, never a prefix of the secret part.
case "$NVIDIA_API_KEY" in
    nvapi-*) ok "NVIDIA_API_KEY present (${#NVIDIA_API_KEY} chars, nvapi- prefix)" ;;
    *)       warn "NVIDIA_API_KEY present (${#NVIDIA_API_KEY} chars) but lacks the usual nvapi- prefix" ;;
esac

# Warn loudly if a key is sitting somewhere git can pick it up.
#
# Search for the key SHAPE (prefix plus a long token), not the bare prefix: this
# script and the docs both mention the prefix in prose, and matching that would make
# the check cry wolf on its own source every run. Exclude this file regardless.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    if git -C "$REPO_ROOT" grep -qIE 'nvapi-[A-Za-z0-9_-]{20,}' \
         -- . ':(exclude)scripts/nim-preflight.sh' 2>/dev/null; then
        bad "a string shaped like an NVIDIA key is tracked in this repository"
        printf '        Rotate it at build.nvidia.com before anything else, then find it\n'
        printf '        with a grep for the same shape.\n'
    else
        ok "no NVIDIA-key-shaped string tracked in this repository"
    fi
fi

# ------------------------------------------------------------------- catalog --
hdr "catalog"

CODE=$(curl -sS -o "$TMP/models.json" -w '%{http_code}' --max-time 30 \
    -H "Authorization: Bearer $NVIDIA_API_KEY" \
    "$NIM_BASE/models" 2>"$TMP/models.err") || CODE="000"

case "$CODE" in
    200)
        ok "GET /models: 200"
        if grep -q "\"$NIM_MODEL\"" "$TMP/models.json" 2>/dev/null; then
            ok "$NIM_MODEL is in the catalog for this key"
        else
            bad "$NIM_MODEL is NOT in the catalog this key can see"
            printf '        The endpoint answered, so the key is valid — the model is not\n'
            printf '        available to it. Check the model page at build.nvidia.com.\n'
        fi
        if command -v python3 >/dev/null 2>&1; then
            COUNT=$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1])).get("data",[])))' "$TMP/models.json" 2>/dev/null) \
                && [ -n "$COUNT" ] && ok "catalog size: $COUNT models"
            # The catalog is the honest answer to "what else can I route to?" — it is
            # scoped to this key, unlike the public browse page, so it also answers
            # "what can I actually reach?" Useful when picking a fallback model.
            if [ "$LIST" = 1 ]; then
                python3 -c 'import json,sys
for m in sorted(x.get("id","") for x in json.load(open(sys.argv[1])).get("data",[])):
    print(m)' "$TMP/models.json" 2>/dev/null | while IFS= read -r m; do
                    printf '  %s      %s%s\n' "$DIM" "$m" "$RST"
                done
            fi
        fi
        ;;
    401|403)
        bad "GET /models: $CODE — the key was rejected"
        printf '        Rotate or regenerate it at build.nvidia.com. Not a retry case.\n'
        ;;
    000)
        bad "GET /models: no response (network, DNS, or proxy)"
        [ -s "$TMP/models.err" ] && printf '        %s\n' "$(head -1 "$TMP/models.err")"
        ;;
    *)
        bad "GET /models: HTTP $CODE"
        ;;
esac

# ------------------------------------------------------------- live completion --
hdr "live completion"

cat > "$TMP/req.json" <<JSON
{"model":"$NIM_MODEL",
 "messages":[{"role":"user","content":"Reply with the single word: ready"}],
 "max_tokens":2048,
 "temperature":1.0,
 "stream":false}
JSON

START=$(date +%s)
CODE=$(curl -sS -o "$TMP/chat.json" -D "$TMP/chat.hdr" -w '%{http_code}' --max-time 180 \
    -H "Authorization: Bearer $NVIDIA_API_KEY" \
    -H "Content-Type: application/json" \
    -d @"$TMP/req.json" \
    "$NIM_BASE/chat/completions" 2>"$TMP/chat.err") || CODE="000"
ELAPSED=$(( $(date +%s) - START ))
CHAT_CODE="$CODE"

case "$CODE" in
    200)
        ok "POST /chat/completions: 200 in ${ELAPSED}s"
        if command -v python3 >/dev/null 2>&1; then
            python3 - "$TMP/chat.json" <<'PY' 2>/dev/null | while IFS= read -r l; do
import json, sys
d = json.load(open(sys.argv[1]))
u = d.get("usage") or {}
if u:
    print("usage: %s prompt + %s completion = %s tokens"
          % (u.get("prompt_tokens","?"), u.get("completion_tokens","?"), u.get("total_tokens","?")))
msg = (d.get("choices") or [{}])[0].get("message") or {}
if msg.get("reasoning_content"):
    print("reasoning_content present — K3 is thinking; budget tokens for it")
PY
                [ "$QUIET" = 1 ] || printf '  %s      %s%s\n' "$DIM" "$l" "$RST"
            done
        fi
        ;;
    429)
        bad "POST /chat/completions: 429 rate limited"
        printf '        The free NIM tier runs around 40 RPM. This is the constraint the\n'
        printf '        delegation split in configs/hermes/config.yaml exists to dodge.\n'
        ;;
    401|403)
        bad "POST /chat/completions: $CODE — rejected. Not a retry case."
        ;;
    000)
        bad "POST /chat/completions: no response after ${ELAPSED}s"
        ;;
    *)
        bad "POST /chat/completions: HTTP $CODE"
        [ -s "$TMP/chat.json" ] && printf '        %s\n' "$(head -c 200 "$TMP/chat.json")"
        ;;
esac

# Did the request actually reach NVIDIA? This is defect (2) in the header comment.
#
# Only meaningful when something answered. On a failed connect curl still writes the
# proxy's own response into the header dump, and reporting "no third-party relay" off
# that would be a green tick for a request that never left the building.
if [ "$CHAT_CODE" = "000" ]; then
    [ "$QUIET" = 1 ] || printf '  %s      no response headers to inspect — nothing reached the endpoint%s\n' "$DIM" "$RST"
elif [ -s "$TMP/chat.hdr" ]; then
    if grep -qi 'openrouter' "$TMP/chat.hdr"; then
        bad "the response carries OpenRouter headers — traffic did NOT reach NVIDIA"
        printf '        This is hermes-agent#39753. Use the named-provider form and rotate\n'
        printf '        the NVIDIA key: it was sent to a third party.\n'
    else
        ok "response headers show no third-party relay"
    fi
    LIMIT=$(grep -i '^x-ratelimit' "$TMP/chat.hdr" | tr -d '\r' | head -4)
    if [ -n "$LIMIT" ]; then
        printf '%s' "$LIMIT" | while IFS= read -r line; do
            [ "$QUIET" = 1 ] || printf '  %s      %s%s\n' "$DIM" "$line" "$RST"
        done
    else
        warn "endpoint advertises no x-ratelimit headers — budget by observation, not by header"
    fi
fi

# -------------------------------------------------------------- tool calling --
hdr "tool calling"

cat > "$TMP/tool.json" <<JSON
{"model":"$NIM_MODEL",
 "messages":[{"role":"user","content":"What is the weather in Santa Fe? Use the tool."}],
 "max_tokens":2048,
 "tools":[{"type":"function","function":{
   "name":"get_weather",
   "description":"Get current weather for a city",
   "parameters":{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}}}],
 "tool_choice":"auto",
 "stream":false}
JSON

CODE=$(curl -sS -o "$TMP/toolres.json" -w '%{http_code}' --max-time 180 \
    -H "Authorization: Bearer $NVIDIA_API_KEY" \
    -H "Content-Type: application/json" \
    -d @"$TMP/tool.json" \
    "$NIM_BASE/chat/completions" 2>/dev/null) || CODE="000"

if [ "$CODE" = "200" ]; then
    if grep -q '"tool_calls"' "$TMP/toolres.json" 2>/dev/null; then
        ok "the endpoint emitted tool_calls — Hermes' tools will work"
    else
        warn "200, but no tool_calls in the reply. The model may have answered in prose."
        printf '        Re-run before concluding tools are unsupported; K3 sometimes reasons\n'
        printf '        its way to a text answer. If it never calls, Hermes tools are degraded.\n'
    fi
elif [ "$CODE" = "429" ]; then
    warn "tool-calling probe: 429 — rate limited, not a capability result"
else
    bad "tool-calling probe: HTTP $CODE"
fi

# ------------------------------------------------------------- other buckets --
#
# The parent runs on NIM. The subagent tier and the 429 fallback deliberately do
# NOT — they sit on separate providers so a rate limit on one cannot starve the
# others. That only holds if those providers actually answer, so check them here.
#
# A tier that is configured but unreachable is the quiet failure: Hermes falls back
# onto whatever still works, which is NIM, and the rate limit you were avoiding
# arrives anyway with nothing in the transcript to explain it.

check_bucket() {   # name  base_url  key_value  purpose
    local name="$1" base="$2" key="$3" purpose="$4"
    if [ -z "$key" ]; then
        warn "$name: no key set — $purpose has nowhere to go"
        return
    fi
    local code
    code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 \
        -H "Authorization: Bearer $key" "$base/models" 2>/dev/null) || code="000"
    case "$code" in
        200)     ok "$name: reachable and the key authenticates" ;;
        401|403) bad "$name: $code — key rejected. Not a retry case." ;;
        000)     bad "$name: no response (network, DNS, or proxy)" ;;
        *)       warn "$name: HTTP $code" ;;
    esac
}

if [ "$NIM_ONLY" = "0" ]; then
    hdr "subagent bucket — Hugging Face Inference ($HF_BASE)"
    check_bucket "hf-router" "$HF_BASE" "${HF_TOKEN:-}" "the subagent tier"

    hdr "fallback bucket — OpenRouter ($OR_BASE)"
    check_bucket "openrouter" "$OR_BASE" "${OPENROUTER_API_KEY:-}" "the 429 fallback"

    if [ "$HF_BASE" = "$NIM_BASE" ] || [ "$OR_BASE" = "$NIM_BASE" ]; then
        bad "a secondary bucket points at the NIM endpoint — they are not independent"
    fi

    # ---------------------------------------------------------- local floor --
    #
    # The one tier nothing can rate-limit. Absent is fine — it is a floor, not a
    # dependency — so this warns rather than fails.
    hdr "local floor — Hermes-4-14B ($LOCAL_BASE)"
    CODE=$(curl -sS -o "$TMP/local.json" -w '%{http_code}' --max-time 5 \
        "$LOCAL_BASE/models" 2>/dev/null) || CODE="000"
    if [ "$CODE" = "200" ]; then
        ok "local server is up — the session survives losing the network"
        if command -v python3 >/dev/null 2>&1; then
            python3 -c 'import json,sys
d = json.load(open(sys.argv[1])).get("data", [])
for m in d[:4]: print("serving:", m.get("id", "?"))' "$TMP/local.json" 2>/dev/null \
            | while IFS= read -r l; do
                [ "$QUIET" = 1 ] || printf '  %s      %s%s\n' "$DIM" "$l" "$RST"
              done
        fi
    else
        warn "local server not reachable (HTTP $CODE) — no offline floor"
        printf '        Start one:  llama-server -m Hermes-4-14B-Q6_K.gguf --port 8080 --jinja\n'
        printf '        See docs/models/local-flash-model.md. Everything else still works.\n'
    fi

    # --------------------------------------------------------- web browsing --
    #
    # Hermes prefers Firecrawl over SearXNG whenever FIRECRAWL_API_KEY merely exists
    # in the environment. The config names searxng to stop that, but the URL still
    # has to resolve or the named backend is a backend that is not there.
    hdr "research browser"
    if [ -z "$SEARXNG" ]; then
        warn "SEARXNG_URL not set — config names searxng but nothing is listening"
        printf '        docker run -d -p 8888:8080 --name searxng searxng/searxng\n'
        printf '        then SEARXNG_URL=http://127.0.0.1:8888 in ~/.hermes/.env\n'
        printf '        Without it Hermes falls to DDGS (keyless, weaker) or errors.\n'
    else
        CODE=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 \
            "$SEARXNG/search?q=test&format=json" 2>/dev/null) || CODE="000"
        case "$CODE" in
            200) ok "SearXNG answers JSON at $SEARXNG" ;;
            403) bad "SearXNG returned 403 — the JSON API is disabled on that instance"
                 printf '        Add `- json` under `search.formats` in its settings.yml.\n' ;;
            000) bad "SearXNG unreachable at $SEARXNG" ;;
            *)   warn "SearXNG returned HTTP $CODE at $SEARXNG" ;;
        esac
    fi

    # ------------------------------------------------------------------ voice --
    #
    # hermes-voicebox is a BRIDGE, not an engine: the plugin can be installed and
    # configured correctly while doing nothing at all, because the Voicebox app it
    # talks to is not running. That is the confusing failure, so name it.
    hdr "voice — Voicebox ($VOICEBOX)"
    CODE=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 \
        "$VOICEBOX/health" 2>/dev/null) || CODE="000"
    case "$CODE" in
        200) ok "Voicebox is up — tts/stt providers have a backend" ;;
        000) warn "Voicebox not reachable — tts/stt are configured but inert"
             printf '        Start the desktop app, or Docker on :17600 and set\n'
             printf '        VOICEBOX_BASE_URL. The plugin alone does nothing.\n' ;;
        *)   warn "Voicebox returned HTTP $CODE at $VOICEBOX" ;;
    esac
fi

# -------------------------------------------------------------------- verdict --
printf '\n'
if [ "$FAILED" -gt 0 ]; then
    printf '%sNIM route is NOT usable: %d failure(s), %d warning(s)%s\n' "$RED" "$FAILED" "$WARNED" "$RST"
    exit 1
fi
if [ "$WARNED" -gt 0 ]; then
    printf '%sNIM route is usable, with %d warning(s)%s\n' "$YLW" "$WARNED" "$RST"
    exit 0
fi
printf '%sNIM route is usable%s\n' "$GRN" "$RST"
exit 0
