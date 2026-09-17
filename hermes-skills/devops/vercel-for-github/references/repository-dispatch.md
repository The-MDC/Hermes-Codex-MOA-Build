# Deployment events: `repository_dispatch`

Source: `/docs/git/vercel-for-github#repository-dispatch-events` and `/kb/guide/how-can-i-run-end-to-end-tests-after-my-vercel-preview-deployment`.

Vercel sends GitHub `repository_dispatch` events when a deployment's status changes. These trigger Actions workflows, enabling CI that depends on a real deployed URL.

## The nine event types

```yaml
on:
  repository_dispatch:
    types:
      - 'vercel.deployment.ready'
      - 'vercel.deployment.success'
      - 'vercel.deployment.error'
      - 'vercel.deployment.canceled'
      - 'vercel.deployment.ignored'    # canceled by the Ignored Build Step
      - 'vercel.deployment.skipped'    # canceled by monorepo unaffected-project skipping
      - 'vercel.deployment.pending'
      - 'vercel.deployment.failed'
      - 'vercel.deployment.promoted'
```

`ignored` and `skipped` are distinct on purpose — `ignored` means *your* Ignored Build Step script aborted the build; `skipped` means Vercel's monorepo change detection decided the project was unaffected. Diagnosing a "missing" deploy often comes down to which of the two fired.

## The hard constraint

**The workflow file must exist on the default branch** (e.g. `main`) for `repository_dispatch` to trigger it. Testing a dispatch-triggered workflow from a feature branch does nothing.

Workaround while iterating: add a `workflow_dispatch` trigger alongside it so you can fire it manually before merging.

## Payload

The event carries a JSON payload reachable at `github.event.client_payload`:

| Path | Contents |
|---|---|
| `github.event.client_payload.url` | The deployment URL that triggered the event |
| `github.event.client_payload.environment` | `production` / `preview` / custom |
| `github.event.client_payload.git.sha` | Commit SHA — check this out so tests match the deployed code |

Full schema: `https://github.com/vercel/repository-dispatch/blob/main/packages/repository-dispatch/src/types.ts`

## E2E tests against the preview Vercel just shipped

```yaml
name: Playwright Tests

on:
  repository_dispatch:
    types:
      - 'vercel.deployment.success'

jobs:
  run-e2es:
    if: github.event_name == 'repository_dispatch'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.client_payload.git.sha }}

      - name: Install dependencies
        run: npm ci && npx playwright install --with-deps

      - name: Run tests
        run: npx playwright test
        env:
          BASE_URL: ${{ github.event.client_payload.url }}
```

Checking out `client_payload.git.sha` rather than the default ref matters: without it you test the tip of the default branch against a preview built from a different commit.

## Migrating from `deployment_status`

`repository_dispatch` reduces both Actions minutes and workflow complexity — you filter by dispatch type instead of running a job and discarding it with an `if`.

```diff
 name: End to End Tests

 on:
-  deployment_status:
+  repository_dispatch:
+    types:
+      - 'vercel.deployment.success'
 jobs:
   run-e2es:
-    if: github.event_name == 'deployment_status' && github.event.deployment_status.state == 'success'
+    if: github.event_name == 'repository_dispatch'
     runs-on: ubuntu-latest
     steps:
       - uses: actions/checkout@v6
       - name: Install dependencies
         run: npm ci && npx playwright install --with-deps
       - name: Run tests
         run: npx playwright test
         env:
-          BASE_URL: ${{ github.event.deployment_status.environment_url }}
+          BASE_URL: ${{ github.event.client_payload.url }}
```

Field mapping when migrating:

| `deployment_status` | `repository_dispatch` |
|---|---|
| `github.event.deployment_status.environment_url` | `github.event.client_payload.url` |
| `github.event.deployment_status.target_url` | `github.event.client_payload.url` |
| `github.event.deployment_status.state == 'success'` | dispatch type `vercel.deployment.success` |
| `github.event.deployment_status.environment` | `github.event.client_payload.environment` |

## Silencing `deployment_status` noise

By default Vercel notifies GitHub via the `deployment_status` webhook, which writes an entry into the PR activity log. Combined with Vercel's own PR comment, this accumulates noise.

Disable at Project → Settings → Git → **`deployment_status` Events** toggle.

**Check nothing depends on it first.** If any workflow still triggers on `deployment_status`, migrate it to `repository_dispatch` before flipping the toggle.

## Reaching a protected preview from CI

If Deployment Protection is enabled, the test runner gets a 401 against the URL it was just handed.

1. **Protection Bypass for Automation** — generate in the project's Deployment Protection settings, store as a repo secret, pass through:

```yaml
env:
  BASE_URL: ${{ github.event.client_payload.url }}
  VERCEL_AUTOMATION_BYPASS_SECRET: ${{ secrets.VERCEL_AUTOMATION_BYPASS_SECRET }}
```

2. **Trusted Sources** (Settings → Deployment Protection → Trusted Sources) — short-lived OIDC scoped to account, repo, and branch. Preferred for new setups; no long-lived shared secret to rotate or leak.

## Non-GitHub CI

Configure a Vercel webhook on the `deployment.succeeded` event and trigger your pipeline from that instead.
