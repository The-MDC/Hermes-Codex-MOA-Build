---
name: api-design
description: "> REST API design patterns — resource naming, HTTP methods, status codes, pagination, filtering, error response format, versioning, and rate limiting for production APIs. Use when designing new API endpoints, reviewing existing contracts, planning versioning, adding pagination or filtering, or building public/partner-facing APIs. Triggers on \"design API\", \"API endpoint\", \"REST\", \"pagination\", \"API versioning\", \"error format\"."
version: 1.0.0
author: "Anthropic — ported for Hermes Agent by MADHATs"
license: "Anthropic skill licence; see upstream"
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [REST, API, Pagination, Versioning, HTTP]
    category: software-development
    related_skills: [backend-patterns, frontend-design, mcp-builder, mcp-server-patterns, verification-loop]
---

# API Design Patterns

## Resource URLs

```
GET    /api/v1/markets           # List
GET    /api/v1/markets/:id       # Single
POST   /api/v1/markets           # Create → 201 + Location header
PATCH  /api/v1/markets/:id       # Update
DELETE /api/v1/markets/:id       # Delete → 204

# Sub-resources
GET    /api/v1/markets/:id/positions
POST   /api/v1/markets/:id/positions

# Actions (verbs only when CRUD doesn't fit)
POST   /api/v1/markets/:id/settle
POST   /api/v1/auth/refresh
```

**Rules**: plural, kebab-case, no verbs in resource URLs.

## Status Codes

| Code | Use |
|---|---|
| 200 | GET, PATCH success with body |
| 201 | POST created — include `Location` header |
| 204 | DELETE, PUT with no body |
| 400 | Malformed JSON, missing required fields |
| 401 | Missing or invalid auth |
| 403 | Authenticated but unauthorized |
| 404 | Resource not found |
| 409 | Conflict (duplicate, state violation) |
| 422 | Valid JSON but semantically invalid |
| 429 | Rate limit — include `Retry-After` header |
| 500 | Unexpected server error — never expose details |

## Response Format

```typescript
// Success
{ "data": { "id": "...", "title": "...", "status": "active" } }

// Collection
{
  "data": [...],
  "meta": { "total": 142, "page": 1, "per_page": 20, "total_pages": 8 },
  "links": { "next": "/api/v1/markets?page=2", "last": "..." }
}

// Error
{
  "error": {
    "code": "validation_error",
    "message": "Request validation failed",
    "details": [{ "field": "resolutionDate", "message": "Must be a future date" }]
  }
}
```

## Pagination

**Cursor-based** (recommended for feeds, large datasets, infinite scroll):
```
GET /api/v1/markets?cursor=eyJpZCI6MTIzfQ&limit=20
Response: { "data": [...], "meta": { "has_next": true, "next_cursor": "eyJpZCI6MTQzfQ" } }
```

**Offset-based** (admin dashboards, small datasets):
```
GET /api/v1/markets?page=2&per_page=20
```

## Filtering + Sorting

```
GET /api/v1/markets?status=active&category=entertainment
GET /api/v1/markets?volume[gte]=1000
GET /api/v1/markets?sort=-volume,created_at   # - prefix = descending
GET /api/v1/markets?q=election
GET /api/v1/markets?fields=id,title,status    # sparse fieldsets
```

## Rate Limit Headers

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640000000
Retry-After: 60   # on 429
```

## Versioning

- Use URL path versioning: `/api/v1/`, `/api/v2/`
- Non-breaking changes (adding fields, optional params, new endpoints) → no new version
- Breaking changes (removing/renaming fields, auth changes) → new version
- Announce deprecation 6 months before sunset
- Add `Sunset: Sat, 01 Jan 2027 00:00:00 GMT` header on deprecated endpoints

## Pre-Ship Checklist

- [ ] URL follows conventions (plural, kebab, no verbs)
- [ ] Correct HTTP method and status codes
- [ ] Input validated with Zod
- [ ] Error responses use standard format with error codes
- [ ] Pagination on all list endpoints
- [ ] Auth required or explicitly marked public
- [ ] Authorization checked (user owns resource)
- [ ] Rate limiting configured
- [ ] No stack traces or SQL errors in responses
- [ ] Consistent naming with existing endpoints
