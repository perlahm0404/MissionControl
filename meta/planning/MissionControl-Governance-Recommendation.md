# MissionControl Governance Model: Recommended Path Forward

**Author**: Claude (Analysis based on repository exploration)
**Date**: 2026-01-16
**For**: tmac
**Status**: RECOMMENDATION FOR REVIEW

---

## Executive Summary

After exploring your 8 repositories, I recommend a **Federated Governance Model** where:

- **MissionControl** = Constitutional authority (principles, skills, protocols)
- **AI_Orchestrator** = Execution coordinator (routes work, manages agents)
- **App Repos** = Local enforcement (agents, constraints, hooks)

This leverages what you already built rather than forcing a rewrite.

---

## Your Current Ecosystem

| Repo | Role Today | Governance Maturity |
|------|-----------|---------------------|
| **credentialmate** | Production app (healthcare credentials) | ★★★★★ Most mature |
| **karematch** | Production app (healthcare matching) | ★★★☆☆ Has infrastructure |
| **AI_Orchestrator** | Agent orchestration system | ★★★★☆ Meta-orchestration ready |
| **MissionControl** | Empty scaffold | ★☆☆☆☆ Just created |
| **research** | Documentation archive | ★☆☆☆☆ Minimal |

**Key Insight**: credentialmate already has 40+ enforcement scripts, 54 skills, 16 agents, and a 5-layer safety system. This is your most battle-tested governance. Don't discard it—elevate it.

---

## Three Options Evaluated

### Option A: Pure Centralization
*Everything in MissionControl*

```
MissionControl/
├─ governance/skills/      ← ALL skills (54+)
├─ governance/agents/      ← ALL agent definitions
├─ governance/hooks/       ← ALL enforcement scripts
└─ governance/protocols/   ← Coordination rules

App Repos/
└─ .claude/
   └─ config.yaml          ← Just points to MissionControl
```

**Pros**:
- Single source of truth
- No duplication
- Easy to audit

**Cons**:
- **Breaking change** - credentialmate's mature system must be torn apart
- **Runtime complexity** - Apps need to fetch governance at runtime
- **Lost context** - App-specific nuances (HIPAA for credentialmate) get diluted
- **Single point of failure** - MissionControl outage breaks all apps

**Verdict**: ❌ Too disruptive for your mature ecosystem

---

### Option B: Pure Federation
*Everything stays in app repos*

```
MissionControl/
├─ governance/capsule/     ← High-level principles only
└─ kb/                     ← Shared knowledge

App Repos/
└─ .claude/
   ├─ agents/              ← Full agent definitions
   ├─ skills/              ← Full skill definitions
   └─ hooks/               ← Full enforcement scripts
```

**Pros**:
- No migration needed
- Apps keep full autonomy
- Works today

**Cons**:
- **Drift** - Same skill defined differently in each repo
- **No coordination** - Apps can't share learnings automatically
- **Duplication** - 54 skills × 3 apps = maintenance nightmare
- **Weak governance** - MissionControl is just a documentation repo

**Verdict**: ❌ Defeats the purpose of MissionControl

---

### Option C: Federated with Constitutional Authority (RECOMMENDED)
*Layered governance with clear precedence*

```
MissionControl/                          ← CONSTITUTIONAL (defines WHAT)
├─ governance/
│  ├─ capsule/                           ← Core principles (read-only)
│  ├─ policies/                          ← Global policies
│  ├─ skills/                            ← Skill DEFINITIONS (not implementations)
│  │  ├─ INDEX.md                        ← Canonical skill registry
│  │  ├─ database-safety.skill.md        ← Skill: what it does, constraints
│  │  ├─ code-review.skill.md
│  │  └─ deploy-production.skill.md
│  └─ protocols/                         ← Inter-agent coordination rules
│     ├─ escalation-protocol.md
│     ├─ handoff-protocol.md
│     └─ approval-workflow.md
├─ kb/                                   ← Shared knowledge
└─ ris/                                  ← Decisions & resolutions

AI_Orchestrator/                         ← COORDINATOR (decides WHO)
├─ orchestration/
│  ├─ routing-rules.yaml                 ← Which agent handles what
│  ├─ team-assignments.yaml              ← Agent team compositions
│  └─ escalation-paths.yaml              ← When to escalate to humans
└─ .claude/
   └─ coordinator-agent.md               ← The orchestration agent itself

App Repos (credentialmate, karematch)/   ← OPERATIONAL (defines HOW)
└─ .claude/
   ├─ CLAUDE.md                          ← Local contract (imports MissionControl)
   ├─ agents/                            ← Agent IMPLEMENTATIONS
   │  └─ database-safety-agent.md        ← Implements database-safety skill
   ├─ constraints/                       ← Local restrictions (tighten only)
   │  └─ hipaa-constraints.md            ← credentialmate-specific
   ├─ hooks/scripts/                     ← Local enforcement
   │  └─ database-deletion-guardian.py   ← Stays here (app-specific)
   └─ skills.lock                        ← Pinned versions from MissionControl
```

