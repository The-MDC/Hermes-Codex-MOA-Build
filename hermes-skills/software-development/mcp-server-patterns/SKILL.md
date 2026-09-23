---
name: mcp-server-patterns
description: "> Build MCP servers with Node/TypeScript SDK — tools, resources, prompts, Zod validation, stdio vs Streamable HTTP transport. Use when building or maintaining MCP servers, adding tools or resources, choosing transport, upgrading the SDK, or debugging MCP registration. Triggers on \"build MCP server\", \"MCP tool\", \"MCP resource\", \"model context protocol\", \"add MCP\", \"MCP integration\"."
version: 1.0.0
author: "Anthropic — ported for Hermes Agent"
license: "Anthropic skill licence; see upstream"
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [MCP, TypeScript, Zod, stdio, HTTP]
    category: software-development
    related_skills: [api-design, backend-patterns, frontend-design, mcp-builder, verification-loop]
---

# MCP Server Patterns

Build MCP servers that expose tools, resources, and prompts to AI agents.

## Core Concepts

- **Tools**: Actions the model can invoke (search, execute, query blockchain)
- **Resources**: Read-only data the model can fetch (file contents, API responses)
- **Prompts**: Reusable parameterized prompt templates
- **Transport**: stdio for local (Claude Desktop); Streamable HTTP for remote (Cursor, cloud)

## Quick Start

```bash
npm install @modelcontextprotocol/sdk zod
```

```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({ name: "example-mcp", version: "1.0.0" });

// Tool registration
server.tool(
  "get_market_odds",
  "Get current odds for a prediction market",
  {
    marketId: z.string().describe("The market ID"),
  },
  async ({ marketId }) => {
    const odds = await fetchMarketOdds(marketId);
    return { content: [{ type: "text", text: JSON.stringify(odds) }] };
  }
);

// Resource registration
server.resource(
  "markets://active",
  "List of currently active prediction markets",
  async (uri) => {
    const markets = await getActiveMarkets();
    return {
      contents: [{ uri: uri.href, text: JSON.stringify(markets), mimeType: "application/json" }]
    };
  }
);

// Connect stdio transport
const transport = new StdioServerTransport();
await server.connect(transport);
```

## Transport Selection

| Transport | Use For | Notes |
|---|---|---|
| **stdio** | Local clients (Claude Desktop, Claude Code) | Default for dev |
| **Streamable HTTP** | Remote clients (Cursor, cloud, production) | Single endpoint `/mcp` |
| **HTTP+SSE (legacy)** | Backward compatibility only | Avoid for new builds |

## Best Practices

**Schema first**: Define Zod schemas for every tool input. Document parameters and return shape.

**Errors**: Return structured errors the model can interpret — avoid raw stack traces.

```typescript
// Good error handling
async ({ marketId }) => {
  if (!marketId.match(/^[a-z0-9-]+$/)) {
    return { content: [{ type: "text", text: "Error: invalid market ID format" }], isError: true };
  }
  try {
    const data = await fetchMarket(marketId);
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  } catch (e) {
    return { content: [{ type: "text", text: `Error fetching market: ${e.message}` }], isError: true };
  }
}
```

**Idempotency**: Prefer idempotent tools — retries should be safe.

**Rate limits**: For tools calling external APIs, document rate limits in tool description.

**Versioning**: Pin SDK version. Check release notes on upgrade.

## Claude.ai / Claude Code Integration

Add to `~/.claude/settings.json` or `.claude/settings.local.json`:

```json
{
  "mcpServers": {
    "example": {
      "command": "npx",
      "args": ["tsx", "/path/to/server.ts"],
      "env": {
        "SUPABASE_URL": "...",
        "ALCHEMY_API_KEY": "..."
      }
    }
  }
}
```

## Official Docs
- Node/TypeScript SDK: `@modelcontextprotocol/sdk` (npm)
- Spec: https://modelcontextprotocol.io
