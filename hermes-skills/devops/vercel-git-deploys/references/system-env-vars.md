# System environment variables

Exposed to deployments when **Automatically Expose System Environment Variables** is enabled. Without it, `VERCEL_*` is unavailable — including to Ignored Build Step scripts.

## Environment identity

| Variable | Available | Notes |
|---|---|---|
| `VERCEL` | build + runtime | `1` when system vars are exposed |
| `CI` | build | `1` |
| `VERCEL_ENV` | build + runtime | `production` \| `preview` \| `development` |
| `VERCEL_TARGET_ENV` | build + runtime | As above, or a custom environment name |
| `VERCEL_REGION` | runtime | e.g. `cdg1` |

## URLs

| Variable | Available | Notes |
|---|---|---|
| `VERCEL_URL` | build + runtime | Generated deployment URL, no scheme. **Cannot be used with Standard Deployment Protection** |
| `VERCEL_BRANCH_URL` | build + runtime | `*-git-*.vercel.app`, no scheme |
| `VERCEL_PROJECT_PRODUCTION_URL` | build + runtime | Shortest production custom domain, or the `.vercel.app` domain. **Always set, even in previews** — the reliable choice for links that must point at production, such as OG image URLs |

Framework prefixes apply: `NEXT_PUBLIC_VERCEL_URL`, `NUXT_ENV_VERCEL_URL`.

## Identifiers

| Variable | Available |
|---|---|
| `VERCEL_DEPLOYMENT_ID` | build + runtime |
| `VERCEL_PROJECT_ID` | build + runtime |
| `VERCEL_SKEW_PROTECTION_ENABLED` | build + runtime |
| `VERCEL_AUTOMATION_BYPASS_SECRET` | build + runtime |
| `VERCEL_OIDC_TOKEN` | build |
| `VERCEL_HASH_SALT` | build |

`VERCEL_OIDC_TOKEN` is also available at runtime as the `x-vercel-oidc-token` request header. Locally: `vercel env pull`.

## Git metadata

| Variable | Available | Notes |
|---|---|---|
| `VERCEL_GIT_PROVIDER` | build + runtime | |
| `VERCEL_GIT_REPO_SLUG` | build + runtime | |
| `VERCEL_GIT_REPO_OWNER` | build + runtime | |
| `VERCEL_GIT_REPO_ID` | build + runtime | |
| `VERCEL_GIT_COMMIT_REF` | build + runtime | Branch name |
| `VERCEL_GIT_COMMIT_SHA` | build + runtime | |
| `VERCEL_GIT_COMMIT_MESSAGE` | build + runtime | Truncated past 2048 bytes |
| `VERCEL_GIT_COMMIT_AUTHOR_LOGIN` | build + runtime | |
| `VERCEL_GIT_COMMIT_AUTHOR_NAME` | build + runtime | |
| `VERCEL_GIT_PULL_REQUEST_ID` | build + runtime | Empty string if the deployment predates the PR |
| `VERCEL_GIT_PREVIOUS_SHA` | build | **Only exposed when an Ignored Build Step is provided.** SHA of the last successful deployment for this project and branch |
| `VERCEL_RELATED_PROJECTS` | build + runtime | Only when `relatedProjects` is set in `vercel.json` |

`VERCEL_GIT_PREVIOUS_SHA` is the correct diff baseline for an Ignored Build Step. `HEAD^` is not — it drifts. See `build-config.md`.

`VERCEL_GIT_PROVIDER` is documented with the example value `github` on the GitLab and Bitbucket pages too; the docs were not updated per provider.

## Local development

```bash
vercel link
vercel env pull        # writes .env.local
```

`vercel pull` is different — it caches settings and variables into `.vercel/.env.<target>.local` for `vercel build` and `vercel dev`. If you are not running those commands, you do not need it.

```bash
vercel pull --environment=production
vercel pull --environment=preview --git-branch=feature-branch
vercel pull --environment=staging        # custom environment
```

Flag naming is inconsistent across commands: `vercel deploy --target=<env>`, `vercel pull --environment=<env>`, `vercel env add <KEY> <env>`.
