# Meta

## Purpose
Contains MissionControl's own governance: conventions, linking rules, and repository standards.

## What Belongs Here
- `conventions.md` – Naming, formatting, and structural conventions
- `linking-rules.md` – Cross-reference and linking standards
- Repository-level configuration and standards

## What Does NOT Belong Here
- Content documentation (use appropriate namespace)
- Session files (use `/sessions/`)
- Repo-specific rules (use `/repos/{repo}/governance/`)

## Human Usage
Read before contributing to MissionControl. All contributors must follow conventions documented here.

## AI Agent Usage
Agents must:
1. Load conventions before creating any files
2. Validate links against `linking-rules.md`
3. Never modify meta files without explicit human approval

## Migration Notes
- Created fresh for MissionControl
- No migration from existing repos
