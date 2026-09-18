# Crawl4AI: the extract half, self-hosted

SearXNG gives the stack keyless **search**. Crawl4AI gives it keyless **extraction** —
the other half, and the one SearXNG explicitly does not do.

```bash
docker run -d -p 11235:11235 --name crawl4ai --shm-size=1g unclecode/crawl4ai:latest
claude mcp add crawl4ai --transport sse http://127.0.0.1:11235/mcp/sse
```

Seven tools arrive: `md`, `html`, `screenshot`, `pdf`, `execute_js`, `crawl`, `ask`.

`--shm-size=1g` is not decoration — Chromium under Playwright will crash on the default
64 MB `/dev/shm`, intermittently and under load, which reads as flaky crawling rather
than as a misconfiguration.

## Why NOT `coleam00/mcp-crawl4ai-rag`

I recommended that repo before reading it. **That recommendation was wrong**, and the
reason is worth recording so nobody re-makes it.

I described it as completing a keyless research browser. It is the opposite. From its
own source at `a1c16f6`:

| | |
|---|---|
| `src/utils.py:28` | raises `ValueError` unless `SUPABASE_URL` **and** `SUPABASE_SERVICE_KEY` are set |
| `src/crawl4ai_mcp.py:147` | calls `get_supabase_client()` inside the **lifespan** |

So Supabase is not optional — the server does not start without it. And
`SUPABASE_SERVICE_KEY` is the **service_role** secret, which bypasses Row Level Security
entirely. This repo's own security-review skill has a section on Supabase RLS; handing an
MCP server the key that ignores RLS is a large trust grant for a crawler.

It also hard-requires `OPENAI_API_KEY`, with `text-embedding-3-small` hardcoded at
`src/utils.py:51`. Every crawl bills OpenAI. That is a new vendor in a stack deliberately
built on NVIDIA NIM, HF Inference, OpenRouter and local weights.

None of that makes it a bad project — it is MIT, small (660 KB), and the RAG layer is the
point of it. It is simply **not what was described**, and not what this stack wants.

**If you do want the RAG layer**, the price is a Supabase project, its service_role key,
and OpenAI billing. Ask and I'll wire it as a second server; it does not replace the
native one.

## The token, and why it is omitted

Crawl4AI's own self-hosting docs: set `CRAWL4AI_API_TOKEN` and *every* endpoint except
`/health` requires `Authorization: Bearer $CRAWL4AI_API_TOKEN`. **Without a token the
server is loopback-only** and a published port answers with connection reset.

The config above binds `127.0.0.1` and sets no token, so the safer default applies by
construction. Set a token *and* keep the loopback bind if you publish the port at all.

## `execute_js` is the one to think about

Six of the seven tools read. `execute_js` runs arbitrary JavaScript in the crawler's
browser against a page you point it at. That is the tool's purpose — dynamic content
needs it — but it is also the one that turns a fetch into an execution, and the agent
chooses the script. Nothing here disables it; know it is in the set.

## Related, not installed

`luxiaolei/searxng-crawl4ai-mcp` bundles exactly this pairing — SearXNG for search,
Crawl4AI for scraping — behind one MCP server, motivated by self-hosted Firecrawl's
search API not working. Worth reading if you'd rather run one container than two. Not
installed here: the two-container split keeps each piece replaceable, and Hermes already
drives SearXNG natively through `web.search_backend`.

---

# Voice: `jamiepine/hermes-voicebox`

TTS and STT providers written for Hermes specifically. MIT, reviewed at `3e8c357`.

```bash
pip install hermes-voicebox     # into the env Hermes runs in
```

Hermes auto-discovers it through the `hermes_agent.plugins` entry point on next
start — nothing to register by hand. The config sets `tts.provider` and
`stt.provider` to `voicebox`.

## What the review found

| | |
|---|---|
| dependencies | `requests>=2.31`. That is the whole list |
| credentials read | **none** — the single `os.environ.get` is `VOICEBOX_BASE_URL`, an endpoint override |
| network reach | every call in the package goes to `127.0.0.1`; the only external URL anywhere is a docs link inside a skill file |
| size / licence | 100 KB, MIT, with tests |

The "fully local" claim verifies. That is worth stating plainly because it is the
rare case where it does.

## It is a bridge, not an engine

The plugin does no inference. It talks to the **Voicebox app**, which has to be
running: desktop build on `:17493`, Docker on `:17600`, override with
`VOICEBOX_BASE_URL`.

So the plugin can be installed, configured and discovered correctly while doing
absolutely nothing — because the thing it bridges to isn't up. That is the confusing
failure mode, and `scripts/nim-preflight.sh` now names it rather than leaving you to
work it out from silence.

It also ships its own skill at `hermes_voicebox/skills/voicebox/SKILL.md`, and
Voicebox exposes an MCP server at `http://127.0.0.1:17493/mcp` for agent-invoked
voice tools rather than Hermes' `tts`/`stt` plumbing. Both are wired.
