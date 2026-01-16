# Multi-Repo Governance Harmonization Plan

**Date**: 2026-01-16
**Status**: READY FOR APPROVAL
**Full Analysis**: `/Users/tmac/Downloads/Multi-Repo-Governance-Harmonization-Analysis.md`

---

## Strategic Architecture

### Three-Layer Model

```
┌─────────────────────────────────────────────────────────────────┐
│                    AI_ORCHESTRATOR (Strategic HQ)               │
│                                                                 │
│  Role: Execution command center, PM, cross-repo coordination    │
│                                                                 │
│  Contains:                                                      │
│  ├─ VIBE KANBAN (execution board)                              │
│  │  ├─ objectives/        ← Imported from MissionControl       │
│  │  ├─ adrs/              ← Decomposed objectives              │
│  │  ├─ tasks/             ← Work queues (existing)             │
│  │  └─ board-state.json   ← Kanban state                       │
│  ├─ Meta-agents (PM, CMO, Governance)                          │
│  ├─ Coordinator (objective → ADR → task decomposition)         │
│  ├─ Ralph verification engine                                  │
│  ├─ Wiggum iteration control (15-50 retries)                   │
│  ├─ Knowledge Objects (institutional memory)                   │
│  ├─ Adapters (per-repo configuration)                          │
│  └─ Circuit breaker (safety limits)                            │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ Governance flows down
                             │ Objectives imported
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    MISSIONCONTROL (Constitution)                │
│                                                                 │
│  Role: Policy definitions, SSOT for governance, audit trail    │
│                                                                 │
│  Contains:                                                      │
│  ├─ governance/                                                │
│  │  ├─ capsule/           ← Core principles (immutable)        │
│  │  ├─ objectives/        ← High-level goals (inputs to Kanban)│
│  │  ├─ policies/          ← Global rules                       │
│  │  ├─ skills/            ← Skill DEFINITIONS (not impl)       │
│  │  └─ protocols/         ← Inter-agent coordination rules     │
│  ├─ ris/                  ← Decisions & resolutions (SSOT)     │
│  ├─ kb/                   ← Shared knowledge base              │
│  └─ repos/{name}/         ← Per-repo documentation namespaces  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ Policies inherited
                             │ Local constraints added
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    APP REPOS (Business Units)                   │
│                                                                 │
│  Role: Domain execution, local agents, operational hooks        │
│                                                                 │
│  credentialmate/.claude/              karematch/.claude/        │
│  ├─ CLAUDE.md (imports MC)            ├─ CLAUDE.md              │
│  ├─ agents/ (implementations)         ├─ agents/                │
│  ├─ hooks/ (local enforcement)        ├─ hooks/                 │
│  ├─ constraints/ (HIPAA etc)          ├─ constraints/           │
│  └─ skills/ (domain-specific)         └─ skills/                │
└─────────────────────────────────────────────────────────────────┘
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Vibe Kanban in AI_Orchestrator | Execution state belongs with execution engine, not constitution |
| Objectives in MissionControl | Goals are stable inputs; Kanban manages dynamic execution |
| Skills DEFINITIONS in MissionControl | SSOT for what agents CAN do |
| Skills IMPLEMENTATIONS in app repos | Context-specific execution |
| RIS centralized in MissionControl | Single audit trail across all repos |
| Knowledge Objects in AI_Orchestrator | Execution learnings, 0.001ms cache |

---

## Vibe Kanban Architecture

### What It Is

The Vibe Kanban is the execution surface that:
- Translates high-level objectives → discrete, parallelizable agent missions
- Assigns tasks to agents that inherit MissionControl governance
- Enables concurrent work without context collision
- Maintains traceability: goals → agents → outputs → decisions (RIS)

### Where Components Live

| Component | Location | Why |
|-----------|----------|-----|
| **Objectives** | MissionControl/governance/objectives/ | Stable, constitutional inputs |
| **Kanban Board** | AI_Orchestrator/vibe-kanban/ | Dynamic execution state |
| **ADR Decomposition** | AI_Orchestrator (Coordinator agent) | Execution logic |
| **Task Routing** | AI_Orchestrator (adapters) | Per-repo configuration |
| **Audit Trail** | MissionControl/ris/ | Permanent record |

### Kanban Item Properties

Each Kanban item is:
- **Scoped** - Clear boundaries, no overlap
- **Governed** - Inherits MissionControl policies
- **Independently executable** - Can run in parallel
- **Auditable** - Traced to RIS decisions

### Flow

```
MissionControl/governance/objectives/
  └─ OBJ-001-harmonize-governance.md
           │
           │ AI_Orchestrator imports
           ▼
