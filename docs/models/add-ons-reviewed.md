# Add-ons: what was reviewed, what was added, what was not

Every candidate here was cloned and read before a verdict. That discipline has already
paid for itself twice — it caught a "keyless" crawler that hard-requires a Supabase
service_role key, and a plugin that cannot install from a clean environment.

| add-on | verdict | why |
|---|---|---|
| `unclecode/crawl4ai` | **added** | native MCP, no keys, loopback-only by default |
| `jamiepine/hermes-voicebox` | **added** | Hermes-specific, MIT, all traffic to `127.0.0.1` |
| `atomicstrata/atomicmemory` | **added** | Apache-2.0, local embeddings, no required credential |
| `coleam00/mcp-crawl4ai-rag` | rejected | hard-requires Supabase service_role + OpenAI billing |
| `ArtemSultanov-PG/memanto-hermes-onprem` | rejected | undeclared hard dependency; will not install |
| `matthewlee0102/FastSkills` | rejected | 19 MB, duplicates `hermes-skills/` and its attribution |

## Added: `atomicstrata/atomicmemory`

Reviewed at `8b71e2e`. Memory is the largest capability this stack was missing — nothing
in it remembered anything across sessions.

```bash
claude mcp add atomicmemory -- npx -y @atomicmemory/mcp-server
```

| | |
|---|---|
| licence | Apache-2.0, with a `SECURITY.md` and a private disclosure channel |
| mcp-server deps | `@atomicmemory/sdk`, `@modelcontextprotocol/sdk`, `zod` |
| SDK deps | `@huggingface/transformers` — **embeddings run locally**, no OpenAI key |
| required credentials | **none.** `ATOMICMEMORY_API_KEY` is optional and defaults to `local-dev-key` against the local core |
| default endpoint | `http://127.0.0.1:17350` |

Two things the review turned up that are worth writing down.

**A telemetry flag that turned out to be nothing.** `feature-flags.ts` defaults
`telemetryCollection: true`, which reads badly. Tracing it: the flag is declared and
defaulted and **never read anywhere in the source**. It gates no network call. Sitting
beside it is `remoteFallback: false, // Disabled by default for privacy`, which is the
author choosing the private default unprompted. Reported here because "I found a
telemetry flag" is the kind of half-finding that should be finished, not left hanging.

**SSRF tests.** The fixtures include a decimal-encoded IP and `10.0.0.5` — someone
deliberately tested that URL fetching cannot be walked into the private network. For a
component that takes URLs from an agent, that is the thing you want to find.

### It is a client, not the store

Like Voicebox: the MCP server talks to a local AtomicMemory **core**, which has to be
running. Configured-and-inert is indistinguishable from absent at the tool boundary, so
`scripts/nim-preflight.sh` probes `/health` and says so.

## Rejected: `ArtemSultanov-PG/memanto-hermes-onprem`

The only Hermes-specific memory provider in existence, which made it worth the read.
Reviewed at `b46a981` — it does not survive one.

**It cannot install.** `pyproject.toml` declares **zero dependencies**. Line 169 does
`from memanto.cli.client.sdk_client import SdkClient` and line 174 constructs it. That
package is not a declared dependency and does not arrive with
`pip install memanto-hermes-onprem`, so the provider raises `ImportError` on first use
from any clean environment.

**"On-prem" is doing work the code does not.** It requires `MOORCHEH_API_KEY`, and its
own setup schema points at `https://console.moorcheh.ai/api-keys` — a hosted console. It
also writes a bearer token to `~/.memanto_token`. On-prem refers to Memanto's product
tier, not to your data staying local.

Not malicious — 498 lines, MIT, and the Hermes `MemoryProvider` subclassing looks
competent. It is unfinished as published. Revisit if the dependency is ever declared.

## Rejected: `matthewlee0102/FastSkills`

The pitch is good: an MCP server exposing Agent Skills — Claude Code's standard — to any
MCP agent, which would let Hermes read skills live instead of through ported copies.

It is 19 MB, and the bulk is vendored Anthropic skills including
`skills/canvas-design/canvas-fonts/*.ttf` — **the same font set `hermes-skills/` already
carries**. Adding it would duplicate ~7 MB of fonts and re-introduce the attribution
problem `scripts/port-skills-to-hermes.js` exists to solve, where upstream authorship and
licence are preserved per skill by `attributionFor()`.

The idea is worth returning to. This packaging of it is not.

## Considered and not applicable

`HKUDS/nanobot` (48.3K⭐), `tinyhumansai/openhuman` (39.9K⭐), `stablyai/orca` (71.5K⭐)
and `najmuzzaman-mohammad/gawkbot` (1.4K⭐) are all credible — and they are **alternatives
to Hermes or layers above it**, not things Hermes gains. Adopting any means leaving this
stack rather than extending it.

`tinyhumansai/tinyjuice` claims 95% lossless token compression at 15 stars with no
published evaluation. A Rust library, not a Hermes plugin. Treat the number as a claim.
