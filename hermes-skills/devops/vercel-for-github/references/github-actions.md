# Building on GitHub Actions instead of Vercel

Source: `/docs/git/vercel-for-github#using-github-actions` and `/kb/guide/github-actions-vercel`.

## When this is worth it

Vercel's Git integration already handles preview URLs, immutable deploys, and instant rollback, so most teams need no pipeline at all. Add Actions only for:

- a **test suite** gating the deploy
- **security scans / SBOM / vulnerability detection**
- **performance budget** gates
- a **human approval step** for compliance

It is **required** for:

- **GitHub Enterprise Server (GHES)** — cannot use the native Git integration at all
- **GitHub Enterprise Cloud with Data Residency on a unique subdomain**

## What you lose

Moving builds off Vercel costs you:

- managed build caching (shifts to the Actions environment — your problem now)
- automatic PR comments with preview URLs (needs a custom step to post them)
- full Git metadata — **CLI deployments do not carry full `gitSource`**, so branch-specific URLs do not generate identically
- auto-configured Turborepo remote caching (set `TURBO_TOKEN` / `TURBO_TEAM` yourself)
- System Environment Variables at build time (see `--prebuilt` tradeoffs)

Unaffected either way, because they are deployment-level features: the Vercel Toolbar and DOM comments, Skew Protection, instant rollback, Fluid compute, and the 126-PoP global distribution.

## Required secrets

| Secret | Where it comes from |
|---|---|
| `VERCEL_TOKEN` | Account settings → Tokens, or `vercel tokens add`. **Scope it**: `vercel tokens add --project` |
| `VERCEL_ORG_ID` | `.vercel/project.json` → `orgId`, after `vercel login && vercel link` |
| `VERCEL_PROJECT_ID` | `.vercel/project.json` → `projectId` |

Reference as `${{ secrets.VERCEL_TOKEN }}`. Never hardcode.

## Prevent double deploys — do this first

Without it, both Vercel's Git integration and your workflow fire on the same push, giving two deployments per commit.

```json
{ "git": { "deploymentEnabled": false } }
```

## Preview workflow

```yaml
name: Vercel Preview Deployment
env:
  VERCEL_ORG_ID: ${{ secrets.VERCEL_ORG_ID }}
  VERCEL_PROJECT_ID: ${{ secrets.VERCEL_PROJECT_ID }}
on:
  push:
    branches-ignore:
      - main
jobs:
  Deploy-Preview:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Vercel CLI
        run: npm install --global vercel@latest
      - name: Pull Vercel Environment Information
        run: vercel pull --yes --environment=preview --token=${{ secrets.VERCEL_TOKEN }}
      - name: Build Project Artifacts
        run: vercel build --token=${{ secrets.VERCEL_TOKEN }}
      - name: Deploy Project Artifacts to Vercel
        run: vercel deploy --prebuilt --token=${{ secrets.VERCEL_TOKEN }}
```

## Production workflow

Two differences only: `--prod` on **both** `vercel build` and `vercel deploy`, and the trigger restricted to `main`.

```yaml
name: Vercel Production Deployment
env:
  VERCEL_ORG_ID: ${{ secrets.VERCEL_ORG_ID }}
  VERCEL_PROJECT_ID: ${{ secrets.VERCEL_PROJECT_ID }}
on:
  push:
    branches:
      - main
jobs:
  Deploy-Production:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Vercel CLI
        run: npm install --global vercel@latest
      - name: Pull Vercel Environment Information
        run: vercel pull --yes --environment=production --token=${{ secrets.VERCEL_TOKEN }}
      - name: Build Project Artifacts
        run: vercel build --prod --token=${{ secrets.VERCEL_TOKEN }}
      - name: Deploy Project Artifacts to Vercel
        run: vercel deploy --prebuilt --prod --token=${{ secrets.VERCEL_TOKEN }}
```

Tag-triggered production — replace the trigger, keep every `--prod`:

```yaml
on:
  push:
    tags: ['*']
```

## `--prebuilt` tradeoffs

`--prebuilt` decouples where the build runs from where it is hosted: the build runs on your Actions runner, and only the compiled `.vercel/output` folder uploads. Without it, **Vercel rebuilds the same artifact** — doubled CI minutes and slower feedback.

- **System environment variables are missing at build time**, because the build runs outside Vercel. Frameworks that read them during build will misbehave. Set them manually in Actions, or do not use `--prebuilt`.
- **Next.js Skew Protection** works with `--prebuilt` only via a custom deployment ID, which **cannot use the `dpl_` prefix**.
- Pair with `--archive=tgz` to avoid the files limit on large trees. Note `--archive` can make deploys *slower* — it defeats source-file upload caching.
- `vercel build` defaults to **preview** environment variables. Pass `--prod` or `--target=production`.
- Run `vercel pull` before `vercel build` so settings and variables are cached locally.

## Build caching

Managed caching is gone. Replace it:

- **Dependencies** — `actions/setup-node@v4` with the `cache` option (`cache: 'npm'` / `'pnpm'` / `'yarn'`).
- **Monorepos** — Turborepo remote caching via `TURBO_TOKEN` (secret) and `TURBO_TEAM` (var). Automatic on the native integration; your responsibility the moment builds move to Actions.

## Protected previews in CI

If Deployment Protection is on, CI cannot fetch the preview it just created. Two options:

1. `VERCEL_AUTOMATION_BYPASS_SECRET` — a static secret, generated in Deployment Protection settings, exposed as a system env var and passable as a header or query param.
2. **Trusted Sources** (Settings → Deployment Protection → Trusted Sources) — short-lived OIDC scoped to account, repo, and branch. **Preferred for new setups.**

## Gating production on Actions

1. Link the project to the GitHub repository.
2. Enable automatic aliasing in the production environment settings.
3. Open **Deployment Checks** settings.
4. **Add Checks** → provider **GitHub**.
5. Select which workflows must pass before production promotion.

## Multiple projects from one repository

Create one project-ID secret per project — `VERCEL_PROJECT_ID_APP`, `VERCEL_PROJECT_ID_DOCS`. Run `vercel link` against each to retrieve its ID. Each project deploys independently via its own workflow file or job.

## Documented failure modes

1. **Building in Actions without `--prebuilt`** — Vercel rebuilds the same artifact. Doubled CI minutes.
2. **Both systems deploying on one push** — set `git.deploymentEnabled: false`.
3. **Missing branch URLs and Git metadata** — CLI deployments do not carry full `gitSource`.
4. **Missing system environment variables at build time** — inherent to `--prebuilt`.
5. **No OIDC for deploy auth** — Vercel does not support OIDC for the deployment itself yet. A static `VERCEL_TOKEN` is still required. (OIDC *is* available for Trusted Sources / backend access — different thing.)

## Security practices

- Scope tokens to a team or project: `vercel tokens add --project`.
- Use GitHub environment protection rules to require approval on production deploys.
- Prefer Trusted Sources OIDC over a static `VERCEL_AUTOMATION_BYPASS_SECRET`.
- Rotate tokens when team members leave.
- Vercel audit logs track team activity and security-relevant events; Enterprise can stream to Datadog, Splunk, S3, Google Cloud Storage, or a custom HTTP endpoint.

## Does a CLI or API deploy disconnect Git?

**No.** Disconnection is only ever explicit — Settings → Git → Disconnect, or `vercel git disconnect`. The Git integration stays fully active, which is precisely why `git.deploymentEnabled: false` is needed to stop double deploys.

But the next push to the production branch **will** create a production deployment that supersedes whatever the CLI deploy aliased. A CLI-shipped fix that is not in the repo does not survive the next push.
