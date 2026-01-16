# AI_Orchestrator Continuity Prompt: Governance Harmonization

**Date**: 2026-01-16
**Source**: MissionControl Planning Session
**Target**: AI_Orchestrator Coordinator Agent
**Status**: READY FOR EXECUTION

---

## Mission Context

You are the AI_Orchestrator Coordinator. A comprehensive governance harmonization plan has been developed and approved. Your mission is to execute this plan across all repositories.

**Strategic Objective**: Harmonize governance across credentialmate, karematch, and AI_Orchestrator with:
- AI_Orchestrator as Strategic HQ (execution command center)
- MissionControl as Constitutional Authority (policies, SSOT)
- App repos as Business Units (domain execution)

---

## Reference Documents

All planning documents are in MissionControl:

```
/Users/tmac/1_REPOS/MissionControl/meta/planning/
├─ harmonization-plan.md                          # Implementation phases
├─ Multi-Repo-Governance-Harmonization-Analysis.md # Repo comparison
└─ MissionControl-Governance-Recommendation.md    # Architecture rationale
```

**READ THESE FIRST** before executing any tasks.

---

## Architecture Summary

```
AI_ORCHESTRATOR (You - Strategic HQ)
├─ vibe-kanban/           # Execution board (create this)
│  ├─ objectives/         # Imported from MissionControl
│  ├─ adrs/               # Decomposed objectives
│  └─ board-state.json    # Kanban state
├─ Coordinator (you)      # Enhance for objective decomposition
├─ Ralph                  # Integrate MissionControl policies
├─ Knowledge Objects      # Replace hot-patterns across all repos
└─ Adapters               # Update for all repos

MISSIONCONTROL (Constitution)
├─ governance/
│  ├─ capsule/            # Core principles (create)
│  ├─ objectives/         # High-level goals (create)
│  ├─ policies/           # Extract from credentialmate rules
│  ├─ skills/             # Skill DEFINITIONS (extract)
│  └─ protocols/          # Inter-agent rules (create)
├─ ris/                   # Centralize from all repos
└─ kb/                    # Shared knowledge

APP REPOS (Business Units)
├─ CLAUDE.md              # Update to import MissionControl
├─ agents/                # Keep implementations
├─ hooks/                 # Keep local enforcement
├─ constraints/           # Keep local tightening
└─ sync-from-orchestrator.yaml  # Create for state sync
```

---

## Phase 1: Constitutional Foundation (Week 1)

### Objective
Establish MissionControl as the governance authority.

### Tasks

**Task 1.1: Create MissionControl governance structure**
```bash
cd /Users/tmac/1_REPOS/MissionControl
mkdir -p governance/{capsule,objectives,policies,skills,protocols}
```

**Task 1.2: Create core principles**
Create `governance/capsule/ai-governance-principles.md`:
- L0-L4 autonomy levels (from credentialmate)
- 5-layer database deletion defense (from credentialmate)
- HIPAA guardrails (non-negotiable)
- Escalation hierarchy (4 levels)

**Task 1.3: Extract policies from credentialmate**
```bash
# Copy and adapt
cp /Users/tmac/1_REPOS/credentialmate/.claude/rules/database-safety.md \
   /Users/tmac/1_REPOS/MissionControl/governance/policies/

cp /Users/tmac/1_REPOS/credentialmate/.claude/rules/security.md \
   /Users/tmac/1_REPOS/MissionControl/governance/policies/

cp /Users/tmac/1_REPOS/credentialmate/.claude/rules/governance.md \
   /Users/tmac/1_REPOS/MissionControl/governance/policies/
```
Then edit to remove credentialmate-specific references, make generic.

**Task 1.4: Create skill definitions**
Create `governance/skills/INDEX.md` with skill registry.
For each skill in credentialmate (54) and karematch (25):
- Extract WHAT it does (not HOW)
- Define constraints
- Reference implementations in app repos

**Task 1.5: Create protocols**
Create `governance/protocols/`:
- `escalation-protocol.md` - When to escalate to humans
- `handoff-protocol.md` - Session continuity rules
- `parallel-execution-protocol.md` - Avoid context collision

**Task 1.6: Migrate RIS resolutions**
```bash
# From credentialmate
for f in /Users/tmac/1_REPOS/credentialmate/docs/20-ris/resolutions/*.md; do
  cp "$f" "/Users/tmac/1_REPOS/MissionControl/ris/resolutions/credentialmate-$(basename $f)"
done

# From karematch (if exists)
for f in /Users/tmac/1_REPOS/karematch/docs/06-ris/resolutions/*.md; do
  cp "$f" "/Users/tmac/1_REPOS/MissionControl/ris/resolutions/karematch-$(basename $f)"
done
```

**Task 1.7: Update app CLAUDE.md files**
Add to both credentialmate and karematch CLAUDE.md:
```markdown
## Authority Hierarchy
1. MissionControl/governance/capsule (constitutional)
2. MissionControl/governance/policies (global)
3. This CLAUDE.md (local)
4. Local constraints/ (tightening only)
```

### Verification
- [ ] MissionControl/governance/ structure complete
- [ ] Core principles documented
- [ ] Policies extracted and generalized
- [ ] RIS resolutions migrated with prefixes
- [ ] App CLAUDE.md files reference MissionControl

---

## Phase 2: AI_Orchestrator as HQ (Week 2)

### Objective
Expand your cross-repo coordination capabilities.

### Tasks

**Task 2.1: Create/update adapters**
Ensure adapters exist for:
- `/Users/tmac/1_REPOS/AI_Orchestrator/adapters/credentialmate/`
- `/Users/tmac/1_REPOS/AI_Orchestrator/adapters/karematch/`
- `/Users/tmac/1_REPOS/AI_Orchestrator/adapters/research/` (new)

