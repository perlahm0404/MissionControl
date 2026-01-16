# CredentialMate Documentation Namespace

## Purpose
Contains all documentation migrated from the CredentialMate repository. This namespace isolates CredentialMate-specific content while allowing cross-repo reference.

## What Belongs Here
- `governance/` – Repo-specific policies, workflows, CLAUDE.md fragments
- `kb/` – CredentialMate knowledge base articles
- `reference/` – API docs, schema references, integration guides
- `research/` – Investigation notes, spike outputs, POC documentation
- `archive-index/` – Index pointers to archived session files (not the sessions themselves)
- `deprecated/` – Sunset documentation awaiting deletion review

## What Does NOT Belong Here
- Active session files (use `/sessions/`)
- Cross-repo decisions (use `/ris/`)
- Global policies (use `/governance/`)
- Actual archived files (sessions remain in source repo, only indexed here)

## Human Usage
Navigate here when working on CredentialMate-specific documentation. Check `governance/` for repo-specific rules before making changes.

## AI Agent Usage
Agents working on CredentialMate tasks should:
1. Check this namespace for repo-specific context
2. Cross-reference with `/ris/` for applicable decisions
3. Never create files here without migration approval

## Migration Notes
- Source: `credentialmate/docs/`
- Migration status: PENDING
- Migration order: governance → kb → reference → research → archive-index
