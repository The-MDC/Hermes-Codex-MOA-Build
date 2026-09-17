# System environment variables

Source: `/docs/git/vercel-for-github#system-environment-variables`.

Exposed to deployments so workflows and APIs can branch on Git information.

**With `vercel build --prebuilt` in GitHub Actions, none of these are injected at build time** — the build runs outside Vercel. Frameworks that read them during build must have them set manually in the Actions environment.

## Platform

| Variable | Available at | Example |
|---|---|---|
| `VERCEL` | build + runtime | `1` — indicator that system env vars are exposed |
| `CI` | build | `1` — indicator of a CI environment |
| `VERCEL_ENV` | build + runtime | `production` \| `preview` \| `development` |
| `VERCEL_TARGET_ENV` | build + runtime | `production` \| `preview` \| `development` \| custom environment name |
| `VERCEL_REGION` | runtime | `cdg1` — region the app is running in |

## URLs

| Variable | Available at | Example |
|---|---|---|
| `VERCEL_URL` | build + runtime | `my-site.vercel.app` — generated deployment URL, **no** scheme |
| `VERCEL_BRANCH_URL` | build + runtime | `my-site-git-improve-about-page.vercel.app` |
| `VERCEL_PROJECT_PRODUCTION_URL` | build + runtime | `my-site.com` |

**`VERCEL_URL` cannot be used with Standard Deployment Protection** — the generated URL stops being publicly reachable. See Vercel's "Migrating to Standard Protection."

`VERCEL_PROJECT_PRODUCTION_URL` is the shortest production custom domain, or the `vercel.app` domain if none exists. **It is always set, even in preview deployments** — which makes it the right choice for generating links that must point at production, such as OG-image URLs. Reaching for `VERCEL_URL` there is a classic bug: OG images in previews end up pointing at the preview.

## Identity

| Variable | Available at | Example |
|---|---|---|
| `VERCEL_DEPLOYMENT_ID` | build + runtime | `dpl_7Gw5ZMBpQA8h9GF832KGp7nwbuh3` — used to implement Skew Protection |
| `VERCEL_PROJECT_ID` | build + runtime | `prj_Rej9WaMNRbffVm34MfDqa4daCEvZzzE` |
| `VERCEL_SKEW_PROTECTION_ENABLED` | build + runtime | `1` when enabled in Project Settings |
| `VERCEL_HASH_SALT` | build | `1783933175` — salt rotating filenames of content-addressed framework output |

## Secrets

| Variable | Available at | Notes |
|---|---|---|
| `VERCEL_AUTOMATION_BYPASS_SECRET` | build + runtime | The Protection Bypass for Automation value, if generated in Deployment Protection settings |
| `VERCEL_OIDC_TOKEN` | build | Set when Secure Backend Access with OIDC Federation is enabled. At runtime the token arrives on the `x-vercel-oidc-token` header of the function's `Request` object. Locally: `vercel env pull` |

## Git metadata

| Variable | Available at | Example |
|---|---|---|
| `VERCEL_GIT_PROVIDER` | build + runtime | `github` |
| `VERCEL_GIT_REPO_SLUG` | build + runtime | `my-site` |
| `VERCEL_GIT_REPO_OWNER` | build + runtime | `acme` |
| `VERCEL_GIT_REPO_ID` | build + runtime | `117716146` |
| `VERCEL_GIT_COMMIT_REF` | build + runtime | `improve-about-page` — branch |
| `VERCEL_GIT_COMMIT_SHA` | build + runtime | `fa1eade47b73733d6312d5abfad33ce9e4068081` |
| `VERCEL_GIT_COMMIT_MESSAGE` | build + runtime | `Update about page` — **truncated above 2048 bytes** |
| `VERCEL_GIT_COMMIT_AUTHOR_LOGIN` | build + runtime | `timmytriangle` |
| `VERCEL_GIT_COMMIT_AUTHOR_NAME` | build + runtime | `Timmy Triangle` |
| `VERCEL_GIT_PREVIOUS_SHA` | build | Last successful deployment SHA for this project + branch. **Only exposed when an Ignored Build Step is provided.** |
| `VERCEL_GIT_PULL_REQUEST_ID` | build + runtime | `23`. **Empty string** if the deployment was created on a branch before a PR existed |

Two traps worth flagging:

- `VERCEL_GIT_PREVIOUS_SHA` is the natural diff baseline for an Ignored Build Step, but it only exists *because* an Ignored Build Step is configured — you cannot read it anywhere else.
- `VERCEL_GIT_PULL_REQUEST_ID` being an empty string rather than unset breaks naive truthiness checks in shell scripts. Test for emptiness explicitly.
