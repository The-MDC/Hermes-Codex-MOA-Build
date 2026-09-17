# Git configuration in `vercel.json` / `vercel.ts`

Source: `/docs/project-configuration/git-configuration` (updated 2025-12-19).

Every option below works in `vercel.json` (static configuration) or `vercel.ts` (programmatic configuration).

---

## `git.deploymentEnabled`

**Type:** `Object` of branch identifier `String` → `Boolean`, **or** a plain `Boolean`.
**Default:** `true` — any unspecified branch deploys.

Specify branches that should not trigger a deployment on commit.

```json
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "git": { "deploymentEnabled": { "dev": false } }
}
```

```typescript
import type { VercelConfig } from '@vercel/config/v1';

export const config: VercelConfig = {
  git: { deploymentEnabled: { dev: false } },
};
```

### Matching multiple branches

[Minimatch syntax](https://github.com/isaacs/minimatch) is supported. This blocks every branch starting with `internal-`:

```json
{ "git": { "deploymentEnabled": { "internal-*": false } } }
```

### Precedence when rules overlap — read this carefully

**If a branch matches multiple rules and at least one rule is `true`, a deployment occurs.**

```json
{ "git": { "deploymentEnabled": { "experiment-*": false, "*-dev": true } } }
```

A branch named `experiment-my-branch-dev` **will** deploy. `true` wins. This is the opposite of what most people assume from firewall-style rule ordering, and it is a common source of "why did that branch deploy."

### Turning off all automatic deployments

```json
{ "git": { "deploymentEnabled": false } }
```

Required when building in GitHub Actions, otherwise both systems deploy on the same push. A repo wired to Actions usually has exactly this — **check for it before concluding the integration is broken.**

---

## `github.autoJobCancelation`

**Type:** `Boolean`. (Note the spelling — one `l`. Vercel's key, not a typo here.)

By default, if a build for an earlier commit on the same branch is still running, that build completes, newer commits queue, and when the first finishes only the **most recent** commit deploys — the rest are cancelled. Intended behaviour, not a fault.

Set to `false` to always build pushes in sequence without cancelling.

```json
{ "$schema": "https://openapi.vercel.sh/vercel.json", "github": { "autoJobCancelation": false } }
```

No GitLab or Bitbucket equivalent.

---

## `github.autoAlias`

**Type:** `Boolean`.

When `false`, Vercel for GitHub creates **preview** deployments upon merge rather than aliasing to production.

> **Vercel's own warning:** follow the [staged production build](https://vercel.com/docs/deployments/promoting-a-deployment#staging-and-promoting-a-production-deployment) workflow instead of using this setting.

```json
{ "$schema": "https://openapi.vercel.sh/vercel.json", "github": { "autoAlias": false } }
```

Treat this as legacy in practice. If deployments are building but not going live on the custom domain, check this **and** the Auto-assign Custom Production Domains setting (Settings → Environments → Production → Branch Tracking) — both produce an identical symptom.

---

## Legacy / deprecated

### `github.silent` — deprecated

Replaced by dashboard settings offering finer control over which comments appear. Project → Settings → Git → Connected Git Repository → toggles.

**Type:** `Boolean`. When `true`, Vercel stops commenting on pull requests and commits.

```json
{ "github": { "silent": true } }
```

If you previously used this property, Vercel migrates the dashboard setting for you automatically.

It is **not currently possible to prevent comments for specific branches.**

### `github.enabled` — deprecated

Replaced by `git.deploymentEnabled`.

**Type:** `Boolean`. When `false`, Vercel will not deploy the project regardless of the GitHub App being installed.

```json
{ "github": { "enabled": false } }
```

**Extra gotcha the modern flag does not share:** `github.enabled: false` also **blocks deploy hooks**. If deploy hooks silently do nothing, look for this legacy key.

---

## Quick reference

| Key | Type | Default | Status |
|---|---|---|---|
| `git.deploymentEnabled` | `Object`/`Boolean` | `true` | Current |
| `github.autoJobCancelation` | `Boolean` | `true` | Current |
| `github.autoAlias` | `Boolean` | `true` | Current, discouraged |
| `github.silent` | `Boolean` | `false` | **Deprecated** → dashboard |
| `github.enabled` | `Boolean` | `true` | **Deprecated** → `git.deploymentEnabled` |

Always include `"$schema": "https://openapi.vercel.sh/vercel.json"` — it gives editor validation and catches the `autoJobCancelation` spelling before it ships.