**How It Works**:

1. **MissionControl defines skills** - "Database Safety" skill says: "Agents must get approval before deletions"

2. **AI_Orchestrator routes work** - "This task needs Database Safety skill, route to credentialmate's database-safety-agent"

3. **App repos implement agents** - credentialmate's agent adds HIPAA-specific checks, karematch adds different checks

4. **Enforcement stays local** - Python hooks run in app repos where they have context

**Pros**:
- ✅ Leverages your existing mature governance (credentialmate)
- ✅ Clear separation of concerns
- ✅ Skills defined once, implemented contextually
- ✅ AI_Orchestrator already designed for this role
- ✅ No single point of failure
- ✅ Incremental migration possible

**Cons**:
- Requires discipline to keep layers clean
- Initial setup to extract skill definitions from credentialmate

**Verdict**: ✅ RECOMMENDED

---

## The Federated Model in Detail

### Layer 1: MissionControl (Constitutional)

**Purpose**: Defines WHAT is allowed across all repos

**Contains**:
| Artifact | Description | Mutability |
|----------|-------------|------------|
| `capsule/` | Core principles | Human-only, version controlled |
| `policies/` | Global rules | Human-only, version controlled |
| `skills/` | Skill definitions (not code) | Human-only, version controlled |
| `protocols/` | Inter-agent rules | Human-only, version controlled |
| `kb/` | Shared knowledge | Human or agent with approval |
| `ris/` | Decisions & resolutions | Human-only |

**Example Skill Definition** (`skills/database-safety.skill.md`):
```markdown
# Skill: Database Safety

## Purpose
Prevent unauthorized data deletion across all repositories.

## Capabilities
- Analyze deletion requests for risk
- Route to approval workflow
- Execute deletions with safeguards

## Constraints
- MUST get human approval for production deletions
- MUST create backup before any deletion
- MUST log all deletion attempts

## Escalation
- Risk score > 7: Escalate to human
- Production database: Always escalate

## Implementations
- credentialmate: `.claude/agents/database-deletion-executor.md`
- karematch: `.claude/agents/data-cleanup-agent.md`
```

**What MissionControl Does NOT Contain**:
- ❌ Executable code (Python hooks)
- ❌ Agent implementations
- ❌ App-specific constraints
- ❌ Runtime configuration

---

### Layer 2: AI_Orchestrator (Coordinator)

**Purpose**: Decides WHO handles WHAT and coordinates multi-agent work

**Contains**:
| Artifact | Description |
|----------|-------------|
| Routing rules | Which skills route to which repos |
| Team assignments | Agent team compositions |
| Escalation paths | When humans must intervene |
| Coordination agents | Agents that manage other agents |

**Example Routing** (`orchestration/routing-rules.yaml`):
```yaml
routing:
  - skill: database-safety
    routes:
      - repo: credentialmate
        when: healthcare_data OR hipaa_context
      - repo: karematch
        when: matching_data
    escalate_to: human
    when: production AND risk_score > 7

  - skill: code-review
    routes:
      - repo: any
    agents:
      - code-reviewer
      - security-scanner
```

**What AI_Orchestrator Does NOT Contain**:
- ❌ Skill definitions (those are in MissionControl)
- ❌ Business logic agents (those are in app repos)
- ❌ App-specific enforcement

---

### Layer 3: App Repos (Operational)

