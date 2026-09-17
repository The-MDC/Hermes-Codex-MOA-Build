---
name: security-review
description: "> Security review for Web3/full-stack applications. Use when adding authentication, handling user input, working with secrets, creating API endpoints, implementing payment or prediction market features, writing smart contracts, or deploying any production code. Covers Supabase RLS, EVM wallet verification, ERC-4337 AA security, smart contract patterns, and standard web security. Always activate before any production deployment or PR review."
version: 1.0.0
author: "Anthropic — ported for Hermes Agent by MADHATs"
license: "Anthropic skill licence; see upstream"
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Security, Audit, Web3, RLS, ERC-4337, Review]
    category: security
    related_skills: [security-audit]
---

# Security Review

## When to Activate
- Implementing auth or authorization (Supabase, JWT, wallet-based)
- Handling user input or file uploads
- Creating new API endpoints (Hono, Next.js)
- Working with secrets or env vars
- Writing or auditing Solidity smart contracts
- ERC-4337 / account abstraction flows
- Payment or prediction market settlement logic
- Any production deployment

---

## 1. Secrets Management

```typescript
// NEVER
const apiKey = "sk-proj-xxxxx"

// ALWAYS
const apiKey = process.env.ALCHEMY_API_KEY
if (!apiKey) throw new Error('ALCHEMY_API_KEY not configured')
```

Checklist:
- [ ] No hardcoded keys, tokens, or passwords anywhere
- [ ] All secrets in environment variables
- [ ] `.env.local` in `.gitignore`
- [ ] No secrets in git history (`git log --all -S "secret"`)
- [ ] Production secrets in Vercel/hosting platform env — not in repo

---

## 2. Input Validation (Zod — mandatory)

```typescript
import { z } from 'zod'

const CreateMarketSchema = z.object({
  title: z.string().min(1).max(200),
  resolutionDate: z.string().datetime(),
  initialLiquidity: z.number().positive().max(1_000_000),
  creatorAddress: z.string().regex(/^0x[a-fA-F0-9]{40}$/)
})

export async function createMarket(input: unknown) {
  const validated = CreateMarketSchema.parse(input) // throws ZodError on failure
  return await db.markets.create(validated)
}
```

Checklist:
- [ ] All user inputs validated with Zod schema
- [ ] Ethereum addresses validated with regex before use
- [ ] Numbers bounded — no unbounded amounts in prediction markets
- [ ] Error messages don't leak internals

---

## 3. Supabase Row Level Security (mandatory on all tables)

```sql
-- Enable on every table
ALTER TABLE markets ENABLE ROW LEVEL SECURITY;
ALTER TABLE positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE settlements ENABLE ROW LEVEL SECURITY;

-- Users read their own positions only
CREATE POLICY "Users view own positions"
  ON positions FOR SELECT
  USING (auth.uid() = user_id);

-- Creator can update their own markets
CREATE POLICY "Creator updates own markets"
  ON markets FOR UPDATE
  USING (auth.uid() = creator_id);
```

Checklist:
- [ ] RLS enabled on ALL Supabase tables
- [ ] Policies tested with anon, authenticated, and admin roles
- [ ] Service role key NEVER exposed to client
- [ ] All queries parameterized — no string concat in SQL

---

## 4. EVM Wallet Signature Verification

```typescript
import { verifyMessage } from 'viem'

async function verifyWalletOwnership(
  address: `0x${string}`,
  message: string,
  signature: `0x${string}`
): Promise<boolean> {
  try {
    const recovered = await verifyMessage({ address, message, signature })
    return recovered
  } catch {
    return false
  }
}

// NEVER trust an address claim without verifying the signature
// NEVER skip replay attack protection — include nonce + timestamp in message
const message = `MAD Gambit login\nNonce: ${nonce}\nTimestamp: ${Date.now()}`
```

