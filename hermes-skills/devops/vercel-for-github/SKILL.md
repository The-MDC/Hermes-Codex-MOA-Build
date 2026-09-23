---
name: vercel-for-github
description: "Operate the Vercel-GitHub integration and build Vercel CI/CD on GitHub Actions. Covers native Git deploys (production and preview branches, fork protection, PR comments), the GitHub App permission model, vercel.json git config, vercel pull/build/deploy --prebuilt workflows, repository_dispatch events, migrating off deployment_status, E2E tests against protected previews, Deployment Checks gating, Turborepo pipelines, and system environment variables. Use when wiring a repo to Vercel, when a push produced no deployment, after a repo rename breaks the webhook, when builds must run in Actions (GitHub Enterprise Server, tests, security scans, approval gates), when preview URLs 401 in CI, or when choosing between the native integration and a custom pipeline. Triggers on \"Vercel for GitHub\", \"GitHub Actions Vercel\", \"vercel deploy --prebuilt\", \"repository_dispatch\", \"vercel.deployment.success\", \"git.deploymentEnabled\", \"VERCEL_TOKEN\", \"GHES\", \"why didn't my push deploy\", \"repo not showing in Vercel\"."
version: 1.0.0
author: "Anthropic — ported for Hermes Agent"
license: "Anthropic skill licence; see upstream"
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Vercel, GitHub-Actions, CI, Deploy]
    category: devops
    related_skills: [vercel-git-deploys]
---

# Vercel for GitHub

Verified against Vercel docs `/docs/git/vercel-for-github` (updated 2026-05-28), `/docs/git` (2026-06-16), `/docs/project-configuration/git-configuration` (2025-12-19), and `/kb/guide/github-actions-vercel`. Retrieved 2026-07-30.

## Decide first: native integration or GitHub Actions?

**Default to the native Git integration.** It already gives you preview URLs per push, immutable deployments, instant rollback, PR comments, commit statuses, full Git metadata, managed build caching, and auto-configured Turborepo remote caching. Most teams need no pipeline at all.

Move builds into GitHub Actions **only** for one of these five reasons:

1. **GitHub Enterprise Server** — cannot use the native integration. Actions is mandatory.
2. **GitHub Enterprise Cloud with Data Residency on a unique subdomain** — also requires Actions.
3. A **test suite** that must gate the deploy.
4. **Security scans / SBOM / vulnerability detection**, or a **performance budget** gate.
5. A **human approval step** for compliance.

Everything you give up by moving off the native build is listed in `references/github-actions.md` under *What you lose*. Read it before committing to a pipeline — the list is longer than people expect.

## The rule that explains most confusion

**A Vercel project has exactly one Git repository, and the repository is the source of truth.**

Any deployment created outside that repo — CLI, REST API, direct file upload — goes live immediately but leaves the repo untouched. The next push to the production branch rebuilds from Git and silently supersedes it. If a fix "went live and then disappeared," this is why. Fix it in the repo.

Corollary: a CLI or API deploy does **not** disconnect Git. Disconnection is only ever explicit (Settings → Git → Disconnect, or `vercel git disconnect`). The integration stays live — which is exactly why `git.deploymentEnabled: false` is required to stop double deploys.

## Never reconstruct a file tree from the outside

`vercel deploy` replaces the entire deployment with the file set you supply. Anything omitted is gone from that deployment.

`middleware.ts` and `vercel.json` are **never served over HTTP**. A tree rebuilt by crawling the live site will silently drop them — taking auth gates, redirects, and security headers with it. If a site is behind a Basic-auth or middleware gate and you cannot read the repo, **do not deploy**. Hand the files to someone who can commit.

## Triage: which layer is broken?

Work top down. Each symptom has a distinct signature and one reference file.

| Symptom | Layer | Reference |
|---|---|---|
| Push happened, **no deployment appeared at all** | Trigger / webhook | `references/why-no-deploy.md` |
| Repo **doesn't appear** in Vercel's import list | Access | `references/permissions-and-access.md` |
| Deployment ran, state `CANCELED` | Ignored Build Step, job cancelation, or skipping | `references/why-no-deploy.md` |
| Deployment `READY` but URL 401s / shows a login | Protection | `references/github-actions.md` → *Protected previews* |
| Deployment `READY` but domain serves old content | Promotion / rollback state | `references/why-no-deploy.md` items 8–9 |
| Deployment `READY`, content current, **one file stale or a stub** | Drift | *Verify what actually shipped*, below |
| Two deployments per commit | Double-deploy | `references/git-configuration.md` → `git.deploymentEnabled` |
| CI can't reach the preview it just deployed | Bypass | `references/repository-dispatch.md` |

