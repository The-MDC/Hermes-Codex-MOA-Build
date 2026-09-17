# A push produced no deployment

Work the list in order. Each item is a real, documented cause.

## 1. `git.deploymentEnabled` is off for that branch

In `vercel.json`:

```json
{ "git": { "deploymentEnabled": { "dev": false } } }
```

Type: object of branch → boolean, **or** a plain boolean. Default `true`.

- Minimatch globs are supported: `{"internal-*": false}`.
- **If a branch matches multiple rules and at least one is `true`, a deployment occurs.** So `{"experiment-*": false, "*-dev": true}` still deploys `experiment-my-branch-dev`.
- `{ "git": { "deploymentEnabled": false } }` disables all automatic deployments. A repo wired to GitHub Actions usually has exactly this — check before assuming the integration is broken.
- The legacy `github.enabled: false` does the same thing and is deprecated. It also **blocks deploy hooks**, which the modern flag's interaction with deploy hooks does not document.

## 2. Ignored Build Step exited 0

**Exit codes are inverted from Unix convention.**

- exit `0` → build **aborted**, deployment state `CANCELED`
- exit `1` or greater → build **proceeds**

A script written normally, where `0` means success, skips every commit on every branch. This is the single most common silent failure.

Details, dropdown options, and diff-baseline traps: `build-config.md`.

## 3. Monorepo unaffected-project skipping

On by default for GitHub-connected projects using npm/yarn/pnpm/Bun workspaces. A project is considered changed only if its own source changed, one of its declared internal dependencies changed, or a lockfile change affects only its dependencies.

Common cause of a false skip: **inter-package dependencies not declared** in `package.json`. If `app` uses `ui` but doesn't list it as a dependency, editing `ui` will not rebuild `app`.

Disable at Settings → Build and Deployment → Root Directory → **Skip deployment** toggle → Save.

Unlike the Ignored Build Step, this evaluates *before* a build slot is claimed, so it does not consume quota or concurrency.

## 4. Commit SHA already deployed

If the SHA was deployed before, Vercel returns the existing deployment rather than building again. Rebases and force-pushes that rewrite history defeat this.

## 5. The commit author lacks project access (private repos)

Commits on private repos only deploy if the commit author also has access to the Vercel project. Applies to **GitHub organizations, GitLab groups, and non-personal Bitbucket workspaces** — not to collaborators on personal Git accounts.

- **Pro team**: the commit author must be a team member. Resolved through Login Connections.
- **Hobby team**: you cannot deploy to Hobby from a private repo in a GitHub org / GitLab group / Bitbucket workspace at all. The commit author must be the Hobby team owner.

## 6. Fork protection is waiting on you

A PR from a fork requires authorization from you or a team member before it deploys. A link to authorize is posted as a comment on the PR. Skipped automatically if the commit author is already a Vercel team member.

Setting lives at Project → Settings → **Security** → Git fork protection. Docs warn: review your environment variables and `vercel.json` before disabling it.

CLI: `vercel project protection enable|disable <name> --git-fork-protection`

## 7. Require Verified Commits is on (GitHub only)

Project → Settings → Git → **Require Verified Commits**. When enabled, unverified commits are **automatically canceled**. Commits authored by tooling frequently show as `unverified` — check the commit's verification state in the deployment metadata before hunting elsewhere.

## 8. The project is in a rolled-back state

After an instant rollback, **Vercel turns off auto-assignment of production domains.** New pushes to the production branch build successfully but do not replace the rolled-back deployment. The deploy is not missing — it is staged and unpromoted.

Fix: dashboard **Undo Rollback**, or `vercel promote <deployment-id-or-url>`.

## 9. Auto-assign Custom Production Domains is disabled

Same visible symptom as #8, different cause. Set at Settings → Environments → Production → Branch Tracking. Also set implicitly by any `vercel --prod --skip-domain` deploy, which **overrides the project setting**.

Deployment shows state **Staged**. Promote it manually.

## 10. Build queue cancellation

If a build for an earlier commit on the same branch is still running, the current build completes and newer commits queue. When the first finishes, the **most recent** commit deploys and the rest are cancelled. Intended behaviour, not a fault.

Disable on GitHub with `{"github": {"autoJobCancelation": false}}` in `vercel.json`. No GitLab or Bitbucket equivalent.

## 11. The webhook is gone

If the integration was removed, or the repo was renamed, transferred, or made private after connection, the webhook may no longer fire. Reconnect at Project → Settings → Git → Connected Git Repository, or `vercel git connect`.