**Purpose**: Defines HOW skills are implemented in context

**Contains**:
| Artifact | Description |
|----------|-------------|
| `agents/` | Agent implementations |
| `constraints/` | Local restrictions |
| `hooks/` | Enforcement scripts |
| `CLAUDE.md` | Local operating contract |
| `skills.lock` | Pinned skill versions |

**Example Agent** (`credentialmate/.claude/agents/database-deletion-executor.md`):
```markdown
# Agent: Database Deletion Executor

## Implements
Skill: database-safety (v1.2) from MissionControl

## Additional Constraints (HIPAA)
- PHI tables require 2-human approval
- Audit logs NEVER deleted
- 7-year retention enforced

## Local Hooks
- Pre-execution: `hooks/scripts/database-deletion-guardian.py`
- Post-execution: `hooks/scripts/audit-logger.py`
```

**Key Rule**: App repos can only TIGHTEN constraints, never loosen them.

---

## Migration Path

### Phase 1: Extract Skill Definitions (Week 1)
Don't move code. Just document skills.

1. Create `MissionControl/governance/skills/INDEX.md`
2. For each of credentialmate's 54 skills:
   - Write a skill DEFINITION (what it does, constraints)
   - Keep the IMPLEMENTATION in credentialmate
   - Add reference from skill to implementation

**Effort**: 4-6 hours
**Risk**: Zero (additive only)

### Phase 2: Create Protocols (Week 1-2)
Document how agents coordinate.

1. Create `MissionControl/governance/protocols/`
2. Extract coordination patterns from AI_Orchestrator
3. Document escalation rules, handoff rules

**Effort**: 2-4 hours
**Risk**: Zero (documentation only)

### Phase 3: Update CLAUDE.md Files (Week 2)
Make app repos reference MissionControl.

1. Add imports to each app's CLAUDE.md:
   ```markdown
   ## Authority Hierarchy
   1. MissionControl/governance/capsule (constitutional)
   2. MissionControl/governance/policies (global)
   3. This CLAUDE.md (local)
   ```

2. Add `skills.lock` file:
   ```yaml
   skills:
     database-safety: v1.2
     code-review: v1.0
   ```

**Effort**: 2-3 hours
**Risk**: Low (just references)

### Phase 4: Enable AI_Orchestrator Routing (Week 3+)
Connect the coordinator.

1. Create routing rules in AI_Orchestrator
2. Test cross-repo skill routing
3. Gradually add more skills

**Effort**: 8-12 hours
**Risk**: Medium (new behavior)

---

## What Stays Where

| Artifact | Location | Reason |
|----------|----------|--------|
| Skill definitions | MissionControl | Single source of truth |
| Agent implementations | App repos | Context-specific |
| Python hooks | App repos | Runtime enforcement |
| Routing rules | AI_Orchestrator | Coordination is its job |
| Knowledge base | MissionControl + local | Global + app-specific |
| RIS decisions | MissionControl | Cross-repo audit trail |
| Session files | App repos | Working notes, app-specific |
| CLAUDE.md | App repos | Local contract (imports global) |

---

## Enforcement Rules

### Rule 1: MissionControl Wins
If MissionControl says "no deletions without approval" and credentialmate says "auto-delete allowed", MissionControl wins.

### Rule 2: Tighten Only
App repos can add constraints, never remove them.
- ✅ credentialmate adds "2-human approval for PHI"
- ❌ credentialmate removes "human approval required"

### Rule 3: Version Pinning
App repos pin skill versions. Breaking changes require explicit upgrade.

### Rule 4: No Silent Drift
Any deviation from MissionControl must be:
- Explicit (documented in constraints/)
- Justified (reason documented)
- Time-bound (expiration if temporary)

---

## Questions You Should Answer

Before proceeding, decide:

1. **Skill granularity**: Are 54 skills too many? Should some be merged?

2. **AI_Orchestrator scope**: Should it only coordinate, or also execute?

3. **Enforcement location**: Keep Python hooks in app repos, or centralize some?

4. **Migration timeline**: Incremental (recommended) or big bang?

5. **Version strategy**: Semantic versioning for skills? Auto-upgrade or manual?

---

