# Skills Governance Architecture: Next Steps & Decision Framework

**Date**: 2026-01-16
**Author**: Claude (Opus 4.5 Architecture Analysis)
**Status**: REVISED AFTER MISSIONCONTROL REVIEW

---

## CORRECTION: MissionControl Does NOT Execute

My previous analysis was based on a misreading. After reviewing MissionControl's actual structure:

**MissionControl is purely definitional:**
- Contains skill **DEFINITIONS** (what a skill does) - NOT implementations
- Contains **POLICIES** (rules) - NOT enforcement code
- Contains **PROTOCOLS** (patterns) - NOT execution logic
- Contains **CAPSULE** (principles) - Constitutional only

**The three-layer model is:**
```
MissionControl    → DEFINES what is allowed (skill specs, policies)
AI_Orchestrator   → DECIDES who does it (routing, coordination)
App Repos         → IMPLEMENTS how it's done (actual code/hooks)
```

**Key Insight**: The `close-session` skill DEFINITION already exists in MissionControl (`governance/skills/INDEX.md`). The "duplication" issue in the assessment refers to multiple IMPLEMENTATIONS in app repos - which is **correct architecture** per this model.

---

## Revised Executive Summary

After reviewing MissionControl's actual content:

| What Exists | Status |
|-------------|--------|
| Skill DEFINITIONS | ✅ 50+ skills defined in `governance/skills/INDEX.md` |
| Governance policies | ✅ database-safety, security, governance policies complete |
| Protocols | ✅ escalation, handoff protocols complete |
| Constitutional capsule | ✅ L0-L4, 5-layer deletion, HIPAA defined |

| What's Actually Needed | Priority |
|------------------------|----------|
| **hotfix-chain IMPLEMENTATION enforcement** | P0 (user approved) |
| **Assess implementation gaps** | P1 |
| **Option A vs B is moot** | N/A - MissionControl is already pure definitions |

**The Real Issues:**
1. **DEFINITIONS exist** but **IMPLEMENTATIONS may not enforce them**
2. The `hotfix-chain` skill has scope limits (3 files, 50 lines) defined but enforcement is "convention-only"
3. Session-close has one DEFINITION but multiple IMPLEMENTATIONS - this is **correct architecture**

---

## Section 1: The Core Architectural Decision

### The Intelligence vs Execution Distinction

Your assessment correctly identifies the fundamental tension:

```
OPTION A (Strong Separation)          OPTION B (Weak Separation)
┌─────────────────────────────┐      ┌─────────────────────────────┐
│ MISSION CONTROL             │      │ MISSION CONTROL             │
│ ├─ Advisory skills ✅       │      │ ├─ Advisory skills ✅       │
│ ├─ Diagnostic skills ✅     │      │ ├─ Diagnostic skills ✅     │
│ ├─ Planning skills ✅       │      │ ├─ Session mgmt skills ⚠️   │
│ └─ NO execution ever        │      │ ├─ "Safe" execution ⚠️      │
│                             │      │ └─ Authority-gated execution│
├─────────────────────────────┤      ├─────────────────────────────┤
│ APP-LOCAL / EMERGENCY       │      │ APP-LOCAL / EMERGENCY       │
│ ├─ session-close (moved)    │      │ ├─ Deployment skills        │
│ ├─ handoff-builder (moved)  │      │ └─ Heavy execution          │
│ ├─ governance-enforcer (mv) │      │                             │
│ └─ All execution skills     │      │                             │
└─────────────────────────────┘      └─────────────────────────────┘

Blast radius: 6 skills need redesign   Blast radius: 0 immediate
Long-term complexity: LOW              Long-term complexity: HIGH
Boundary erosion risk: LOW             Boundary erosion risk: HIGH
```

### My Position: Option A with Phased Migration

**Why Option A is architecturally superior:**

1. **Binary boundaries are self-enforcing** - No judgment calls needed
2. **Composition is cleaner** - Intelligence-only skills have no side-effect conflicts
3. **Testing is simpler** - No mocking required for Mission Control skills
4. **Precedent is clear** - First violation is immediately visible

**Why Option B is operationally tempting:**

