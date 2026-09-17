# Building on GitHub Actions instead of Vercel

## When this is worth it

Only for the four things Vercel's build does not run: a test suite, security scans / SBOM / vulnerability detection, performance budget gates, and a human approval step for compliance. It is also **required** for GitHub Enterprise Server, which cannot use the native Git integration.

Otherwise use the native integration. Moving builds off Vercel costs you managed build caching, automatic PR comments, full Git metadata, and auto-configured Turborepo remote caching.

## Required secrets

- **`VERCEL_TOKEN`** — create in account settings or with `vercel tokens add`. Scope it: `vercel tokens add --project`.
- **`VERCEL_ORG_ID`** and **`VERCEL_PROJECT_ID`** — from `.vercel/project.json` after `vercel login` && `vercel link` (fields `orgId` and `projectId`).

## Prevent double deploys — do this first

Without it, both Vercel's Git integration and your workflow fire on the same push and you get two deployments per commit.

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

For tag-triggered production, replace `on.push.branches` with `on.push.tags: ['*']`.

## `--prebuilt` tradeoffs

- **System environment variables are missing at build time**, because the build runs outside Vercel. Frameworks that read them during build will misbehave. If you need them, do not use `--prebuilt`.
- Next.js Skew Protection works with `--prebuilt` only via a custom deployment ID, and **cannot use the `dpl_` prefix**.
- Pair with `--archive=tgz` to avoid the files limit on large trees. Note `--archive` can make deploys *slower*, since it defeats source-file upload caching.
- `vercel build` defaults to **preview** environment variables. Pass `--prod` or `--target=production`.
- Run `vercel pull` before `vercel build` so settings and variables are cached locally.

## Triggering on deployment status

Modern approach — Vercel sends `repository_dispatch` events:

```yaml
on:
  repository_dispatch:
    types:
      - 'vercel.deployment.success'
```

Available types: `ready`, `success`, `error`, `canceled`, `ignored`, `skipped`, `pending`, `failed`, `promoted` (each prefixed `vercel.deployment.`).

The payload is at `github.event.client_payload` — deployment `url` and `environment` among others.

**The workflow file must exist on the default branch** for `repository_dispatch` to trigger. Add a `workflow_dispatch` trigger if you want to test before merging.

Migrating from the older `deployment_status` event:

```diff
- deployment_status:
+ repository_dispatch:
+   types: ['vercel.deployment.success']
-  BASE_URL: ${{ github.event.deployment_status.environment_url }}
+  BASE_URL: ${{ github.event.client_payload.url }}
```

You can disable `deployment_status` events in Project → Settings → Git if the activity-log noise on PRs is a problem — but check nothing depends on them first.

## E2E tests against a protected preview

Pass the bypass secret:

```yaml
env:
  BASE_URL: ${{ github.event.deployment_status.target_url }}
  VERCEL_AUTOMATION_BYPASS_SECRET: ${{ secrets.VERCEL_AUTOMATION_BYPASS_SECRET }}
```

Prefer **Trusted Sources** (Settings → Deployment Protection → Trusted Sources) over a static secret for new setups — short-lived OIDC scoped to account, repo, and branch.

## Gating production on Actions

Link the project to GitHub, enable automatic aliasing in the production environment settings, then Deployment Checks → **Add Checks** → provider **GitHub** → select required workflows.

## Documented pitfalls

1. Building in Actions **without** `--prebuilt` — Vercel rebuilds the same artifact.
2. Both systems deploying on one push — set `git.deploymentEnabled: false`.
3. Missing branch URLs and Git metadata — CLI deployments do not carry full `gitSource`.
4. Missing system environment variables at build time.
5. Deploy auth still needs a static `VERCEL_TOKEN`; there is no OIDC for it yet.

## Does a CLI or API deploy disconnect Git?

**No.** Disconnection is only ever an explicit action — Settings → Git → Disconnect, or `vercel git disconnect`. The Git integration stays fully active, which is exactly why `git.deploymentEnabled: false` is needed to stop double deploys.

But the next push to the production branch **will** produce a new production deployment that supersedes whatever the CLI deploy aliased. A CLI-shipped fix that is not in the repo does not survive the next push.
