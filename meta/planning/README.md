# Planning Documents

This directory contains strategic planning documents for the MissionControl governance harmonization initiative.

## Documents

| Document | Purpose | Date |
|----------|---------|------|
| [harmonization-plan.md](harmonization-plan.md) | Implementation plan with 5 phases | 2026-01-16 |
| [Multi-Repo-Governance-Harmonization-Analysis.md](Multi-Repo-Governance-Harmonization-Analysis.md) | Comprehensive comparison of all repos | 2026-01-16 |
| [MissionControl-Governance-Recommendation.md](MissionControl-Governance-Recommendation.md) | Initial recommendation with Options C/D/E | 2026-01-16 |
| [AI-ORCHESTRATOR-CONTINUITY-PROMPT.md](AI-ORCHESTRATOR-CONTINUITY-PROMPT.md) | **Handoff prompt for AI_Orchestrator to execute plan** | 2026-01-16 |

## Quick Reference

### Architecture Decision

```
AI_Orchestrator (Strategic HQ)
├─ Vibe Kanban (execution board)
├─ PM, CMO, Governance meta-agents
├─ Coordinator, Ralph, KOs
└─ Per-repo adapters
         │
         ▼
MissionControl (Constitution)
├─ Objectives (Kanban inputs)
├─ Policies, Skills (definitions)
├─ RIS (audit trail)
└─ KB (shared knowledge)
         │
         ▼
App Repos (Business Units)
├─ Agent implementations
├─ Local hooks
└─ Domain skills
```

### Key Decisions

1. **Vibe Kanban** lives in AI_Orchestrator (not MissionControl)
2. **Objectives** live in MissionControl (inputs to Kanban)
3. **Skill definitions** in MissionControl; **implementations** in app repos
4. **RIS** centralized in MissionControl
5. **Knowledge Objects** in AI_Orchestrator (execution learnings)

### Implementation Timeline

| Phase | Goal | Week |
|-------|------|------|
| 1 | Constitutional Foundation | 1 |
| 2 | AI_Orchestrator as HQ | 2 |
| 3 | Vibe Kanban | 3 |
| 4 | App Repo Simplification | 4 |
| 5 | Metrics & Optimization | 5+ |

## Status

**Current**: Planning complete, awaiting approval
**Next**: Phase 1 - Constitutional Foundation
