# The native Git integration

Source: `/docs/git/vercel-for-github` and `/docs/git`.

## A deployment for each push

Vercel for GitHub **deploys every push by default** — pushes and pull requests to any branch. This lets anyone in the repo preview changes before they reach production.

### Build queue behaviour

If Vercel is already building a previous commit on the same branch, the current build completes and commits pushed during that window are **queued**. When the first build finishes, the **most recent** commit deploys and the other queued builds are **cancelled**.

This is intended — it keeps the latest change live as fast as possible. It is also a frequent false alarm: a commit "didn't deploy" because a newer one superseded it.

Disable with `github.autoJobCancelation: false` in `vercel.json`.

## Production branch

A production deployment is created each time you merge to the **production branch**.

### Default selection order

1. `main`
2. `master`, if `main` is absent
3. *(Bitbucket only)* the repo's "production branch" setting
4. the Git repository's default branch

### Changing it

Project Settings → **Environments** → **Production** → **Branch Tracking** → change the branch name → **Save**.

Verify this after any repository reconnect — reconnecting can reset it to the repo's default branch, which produces "builds run but production never updates."

## Updating the production domain

When custom domains are set on the project, pushes and merges to the production branch go live on those domains with the latest deployment.

**Instant rollback:** revert a commit already deployed to production and the previous production deployment becomes available at the custom domain instantly. It is a pointer update at the domain alias level — no rebuild, no redeploy, no scale-down event, CDN cache intact. Requires no configuration.

Caveat: after an instant rollback, **Vercel turns off auto-assignment of production domains**. New pushes build successfully but do not replace the rolled-back deployment — they are *staged*, not missing. Fix with **Undo Rollback** in the dashboard, or `vercel promote <deployment-id-or-url>`.

## Preview branches

Every branch that is not the production branch is a preview branch (or a custom-environment branch, if configured). There can be many preview branches; there is exactly one production branch.

Each preview branch automatically receives its own generated domain on push.

### Preview URLs on pull requests

The latest push to any PR is made available at a unique preview URL derived from project name, branch, and team/username. Vercel posts it as a comment on the PR. Comments on preview deployments (the Vercel Toolbar DOM comments) are supported on GitHub PRs.

### Multiple preview phases (staging)

To accumulate changes before production without custom environments:

1. Create a branch named `staging`.
2. Assign a domain (`staging.example.com`) to that Git branch in the project's domain settings.
3. Add preview environment variables scoped to that branch.
4. Push to `staging` to update the phase — it picks up the domain and variables automatically.
5. When happy, merge into production but **keep the branch** so you can push to it again.

Pro teams can use **custom environments** instead, which allow matching specific branches or branch names (including `main`) to a named pre-production environment with its own domain.

## Deployment authorizations for forks

A PR from a fork of your repository requires authorization from you or a team member before it deploys — protection against leaking environment variables and the OIDC Token. Skipped if the commit author is already a Vercel team member. Toggle at Settings → Security → Git Fork Protection.

## GitHub surface: Deployments API, checks, Slack

Vercel uses GitHub's Deployments API, so all deployments — production and preview — appear on their own page inside GitHub, and integrate with **GitHub checks**. Vercel provides the deployment URL to checks that require it (e.g. Checkly). With the Slack GitHub app installed, deployment status also surfaces in Slack.

## Commit statuses

By default every commit receives a **GitHub Commit Status** per project it deploys — success, failure, or skipped.

**Monorepos** can enable a *consolidated* commit status to cut PR noise. Projects inside the consolidated status can additionally be marked **soft failures**, so a temporarily broken project does not block merges or fail the commit for everyone else.

Configure at Project → Settings → Git → Git Commits.

## Silencing PR comments

Project → **Settings** → **Git** → **Connected Git Repository** → toggle the switches.

The deprecated `github.silent` property is migrated to this setting automatically. **It is not currently possible to prevent comments for specific branches.**

## Silencing `deployment_status` activity-log entries

Vercel notifies GitHub via the `deployment_status` webhook, creating an entry in the PR activity log — noisy alongside Vercel's own PR comment.

Disable at Project → Settings → Git → `deployment_status` Events toggle. **Confirm no workflow depends on the event first**; migrate to `repository_dispatch` if one does.

## Creating a deployment from a Git reference

Useful precisely when automatic deployments are interrupted or unavailable — including a broken webhook after a rename.

1. Dashboard → select the project.
2. Sidebar → **Deployments** → **Create Deployment**.
3. Either:
   - **Targeted:** a commit SHA, to build that specific commit
   - **Branch-based:** a full branch name or URL (e.g. `https://github.com/vercel/examples/tree/deploy`) to build the latest commit on it
4. **Create Deployment**.

If the same commit exists on multiple branches, Vercel prompts you to choose the branch configuration — this matters because environment variables are linked per branch.

## Deploying without a supported provider

If the Git provider is not supported (or is self-hosted), use the Vercel CLI for custom workflows, or the provider-specific guides: GitHub Enterprise Server → GitHub Actions; self-managed GitLab → GitLab Pipelines; Bitbucket Data Center → Bitbucket Pipelines.
