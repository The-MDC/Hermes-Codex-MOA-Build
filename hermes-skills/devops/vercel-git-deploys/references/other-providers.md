# GitLab and Bitbucket — what differs from GitHub

Everything not listed here behaves identically: deploy-on-every-push, build queueing and cancellation, instant rollback, preview URL per PR posted as a comment, and repo disconnection via Settings → Git.

## GitLab

**Access to import:** Maintainer on the repository, **and Maintainer on the group** if the repo belongs to one. Both.

**Permissions:** a single `API` scope, read and write — all groups and projects, container registry, package registry. No granular scopes.

**Not available:**

- `github.*` options in `vercel.json` — including `autoJobCancelation`. Auto-cancellation still happens; there is no opt-out.
- Require Verified Commits (GitHub only)
- Monorepo unaffected-project skipping (GitHub only) — you must use the Ignored Build Step, which *does* consume build slots and quota
- Checks, Deployments API, commit statuses, consolidated commit status
- `repository_dispatch` and `deployment_status` events
- The preview-deployment Comments integration on merge requests — you get a plain bot comment with the URL
- `VERCEL_HASH_SALT` is absent from the GitLab system env var list

**Provider-specific gotcha, documented by Vercel:** a GitLab merge pipeline can fail while the branch pipeline succeeds, **allowing merge requests to merge with failing tests**. This is a GitLab issue. Vercel's recommendation is to deploy via the CLI instead.

**Self-managed GitLab** is supported only through GitLab Pipelines running `vercel build` + `vercel deploy --prebuilt`, not the native integration.

## Bitbucket

**Access to import:** **Admin** access configured for the repository.

**Permissions:** `Web Hooks` is read-only (GitHub has write). `Issues` read/write, required alongside Pull Requests. `Pull requests` read/write. Organization `Team` read. User `Account` read. No Checks, Deployments, Commit Statuses, Administration, Contents, or Metadata scopes — so commit-status and checks integration is not possible.

**Bitbucket-only behaviour:** the production branch resolution order includes an extra step. `main` → `master` → **the repository's own "production branch" setting** → repository default branch. No other provider has this.

**Not available:** the same list as GitLab — Verified Commits, monorepo skipping, `github.*` config, commit statuses, checks, dispatch events, preview Comments integration.

**Bitbucket Data Center (self-hosted)** is supported only through Bitbucket Pipelines with `vercel build` + `vercel deploy --prebuilt`.

## GitHub Enterprise Server

Cannot use the native Git integration at all. Use GitHub Actions — see `github-actions.md`. The same applies to GitHub Enterprise Cloud when using Data Residency with a unique subdomain.

## Any other provider

Deploy with the Vercel CLI from whatever CI you have. You lose preview URLs per branch, PR comments, and full Git metadata, but builds and deployments work.
