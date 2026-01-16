# MissionControl Conventions

## File Naming

| Type | Pattern | Example |
|------|---------|---------|
| Session | `{YYYY-MM-DD}_{repo}_{topic}.md` | `2025-01-16_credentialmate_auth-refactor.md` |
| Decision | `{repo}-{NNN}-{slug}.md` | `credentialmate-042-api-versioning.md` |
| Resolution | `{repo}-RES-{NNN}.md` | `credentialmate-RES-015.md` |
| KB Article | `{slug}.md` | `postgres-connection-pooling.md` |

## Directory Rules

- No nested directories beyond defined structure
- No empty directories (each must have README.md)
- No duplicate content across namespaces

## Markdown Standards

- H1 for document title only
- H2 for major sections
- Tables for structured data
- Code blocks with language specifier
- No HTML unless required for rendering

## Metadata Headers

All documents must include:

```yaml
---
created: YYYY-MM-DD
author: {human|agent}
status: {draft|active|deprecated}
repo: {repo-name|global}
---
```

## Retention

| Type | Retention | Archive Location |
|------|-----------|------------------|
| Sessions | 30 days active | `/sessions/archive/` |
| Decisions | Permanent | In place |
| Resolutions | 365 days | In place, then summary only |
| KB Articles | Permanent | In place |
