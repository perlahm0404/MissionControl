# MissionControl

**The authoritative control plane for governance, knowledge, and AI coordination across all repositories.**

MissionControl is the Single Source of Truth (SSOT) for:
- **Governance** - Policies, skills definitions, protocols
- **Knowledge** - Shared KB, RIS decisions, institutional memory
- **Coordination** - Objectives that drive the Vibe Kanban execution board

---

## Architecture

MissionControl is the **Constitutional Layer** in a three-tier governance model:

```
┌─────────────────────────────────────────────────────────────────┐
│                    AI_ORCHESTRATOR (Strategic HQ)               │
│  Vibe Kanban, PM, Coordinator, Ralph, Knowledge Objects         │
│  Role: Execution command center, cross-repo coordination        │
└────────────────────────────┬────────────────────────────────────┘
                             │ Imports objectives, inherits policies
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              MISSIONCONTROL (Constitution) ← YOU ARE HERE       │
│  Objectives, Policies, Skill Definitions, RIS, KB               │
│  Role: Define WHAT is allowed, preserve shared context          │
└────────────────────────────┬────────────────────────────────────┘
                             │ Policies inherited, local constraints added
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    APP REPOS (Business Units)                   │
│  credentialmate, karematch, research                            │
│  Role: Domain execution, local agents, operational hooks        │
└─────────────────────────────────────────────────────────────────┘
```

---

## Directory Structure

```
MissionControl/
├─ governance/                    # Constitutional authority
│  ├─ capsule/                    # Core principles (immutable)
│  ├─ objectives/                 # High-level goals (Kanban inputs)
│  ├─ policies/                   # Global rules (database-safety, HIPAA, etc.)
│  ├─ skills/                     # Skill DEFINITIONS (not implementations)
│  └─ protocols/                  # Inter-agent coordination rules
│
├─ ris/                           # Resolution & Incident System (central)
│  ├─ decisions/                  # Architectural Decision Records
│  └─ resolutions/                # Incident resolutions (prefixed by repo)
│
├─ kb/                            # Global knowledge base
│
├─ repos/                         # Per-repo documentation namespaces
│  ├─ credentialmate/
│  └─ karematch/
│
├─ sessions/                      # Cross-repo session tracking
│  ├─ active/
│  └─ archive/
│
└─ meta/                          # Repository standards
   ├─ conventions.md
   ├─ linking-rules.md
   └─ planning/                   # Harmonization planning docs
```

---

## Quick Reference

| Need | Location |
|------|----------|
| Core principles | `/governance/capsule/` |
| Strategic objectives | `/governance/objectives/` |
| Global policies | `/governance/policies/` |
| Skill definitions | `/governance/skills/` |
| Inter-agent protocols | `/governance/protocols/` |
| Architectural decisions | `/ris/decisions/` |
| Incident resolutions | `/ris/resolutions/` |
| Cross-repo knowledge | `/kb/` |
| Repo-specific docs | `/repos/{repo}/` |
| Planning documents | `/meta/planning/` |

---

## Key Documents

### Planning (Current Initiative)
| Document | Purpose |
|----------|---------|
| [Harmonization Plan](meta/planning/harmonization-plan.md) | 5-phase implementation plan |
| [Governance Analysis](meta/planning/Multi-Repo-Governance-Harmonization-Analysis.md) | Comprehensive repo comparison |
| [AI_Orchestrator Continuity Prompt](meta/planning/AI-ORCHESTRATOR-CONTINUITY-PROMPT.md) | Execution handoff |

### Standards
| Document | Purpose |
|----------|---------|
| [Conventions](meta/conventions.md) | Naming, formatting rules |
| [Linking Rules](meta/linking-rules.md) | Cross-reference standards |

---

## Governance Model

### What MissionControl Owns
- **Objectives** - High-level goals (inputs to Vibe Kanban)
- **Policies** - Global rules all repos must follow
- **Skill Definitions** - WHAT agents can do (not HOW)
- **Protocols** - Inter-agent coordination rules
- **RIS** - Central audit trail for all decisions

### What MissionControl Does NOT Own
- **Execution state** - Lives in AI_Orchestrator (Vibe Kanban)
- **Agent implementations** - Live in app repos
- **Knowledge Objects** - Live in AI_Orchestrator
- **Local hooks** - Live in app repos

### Authority Rules
1. **MissionControl policies cannot be overridden** by app repos
2. **App repos can only tighten** constraints, never loosen
3. **All governance changes** require human approval
4. **RIS entries** required for any policy exception

---

## Integration with AI_Orchestrator

AI_Orchestrator imports from MissionControl:
```
MissionControl/governance/objectives/  →  AI_Orchestrator/vibe-kanban/objectives/
MissionControl/governance/policies/    →  AI_Orchestrator/ralph/ (verification)
MissionControl/governance/skills/      →  Referenced by app repo agents
```

---

## Integration with App Repos

App repos reference MissionControl in their CLAUDE.md:
```markdown
## Authority Hierarchy
1. MissionControl/governance/capsule (constitutional)
2. MissionControl/governance/policies (global)
3. This CLAUDE.md (local)
4. Local constraints/ (tightening only)
```

---

## Migration Status

| Repository | Status | Phase |
|------------|--------|-------|
| CredentialMate | PENDING | Phase 1 |
| KareMatch | PENDING | Phase 1 |
| AI_Orchestrator | PENDING | Phase 2 |

See [Harmonization Plan](meta/planning/harmonization-plan.md) for details.

---

## Contributing

1. Read [CLAUDE.md](CLAUDE.md) for agent governance
2. Read [conventions.md](meta/conventions.md) for standards
3. Read [linking-rules.md](meta/linking-rules.md) for cross-references
4. Create content in appropriate namespace
5. All policy changes require RIS entry

---

## Contact

Repository: https://github.com/perlahm0404/MissionControl