1. **Zero immediate redesign** - Adopt current skills as-is
2. **Faster adoption** - No migration overhead
3. **Preserves existing patterns** - session-close works today

**My Recommendation: Option A with a transition period**

```
PHASE 1 (NOW):        Emergency skills formalized
PHASE 2 (1-2 weeks):  Session-close SSOT resolved (pick authoritative version)
PHASE 3 (2-4 weeks):  Intelligence/execution split for borderline skills
PHASE 4 (1 month):    Full Option A enforcement
```

---

## Section 2: Immediate Actions (P0 - Emergency/Break-Glass)

### The 3 EMERGENCY-ONLY Skills Need Formalization

| Skill | Current Gap | Required Action |
|-------|-------------|-----------------|
| `rollback-lambda` | No approval gate for production alias changes | Add explicit human approval step |
| `deploy-ec2-fallback` | L4 authority with no audit trail | Add audit logging + approval |
| `hotfix-chain` | Scope limits (3 files, 50 lines) enforced by convention only | Add code-level validation |

### Proposed Emergency Protocol

```yaml
# MissionControl/governance/protocols/emergency-protocol.yaml

emergency_skills:
  - id: rollback-lambda
    authority: L4
    approval_required: always
    approval_format: "I APPROVE PRODUCTION ROLLBACK TO [version]"
    audit_required: true
    post_incident_review: mandatory

  - id: deploy-ec2-fallback
    authority: L4
    approval_required: always
    approval_format: "I APPROVE EC2 FALLBACK DEPLOYMENT"
    audit_required: true
    max_duration: 4_hours
    escalation: site_reliability_review

  - id: hotfix-chain
    authority: L4
    approval_required: always
    scope_limits:
      max_files: 3
      max_lines: 50
      enforcement: code_validation  # NOT convention
    audit_required: true
    rollback_plan: required

audit_requirements:
  - timestamp
  - initiating_agent
  - approving_human
  - affected_resources
  - outcome
  - rollback_status
```

### Action Item 1: Create Emergency Protocol

**File**: `MissionControl/governance/protocols/emergency-protocol.md`
**Effort**: 2 hours
**Risk**: Zero (additive governance)
**Dependency**: None

---

## Section 3: Session-Close SSOT Resolution (P1)

### Current State: Dual Implementations

| Location | Structure | Execution Components |
|----------|-----------|---------------------|
| AI_Orchestrator | Generic session termination | Git operations, file creation |
| KareMatch | Verification-heavy session close | turbo typecheck/lint/test, security scans, git ops |

### The SSOT Violation

Both implementations:
- Create handoff files
- Run git status/diff/log
- Perform commits
- Have HIGH severity violations of "intelligence without execution"

### Resolution Options

**Option 1: KareMatch version becomes authoritative**
- Pros: More mature, verification-heavy
- Cons: Turborepo-specific patterns may not generalize
- Migration: AI_Orchestrator references KareMatch

**Option 2: AI_Orchestrator version becomes authoritative**
- Pros: Generic, no app-specific coupling
- Cons: Less sophisticated than KareMatch version
- Migration: KareMatch inherits from AI_Orchestrator

**Option 3: Split into intelligence + execution (Recommended)**
```
session-close-intelligence (MISSION-CONTROL)
├─ Analyzes what changed
├─ Generates handoff summary
├─ Recommends verification steps
└─ Returns structured data, NO execution

session-close-execution (APP-LOCAL)
├─ Receives intelligence output
├─ Runs verification commands
├─ Creates files
├─ Performs git operations
└─ Implementation varies per app
```

### My Recommendation: Option 3 (Split)

This aligns with Option A (Strong Separation) and creates a clean architecture:

```
MissionControl/governance/skills/session-close-intelligence.md
  → "Analyze session, generate handoff summary, recommend steps"
  → Pure intelligence, no execution
  → Same skill definition across all repos

KareMatch/.claude/skills/session-close-execution/
  → Imports session-close-intelligence
  → Adds: turbo typecheck, lint, test
  → Adds: security scan patterns
  → Performs git operations

AI_Orchestrator/.claude/skills/session-close-execution/
  → Imports session-close-intelligence
  → Simpler execution (generic git ops)
  → No turborepo specifics
```

