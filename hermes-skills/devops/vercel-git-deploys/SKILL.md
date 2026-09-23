---
name: vercel-git-deploys
description: "Diagnose and operate Vercel deployments driven by Git (GitHub, GitLab, Bitbucket) — why a push didn't deploy, why a build is red, why a page 401s, how to promote or roll back, how to run builds in GitHub Actions, and how deployment protection interacts with custom domains. Use when a deploy is stuck, missing, reverted, erroring, or gated behind an unexpected login, when wiring a repo to Vercel, when a repo won't appear in the import list, when configuring vercel.json git options, Ignored Build Step, deploy hooks, or monorepo build skipping, and when a fix that went live silently disappears later. Triggers on \"Vercel\", \"vercel.json\", \"deploy hook\", \"preview deployment\", \"production branch\", \"promote to production\", \"instant rollback\", \"Ignored Build Step\", \"deployment protection\", \"why didn't my push deploy\", \"Vercel build failed\", \"vercel deploy --prebuilt\", \"VERCEL_ENV\", \"repo not showing in Vercel\"."
version: 1.0.0
author: "Anthropic — ported for Hermes Agent"
license: "Anthropic skill licence; see upstream"
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Vercel, Deploy, Rollback, Preview]
    category: devops
    related_skills: [vercel-for-github]
---

# Vercel + Git deployments

Operating and debugging Vercel projects that deploy from a Git repository. Verified against Vercel docs as of 2026-07-29.

## The one rule that explains most confusion

**A Vercel project has exactly one Git repository, and the repository is the source of truth.** Any deployment created outside that repo — CLI, REST API, `deploy_to_vercel` — goes live immediately but leaves the repo untouched. The next push to the production branch rebuilds from Git and silently reverts it.

If a fix "went live and then disappeared," this is why. Fix it in the repo, not in the deployment.

## Diagnose first: which layer is broken?

Work top down. Each layer has a distinct signature.

| Symptom | Layer | Go to |
|---|---|---|
| Push happened, no deployment appeared at all | Trigger | `references/why-no-deploy.md` |
| Deployment ran but state is `CANCELED` | Ignored Build Step / skip | `references/build-config.md` |
| Deployment state is `ERROR` | Build | Read the build log — see below |
| Deployment is `READY` but the URL 401s / 403s / shows a login | Protection | `references/deployment-protection.md` |
| Deployment is `READY` but the domain serves old content | Promotion / rollback | `references/promotion-and-rollback.md` |
| Deployment is `READY`, content is current, but a file is missing or stale | Drift | Compare deployed bytes against the repo — see below |
| Repo doesn't appear in Vercel's import list | Access | `references/access-and-permissions.md` |

### Reading the build log

A build can report `READY` while the log contains errors. TypeScript diagnostics in `middleware.ts` are the classic case — they print as `error TSxxxx` and the build still completes. Never treat "the deploy is green" as "the log is green"; read the log explicitly.

Common red lines and their fixes are in `references/build-config.md`.

### Detecting drift between repo and production

Production serves build output, not source. To confirm a specific file is what you think it is:

```bash
curl -s -o /tmp/live.html -w '%{http_code} %{size_download}\n' https://<domain>/<path>
```

Compare the byte count against the file in the repo. A large discrepancy usually means the committed file is a stub, a pointer, or an LFS object that was never resolved. Crawl the whole tree to find what actually exists:

```bash
for f in index.html app.html vercel.json middleware.ts README.md robots.txt favicon.ico; do
  printf '%-24s %s\n' "$f" "$(curl -s -o /dev/null -w '%{http_code}' https://<domain>/$f)"
done
```

Note what this cannot see: `vercel.json`, `middleware.ts`, and anything not served are 404 from the outside even though they exist in the repo and shape every response. Infer them from response headers instead — see `references/deployment-protection.md` for reading a protection scheme off its headers.

## Never reconstruct a file tree from the outside

Deploying via CLI or API replaces the entire deployment with the file set you supply. Anything you omit is gone from that deployment. Since `middleware.ts` and `vercel.json` are never served, a tree rebuilt by crawling the live site will silently drop them — taking auth gates and security headers with it.

If you cannot read the repo, do not deploy. Hand the files to someone who can commit.

## Environment variables you will actually use

`VERCEL_ENV` (`production` | `preview` | `development`), `VERCEL_GIT_COMMIT_REF` (branch), `VERCEL_GIT_COMMIT_SHA`, `VERCEL_URL`, `VERCEL_PROJECT_PRODUCTION_URL`, `VERCEL_GIT_PREVIOUS_SHA` (only exposed when an Ignored Build Step is configured).

`VERCEL_URL` cannot be used with Standard Deployment Protection — the generated URL stops being publicly reachable. Full list and caveats in `references/system-env-vars.md`.

## Reference files

- `references/why-no-deploy.md` — the full checklist for a push that produced nothing
- `references/access-and-permissions.md` — who can import a repo, per provider; the exact permission scopes Vercel requests; diagnosing a repo that won't appear
- `references/build-config.md` — Build & Deployment settings, Root Directory, Ignored Build Step (inverted exit codes), monorepo skipping, shallow clone
- `references/promotion-and-rollback.md` — staged production builds, promote, instant rollback, and the auto-assign trap
- `references/deployment-protection.md` — Vercel Authentication, Password Protection, Trusted IPs, protection scopes vs custom domains, bypass for automation
- `references/github-actions.md` — complete preview and production workflows, `--prebuilt` tradeoffs, avoiding double deploys
- `references/vercel-json.md` — git configuration options with exact semantics
- `references/system-env-vars.md` — every system environment variable, when it is available
- `references/other-providers.md` — what GitLab and Bitbucket do not have

## Working checklist for "make production green"

1. Identify the project, the connected repo, and the production branch.
2. Pull the latest production deployment: state, source (`git` vs `upload`), commit SHA.
3. Read the build log end to end. Note every error line, including ones that didn't fail the build.
4. Fetch the live URL. Record status code, byte size, and response headers.
5. Compare against the repo. Confirm the committed file is the file you expect.
6. Fix in the repo. Commit. Push.
7. Re-verify: new deployment `READY`, build log clean, live bytes correct, protection behaving as intended.

Step 7 is the one people skip. A deployment reaching `READY` proves the build finished, nothing more.
