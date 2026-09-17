# Promotion, staging, and rollback

## Production deployment states

- **Staged** — pushed to the production branch, but no domain auto-assigned. Promotable.
- **Promoted** — was promoted from staging. **Cannot be promoted a second time.** To reuse it, roll back to it.
- **Current** — aliased to your domain, serving users.

## Three ways to change what production serves

| Method | Rebuild? | Use when |
|---|---|---|
| **Instant rollback** | No | Revert to a deployment that already served production traffic |
| **Promote preview → production** | **Yes, full rebuild** | Ship a branch that isn't the production branch |
| **Promote a staged production build** | No | Verify a production build before it takes traffic |

## Staged production build

CLI:

```bash
vercel --prod --skip-domain     # build production, do not alias
vercel promote <deployment-id-or-url>
```

`--skip-domain` requires `--prod` and **overrides the project's Auto-assign Custom Production Domains setting.**

Dashboard: Settings → Environments → Production → Branch Tracking → disable **Auto-assign Custom Production Domains**. Then Deployments → ellipsis → **Promote**.

Promotion is instant, no rebuild.

`github.autoAlias: false` in `vercel.json` does something similar, but the docs explicitly say to use the staged-production-build workflow instead.

## Promote preview → production

Deployments → ellipsis → **Promote to Production** → confirm.

**This is a full rebuild**, and the environment variables switch from preview to production. You cannot carry preview environment variables into a production deployment.

## Instant rollback

Project overview → Production Deployment tile → **Instant Rollback**. Or Deployments → ellipsis → **Instant Rollback** (filter by the production branch to see eligible deployments).

Eligible: any deployment **previously aliased to a production domain**. Preview deployments are not eligible. Hobby can roll back to the immediately previous deployment only; Pro and Enterprise to any eligible deployment.

### What rollback does not do

- **Does not rebuild.** Environment variables are not re-read — changing them in project settings has no effect on the rolled-back deployment.
- **Cron jobs revert** to the state of the rolled-back deployment.
- **Custom aliases are not restored** unless they were present on the previous production deployment. Domains configured in project settings are handled; aliases set outside it are not.

### The trap

**After a rollback, Vercel turns off auto-assignment of production domains.** Subsequent pushes to the production branch build successfully and do not go live. Builds look healthy, the site doesn't move.

Recover with dashboard **Undo Rollback**, or:

```bash
vercel promote <deployment-id-or-url>
```

Both restore auto-assignment.

## Who can do this

Hobby: previous deployment only. Pro and Enterprise: Owners, Members, and Developers. Also available to a Project Administrator, or anyone holding the Full Production Deployment permission on an access group.

## Generated URL shapes

| Source | Shape |
|---|---|
| Git commit | `<project>-<9-char-hash>-<scope-slug>.vercel.app` |
| Git branch | `<project>-git-<branch>-<scope-slug>.vercel.app` |
| CLI | `<project>-<scope-slug>.vercel.app` |
| CLI, team member | `<project>-<author>-<scope-slug>.vercel.app` |

The 9-character hash is produced **only** by Git commit deployments — a CLI or API deployment is identifiable by its absence.

Anything over **63 characters** before `.vercel.app` is truncated. A project name resembling a domain gets shortened to avoid tripping browser anti-phishing — `www-company-com` becomes `company`.
