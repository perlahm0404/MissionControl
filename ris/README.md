# RIS (Resolution & Incident System)

## Purpose
Central registry for architectural decisions and incident resolutions across all repositories.

## What Belongs Here
- `decisions/` – Architectural Decision Records (ADRs) with cross-repo impact
- `resolutions/` – Incident resolutions and post-mortems

## What Does NOT Belong Here
- Repo-specific decisions without cross-repo impact (keep in source repo)
- Active incident investigation (use `/sessions/active/`)
- Policies (use `/governance/policies/`)

## Human Usage
Consult before making architectural changes. All cross-repo decisions must be documented here before implementation.

## AI Agent Usage
Agents must:
1. Search `decisions/` before proposing architectural changes
2. Reference RIS entries when explaining constraints
3. Create new entries only with human approval
4. Link resolutions to related decisions

## Migration Notes
- RIS entries from source repos migrated when cross-repo relevance confirmed
- Each entry retains original ID with prefix: `{repo}-{original-id}`
- Superseded entries marked but not deleted