### Action Item 2: Resolve Session-Close SSOT

**Decision Needed**: Approve Option 3 (split into intelligence + execution)
**Effort**: 4-6 hours
**Risk**: Medium (behavioral change)
**Dependency**: Completes before Mission Control charter finalization

---

## Section 4: Mission Control Charter Clarification (P2)

### Why This Can Wait

1. **Emergency governance is more urgent** - L4 skills lack approval gates NOW
2. **Session-close resolution informs the decision** - Proves/disproves the split pattern
3. **50% of MISSION-CONTROL candidates are already clean** - Advisory skills need no change

### The 6 Skills Requiring Redesign Under Option A

| Skill | Violation | Structural? | Split Strategy |
|-------|-----------|-------------|----------------|
| session-close (both) | File creation, git operations | Yes | Intelligence + Execution |
| handoff-builder | File creation | Yes | Intelligence + Execution |
| governance-enforcer | Execution blocking | Yes | Policy definition + Enforcement hook |
| tdd-enforcer | Workflow gating | Yes | TDD analysis + Gate hook |
| auto-investigator | Command execution | **No** | Remove execution, output recommendations |

### Auto-Investigator is the Exception

This skill has an **incidental** violation - it CAN be redesigned to output recommendations only without losing core functionality. The other 5 have **structural** violations where execution IS the deliverable.

### Decision Framework for Charter

**If you choose Option A (Strong Separation):**

1. Formalize emergency protocol immediately (P0)
2. Split session-close as proof of concept (P1)
3. Apply same pattern to handoff-builder, governance-enforcer, tdd-enforcer
4. Auto-investigator becomes recommendation-only
5. MISSION-CONTROL boundary becomes: "Skills that produce data/analysis, never side effects"

**If you choose Option B (Weak Separation):**

1. Formalize emergency protocol immediately (P0)
2. Define "safe execution" criteria explicitly
3. Document which execution types are allowed in MISSION-CONTROL
4. Accept ongoing adjudication burden
5. Plan for boundary erosion mitigation

---

## Section 5: Location Mismatches to Address

### 8 MISSION-CONTROL Skills Currently in KareMatch

| Skill | Should Move To | Blocker |
|-------|----------------|---------|
| governance-enforcer | MissionControl (after split) | Structural violation |
| tdd-enforcer | MissionControl (after split) | Structural violation |
| diagnose-docker | MissionControl (ready now) | None - pure diagnostic |
| diagnose-build | MissionControl (ready now) | Minor turborepo coupling |
| handoff-builder | MissionControl (after split) | Structural violation |
| plan-optimizer | MissionControl (ready now) | None - pure intelligence |
| context-monitor | MissionControl (ready now) | None - read-only |
| auto-investigator | MissionControl (after redesign) | Incidental violation |

### Immediate Moves (No Redesign Needed)

These 4 skills can move to MissionControl TODAY:
- `diagnose-docker` - Generic, no app dependencies
- `diagnose-build` - Minor turborepo refs, easily parameterized
- `plan-optimizer` - Token budget logic is universal
- `context-monitor` - Pure read-only utility

### Action Item 3: Move Clean MISSION-CONTROL Skills

**Files to create**:
```
MissionControl/governance/skills/diagnose-docker.skill.md
MissionControl/governance/skills/diagnose-build.skill.md
MissionControl/governance/skills/plan-optimizer.skill.md
MissionControl/governance/skills/context-monitor.skill.md
```

**Effort**: 2-3 hours
**Risk**: Zero (skill definitions, not implementations)
**Dependency**: None

---

## Section 6: Authority Level Remediation

### 15+ Skills Have "Unknown" Authority

The assessment notes 15+ skills lack explicit authority level. This creates enforcement gaps.

### Proposed Authority Assignment

| Skill Category | Default Authority | Rationale |
|----------------|-------------------|-----------|
| Advisory (app/data/uiux) | L1 | Consultation only, no side effects |
| Diagnostic | L1-L2 | Read-only or limited command execution |
| Session Management | L2 | File creation, git operations |
| Database Operations | L3 | Schema changes require verification |
| Deployment | L3-L4 | Production impact |
| Emergency | L4 | Break-glass authority |

