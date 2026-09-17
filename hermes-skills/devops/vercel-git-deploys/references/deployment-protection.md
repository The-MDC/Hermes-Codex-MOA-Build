# Deployment protection

Path: **Project → Settings → Deployment Protection**.

Protection applies to **all requests, including those to routing middleware**. If protection is on, your middleware never runs for a blocked request.

## Diagnosing a 401 or 403 from the outside

Read the response headers. They identify the mechanism precisely.

```bash
curl -s -D - -o /dev/null https://<domain>/
```

- **`www-authenticate: Basic realm="..."`** → HTTP Basic Auth implemented in **your own middleware**, not Vercel protection. The realm string and body text come from your code.
- **401 with no `www-authenticate`** → your middleware tried to send one and it was dropped. Header values must be Latin-1; a single non-Latin-1 character such as an em-dash makes the Edge runtime discard the entire header, so the browser never prompts and the user sees the raw 401 body. Keep realms plain ASCII.
- **A Vercel-branded login page** → Vercel Authentication (SSO).
- **A password form** → Password Protection.
- **`404` No Deployment Found** from some networks but not others → Trusted IPs. It returns 404, not 403, deliberately.

A `.vercel.app` URL that 401s while the custom domain works is the signature of **Standard Protection** — see the scope table below.

## Methods

| Method | Availability |
|---|---|
| Vercel Authentication | All plans |
| Passport | Beta, Enterprise only — not in the Advanced Deployment Protection add-on |
| Password Protection | Enterprise, or paid add-on for Pro |
| Trusted IPs | Enterprise only |

## Scopes, and how they treat custom domains

| Dashboard scope | Custom production domain | Availability |
|---|---|---|
| **Standard Protection** | **Not protected** — everything else is | All plans |
| **All Deployments** | Protected, including `example.com` and generated URLs | Pro, Enterprise |
| **Only Production Deployments** | Protected; previews stay public | Enterprise only, Trusted IPs only |

On Hobby, Vercel Authentication with Standard Protection is available: previews and deployment URLs are protected, the production domain stays public. Protecting a production domain requires Pro or Enterprise.

### API values

`ssoProtection.deploymentType`, `passwordProtection.deploymentType`, `trustedIps.deploymentType` accept:

- `prod_deployment_urls_and_all_previews` → **Standard Protection**
- `all` → **All Deployments**
- `preview` → **Only Preview Deployments**
- `production` → **Only Production Deployments** (Trusted IPs only)
- `all_except_custom_domains` → present in the API enum, **not documented on any user-facing page**, no per-value description. Semantically the strictest scope that still leaves custom production domains public. If you see it on a project, it was set by the API or by an older dashboard. The documented value for Standard Protection is `prod_deployment_urls_and_all_previews`.

Disable by setting the object to `null`.

## Standard Protection breaks `VERCEL_URL`

Enabling it makes the production **generated** deployment URL non-public. Any fetch built from `VERCEL_URL` or `VERCEL_BRANCH_URL` breaks.

- Client-side: use relative paths — `fetch('/some/path')` sends the user's auth cookie automatically. For fully qualified URLs such as OG images, use the real domain.
- Server-side: forward the incoming cookie header and target the incoming request's origin.
- Framework prefixes matter: `NEXT_PUBLIC_VERCEL_URL`, `NUXT_ENV_VERCEL_URL`.

Protection Bypass for Automation is an option here but is **not required** for same-domain requests.

## Cookie behaviour

For both Vercel Authentication and Password Protection, the token is a cookie **scoped to one URL** and is not transferable — not even between two URLs pointing at the same deployment.

Disabling either method **renders all existing deployments unprotected immediately**. Re-enabling does not force re-login for users who already hold a valid cookie for that specific deployment.

Changing the password invalidates existing cookies.

## Trusted IPs

- IPv4 addresses and IPv4 CIDR ranges only.
- **Can only be enabled in preview when Vercel Authentication is also enabled.**
- Operates as a required layer *on top of* the other methods.
- Vercel Firewall takes precedence; an IP in IP Blocking is blocked even if it is in Trusted IPs.
- Does not bypass DDoS mitigation unless configured.
- `protectionMode: "additional"` is the recommended setting — IP required *in addition to* other methods.

## Protection Bypass for Automation

Multiple secrets per project are supported; one populates `VERCEL_AUTOMATION_BYPASS_SECRET`.

**The value is baked in at build time.** Regenerating or deleting the secret invalidates previous deployments — you must redeploy to pick up a new value.

- Header (recommended): `x-vercel-protection-bypass: <secret>`
- Query parameter, same name, for tools that cannot set headers (Slack URL verification, Stripe and GitHub webhooks)
- `x-vercel-set-bypass-cookie: true` sets the bypass as a cookie via redirect; use `samesitenone` for iframes (default is `Lax`)

Bypasses Password Protection, Vercel Authentication, Trusted IPs, standard firewall blocks, and bot challenges. Does **not** bypass active DDoS mitigations, attack-time rate limits, or challenges triggered by attack patterns.

For CI, prefer **Trusted Sources** (short-lived OIDC, scoped to a GitHub account, repository, and branch) over a static secret.

## Advanced Deployment Protection add-on

Enterprise by default; **$150/month on Pro**. Includes Password Protection, Private Production Deployments, and Deployment Protection Exceptions. Passport is excluded.

Must be used for **30 days minimum** before it can be disabled. Cancelling disables all features in the add-on.

## Deployment Protection Exceptions

Removes all protection from named **preview** domains. Adding one requires typing the domain and the phrase `unprotect my domain`; removing requires `reprotect my domain`. For a public production domain, use Only Production Deployments instead.

## CLI

```
vercel project protection [enable|disable] [name] [options]
```

Options include `--sso`, `--password`, `--protection-bypass`, `--protection-bypass-secret <SECRET>`, `--git-fork-protection`, `--skew`, `--skew-max-age <SECONDS>`, `--format json`. Omit the action to print current settings.
