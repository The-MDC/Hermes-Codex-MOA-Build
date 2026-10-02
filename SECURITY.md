# 🔒 Seven6-Hermes-MOA Security Policy

## API Keys and Credentials

**ALL API keys, tokens, passwords, and credentials are EXCLUDED from this repository.**

### Policy
- API keys and sensitive values are never committed to this repository
- Hermes reads from `$HERMES_HOME/.env` at runtime
- Keys are provided by injection from the host environment, not stored in source control
- This is enforced via `.gitignore` exclusions: `.env`, `*.env`, `*.key`, `secrets/`, `credentials.json`

### Required Setup
1. Copy `.env.example` to `.env` in the project root
2. Add your API keys to the `.env` file
3. Ensure `.env` is listed in your local `.gitignore` (it is, per the repo-level `.gitignore`)
4. Never commit `.env` or any credential files

### .gitignore Enforcement
The repository `.gitignore` explicitly excludes:
- `.env`
- `*.env`
- `*.key`
- `secrets/`
- `credentials.json`

Any attempt to commit these files will be rejected by Git.

### Security Violations
- Committing API keys, tokens, or passwords to this repository
- Sharing credentials in chat, issues, or pull requests
- Storing secrets in code, comments, or documentation within this repo

### References
- **Hermes Runtime**: Reads configuration from `$HERMES_HOME/.env`
- **PR Policy**: "API keys excluded per security policy - see SECURITY.md"
- **Security Template**: `.env.example` documents the expected format without exposing values

---
*This file is auto-enforced by the repository .gitignore. Do not modify credential values or commit sensitive data.*
