# Build configuration

Dashboard path for everything here: **Project → Settings → Build and Deployment**.

## Shallow clone

Vercel clones with `git clone --depth=10` — the latest ten commits only. Any `git diff` reaching further back works locally and fails on Vercel.

To reproduce a build environment locally, clone the same way.

## Framework Preset

Applies to all deployments. Per-deployment override: `framework` in `vercel.json`. When no framework is detected, **Other** is selected and the Build Command override toggle is enabled by default.

## Build Command

Auto-configured per framework. Override applies to all deployments; per-deployment override is `buildCommand` in `vercel.json`. Changes apply on the **next** deployment.

**Skip the build step entirely:** Framework Preset = Other, enable Override for Build Command, leave it empty.

## Output Directory

Only the contents of the Output Directory are served statically. Preset **Other** sets it to `public` if that exists, otherwise the project root. Enabling Override and leaving it blank also skips the build step. Per-deployment override: `outputDirectory`.

## Root Directory

- The app **cannot access files outside** this directory, and `..` is not allowed in the setting itself.
- **Also applies to Vercel CLI** — set it here and run `vercel` rather than `vercel <subdir>`.
- Applied on the next deployment.

## Install Command

Auto-detected; installs from `package.json` including devDependencies. **The install path is set by the Root Directory.**

Corepack: set `ENABLE_EXPERIMENTAL_COREPACK=1` on the project and add `"packageManager": "pnpm@7.5.1"` to the root `package.json`. Officially experimental.

Functions in the native `api` directory use a separate, non-customizable install command per language.

## Ignored Build Step

Located at Settings → Build and Deployment → **Ignored Build Step**. Runs when the deployment enters `BUILDING`, executes **within the Root Directory**, and can read all system environment variables.

### Exit codes are inverted

- exit `0` → build aborted, state `CANCELED`
- exit `1` or greater → build proceeds

Write it backwards from instinct. A conventional script returning `0` for success cancels everything.

### Dropdown options

`Automatic` · `Only build production` · `Only build preview` · `Only build if there are changes` · `Only build if there are changes in a folder` · `Don't build anything` · `Run my Bash script` · `Run my Node script` · `Custom`

### Quota warning

Canceled builds still execute a build command, so they **count toward deployment quotas and concurrent build slots**. For monorepos, unaffected-project skipping is cheaper — it evaluates before a slot is claimed.

### The stale diff baseline

`git diff HEAD^ HEAD` compares against the previous commit **on the branch**, not the last successful deployment. Failure mode: a commit touching only `/api` skips the frontend project; a later deploy-hook trigger also skips, because the most recent commit still isn't a frontend change. The project can stop deploying indefinitely.

Fix by diffing against `$VERCEL_GIT_PREVIOUS_SHA` — the SHA of the last successful deployment for that project and branch. It is **only exposed when an Ignored Build Step is configured**, which makes it a chicken-and-egg surprise the first time.

For Turborepo: `npx turbo-ignore --fallback=HEAD^1`. This depends on `turbo.json` declaring the dependency graph correctly — an undeclared shared package means dependents silently never rebuild.

### Examples

Production only:

```bash
if [[ "$VERCEL_ENV" == "production" ]] ; then exit 1; else exit 0; fi
```

Branch allowlist:

```bash
#!/bin/bash
if [[ "$VERCEL_GIT_COMMIT_REF" == "staging" || "$VERCEL_GIT_COMMIT_REF" == "main" ]] ; then
  exit 1
else
  exit 0
fi
```

Folder watch, relative to Root Directory:

```bash
git diff HEAD^ HEAD --quiet -- ./packages/frontend/
git diff HEAD^ HEAD --quiet -- ../../packages/docs
```

### Debugging

1. `git clone --depth=10` into a fresh folder to match Vercel's clone.
2. Run the command.
3. Check `echo $?`.
4. Confirm **Automatically Expose System Environment Variables** is enabled, or `VERCEL_*` is unavailable to the script.

### Skipping it on a redeploy

Deployments → find the deployment → ellipsis → **Redeploy** → uncheck **Use project's Ignore Build Step**.

## Monorepo unaffected-project skipping

GitHub-connected projects only. Requires npm, yarn, pnpm, or Bun workspaces.

A project counts as changed when its source changed, a declared internal dependency changed, or a lockfile change affects only its dependencies.

Requirements that bite:

- Every package needs a **unique `name`** in `package.json`.
- **Inter-package dependencies must be explicitly declared.** Undeclared means dependents never rebuild.
- Changes **outside the workspace definition** are treated as global and deploy everything.
- Package manager is detected from the lockfile at the repository root; override with `packageManager` in the root `package.json`.

Disable: Settings → Build and Deployment → Root Directory → **Skip deployment** → Disabled → Save.

## Related Projects

Max **3** per app, same repository only, **CLI deployments not supported**. Declare in the app's `vercel.json`:

```json
{ "relatedProjects": ["prj_123"] }
```

The next deployment receives `VERCEL_RELATED_PROJECTS`. Under Turborepo Strict Mode, add that variable to `turbo.json`.

## Build log errors that do not fail the build

A TypeScript diagnostic can print as `error TSxxxx` while the build completes and the deployment reaches `READY`.

`middleware.ts(NN,NN): error TS2550: Property 'hasOwn' does not exist on type 'ObjectConstructor'` — `Object.hasOwn` requires ES2022. Either add a `tsconfig.json` with `"lib": ["ES2022", "DOM"]`, or use `Object.prototype.hasOwnProperty.call(obj, key)`.

Vercel notes it uses built-in TypeScript when `typescript` is absent from devDependencies, so a project with no tsconfig gets defaults that may not match your code.