Checklist:
- [ ] Wallet signatures verified with `viem` or `ethers` — not manual
- [ ] Nonce included in signed message — prevents replay attacks
- [ ] Nonce invalidated after use
- [ ] Timestamp bounded — reject messages older than 5 minutes

---

## 5. Smart Contract Security (Solidity + Foundry)

```solidity
// NEVER use tx.origin for auth
require(tx.origin == owner, "Not owner"); // VULNERABLE

// ALWAYS use msg.sender
require(msg.sender == owner, "Not owner"); // CORRECT

// Reentrancy guard on all external-call functions
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract MADMarket is ReentrancyGuard {
    function settle(uint256 marketId) external nonReentrant {
        // state changes BEFORE external calls (Checks-Effects-Interactions)
        markets[marketId].settled = true;
        emit MarketSettled(marketId);
        // external call LAST
        payable(winner).transfer(amount);
    }
}
```

Checklist:
- [ ] No `tx.origin` for authorization — use `msg.sender`
- [ ] Checks-Effects-Interactions pattern on all state-changing functions
- [ ] `nonReentrant` modifier on all functions with external calls
- [ ] No unchecked arithmetic unless explicitly needed with bounds proof
- [ ] OpenZeppelin contracts for standard logic — no homebrew ERC20/721
- [ ] Events emitted for all state changes (for indexer/subgraph)
- [ ] Pausable on market creation + settlement (emergency stop)

---

## 6. ERC-4337 / Account Abstraction

```typescript
// Validate paymasters sponsor only legitimate user ops
// NEVER allow arbitrary calldata to be sponsored
const isValidOp = (userOp: UserOperation): boolean => {
  const allowedTargets = [MARKET_CONTRACT, NFT_CONTRACT]
  return allowedTargets.includes(userOp.callData.target)
}

// Gas limits — always set explicit limits
const userOp = {
  callGasLimit: 200_000n,
  verificationGasLimit: 150_000n,
  preVerificationGas: 50_000n,
  maxFeePerGas: parseGwei('20'),
  maxPriorityFeePerGas: parseGwei('2')
}
```

Checklist:
- [ ] Paymaster validates calldata target whitelist before sponsoring
- [ ] Gas limits set explicitly — no unbounded ops
- [ ] Bundler endpoint is trusted (Alchemy, not public)
- [ ] Account factory audited or using Alchemy light-account/modular-account

---

## 7. Authentication (JWT + httpOnly cookies)

```typescript
// NEVER store tokens in localStorage — XSS vulnerable
localStorage.setItem('token', token) // BAD

// ALWAYS httpOnly cookies
res.setHeader('Set-Cookie',
  `token=${token}; HttpOnly; Secure; SameSite=Strict; Max-Age=3600`)
```

---

## 8. Rate Limiting (all API endpoints)

```typescript
// Hono rate limit middleware
import { rateLimiter } from 'hono-rate-limiter'

app.use('/api/*', rateLimiter({
  windowMs: 60_000,
  limit: 100,
  keyGenerator: (c) => c.req.header('x-forwarded-for') ?? 'unknown'
}))

// Stricter on sensitive routes
app.use('/api/markets/create', rateLimiter({ windowMs: 60_000, limit: 5 }))
app.use('/api/auth/*', rateLimiter({ windowMs: 60_000, limit: 10 }))
```

---

## Pre-Deployment Checklist

- [ ] No hardcoded secrets
- [ ] All inputs Zod-validated
- [ ] RLS enabled on all Supabase tables
- [ ] Wallet signatures verified with nonce
- [ ] Smart contracts: CEI pattern, nonReentrant, no tx.origin
- [ ] AA: paymaster whitelist, explicit gas limits
- [ ] Auth tokens in httpOnly cookies
- [ ] Rate limiting on all endpoints
- [ ] HTTPS enforced
- [ ] CSP headers configured
- [ ] Error messages don't leak stack traces or SQL
- [ ] `npm audit` clean
- [ ] Foundry `forge test` passing with coverage >80%
