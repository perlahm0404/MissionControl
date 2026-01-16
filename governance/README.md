# Global Governance

## Purpose
Contains cross-repo policies, capsule definitions, and governance artifacts that apply to all repositories under MissionControl.

## What Belongs Here
- `capsule/` – Capsule definitions for context packaging and agent handoff
- `policies/` – Organization-wide policies (naming, versioning, retention)

## What Does NOT Belong Here
- Repo-specific governance (use `/repos/{repo}/governance/`)
- Session files (use `/sessions/`)
- Research or investigation notes (use `/repos/{repo}/research/`)

## Human Usage
Consult before creating new policies. All global rules must be documented here before enforcement.

## AI Agent Usage
Agents must:
1. Load applicable policies from `policies/` before making cross-repo changes
2. Reference capsule definitions when packaging context for handoff
3. Never modify policies without human approval

## Migration Notes
- This directory is created fresh for MissionControl
- No migration from existing repos required