## Recommended Next Steps

1. **Review this document** - Does the model make sense?

2. **Start Phase 1** - Extract skill definitions (zero risk)

3. **Test with one skill** - database-safety is a good candidate

4. **Iterate** - Adjust the model based on what you learn

---

## Summary

| Layer | Repo | Defines | Contains |
|-------|------|---------|----------|
| Constitutional | MissionControl | WHAT is allowed | Skills, policies, protocols |
| Coordinator | AI_Orchestrator | WHO handles it | Routing, assignments |
| Operational | App repos | HOW it's done | Agents, hooks, constraints |

This model respects what you've built, enables multi-agent coordination, and provides clear governance without requiring a risky rewrite.

---

# ADDENDUM: Revised Model After AI_Orchestrator Analysis

**Date**: 2026-01-16
**Context**: User asked whether AI_Orchestrator should be the central execution engine, not just coordinator

---

## What AI_Orchestrator Actually Is

After deep analysis, AI_Orchestrator is NOT just a router. It's a **full autonomous execution engine**:

| Capability | Description |
|------------|-------------|
| **Bug Discovery** | Scans repos for ESLint, TypeScript, test failures |
| **Work Queue** | Auto-generates prioritized task lists |
| **Team Execution** | QA Team, Dev Team, Operator Team with specialized agents |
| **Self-Correction** | Wiggum loops retry 15-50 times until success |
| **Ralph Verification** | Quality gates after every change |
| **Direct Commits** | Works in target repos, commits to branches |
| **Knowledge Objects** | Institutional memory that survives sessions |
| **Cross-Repo** | Manages KareMatch AND CredentialMate simultaneously |

**Key insight**: AI_Orchestrator already DOES autonomous building and debugging. It's not theoretical.

---

## Revised Question

The real question is:

**Should AI_Orchestrator be the ONLY execution layer, or should app-level Claude Code sessions coexist?**

---

## Two Execution Modes Today

| Mode | Tool | When Used | Governance |
|------|------|-----------|------------|
| **Autonomous** | AI_Orchestrator | Background work, bulk fixes, feature building | Contracts + Ralph |
| **Interactive** | Claude Code CLI | Real-time debugging, exploration, human-guided | CLAUDE.md + hooks |

**Current friction**: These two modes have different governance systems that can drift.

---

## Option D: AI_Orchestrator as Central Executor (NEW)

*All agent execution flows through AI_Orchestrator*

```
MissionControl/                          ← CONSTITUTIONAL (defines WHAT)
├─ governance/
│  ├─ capsule/
│  ├─ policies/
│  ├─ skills/                            ← Skill definitions
│  └─ protocols/

AI_Orchestrator/                         ← EXECUTOR (does the WORK)
├─ teams/
│  ├─ qa-team/                           ← Bug fixes, code quality
│  ├─ dev-team/                          ← Features, tests
│  └─ operator-team/                     ← Deploys, migrations
├─ adapters/
│  ├─ credentialmate/                    ← App-specific config
│  ├─ karematch/                         ← App-specific config
│  └─ base.py                            ← Shared adapter logic
├─ governance/contracts/                 ← Autonomy contracts
├─ ralph/                                ← Verification engine
└─ knowledge/                            ← Institutional memory

App Repos/                               ← MINIMAL (runtime only)
└─ .claude/
   ├─ adapter-config.yaml                ← Points to AI_Orchestrator adapter
   ├─ constraints/                       ← Local constraints (HIPAA, etc.)
   └─ hooks/scripts/                     ← Runtime enforcement only
```

**How It Works**:

1. **All development work** routes through AI_Orchestrator
2. **Claude Code CLI** invokes AI_Orchestrator commands instead of running directly
3. **App repos** become "targets" with minimal local governance
4. **MissionControl** remains the constitutional authority

**Pros**:
- ✅ Single execution model (no governance drift)
- ✅ Unified quality gates (Ralph everywhere)
- ✅ Cross-repo learning (Knowledge Objects shared)
- ✅ Autonomous AND interactive through same system
- ✅ Already built and working

**Cons**:
- ❌ Interactive sessions slower (must route through orchestrator)
- ❌ Single point of failure (orchestrator down = no work)
- ❌ Requires adapter for every repo
- ❌ May be overkill for simple tasks

