# Permissions, access, and the missing repository

Source: `/docs/git/vercel-for-github` (permission tables, "Missing Git repository") and `/docs/git` (private repo rules).

## GitHub App permissions Vercel requests

### Repository permissions

| Permission | Read | Write | Why |
|---|---|---|---|
| `Administration` | Y | Y | Create repositories on the user's behalf |
| `Checks` | Y | Y | Add checks against source code on push |
| `Contents` | Y | Y | Fetch and write source for new project templates |
| `Deployments` | Y | Y | Synchronize deployment status between GitHub and Vercel |
| `Pull Requests` | Y | Y | Create deployments per PR and comment status updates |
| `Issues` | Y | Y | Required by GitHub alongside Pull Requests for access |
| `Metadata` | Y | N | Read basic repository metadata for the dashboard |
| `Web Hooks` | Y | Y | React to GitHub events |
| `Commit Statuses` | Y | Y | Synchronize commit status between GitHub and Vercel |

### Organization permissions

| Permission | Read | Write | Why |
|---|---|---|---|
| `Members` | Y | N | Better team onboarding experience |

### User permissions

| Permission | Read | Write | Why |
|---|---|---|---|
| `Email addresses` | Y | N | Associate an email with a GitHub account |

Note `Web Hooks: write` — this is the permission that keeps the deploy trigger alive. If the App's access to a repository is revoked or the repo is removed from its selected-repositories list, the webhook stops firing and pushes produce nothing, with no error surfaced.

## "The repository doesn't appear in Vercel's import list"

The required permission depends on who **owns** the repository.

### Personal-account repositories

You must be the repository **Owner**. This is what lets Vercel configure the webhook.

**A Collaborator on a personal repository cannot** create a Vercel project from it or connect it to an existing project. There is no workaround short of transferring ownership or moving the repo into an organization.

### Organization repositories

You need one of:

- **Owner** of the GitHub organization, **or**
- **Member** of the organization **with an access role on the repository**

Being an org Member is not sufficient on its own — verify you also hold a [repository role](https://docs.github.com/en/organizations/managing-user-access-to-your-organizations-repositories/managing-repository-roles/repository-roles-for-an-organization) on that specific repo.

**Outside Collaborators cannot import or connect**, even with full repository access. You must be an Owner or Member of the organization. This one is a hard stop — confirm your role with an org Owner rather than debugging further.

## Deploying private repositories: the commit-author rule

As a security measure, commits on private repos (and commits on forks targeting them) deploy **only if the commit author also has access to the Vercel project**.

Applies to **GitHub organizations, GitLab groups, and non-personal Bitbucket workspaces**. Does **not** apply to collaborators on personal Git accounts.

### Pro teams

The commit author must be a member of the Vercel team containing the project. Membership is resolved by finding the Vercel user associated with the commit author through **Login Connections**.

If the author is not yet a member but has a Vercel account, they may be auto-added or require approval depending on the team's collaboration settings. If they have no Vercel account, they must create one and link their Git provider before their commits will deploy.

### Hobby teams

**You cannot deploy to a Hobby team from a private repository in a GitHub org, GitLab group, or Bitbucket workspace at all.** Make the repo public or upgrade to Pro.

For other cases, the commit author must be the Hobby team **owner**, verified by comparing Login Connections against the owner. If not, the deployment is prevented and a recommendation to transfer the project to a Pro team appears on the Git provider.

## Forks of public repositories

Commits from forks usually deploy automatically. But a **pull request from a fork requires authorization** from you or a team member before it deploys. A link to authorize is posted as a comment on the PR.

This protects against leaking environment variables and the OIDC Token.

The authorization step is **skipped automatically** if the commit author is already a Vercel team member.

Disable at Project → Settings → **Security** → Git Fork Protection. Vercel's docs warn: review your environment variables and `vercel.json` before disabling.

CLI: `vercel project protection enable|disable <name> --git-fork-protection`

## Supported GitHub products

- GitHub Free
- GitHub Team
- GitHub Enterprise Cloud
- **GitHub Enterprise Server — only via GitHub Actions.** It cannot use the native Git integration.

Also: GitHub Enterprise Cloud with **Data Residency on a unique subdomain** requires GitHub Actions.

## Signing up with a different GitHub account

Sign out of the current GitHub account, then restart the Vercel signup process. There is no account-switcher inside the Vercel flow.

## Changing or disconnecting the repository

Project Settings → **Git** section → Connected Git Repository. Connect a different repository or disconnect entirely. CLI equivalents: `vercel git connect` / `vercel git disconnect`.

A CLI or API deploy never disconnects Git — only this explicit action does.
