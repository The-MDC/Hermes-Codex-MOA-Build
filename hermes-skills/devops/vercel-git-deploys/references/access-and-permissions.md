# Access and permissions

## Who can import or connect a repository

### GitHub — personal account repositories

You must be the repository **Owner**. A Collaborator on a personal repo **cannot** create a Vercel project from it or connect it to an existing one. Ownership is what lets Vercel configure the webhook.

### GitHub — organization repositories

One of:

- **Owner** of the GitHub organization, **or**
- **Member** of the organization *with access to the repository*

Being a Member is not sufficient on its own — you need a repository-level access role too. If you can see the repo on GitHub but not in Vercel's import list, check your repository role, not just your org membership.

**Outside Collaborators cannot import**, even with full repo access. You must be an Owner or Member of the org.

### GitLab

**Maintainer** access to the repository. **If the repository belongs to a group, you also need Maintainer access to the group.** Both are required.

### Bitbucket

**Admin** access configured for the repository.

## Permission scopes Vercel requests

### GitHub — repository permissions

| Permission | Read | Write | Purpose |
|---|---|---|---|
| Administration | Y | Y | Create repositories on your behalf |
| Checks | Y | Y | Add checks against source code on push |
| Contents | Y | Y | Fetch and write source for new project templates |
| Deployments | Y | Y | Sync deployment status between GitHub and Vercel |
| Pull Requests | Y | Y | Create deployments per PR and comment status |
| Issues | Y | Y | Required by GitHub alongside Pull Requests |
| Metadata | Y | N | Read basic repository metadata |
| Web Hooks | Y | Y | React to GitHub events |
| Commit Statuses | Y | Y | Sync commit status |

Organization: `Members` (read). User: `Email addresses` (read).

### GitLab

A single **`API`** scope, read and write — covering all groups and projects, the container registry, and the package registry. Far coarser than GitHub's nine granular scopes.

### Bitbucket

`Web Hooks` (read only — no write, unlike GitHub), `Issues` (read/write, required alongside Pull Requests), `Pull requests` (read/write), `Repository`, organization `Team` (read), user `Account` (read). No Checks, no Deployments, no Commit Statuses.

## Diagnosing a repo that will not appear

This applies both to Vercel's import list and to any tool authenticating through a GitHub App.

**Decisive test:** try reading a known public repository through the same credential, then the repository in question.

- Public repo reads succeed, target repo returns **404** → the credential is valid but the App installation does not include that repository. GitHub returns 404 rather than 403 for repositories outside an installation's scope, so 404 means "not in scope," not "does not exist."
- A search scoped to the owner (`user:<login>`) returning **0 results** while the profile reports a non-zero public repo count is a strong signal that the installation has **no repositories selected at all**.
- Anonymous `git clone` prompting for a username means the repo is private or invisible to that identity.

**Fix:** github.com/settings/installations → Configure on the app → Repository access → add the repository. The Save button stays disabled until you select from the dropdown — an easy step to miss and then believe you saved.

If the app offers no repository picker, the authorization is scoped to public repositories only. Disconnect and reauthorize, approving private repository access.

## Deployment protection is a different thing

Repository access governs whether Vercel can *read your code*. Deployment protection governs whether a *visitor* can reach the deployed site. A 401 on your production URL is never a repository permissions problem — see `deployment-protection.md`.
