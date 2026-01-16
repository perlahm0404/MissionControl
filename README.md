# MissionControl

Single Source of Truth (SSOT) for documentation across repositories.

## Structure

```
MissionControl/
├─ repos/           # Per-repo documentation namespaces
├─ governance/      # Global policies and capsules
├─ kb/              # Global knowledge base
├─ sessions/        # Active and archived sessions
├─ ris/             # Decisions and resolutions
└─ meta/            # Repository conventions
```

## Quick Reference

| Need | Location |
|------|----------|
| Repo-specific docs | `/repos/{repo}/` |
| Global policies | `/governance/policies/` |
| Cross-repo learnings | `/kb/` |
| Active work | `/sessions/active/` |
| Architectural decisions | `/ris/decisions/` |
| Incident resolutions | `/ris/resolutions/` |
| Conventions | `/meta/` |

## Contributing

1. Read `/meta/conventions.md`
2. Read `/meta/linking-rules.md`
3. Create content in appropriate namespace
4. Follow naming conventions

## Migration Status

| Repository | Status | Target |
|------------|--------|--------|
| CredentialMate | PENDING | Q1 2025 |

## Governance

This repository is governed by policies in `/governance/policies/`.
All changes require review per documented workflow.