AI_Orchestrator/vibe-kanban/objectives/
  └─ OBJ-001-harmonize-governance.md (reference)
           │
           │ Coordinator decomposes
           ▼
AI_Orchestrator/vibe-kanban/adrs/
  ├─ ADR-harmonize-phase1.md
  ├─ ADR-harmonize-phase2.md
  └─ ADR-harmonize-phase3.md
           │
           │ Coordinator decomposes further
           ▼
AI_Orchestrator/tasks/work_queue_*.json
  ├─ Task: Migrate RIS resolutions
  ├─ Task: Create skill definitions
  └─ Task: Update CLAUDE.md imports
           │
           │ Assigned to agents
           ▼
App Repos execute tasks
           │
           │ Results flow back
           ▼
MissionControl/ris/resolutions/
  └─ Audit trail of what was done
```

---

## Implementation Phases

### Phase 1: Constitutional Foundation (Week 1)
**Goal**: Establish MissionControl as governance authority

| Task | Effort | Deliverable |
|------|--------|-------------|
| Create governance/objectives/ structure | 2h | Objective template + first objectives |
| Create governance/policies/ from credentialmate rules | 3h | Shared policy definitions |
| Create governance/skills/ with skill DEFINITIONS | 4h | Skill registry (definitions only) |
| Create governance/protocols/ for inter-agent rules | 2h | Escalation, handoff protocols |
| Migrate RIS resolutions with repo prefixes | 2h | Central audit trail |
| Update credentialmate CLAUDE.md to import MissionControl | 1h | Authority hierarchy |
| Update karematch CLAUDE.md to import MissionControl | 1h | Authority hierarchy |

**Verification**:
- [ ] MissionControl/governance/ structure complete
- [ ] Both app repos import MissionControl policies
- [ ] RIS resolutions searchable with prefixes

---

### Phase 2: AI_Orchestrator as HQ (Week 2)
**Goal**: Expand AI_Orchestrator's cross-repo coordination

| Task | Effort | Deliverable |
|------|--------|-------------|
| Create/update adapters for all repos | 4h | credentialmate, karematch, research adapters |
| Integrate MissionControl policies into Ralph | 3h | Unified verification |
| Enhance Coordinator for objective decomposition | 4h | OBJ → ADR → Task flow |
| Add circuit breaker for all repos | 2h | Cost/iteration safety |
| Create PM meta-agent for cross-repo prioritization | 6h | Evidence-driven work queue |
| Implement MissionControl objective import | 2h | Sync objectives to Kanban |

**Verification**:
- [ ] All repos have working adapters
- [ ] Ralph enforces MissionControl policies
- [ ] Coordinator can decompose objectives

---

### Phase 3: Vibe Kanban Implementation (Week 3)
**Goal**: Enable parallel, governed agent execution

| Task | Effort | Deliverable |
|------|--------|-------------|
| Create vibe-kanban/ directory structure | 2h | objectives/, adrs/, board-state.json |
| Implement objective → ADR decomposition | 4h | Coordinator enhancement |
| Implement ADR → task decomposition | 4h | Work queue generation |
| Create board-state.json schema | 2h | Kanban state tracking |
| Add parallel execution tracking | 4h | No context collision |
| Create traceability links (goal → task → RIS) | 3h | Audit trail |

**Verification**:
- [ ] Objectives flow through Kanban to tasks
- [ ] Multiple agents can work in parallel
- [ ] All work traceable to objectives and RIS

---

### Phase 4: App Repo Simplification (Week 4)
**Goal**: Remove duplication, streamline app repos

| Task | Effort | Deliverable |
|------|--------|-------------|
| Replace hot-patterns.md with KO references | 2h | Faster memory |
| Remove duplicated governance rules | 3h | Smaller .claude/ |
| Add sync-from-orchestrator.yaml | 2h | State awareness |
| Update skills to reference MissionControl definitions | 3h | SSOT compliance |
| Test end-to-end workflow | 4h | Validation |

**Verification**:
- [ ] No duplicated governance across repos
- [ ] App repos reference MissionControl for policies
- [ ] Full workflow works end-to-end

---

### Phase 5: Metrics & Optimization (Week 5+)
**Goal**: Measure and improve

| Task | Effort | Deliverable |
|------|--------|-------------|
| Implement cross-repo autonomy tracking | 4h | Data-driven improvement |
| Create governance dashboard | 6h | Visibility |
| Token usage profiling | 3h | Optimization targets |
| Establish quarterly governance review | 2h | Continuous improvement |

**Verification**:
- [ ] Autonomy % tracked per repo
- [ ] Token usage measured
- [ ] Review process documented

---

## What Lives Where (Final)

### MissionControl Contains

```
MissionControl/
├─ governance/
│  ├─ capsule/                    # Core principles (immutable)
│  │  └─ ai-governance-principles.md
│  ├─ objectives/                 # High-level goals (Kanban inputs)
│  │  └─ OBJ-001-*.md
│  ├─ policies/                   # Global rules
│  │  ├─ database-safety.md
│  │  ├─ hipaa-compliance.md
│  │  └─ escalation-rules.md
│  ├─ skills/                     # Skill DEFINITIONS (not implementations)
│  │  ├─ INDEX.md
│  │  └─ {skill-name}.skill.md
│  └─ protocols/                  # Inter-agent coordination
│     ├─ handoff-protocol.md
│     └─ escalation-protocol.md
├─ ris/                           # Central audit trail
│  ├─ decisions/
│  └─ resolutions/
├─ kb/                            # Shared knowledge
└─ repos/                         # Per-repo namespaces
   ├─ credentialmate/
   └─ karematch/