## The single most-missed cause: a renamed repo

If the repository was **renamed, transferred, or made private after** it was connected, the webhook may stop firing. Vercel does not error — it never hears about the commit, so there is no failed build to debug. `latestDeployment` simply stays frozen at the last commit that worked.

Fix: Project → Settings → Git → Connected Git Repository → **Disconnect**, then **Connect** the repo under its new name. Or `vercel git connect`. Then push any commit, or hit **Redeploy**.

After reconnecting, confirm the production branch survived the reconnect — it can reset to the repo's default branch.

## Verify what actually shipped

**A deployment reaching `READY` proves the build finished. Nothing more.** This is the step people skip.

```bash
# Byte-compare live output against what you believe you committed
curl -s -o /dev/null -w '%{http_code} %{size_download}\n' https://<domain>/<path>

# Crawl the tree for what exists vs. what 404s
for f in index.html app.html README.md robots.txt favicon.ico; do
  printf '%-24s %s\n' "$f" "$(curl -s -o /dev/null -w '%{http_code}' https://<domain>/$f)"
done
```

A large size discrepancy usually means the committed file is a stub, a pointer, or an unresolved LFS object. A 250-byte HTML file where you expect 250 KB is a placeholder someone committed and forgot.

Then check all four of these, in order:

1. New deployment is `READY` **and its commit SHA matches your push**.
2. Build log read **end to end** — a build can report `READY` with `error TSxxxx` lines in the log. TypeScript diagnostics in `middleware.ts` are the classic case.
3. Live bytes correct on every changed path.
4. Protection behaving as intended — gated URL returns `401` bare, `200` with credentials.

## Minimum viable Actions pipeline

Three secrets, then two workflow files. Full versions in `assets/workflows/`.

```bash
vercel login && vercel link          # writes .vercel/project.json
# VERCEL_ORG_ID     ← project.json .orgId
# VERCEL_PROJECT_ID ← project.json .projectId
vercel tokens add --project <name>   # VERCEL_TOKEN, scoped — never account-wide
```

**Do this first or you get two deployments per commit** — `vercel.json`:

```json
{ "$schema": "https://openapi.vercel.sh/vercel.json", "git": { "deploymentEnabled": false } }
```

The three-command core, in order — `pull` before `build` so settings and env vars are cached locally:

```bash
vercel pull --yes --environment=production --token=$VERCEL_TOKEN
vercel build --prod --token=$VERCEL_TOKEN
vercel deploy --prebuilt --prod --token=$VERCEL_TOKEN
```

Preview is the same three commands with `--environment=preview` and **no** `--prod` anywhere. `--prod` goes on **both** `build` and `deploy` for production — putting it only on `deploy` builds preview env vars into a production deployment, which is the quietest and nastiest failure in this whole area.

## Assets

Copy-ready workflow files, no placeholders beyond secret names:

- `assets/workflows/preview.yml` — preview on every non-`main` push
- `assets/workflows/production.yml` — production on `main` (tag-triggered variant included)
- `assets/workflows/e2e-repository-dispatch.yml` — Playwright against the preview Vercel just shipped
- `assets/workflows/turborepo-monorepo.yml` — build/test/lint gate, then fan out to preview or production
- `assets/vercel.json.example` — annotated git configuration block

## Reference files

- `references/github-actions.md` — full workflows, `--prebuilt` tradeoffs, what you lose, build caching, protected previews, Deployment Checks gating, multiple projects from one repo, security practices, every documented failure mode
- `references/repository-dispatch.md` — all 9 `vercel.deployment.*` event types, `client_payload` schema, migrating off `deployment_status`, E2E patterns, bypass secret vs Trusted Sources OIDC
- `references/git-configuration.md` — every `vercel.json` / `vercel.ts` git option with exact semantics, minimatch precedence, and deprecations
- `references/permissions-and-access.md` — the GitHub App permission table, personal vs organization repo rules, Outside Collaborator dead end, private-repo commit-author rules on Pro vs Hobby
- `references/native-integration.md` — per-push deploys, build queue cancelation, production branch selection and customization, preview branches and staging phases, custom environments, fork authorization, PR comments, commit statuses, deploying from a Git reference
- `references/why-no-deploy.md` — the ordered 11-cause checklist for a push that produced nothing
- `references/system-env-vars.md` — every system environment variable, its value shape, and whether it exists at build time, runtime, or both

## Note on overlap

If a `vercel-git-deploys` skill is also installed, it covers the same diagnostic ground at a shallower depth and spans GitLab/Bitbucket. This skill is GitHub-specific and deeper on the Actions pipeline, the App permission model, and the event system. Prefer this one for anything GitHub; there is no conflict in guidance.
