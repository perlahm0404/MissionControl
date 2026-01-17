# AI Orchestrator System Architecture & Workflow

**Document**: AI Orchestrator Complete System Guide
**Version**: 1.0
**Date**: 2026-01-16
**Status**: Approved

---

## Executive Summary

The AI Orchestrator is an autonomous multi-agent system with **three distinct components**:

| Component | Purpose | What It Does |
|-----------|---------|--------------|
| **Ralph** | Verification Engine | Runs quality checks (lint, typecheck, tests) and returns PASS/FAIL/BLOCKED |
| **Wiggum** | Iteration Control | Manages agent retry loops until Ralph says PASS or budget exhausted |
| **Autonomous Loop** | Task Orchestration | Loads work queues, runs agents, handles results |

**Key Insight**: Ralph tells you IF code is good. Wiggum decides WHAT to do about it.

---

## Table of Contents

1. [System Architecture Overview](#1-system-architecture-overview)
2. [Ralph: The Verification Engine](#2-ralph-the-verification-engine)
3. [Wiggum: The Iteration Controller](#3-wiggum-the-iteration-controller)
4. [The Autonomous Loop](#4-the-autonomous-loop)
5. [How MissionControl, AI_Orchestrator, and Repos Interact](#5-how-missioncontrol-ai_orchestrator-and-repos-interact)
6. [Complete Workflow: Objective to Execution](#6-complete-workflow-objective-to-execution)
7. [Bug Discovery and Task Generation](#7-bug-discovery-and-task-generation)
8. [Adapter System](#8-adapter-system)
9. [Completion Signals](#9-completion-signals)
10. [Governance and Policy Integration](#10-governance-and-policy-integration)

---

## 1. System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        MISSIONCONTROL                                    │
│                    (Constitutional Authority)                            │
│                                                                          │
│  governance/                                                             │
│  ├─ capsule/        → Immutable principles (L0-L4 autonomy, HIPAA)      │
│  ├─ policies/       → database-safety.md, security.md, governance.md    │
│  ├─ protocols/      → escalation, handoff, parallel-execution           │
│  ├─ objectives/     → High-level goals                                  │
│  └─ skills/         → Skill registry                                    │
│                                                                          │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ Policies flow DOWN
                                 │ Objectives flow DOWN
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        AI_ORCHESTRATOR                                   │
│                       (Strategic HQ / Execution Engine)                  │
│                                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                   │
│  │   RALPH      │  │   WIGGUM     │  │  AUTONOMOUS  │                   │
│  │ Verification │  │  Iteration   │  │    LOOP      │                   │
│  │   Engine     │  │   Control    │  │              │                   │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘                   │
│         │                 │                 │                            │
│         │    Verdict      │    Decision     │    Task                    │
│         │  PASS/FAIL/     │   ALLOW/BLOCK/  │   Execution                │
│         │   BLOCKED       │   ASK_HUMAN     │                            │
│         │                 │                 │                            │
│  ┌──────┴─────────────────┴─────────────────┴──────┐                    │
│  │                                                  │                    │
│  │  vibe-kanban/     → Objectives, ADRs, Tasks     │                    │
│  │  adapters/        → Repo configurations         │                    │
│  │  tasks/           → Work queues                 │                    │
│  │  agents/          → PM Agent, Traceability      │                    │
│  │                                                  │                    │
│  └──────────────────────────────────────────────────┘                    │
│                                                                          │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ Tasks flow DOWN
                                 │ Results flow UP
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          APP REPOS                                       │
│                      (Business Units / Execution)                        │
│                                                                          │
│  ┌─────────────────────┐         ┌─────────────────────┐                │
│  │   CREDENTIALMATE    │         │     KAREMATCH       │                │
│  │   (L1 - HIPAA)      │         │     (L2 - Standard) │                │
│  │                     │         │                     │                │
│  │  CLAUDE.md          │         │  CLAUDE.md          │                │
│  │  → References       │         │  → References       │                │
│  │    MissionControl   │         │    MissionControl   │                │
│  │                     │         │                     │                │
│  │  .claude/           │         │  .claude/           │                │
│  │  → Local hooks      │         │  → Local hooks      │                │
│  │  → Local rules      │         │  → Local rules      │                │
│  │                     │         │                     │                │
│  │  Source code        │         │  Source code        │                │
│  │  Tests              │         │  Tests              │                │
│  └─────────────────────┘         └─────────────────────┘                │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Ralph: The Verification Engine

### What Ralph Is

**Ralph is a 4-step code quality verification pipeline.** It does NOT control iteration loops or make decisions about what to do next - it simply verifies code and returns a verdict.

**Location**: `/Users/tmac/1_REPOS/AI_Orchestrator/ralph/`

### The 4-Step Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                    RALPH VERIFICATION PIPELINE                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  STEP 0: GUARDRAILS SCAN (CRITICAL - Runs First)                │
│  ├─ Scans for patterns from MissionControl policies             │
│  ├─ Checks: @ts-ignore, eslint-disable, .skip(), hardcoded PHI  │
│  └─ If violations found → BLOCKED (cannot proceed)              │
│                                                                  │
│  STEP 1: LINT                                                    │
│  ├─ ESLint (TypeScript projects)                                │
│  ├─ Ruff (Python projects)                                       │
│  └─ Collects: unused imports, console logs, security issues     │
│                                                                  │
│  STEP 2: TYPECHECK                                               │
│  ├─ TypeScript compiler (tsc)                                    │
│  ├─ MyPy (Python projects)                                       │
│  └─ Collects: type errors, missing annotations                  │
│                                                                  │
│  STEP 3: TESTS                                                   │
│  ├─ Vitest (TypeScript projects)                                │
│  ├─ Pytest (Python projects)                                     │
│  └─ Collects: test failures, coverage gaps                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Ralph Verdicts

| Verdict | Meaning | What Happens Next |
|---------|---------|-------------------|
| **PASS** | All steps succeeded | Safe to merge/proceed |
| **FAIL** | One or more steps failed (fixable) | Agent should retry |
| **BLOCKED** | Guardrail violations detected | Cannot proceed without human decision |

### Regression Detection

Ralph compares current results against a baseline to detect regressions:

```python
# Example Ralph verdict structure
{
    "verdict": "FAIL",
    "safe_to_merge": True,      # Pre-existing failures only
    "regression_detected": False,
    "pre_existing_failures": ["lint", "typecheck"],
    "new_failures": [],
    "steps": {
        "guardrails": {"status": "pass"},
        "lint": {"status": "fail", "count": 3},
        "typecheck": {"status": "fail", "count": 1},
        "tests": {"status": "pass"}
    }
}
```

**Key Insight**: If failures existed BEFORE the agent made changes, `safe_to_merge=True` even with a FAIL verdict.

### MissionControl Policy Integration

Ralph loads guardrail patterns from MissionControl:

```
/Users/tmac/1_REPOS/MissionControl/governance/policies/
├─ database-safety.md  → DELETE without WHERE, DROP TABLE patterns
├─ security.md         → Hardcoded secrets, PHI patterns
└─ governance.md       → Protected file patterns
```

---

## 3. Wiggum: The Iteration Controller

### What Wiggum Is

**Wiggum is the iteration control system that manages agent self-correction loops.** It uses Ralph's verdicts to decide whether an agent should continue iterating, stop successfully, or escalate to a human.

**Location**: `/Users/tmac/1_REPOS/AI_Orchestrator/orchestration/iteration_loop.py`

### The Stop Hook Decision Tree

```
┌─────────────────────────────────────────────────────────────────┐
│                    WIGGUM STOP HOOK DECISION TREE                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. CHECK COMPLETION SIGNAL                                      │
│     └─ Agent output contains: <promise>BUGFIX_COMPLETE</promise> │
│        ├─ YES → Continue to verification                        │
│        └─ NO  → Continue anyway (signal optional)               │
│                                                                  │
│  2. CHECK ITERATION BUDGET                                       │
│     └─ current_iteration >= max_iterations?                     │
│        ├─ YES → ASK_HUMAN (budget exhausted)                    │
│        └─ NO  → Continue                                        │
│                                                                  │
│  3. CHECK FOR CHANGES                                            │
│     └─ git diff shows files changed?                            │
│        ├─ YES → Continue                                        │
│        └─ NO  → BLOCK (agent may have failed silently)          │
│                                                                  │
│  4. RUN RALPH VERIFICATION                                       │
│     └─ Ralph returns verdict:                                   │
│        ├─ PASS     → ALLOW ✓ (task complete)                    │
│        ├─ BLOCKED  → ASK_HUMAN (guardrail violation)            │
│        └─ FAIL     → Check regression:                          │
│           ├─ safe_to_merge=true  → ALLOW ✓ (pre-existing OK)    │
│           └─ regression=true     → BLOCK (agent retries)        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Wiggum Decisions

| Decision | Meaning | What Happens |
|----------|---------|--------------|
| **ALLOW** | Task completed successfully | Exit loop, commit changes |
| **BLOCK** | Agent should retry | Continue to iteration N+1 |
| **ASK_HUMAN** | Human decision needed | Pause for R/O/A prompt |

### Iteration Budgets

| Agent Type | Max Iterations | Use Case |
|------------|---------------|----------|
| BugFixAgent | 15 | Fix specific bugs |
| CodeQualityAgent | 20 | Lint/type cleanup |
| FeatureBuilder | 50 | New functionality |
| TestWriter | 15 | Write tests |

### Non-Interactive Mode

```bash
python autonomous_loop.py --project karematch --non-interactive
```

In non-interactive mode:
- **BLOCKED → Auto-revert** changes instead of prompting
- Useful for CI/CD pipelines and batch execution

---

## 4. The Autonomous Loop

### What the Autonomous Loop Does

**The autonomous loop is the main orchestration system** that loads work queues, runs agents through Wiggum, and handles results.

**Location**: `/Users/tmac/1_REPOS/AI_Orchestrator/autonomous_loop.py`

### Execution Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    AUTONOMOUS LOOP EXECUTION                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  INITIALIZATION:                                                 │
│  ├─ Load work queue: tasks/work_queue_{project}.json            │
│  ├─ Load adapter: KareMatchAdapter or CredentialMateAdapter     │
│  ├─ Initialize circuit breaker (max 100 Lambda calls)           │
│  ├─ Initialize resource tracker (max $50/day, 500 iterations)   │
│  └─ Validate tasks (mark missing files as blocked)              │
│                                                                  │
│  MAIN LOOP (for each iteration up to max):                      │
│  │                                                               │
│  ├─ 1. SYSTEM CHECKS                                            │
│  │     ├─ Kill-switch status                                    │
│  │     ├─ Circuit breaker limits                                │
│  │     └─ Resource budget                                       │
│  │                                                               │
│  ├─ 2. GET NEXT TASK                                            │
│  │     └─ From queue: in_progress first, then pending           │
│  │                                                               │
│  ├─ 3. RUN META-AGENT GATES (v6.0)                              │
│  │     ├─ Governance Agent (ALWAYS: risk assessment)            │
│  │     ├─ PM Agent (if feature or user-impacting)               │
│  │     └─ CMO Agent (if GTM-related)                            │
│  │                                                               │
│  ├─ 4. CREATE AGENT                                             │
│  │     ├─ Infer type from task ID (BUGFIX-001 → BugFixAgent)    │
│  │     ├─ Set completion promise (e.g., "BUGFIX_COMPLETE")      │
│  │     └─ Set iteration budget (15-50)                          │
│  │                                                               │
│  ├─ 5. RUN WIGGUM ITERATION LOOP                                │
│  │     ┌─────────────────────────────────────────────────┐      │
│  │     │  Loop iteration N (up to max_iterations):       │      │
│  │     │  ├─ Agent.execute(task_id)                      │      │
│  │     │  ├─ Get changed files (git diff)                │      │
│  │     │  ├─ Run stop hook → ALLOW/BLOCK/ASK_HUMAN       │      │
│  │     │  └─ Record iteration metrics                    │      │
│  │     └─────────────────────────────────────────────────┘      │
│  │                                                               │
│  ├─ 6. HANDLE RESULT                                            │
│  │     ├─ COMPLETED:                                            │
│  │     │   ├─ Git commit with task ID                           │
│  │     │   ├─ Create Knowledge Object if warranted              │
│  │     │   └─ Update progress file                              │
│  │     └─ BLOCKED/FAILED:                                       │
│  │         └─ Mark task blocked, continue to next               │
│  │                                                               │
│  └─ Continue until: queue empty OR max_iterations OR kill-switch│
│                                                                  │
│  FINAL STATS:                                                    │
│  ├─ Work queue summary                                          │
│  ├─ Circuit breaker stats                                       │
│  └─ Resource usage (iterations, API calls, cost)                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Running the Autonomous Loop

```bash
# Start autonomous execution
python autonomous_loop.py --project karematch --max-iterations 100

# Resume interrupted session (automatic)
python autonomous_loop.py --project karematch

# Non-interactive mode (for CI)
python autonomous_loop.py --project karematch --non-interactive
```

### State Persistence

State is saved to `.aibrain/agent-loop.local.md`:

```yaml
iteration: 2
max_iterations: 15
completion_promise: "BUGFIX_COMPLETE"
task_id: "BUGFIX-001"
agent_name: "BugFixAgent"
session_id: "abc-123"
started_at: "2026-01-16T10:30:00"
project_name: "karematch"
```

If interrupted (Ctrl+C, crash), simply re-run the same command - it automatically resumes.

---

## 5. How MissionControl, AI_Orchestrator, and Repos Interact

### Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         DATA FLOW                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  MISSIONCONTROL → AI_ORCHESTRATOR                               │
│  ├─ Policies (database-safety, security, governance)            │
│  ├─ Objectives (high-level goals)                               │
│  ├─ Protocols (escalation, handoff, parallel-execution)         │
│  └─ Skill definitions (what skills should do)                   │
│                                                                  │
│  AI_ORCHESTRATOR → APP REPOS                                    │
│  ├─ Tasks (work queue items)                                    │
│  ├─ Agent execution (runs in repo context)                      │
│  ├─ Ralph verification (runs repo lint/type/tests)              │
│  └─ Git commits (after successful verification)                 │
│                                                                  │
│  APP REPOS → AI_ORCHESTRATOR                                    │
│  ├─ Test results                                                │
│  ├─ Lint/typecheck output                                       │
│  ├─ Changed files (git diff)                                    │
│  └─ Completion signals                                          │
│                                                                  │
│  AI_ORCHESTRATOR → MISSIONCONTROL                               │
│  ├─ Metrics (autonomy %, iterations, escalations)               │
│  ├─ RIS resolutions (new learnings)                             │
│  └─ Traceability (Objective → ADR → Task → Resolution)          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Interaction Mechanisms

#### 1. Policy Inheritance (MissionControl → AI_Orchestrator → Repos)

```python
# AI_Orchestrator loads MissionControl policies
from ralph.policy.mission_control import get_policies

policies = get_policies()
# policies.capsule_path = /Users/tmac/1_REPOS/MissionControl/governance/capsule
# policies.policies_path = /Users/tmac/1_REPOS/MissionControl/governance/policies

# Ralph loads guardrail patterns from policies
patterns = policies.get_guardrail_patterns(hipaa_enabled=True)
# Returns: DELETE without WHERE, DROP TABLE, hardcoded secrets patterns
```

#### 2. Adapter System (AI_Orchestrator → Repos)

```python
# Each repo has an adapter with commands and paths
class KareMatchAdapter:
    def get_context(self) -> AppContext:
        return AppContext(
            project_name="karematch",
            project_path="/Users/tmac/1_REPOS/karematch",
            lint_command="npm run lint -- --format=json",
            typecheck_command="npm run check",
            test_command="npm test -- --reporter=json",
            autonomy_level="L2"  # Higher trust (not HIPAA)
        )
```

#### 3. Objective Decomposition (MissionControl → AI_Orchestrator)

```
MissionControl/governance/objectives/
    └─ objective-001.yaml
           ↓
AI_Orchestrator/vibe-kanban/objectives/
    └─ objective-001.yaml (synced)
           ↓
    VibeKanbanIntegration.decompose_objective_to_adrs()
           ↓
AI_Orchestrator/vibe-kanban/adrs/
    └─ ADR-objective-001-001.yaml
           ↓
    VibeKanbanIntegration.decompose_adr_to_tasks()
           ↓
AI_Orchestrator/tasks/work_queue_karematch.json
    └─ TASK-ADR-objective-001-001-001
```

#### 4. CLAUDE.md Authority Hierarchy (Repos → MissionControl)

Both app repos reference MissionControl in their CLAUDE.md:

```markdown
## Authority Hierarchy

| Level | Source | Scope |
|-------|--------|-------|
| 1 | MissionControl/governance/capsule/ | Constitutional principles (immutable) |
| 2 | MissionControl/governance/policies/ | Global policies (can tighten) |
| 3 | This CLAUDE.md | Local rules (can tighten global) |
| 4 | .claude/rules/ | Additional tightening only |

**Inherited from MissionControl:**
- L0-L4 autonomy levels → capsule/ai-governance-principles.md
- 5-layer database deletion defense → policies/database-safety.md
- Security guardrails → policies/security.md
- Escalation hierarchy → protocols/escalation-protocol.md
```

---

## 6. Complete Workflow: Objective to Execution

### End-to-End Example

```
┌─────────────────────────────────────────────────────────────────┐
│              COMPLETE WORKFLOW: FIXING A BUG                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  STEP 1: OBJECTIVE CREATED IN MISSIONCONTROL                    │
│  ────────────────────────────────────────────                   │
│  File: MissionControl/governance/objectives/improve-auth.yaml   │
│  Content:                                                        │
│    id: improve-auth                                              │
│    title: "Improve authentication reliability"                   │
│    repos: [karematch]                                           │
│    priority: P1                                                  │
│                                                                  │
│  STEP 2: OBJECTIVE SYNCED TO AI_ORCHESTRATOR                    │
│  ───────────────────────────────────────────                    │
│  python -m vibe_kanban.objective_sync sync                      │
│  → Creates: AI_Orchestrator/vibe-kanban/objectives/improve-auth.yaml │
│                                                                  │
│  STEP 3: OBJECTIVE DECOMPOSED TO ADRs                           │
│  ────────────────────────────────────                           │
│  VibeKanbanIntegration.decompose_objective_to_adrs(objective)   │
│  → Creates: ADR-improve-auth-001.yaml                           │
│    Title: "API Design: Improve authentication reliability"      │
│                                                                  │
│  STEP 4: ADR DECOMPOSED TO TASKS                                │
│  ───────────────────────────────                                │
│  VibeKanbanIntegration.decompose_adr_to_tasks(adr)              │
│  → Creates tasks in work queue:                                 │
│    - TASK-ADR-improve-auth-001-001: "Implement API"             │
│    - TASK-ADR-improve-auth-001-002: "Write API tests"           │
│                                                                  │
│  STEP 5: AUTONOMOUS LOOP STARTS                                 │
│  ──────────────────────────────                                 │
│  python autonomous_loop.py --project karematch                  │
│                                                                  │
│  STEP 6: TASK EXECUTION (WIGGUM ITERATION LOOP)                 │
│  ──────────────────────────────────────────────                 │
│                                                                  │
│    Iteration 1:                                                  │
│    ├─ Agent modifies: src/auth/session.ts                       │
│    ├─ Ralph verification:                                       │
│    │   ├─ Guardrails: PASS                                      │
│    │   ├─ Lint: FAIL (2 errors)                                 │
│    │   ├─ Typecheck: PASS                                       │
│    │   └─ Tests: PASS                                           │
│    │   → Verdict: FAIL (regression detected)                    │
│    └─ Wiggum decision: BLOCK (retry)                            │
│                                                                  │
│    Iteration 2:                                                  │
│    ├─ Agent fixes lint errors                                   │
│    ├─ Ralph verification: PASS (all steps)                      │
│    ├─ Agent output: "Done. <promise>FEATURE_COMPLETE</promise>" │
│    └─ Wiggum decision: ALLOW (task complete)                    │
│                                                                  │
│  STEP 7: TASK COMPLETED                                         │
│  ──────────────────────                                         │
│  ├─ Git commit: "feat: Improve authentication API"              │
│  ├─ Task marked COMPLETE in work queue                          │
│  ├─ Knowledge Object created (2 iterations + PASS = high value) │
│  └─ Traceability recorded:                                      │
│      Objective:improve-auth → ADR-001 → TASK-001 → KO-xxx       │
│                                                                  │
│  STEP 8: METRICS UPDATED                                        │
│  ───────────────────────                                        │
│  MetricsCollector.complete_task("TASK-001", ralph_verdict="PASS")│
│  → Autonomy tracking updated                                    │
│  → Token usage recorded                                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 7. Bug Discovery and Task Generation

### Automated Bug Discovery

```bash
aibrain discover-bugs --project karematch
```

### Discovery Sources

| Source | What It Finds | Parser |
|--------|--------------|--------|
| **ESLint** | Unused imports, console logs, security issues | ESLintParser |
| **TypeScript** | Type errors, missing annotations | TypeScriptParser |
| **Vitest** | Test failures | TestParser |
| **Guardrails** | @ts-ignore, eslint-disable, .only(), .skip() | GuardrailParser |

### Task Generation Flow

```
1. BugScanner runs all 4 parsers
   ↓
2. Collect bugs with: file, line, message, severity
   ↓
3. Detect NEW vs BASELINE (first run = baseline)
   ↓
4. TaskGenerator groups by file (reduces 50-70%)
   ↓
5. Assign priority: P0 (blocks) > P1 (degrades UX) > P2 (tech debt)
   ↓
6. Set completion_promise (auto-detected from task type)
   ↓
7. Register in work queue as pending tasks
```

### Example Output

```
📋 Task Summary:
  🆕 [P0] TEST-LOGIN-001: Fix 2 test error(s) (NEW REGRESSION)
  🆕 [P0] TYPE-SESSION-002: Fix 1 typecheck error(s) (NEW REGRESSION)
     [P1] LINT-MATCHING-003: Fix 3 lint error(s) (baseline)
     [P2] GUARD-CONFIG-007: Fix 2 guardrails error(s) (baseline)
```

---

## 8. Adapter System

### Adapter Configuration

Each repo has an adapter in `/Users/tmac/1_REPOS/AI_Orchestrator/adapters/`:

```yaml
# adapters/karematch/config.yaml
project:
  name: karematch
  path: /Users/tmac/1_REPOS/karematch

commands:
  lint: npm run lint -- --format=json
  typecheck: npm run check
  test: npm test -- --reporter=json
  build: npm run build

autonomy_level: L2

governance:
  authority: MissionControl
  capsule_path: /Users/tmac/1_REPOS/MissionControl/governance/capsule/
  policies_path: /Users/tmac/1_REPOS/MissionControl/governance/policies/
  policies:
    - database-safety.md
    - security.md
    - governance.md
```

### Adapter Usage

```python
from adapters import KareMatchAdapter

adapter = KareMatchAdapter()
context = adapter.get_context()

# context.project_path = "/Users/tmac/1_REPOS/karematch"
# context.lint_command = "npm run lint -- --format=json"
# context.autonomy_level = "L2"
```

---

## 9. Completion Signals

### Auto-Detection from Task Keywords

| Task Type | Signal | Keywords |
|-----------|--------|----------|
| bugfix | `BUGFIX_COMPLETE` | bug, fix, error, issue |
| codequality | `CODEQUALITY_COMPLETE` | quality, lint, clean |
| feature | `FEATURE_COMPLETE` | feature, add, implement |
| test | `TESTS_COMPLETE` | test, spec, coverage |
| refactor | `REFACTOR_COMPLETE` | refactor, restructure |

### Signal Format

Agent outputs:
```
All tests passing, bug fixed. <promise>BUGFIX_COMPLETE</promise>
```

Wiggum extracts with regex: `r'<promise>(.*?)</promise>'`

### Signal Impact on Decisions

| Signal + Verdict | Wiggum Decision |
|-----------------|-----------------|
| Signal + PASS | ALLOW (exit) |
| Signal + FAIL (pre-existing) | ALLOW (exit) |
| Signal + FAIL (regression) | BLOCK (retry) |
| Signal + BLOCKED | ASK_HUMAN |

---

## 10. Governance and Policy Integration

### Branch Ownership

| Branch Pattern | Owner | Ralph Timing |
|----------------|-------|--------------|
| `main` | Protected | Always |
| `fix/*` | QA Team | Every commit |
| `feature/*` | Dev Team | PR only |

### Autonomy Levels

| Level | Name | Permissions |
|-------|------|-------------|
| L0 | Observer | Read-only |
| L1 | Contributor | + Code changes (HIPAA repos) |
| L2 | Developer | + Schema changes |
| L3 | Deployer | + Production deployments |
| L4 | Architect | + Architecture changes |

### Team Configuration

| Repo | Autonomy | HIPAA | Max Lines | Max Files |
|------|----------|-------|-----------|-----------|
| credentialmate | L1 | Yes | 100 | 5 |
| karematch | L2 | No | 500 | 20 |
| research | L2 | No | 500 | 20 |

### Policy Enforcement Chain

```
MissionControl capsule (immutable)
    ↓ cannot loosen
MissionControl policies (global)
    ↓ cannot loosen
Repo CLAUDE.md (local)
    ↓ cannot loosen
Repo .claude/rules/ (tightening only)
```

---

## Quick Reference

### Start Autonomous Execution

```bash
cd /Users/tmac/1_REPOS/AI_Orchestrator
python autonomous_loop.py --project karematch --max-iterations 100
```

### Discover Bugs

```bash
aibrain discover-bugs --project karematch
```

### Check Metrics

```bash
python -m agents.coordinator.metrics dashboard
```

### View Traceability

```bash
python -m agents.coordinator.traceability chain --task TASK-001
```

### Ralph vs Wiggum Summary

| Aspect | Ralph | Wiggum |
|--------|-------|--------|
| **Purpose** | Verify code quality | Control iteration loops |
| **Input** | Changed files | Agent output + Ralph verdicts |
| **Output** | PASS/FAIL/BLOCKED | ALLOW/BLOCK/ASK_HUMAN |
| **Role** | Gate (prevents bad code) | Loop (enables self-correction) |

---

*This document describes the actual implementation of the AI Orchestrator system as of 2026-01-16.*