Each adapter needs:
- `config.yaml` with paths, commands, thresholds
- Autonomy level (L1 for HIPAA repos, L2 for others)
- HIPAA configuration (if applicable)

**Task 2.2: Integrate MissionControl policies into Ralph**
Update Ralph verification to load policies from:
`/Users/tmac/1_REPOS/MissionControl/governance/policies/`

Add checks:
- Database safety patterns
- HIPAA violation detection
- Protected file patterns

**Task 2.3: Create PM meta-agent**
Create `/Users/tmac/1_REPOS/AI_Orchestrator/agents/coordinator/pm_agent.py`:
- Cross-repo prioritization
- Evidence-driven work queue ordering
- Resource allocation across repos

**Task 2.4: Implement objective import**
Create sync mechanism to import objectives from:
`/Users/tmac/1_REPOS/MissionControl/governance/objectives/`
to:
`/Users/tmac/1_REPOS/AI_Orchestrator/vibe-kanban/objectives/`

### Verification
- [ ] All repos have working adapters
- [ ] Ralph loads MissionControl policies
- [ ] PM meta-agent functional
- [ ] Objective import working

---

## Phase 3: Vibe Kanban Implementation (Week 3)

### Objective
Enable parallel, governed agent execution.

### Tasks

**Task 3.1: Create vibe-kanban structure**
```bash
cd /Users/tmac/1_REPOS/AI_Orchestrator
mkdir -p vibe-kanban/{objectives,adrs}
```

**Task 3.2: Create board-state.json schema**
```json
{
  "version": "1.0",
  "objectives": [],
  "adrs": [],
  "tasks": [],
  "agents_active": [],
  "last_updated": "ISO8601"
}
```

**Task 3.3: Enhance Coordinator for objective decomposition**
Update Coordinator agent to:
1. Read objectives from vibe-kanban/objectives/
2. Decompose to ADRs
3. Decompose ADRs to tasks
4. Route tasks to appropriate repo/team

**Task 3.4: Implement parallel execution tracking**
- Track which agents are working on what
- Prevent file collision (same file, multiple agents)
- Implement lock mechanism if needed

**Task 3.5: Create traceability**
Link structure: Objective → ADR → Task → RIS resolution

### Verification
- [ ] vibe-kanban/ structure created
- [ ] board-state.json tracking state
- [ ] Objectives decompose to tasks
- [ ] Parallel execution safe
- [ ] Traceability working

---

## Phase 4: App Repo Simplification (Week 4)

### Objective
Remove duplication, streamline app repos.

### Tasks

**Task 4.1: Replace hot-patterns with KO references**
In both credentialmate and karematch:
- Remove `.claude/memory/hot-patterns.md`
- Add reference to AI_Orchestrator Knowledge Objects
- Update memory search to query KOs

**Task 4.2: Remove duplicated governance**
Remove from app repos any rules that now live in MissionControl:
- Database safety (now in MissionControl)
- Generic security rules (now in MissionControl)
- Keep only domain-specific rules

**Task 4.3: Create sync-from-orchestrator.yaml**
Add to each app repo `.claude/`:
```yaml
orchestrator:
  path: /Users/tmac/1_REPOS/AI_Orchestrator

sync:
  knowledge_objects: true
  work_queue: read-only
  ralph_results: true

constraints:
  no_conflict_with_autonomous: true
```

**Task 4.4: Update skill references**
Update app repo skills to reference MissionControl definitions:
```markdown
## Implements
Skill: database-safety (v1.0) from MissionControl/governance/skills/
```

### Verification
- [ ] No hot-patterns.md in app repos
- [ ] No duplicated governance rules
- [ ] sync-from-orchestrator.yaml in place
- [ ] Skills reference MissionControl definitions

---

## Phase 5: Metrics & Optimization (Week 5+)

### Objective
Measure and improve.

### Tasks

**Task 5.1: Implement autonomy tracking**
Track per-repo:
- % of tasks completed without human intervention
- Average iterations per task
- Escalation frequency

**Task 5.2: Token usage profiling**
Measure:
- Governance context tokens per task
- Target: 2K (down from 5K)

**Task 5.3: Create governance dashboard**
Report:
- Cross-repo task status
- Agent utilization
- Policy violations

### Verification
- [ ] Autonomy metrics collected
- [ ] Token usage measured
- [ ] Dashboard functional

---

## Success Criteria

| Metric | Current | Target |
|--------|---------|--------|
| Autonomy % (credentialmate) | 40-60% | 85%+ |
| Autonomy % (karematch) | 50-70% | 90%+ |
| Governance tokens | 5K/task | 2K/task |
| Cross-repo routing | Manual | Automatic |
| Duplicate learnings | Frequent | Zero |
| Parallel agents | 0 | 3+ concurrent |

---

## Rollback Plan

| Phase | Rollback |
|-------|----------|
| Phase 1 | `git revert` MissionControl commits |
| Phase 2 | `git revert` AI_Orchestrator commits |
| Phase 3 | Disable vibe-kanban/, use existing work_queue |
| Phase 4 | Restore app repo .claude/ from backup |

---

## Execution Notes

1. **Create backups before each phase**
2. **Commit atomically per task** (not per phase)
3. **Run Ralph verification after each change**
4. **Update board-state.json as you progress**
5. **Log all decisions to RIS**

---

## Start Command

To begin execution:
```
Read all planning documents in MissionControl/meta/planning/
Start with Phase 1, Task 1.1
Report progress to board-state.json
```

---

*This continuity prompt enables AI_Orchestrator to execute the governance harmonization plan autonomously.*