### Action Item 4: Authority Level Audit

**Task**: Assign authority levels to all 36 inventoried skills
**Effort**: 3-4 hours
**Risk**: Zero (metadata only)
**Dependency**: None

---

## Section 7: Recommended Sequence

```
WEEK 1
├─ Day 1-2: Formalize Emergency Protocol (P0)
│   └─ Create emergency-protocol.yaml
│   └─ Add audit requirements to 3 emergency skills
│   └─ Implement approval gates
│
├─ Day 3-4: Move Clean Skills (P1 parallel)
│   └─ Move diagnose-docker, diagnose-build, plan-optimizer, context-monitor
│   └─ Create skill definitions in MissionControl
│
└─ Day 5: Authority Level Audit
    └─ Assign L0-L4 to all 36 skills

WEEK 2
├─ Day 1-3: Session-Close Split (P1)
│   └─ Create session-close-intelligence skill definition
│   └─ Create session-close-execution template
│   └─ Implement in KareMatch and AI_Orchestrator
│
└─ Day 4-5: Validate Pattern
    └─ Test split skill workflow
    └─ Document lessons learned

WEEK 3-4
├─ Apply split pattern to:
│   └─ handoff-builder
│   └─ governance-enforcer
│   └─ tdd-enforcer
│
└─ Finalize Mission Control Charter
    └─ Option A (Strong Separation) confirmed by successful splits
    └─ OR Option B if splits prove impractical
```

---

## Section 8: Decision Checkpoints

### Checkpoint 1: Emergency Protocol (End of Week 1)

**Success Criteria**:
- [ ] All 3 EMERGENCY-ONLY skills have explicit approval gates
- [ ] Audit logging requirements documented
- [ ] Scope limits for hotfix-chain are code-enforced (not convention)

### Checkpoint 2: Session-Close Resolution (End of Week 2)

**Success Criteria**:
- [ ] Single authoritative definition exists
- [ ] Intelligence/execution split proven viable (or rejected)
- [ ] Both repos use consistent implementation

### Checkpoint 3: Mission Control Charter (End of Week 4)

**Success Criteria**:
- [ ] Option A or Option B formally selected
- [ ] All MISSION-CONTROL skills comply with chosen boundary
- [ ] Enforcement mechanism documented

---

## Section 9: Questions for tmac

Before proceeding, I need your input on:

### Q1: Emergency Protocol Urgency
The 3 EMERGENCY-ONLY skills (rollback-lambda, deploy-ec2-fallback, hotfix-chain) can modify production without documented approval gates.

**Do you want me to draft the emergency-protocol.yaml now?**

### Q2: Session-Close Split Approach
I recommend splitting session-close into intelligence (MISSION-CONTROL) and execution (APP-LOCAL).

**Do you approve this approach, or prefer a different resolution?**

### Q3: Option A vs Option B Timeline
I recommend deferring the final charter decision until after session-close split proves the pattern.

**Is this timeline acceptable, or do you need the charter decision sooner?**

### Q4: Clean Skill Migration
The 4 clean skills (diagnose-docker, diagnose-build, plan-optimizer, context-monitor) can move to MissionControl immediately.

**Do you want me to create these skill definitions now?**

---

## Summary

| Layer | Decision | My Recommendation | Urgency |
|-------|----------|-------------------|---------|
| Emergency | Formalize 3 L4 skills | Create protocol ASAP | **HIGH** |
| SSOT | Resolve session-close | Split into intelligence + execution | **MEDIUM** |
| Charter | Option A vs Option B | Option A (Strong Separation) | **LOW** (defer 2-4 weeks) |
| Location | Move 8 skills | Start with 4 clean skills | **MEDIUM** |
| Authority | Assign L0-L4 | Audit all 36 skills | **LOW** |

The path forward is clear: **stabilize emergency governance first, prove the intelligence/execution split pattern, then formalize the charter.**

---

*Document created: 2026-01-16*
*Based on: skills-governance-assessment-v2.md analysis*
*Architectural recommendation: Option A (Strong Separation) with phased migration*
