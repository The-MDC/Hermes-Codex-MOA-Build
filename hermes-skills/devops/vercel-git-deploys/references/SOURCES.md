# Sources

Crawled 2026-07-29. Vercel docs pages carry their own `last_updated` dates, noted where known.

## Primary
- https://vercel.com/docs/git/vercel-for-github (2026-05-28)
- https://vercel.com/docs/git (2026-06-16)
- https://vercel.com/docs/project-configuration/git-configuration (2025-12-19)
- https://vercel.com/docs/project-configuration/git-settings (2026-03-10)
- https://vercel.com/docs/deployments/promoting-a-deployment (2026-06-26)
- https://vercel.com/docs/deployments/environments (2026-05-28)
- https://vercel.com/docs/instant-rollback (2026-07-07)
- https://vercel.com/docs/deployments/generated-urls (2025-09-24)
- https://vercel.com/docs/security/deployment-protection (2026-06-26)
- https://vercel.com/docs/deploy-hooks (2026-06-16)
- https://vercel.com/docs/monorepos
- https://vercel.com/docs/builds/configure-a-build
- https://vercel.com/docs/cli/deploying-from-cli
- https://vercel.com/kb/guide/github-actions-vercel
- https://vercel.com/docs/git/vercel-for-gitlab (2025-11-25)
- https://vercel.com/docs/git/vercel-for-bitbucket (2025-11-25)

## Secondary (pulled where a topic was not on the primary page)
- /docs/cli/deploy, /docs/cli/build, /docs/cli/pull, /docs/cli/git, /docs/cli/project
- /docs/project-configuration/project-settings (Ignored Build Step, 2026-05-08)
- /docs/project-configuration/security-settings (Git fork protection, 2026-07-01)
- /docs/environment-variables/system-environment-variables
- /docs/security/deployment-protection/methods-to-protect-deployments/{vercel-authentication,password-protection,trusted-ips} (2026-07-01)
- /docs/rest-api/reference/endpoints/projects/update-an-existing-project (protection enum values)
- /kb/guide/how-do-i-use-the-ignored-build-step-field-on-vercel
- /kb/guide/why-aren-t-commits-triggering-deployments-on-vercel
- github.com/vercel/examples/tree/main/ci-cd/github-actions

## Corrections made against the raw docs
- There is no protection scope named `standard` in the REST API. The dashboard's "Standard Protection" maps to `prod_deployment_urls_and_all_previews`. `all_except_custom_domains` exists in the enum but has no user-facing documentation.
- `/docs/project-configuration/git-settings` no longer hosts Ignored Build Step or Git fork protection despite older references; they live under Build and Deployment and Security respectively.
- The Bitbucket page has a literal gap where the required permission level should appear; the troubleshooting section resolves it to repository Admin.

## Field-verified, not from docs
- Non-Latin-1 characters in a `WWW-Authenticate` realm cause the Edge runtime to drop the whole header, so browsers never prompt and users see the raw 401 body. Observed and fixed on a live project.
- A build can reach READY with `error TSxxxx` lines in the log. Reading the log is not optional.
