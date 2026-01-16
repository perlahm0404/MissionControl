# Sessions

## Purpose
Central location for all documentation sessions across repos. Provides unified view of active work and historical archive.

## What Belongs Here
- `active/` – Currently open sessions (any repo)
- `archive/` – Completed sessions with retention policy applied

## What Does NOT Belong Here
- Knowledge base articles (use `/kb/` or `/repos/{repo}/kb/`)
- Permanent documentation (extract and migrate before archiving)
- Governance policies (use `/governance/`)

## Human Usage
Check `active/` for ongoing work. Search `archive/` for historical context. Sessions older than 30 days auto-archive unless marked for retention.

## AI Agent Usage
Agents must:
1. Create session files in `active/` at session start
2. Move to `archive/` at session close
3. Extract reusable learnings to appropriate `/kb/` before archiving
4. Use consistent naming: `{YYYY-MM-DD}_{repo}_{topic}.md`

## Migration Notes
- Sessions from source repos are indexed, not moved
- Index entries in `/repos/{repo}/archive-index/` point to original locations
- Only new sessions created directly in MissionControl
