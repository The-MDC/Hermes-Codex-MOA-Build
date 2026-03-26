# Skill: MPP (MADHATs Platform Protocol) Development

## When to Use This Skill
Trigger for: platform architecture, MPP spec work, API design, database schema,
frontend components, prediction market mechanics, tokenomics implementation.

## Platform Architecture
- Frontend: React 18 + TypeScript + TailwindCSS + Hono/HonoX
- Backend: Supabase (Postgres + Edge Functions + Realtime)
- Blockchain layer: Foundry contracts + Alchemy AA-SDK
- AI layer: Claude Opus 4.6 + MCP servers + GraphRAG

## Core Platform Components
1. **Scandal Pack System** — Dutch auction NFT drops
2. **Prediction Market Engine** — event creation, resolution, settlement
3. **Card Evolution System** — burn mechanics, rarity tiers
4. **$MADx Economy** — staking, governance, fee distribution
5. **Creator Tools** — market creation, 40% revenue share
6. **Leaderboards** — points, rankings, social proof

## Design System
- Aesthetic: retro-futuristic (verdigris + gold + cyan + purple)
- Primary palette: verdigris (#3D9E8C), gold (#C9A84C), dark (#1A1A2E)
- Typography: monospace accents, clean sans-serif body
- Components: pixel-perfect, responsive (desktop → tablet → mobile)

## Database Schema Conventions (Supabase)
- All tables: snake_case naming
- UUID primary keys
- created_at / updated_at on all tables
- RLS (Row Level Security) on all user data tables
- Soft deletes: deleted_at column, never hard delete

## API Design
- RESTful endpoints via Supabase Edge Functions
- Response format: `{ data, error, meta }` always
- Auth: Supabase Auth + wallet signature verification
- Rate limiting on all public endpoints
