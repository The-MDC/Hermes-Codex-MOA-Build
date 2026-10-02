---
name: backend-patterns
description: """"
version: 1.0.0
author: "unknown"
license: "MIT"
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [automatically-portled]
    category: general
    related_skills: []
---


# Backend Patterns

Architecture patterns for the MAD Gambit Hono + Supabase stack.

## API Design (Hono)

```typescript
import { Hono } from 'hono'
import { zValidator } from '@hono/zod-validator'
import { z } from 'zod'

const app = new Hono()

// Resource-based routes
const markets = new Hono()
  .get('/', listMarkets)                              // GET /markets
  .get('/:id', getMarket)                             // GET /markets/:id
  .post('/', zValidator('json', CreateMarketSchema), createMarket)  // POST /markets
  .patch('/:id', zValidator('json', UpdateMarketSchema), updateMarket)
  .delete('/:id', deleteMarket)

app.route('/api/v1/markets', markets)
```

## Repository Pattern (Supabase)

```typescript
interface MarketRepository {
  findAll(filters?: MarketFilters): Promise<Market[]>
  findById(id: string): Promise<Market | null>
  create(data: CreateMarketDto): Promise<Market>
  update(id: string, data: UpdateMarketDto): Promise<Market>
}

class SupabaseMarketRepository implements MarketRepository {
  async findAll(filters?: MarketFilters): Promise<Market[]> {
    let query = supabase
      .from('markets')
      .select('id, title, status, volume, creator_id, resolution_date')  // never select *
      .order('volume', { ascending: false })

    if (filters?.status) query = query.eq('status', filters.status)
    if (filters?.limit) query = query.limit(filters.limit)

    const { data, error } = await query
    if (error) throw new Error(error.message)
    return data
  }
}
```

## N+1 Prevention

```typescript
// BAD — N+1
const markets = await getMarkets()
for (const market of markets) {
  market.creator = await getUser(market.creator_id) // N queries
}

// GOOD — batch fetch
const markets = await getMarkets()
const creatorIds = [...new Set(markets.map(m => m.creator_id))]
const { data: creators } = await supabase.from('users').select('id, name').in('id', creatorIds)
const creatorMap = new Map(creators.map(c => [c.id, c]))
markets.forEach(m => m.creator = creatorMap.get(m.creator_id))
```

## Transactions (Supabase RPC)

```typescript
// Client call
const { data, error } = await supabase.rpc('settle_market_and_distribute', {
  p_market_id: marketId,
  p_winning_outcome: outcome
})

// SQL function in Supabase (transactional)
CREATE OR REPLACE FUNCTION settle_market_and_distribute(
  p_market_id uuid, p_winning_outcome text
) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
  UPDATE markets SET status = 'settled', outcome = p_winning_outcome WHERE id = p_market_id;
  UPDATE positions SET settled = true WHERE market_id = p_market_id AND outcome = p_winning_outcome;
  PERFORM distribute_winnings(p_market_id);
  RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END; $$;
```

## Error Handling

```typescript
class ApiError extends Error {
  constructor(
    public statusCode: number,
    public message: string,
    public code: string
  ) { super(message) }
}

// Centralized Hono error handler
app.onError((err, c) => {
  if (err instanceof ApiError) {
    return c.json({ error: { code: err.code, message: err.message } }, err.statusCode)
  }
  if (err instanceof z.ZodError) {
    return c.json({ error: { code: 'validation_error', details: err.errors } }, 400)
  }
  console.error('Unexpected:', err)
  return c.json({ error: { code: 'internal_error', message: 'Internal error' } }, 500)
})
```

## Retry with Exponential Backoff

```typescript
async function withRetry<T>(fn: () => Promise<T>, maxRetries = 3): Promise<T> {
  for (let i = 0; i < maxRetries; i++) {
    try { return await fn() }
    catch (err) {
      if (i === maxRetries - 1) throw err
      await new Promise(r => setTimeout(r, Math.pow(2, i) * 1000))
    }
  }
  throw new Error('unreachable')
}
```

## Rate Limiting (Hono)

```typescript
import { rateLimiter } from 'hono-rate-limiter'

app.use('/api/*', rateLimiter({ windowMs: 60_000, limit: 100,
  keyGenerator: (c) => c.req.header('x-forwarded-for') ?? 'anon' }))
app.use('/api/markets/create', rateLimiter({ windowMs: 60_000, limit: 5 }))
```

## Structured Logging

```typescript
const logger = {
  info: (msg: string, ctx?: object) =>
    console.log(JSON.stringify({ ts: new Date().toISOString(), level: 'info', msg, ...ctx })),
  error: (msg: string, err: Error, ctx?: object) =>
    console.error(JSON.stringify({ ts: new Date().toISOString(), level: 'error', msg,
      error: err.message, ...ctx }))  // NEVER log stack trace to user
}
```