---

## Option E: Hybrid with Clear Boundaries (REVISED RECOMMENDATION)

*AI_Orchestrator for autonomous work, app-level for interactive, MissionControl for governance*

```
MissionControl/                          ← CONSTITUTIONAL
├─ governance/
│  ├─ skills/                            ← Skill definitions (SSOT)
│  ├─ protocols/                         ← Inter-agent coordination
│  └─ policies/                          ← Global rules

AI_Orchestrator/                         ← AUTONOMOUS EXECUTION
├─ teams/                                ← QA, Dev, Operator
├─ adapters/                             ← Per-repo config
├─ ralph/                                ← Verification
└─ knowledge/                            ← Shared memory
   └─ imports from MissionControl/kb/

App Repos/                               ← INTERACTIVE EXECUTION
└─ .claude/
   ├─ CLAUDE.md                          ← Imports MissionControl + local
   ├─ agents/                            ← Interactive agents
   ├─ hooks/                             ← Runtime enforcement
   └─ sync-from-orchestrator.yaml        ← NEW: Sync state with AI_Orchestrator
```

**Key Addition**: `sync-from-orchestrator.yaml`

This file keeps app-level Claude Code sessions aware of AI_Orchestrator's state:

```yaml
# .claude/sync-from-orchestrator.yaml
orchestrator:
  path: /Users/tmac/1_REPOS/AI_Orchestrator

sync:
  knowledge_objects: true      # Import KOs into local memory
  work_queue: read-only        # See pending tasks
  ralph_results: true          # Import verification results

constraints:
  no_conflict_with_autonomous: true  # Block if orchestrator is working on same files
```

**Execution Rules**:

| Task Type | Executor | Why |
|-----------|----------|-----|
| Bulk bug fixes | AI_Orchestrator | Autonomous, self-correcting |
| Feature building | AI_Orchestrator | Team isolation, branches |
| Production deploys | AI_Orchestrator | Operator team, approval gates |
| Real-time debugging | Claude Code CLI | Interactive, exploratory |
| Architecture decisions | Claude Code CLI | Human-guided, nuanced |
| Documentation | Either | Low risk |

---

## Decision Framework

**Use AI_Orchestrator when**:
- Task is well-defined (fix lint errors, run tests)
- Autonomous execution is safe
- Cross-repo coordination needed
- Bulk work (10+ files)

**Use Claude Code CLI when**:
- Exploratory/investigative work
- Human needs to guide decisions
- Single-file changes
- Real-time debugging

**Neither should**:
- Redefine skills (MissionControl only)
- Bypass Ralph verification
- Work on same files simultaneously

---

## My Recommendation

**Option E (Hybrid)** because:

1. **AI_Orchestrator is powerful but heavy** - Overkill for "add a console.log"
2. **Interactive sessions need speed** - Routing through orchestrator adds latency
3. **Both modes have value** - Autonomous for bulk, interactive for exploration
4. **Sync mechanism bridges them** - No governance drift

**But with one change**: Add a **Mode Selector** to Claude Code CLI:

```
/mode autonomous   → Route to AI_Orchestrator
/mode interactive  → Run locally with app-level governance
/mode check        → See which mode is appropriate for current task
```

This gives you unified entry point with appropriate execution backend.

---

## Updated Layer Model

| Layer | Repo | Role | Contains |
|-------|------|------|----------|
| **Constitutional** | MissionControl | Defines WHAT | Skills, policies, protocols |
| **Autonomous Execution** | AI_Orchestrator | Does bulk WORK | Teams, Ralph, Knowledge |
| **Interactive Execution** | App repos (.claude/) | Does guided WORK | Agents, hooks |
| **Sync** | Both | Bridges modes | sync-from-orchestrator.yaml |

---

## Next Decision Needed

**Do you want**:

A) **Full centralization** (Option D) - Everything through AI_Orchestrator

B) **Hybrid with sync** (Option E) - Both modes, bridged by sync mechanism

C) **Something else** - Describe your ideal workflow

---

*Document updated: `/Users/tmac/Downloads/MissionControl-Governance-Recommendation.md`*