```

### AI_Orchestrator Contains

```
AI_Orchestrator/
├─ vibe-kanban/                   # Execution board
│  ├─ objectives/                 # Imported from MissionControl
│  ├─ adrs/                       # Decomposed objectives
│  └─ board-state.json            # Kanban state
├─ tasks/                         # Work queues (existing)
│  ├─ work_queue_credentialmate.json
│  └─ work_queue_karematch.json
├─ agents/                        # Execution agents
│  ├─ coordinator/                # Enhanced for objectives
│  ├─ advisor/
│  └─ builders/
├─ governance/
│  ├─ contracts/                  # Autonomy contracts
│  └─ unified/                    # Guardrails
├─ ralph/                         # Verification engine
├─ knowledge/                     # Knowledge Objects
└─ adapters/                      # Per-repo configs
   ├─ credentialmate/
   └─ karematch/
```

### App Repos Contain

```
{repo}/.claude/
├─ CLAUDE.md                      # Imports MissionControl + local
├─ agents/                        # Domain agent IMPLEMENTATIONS
├─ hooks/scripts/                 # Local enforcement
├─ constraints/                   # Local restrictions (tighten only)
├─ skills/                        # Domain-specific skills
└─ sync-from-orchestrator.yaml    # State sync config
```

---

## Token Budget (Target)

| Layer | Tokens | When Loaded |
|-------|--------|-------------|
| MissionControl core | ~2K | Always (constitutional) |
| AI_Orchestrator (autonomous mode) | ~5K | When coordinating |
| App-specific context | ~3K | Per-task |
| **Total** | **~10K** | vs. 15-20K today |

**Savings**: 30-50% reduction in governance tokens per task

---

## Success Metrics

| Metric | Current | Target | Timeline |
|--------|---------|--------|----------|
| Autonomy % (credentialmate) | 40-60% | 85%+ | 3 months |
| Autonomy % (karematch) | 50-70% | 90%+ | 3 months |
| Governance token overhead | 5K/task | 2K/task | 1 month |
| Cross-repo task routing | Manual | Automatic | 2 months |
| Duplicate learnings | Frequent | Zero | 2 months |
| Parallel agent execution | None | 3+ concurrent | 2 months |

---

## Rollback Plan

Each phase commits separately to both MissionControl and AI_Orchestrator.

| Phase | Rollback |
|-------|----------|
| Phase 1 | `git revert` MissionControl commits |
| Phase 2 | `git revert` AI_Orchestrator commits |
| Phase 3 | Disable vibe-kanban/, use existing work_queue |
| Phase 4 | Restore app repo .claude/ from backup |

---

## Approval Checklist

- [ ] Architecture approved (3-layer model)
- [ ] Vibe Kanban placement in AI_Orchestrator approved
- [ ] Objectives in MissionControl approved
- [ ] Phase 1-5 scope approved
- [ ] Token budget targets approved
- [ ] Success metrics approved
