# A push produced no deployment

Work the list in order. Every item is a real, documented cause.

## 1. The webhook is gone — start here after any repo change

If the integration was removed, or the repo was **renamed, transferred, or made private** after connection, the webhook may no longer fire.

Signature: Vercel does not error. There is no failed build to debug because there is no build. `latestDeployment` stays frozen at the last commit that worked, while GitHub shows your new commits sitting on the branch.

Fix: Project → Settings → Git → Connected Git Repository → Disconnect, then Connect the repo under its current name. Or `vercel git connect`. Then push, or use **Create Deployment** from a Git reference to ship immediately.

After reconnecting, re-check the production branch (Settings → Environments → Production → Branch Tracking) — it can reset.

## 2. `git.deploymentEnabled` is off for that branch

```json
{ "git": { "deploymentEnabled": { "dev": false } } }
```

Type: object of branch → boolean, or a plain boolean. Default `true`.

- Minimatch globs supported: `{"internal-*": false}`.
- **If a branch matches multiple rules and at least one is `true`, a deployment occurs.** So `{"experiment-*": false, "*-dev": true}` still deploys `experiment-my-branch-dev`.
- `{ "git": { "deploymentEnabled": false } }` disables all automatic deployments. A repo wired to GitHub Actions usually has exactly this — check before assuming the integration is broken.
- Legacy `github.enabled: false` does the same and is deprecated. It **also blocks deploy hooks**, which the modern flag does not.

## 3. Ignored Build Step exited 0

**Exit codes are inverted from Unix convention.**

- exit `0` → build **aborted**, deployment state `CANCELED`
- exit `1` or greater → build **proceeds**

A script written normally, where `0` means success, skips every commit on every branch. The single most common silent failure. Fires a `vercel.deployment.ignored` dispatch event.

## 4. Monorepo unaffected-project skipping

On by default for GitHub-connected projects using npm/yarn/pnpm/Bun workspaces. A project counts as changed only if its own source changed, a declared internal dependency changed, or a lockfile change affects only its dependencies.

Most common false skip: **inter-package dependencies not declared** in `package.json`. If `app` uses `ui` but does not list it as a dependency, editing `ui` will not rebuild `app`.

Disable at Settings → Build and Deployment → Root Directory → **Skip deployment** toggle → Save.

Evaluates *before* a build slot is claimed, so it consumes no quota or concurrency. Fires `vercel.deployment.skipped`.

## 5. Commit SHA already deployed

If the SHA was deployed before, Vercel returns the existing deployment rather than building again. Rebases and force-pushes that rewrite history defeat this.

## 6. The commit author lacks project access (private repos)

Commits on private repos deploy only if the commit author also has access to the Vercel project. Applies to GitHub organizations, GitLab groups, and non-personal Bitbucket workspaces — not to collaborators on personal Git accounts.

- **Pro team:** the commit author must be a team member, resolved through Login Connections.
- **Hobby team:** you cannot deploy to Hobby from a private repo in an org/group/workspace at all. The commit author must be the Hobby team owner.

## 7. Fork protection is waiting on you

A PR from a fork requires authorization from you or a team member before it deploys. The authorization link is posted as a PR comment. Skipped automatically if the commit author is already a Vercel team member.

Settings → **Security** → Git fork protection. Review environment variables and `vercel.json` before disabling.

CLI: `vercel project protection enable|disable <name> --git-fork-protection`

## 8. Require Verified Commits is on (GitHub only)

Project → Settings → Git → **Require Verified Commits**. When enabled, unverified commits are **automatically canceled**.

Commits authored by tooling — and commits created through GitHub's web "Add files via upload" flow in some configurations — frequently show as `unverified`. Check the commit's verification state in the deployment metadata before hunting elsewhere.

## 9. The project is in a rolled-back state

After an instant rollback, **Vercel turns off auto-assignment of production domains.** New pushes to the production branch build successfully but do not replace the rolled-back deployment. The deploy is not missing — it is staged and unpromoted.

Fix: dashboard **Undo Rollback**, or `vercel promote <deployment-id-or-url>`.

## 10. Auto-assign Custom Production Domains is disabled

Same visible symptom as #9, different cause. Settings → Environments → Production → Branch Tracking. Also set implicitly by any `vercel --prod --skip-domain` deploy, which **overrides the project setting**.

Deployment shows state **Staged**. Promote it manually.

## 11. Build queue cancellation

If a build for an earlier commit on the same branch is still running, the current build completes and newer commits queue. When the first finishes, the **most recent** commit deploys and the rest are cancelled. Intended behaviour.

Disable with `{"github": {"autoJobCancelation": false}}`. No GitLab or Bitbucket equivalent.

---

## Fast triage script

```bash
# 1. Is there a new deployment at all? Compare its commit SHA to your push.
#    If latestDeployment is older than your push → causes 1, 2, 3, 4, 5, 6, 7, 8.
#    If it exists and is READY but the domain is stale → causes 9, 10.
#    If it exists and is CANCELED → causes 3, 4, 8, 11.

# 2. Byte-compare live output against what you believe you shipped.
curl -s -o /dev/null -w '%{http_code} %{size_download}\n' https://<domain>/<path>
```

A `READY` deployment proves the build finished and nothing else. Read the build log end to end — TypeScript errors print as `error TSxxxx` while the build still reports green.
