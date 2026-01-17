# Governance Policy

**Authority**: MissionControl Governance Policy
**Version**: 1.0
**Last Updated**: 2026-01-16
**Applies To**: All managed repositories

---

## Overview

This policy defines governance rules for AI agent operations, including autonomy management, escalation procedures, SSOT handling, and deterministic enforcement. It operationalizes the Constitutional Principles.

---

## 1. Graduated Autonomy Implementation

### Level Definitions

| Level | Name | Operations Allowed | Operations Forbidden |
|-------|------|-------------------|---------------------|
| **L0** | Observer | Read files, analyze code | Any writes |
| **L1** | Contributor | Write to sessions/, docs/, comments | Code changes |
| **L2** | Developer | Edit code, run tests, create branches | Config changes, deletions |
| **L3** | Architect | Create files, modify config, schema | Production ops, deletions |
| **L4** | Admin | Deletions, production ops | Nothing (with approval) |

### Auto-Promotion Triggers

```yaml
# Triggers for automatic level promotion
auto_promotion:
  L0_to_L1:
    trigger: "Read CONTEXT.md or CLAUDE.md"
    validation: "File read confirmed in session log"

  L1_to_L2:
    trigger: "Successful write to sessions/ or docs/"
    validation: "Write completed without errors"

  L2_to_L3:
    trigger: "Human confirms file creation request"
    validation: "Explicit approval in chat"

  L3_to_L4:
    trigger: "RIS entry + human approval"
    validation: "RIS ID + approval string"
```

### Demotion Triggers

| Violation | Demotion |
|-----------|----------|
| Exposed secrets | Immediate to L0 |
| Production outage caused | -2 levels |
| Governance bypass attempt | Immediate to L0 |
| 3+ escalation violations | -1 level |
| Failed operation without recovery | -1 level |

### Session Boundary Behavior

```yaml
# Session autonomy handling
session_start:
  default_level: L0
  trust_registry: check  # Look up previous level
  max_carry_over: L2     # Never start above L2

session_end:
  save_level: true       # Record final level
  save_if_demoted: false # Don't save demotions
```

---

## 2. Agent Escalation Hierarchy

### Level 1: Direct Execution (Try First)

Tools available at this level:
- Bash commands
- Python execution
- File operations (read/write/edit)
- MCP tools (if configured)
- Local API calls

**Evidence required**: None (just try it)

### Level 2: Delegated Infrastructure (Try Second)

Tools available at this level:
- AWS RDS Data API
- SSM Parameter Store
- AWS Lambda invocation
- Docker exec
- GitHub Actions dispatch
- Database query skills

**Evidence required**: Document that Level 1 failed

### Level 3: Alternative Approaches (Try Third)

**MANDATORY**: Try at least 3 alternatives before escalating

Document each attempt:
```yaml
alternative_attempt:
  attempt_number: 1-3
  timestamp: ISO8601
  approach: "what was tried"
  command: "actual command/action"
  result: "what happened"
  reason_failed: "why this didn't work"
```

### Level 4: User Escalation (Last Resort)

**Only after Levels 1-3 exhausted with evidence**

Format for user escalation:
```markdown
## Human Assistance Needed

**Task**: {what I'm trying to do}

**Alternatives Tried**:
1. {Level 1 attempt} - Failed because: {reason}
2. {Level 2 attempt} - Failed because: {reason}
3. {Level 3 attempt 1} - Failed because: {reason}
4. {Level 3 attempt 2} - Failed because: {reason}
5. {Level 3 attempt 3} - Failed because: {reason}

**What I Need**: {specific help required}
```

### Escalation Enforcement

```python
# Pseudocode for escalation validation
def validate_escalation(request):
    if not request.level_1_attempted:
        return BLOCK("Must try direct execution first")

    if not request.level_2_attempted:
        return BLOCK("Must try delegated infrastructure")

    if len(request.level_3_alternatives) < 3:
        return BLOCK(f"Need 3 alternatives, only tried {len(request.level_3_alternatives)}")

    return ALLOW("Evidence trail complete")
```

---

## 3. SSOT (Single Source of Truth) Governance

### SSOT Principles

1. **One Source**: Each data type has exactly one authoritative source
2. **Derived Files**: Generated files marked as such, never hand-edited
3. **Update Workflow**: Changes flow from SSOT to derived, never reverse

### SSOT File Patterns

```yaml
# Repository SSOT configuration
ssot:
  definitions:
    - pattern: "ssot/**/*.csv"
      type: source
      derived: ["generated/**/*.json"]
      workflow: "edit source -> regenerate derived"

    - pattern: "config/**/*.yaml"
      type: source
      derived: []
      workflow: "edit directly, validate"

    - pattern: "generated/**/*"
      type: derived
      source: "ssot/**/*"
      workflow: "NEVER hand-edit, regenerate from source"
```

### SSOT Modification Rules

| File Type | Direct Edit | Approval Required |
|-----------|-------------|-------------------|
| Source file | Yes | If protected |
| Derived file | NEVER | N/A (regenerate instead) |
| Configuration | Yes | If affects production |

### SSOT Violation Detection

```python
# Check for SSOT violations
def check_ssot_violation(file_path, change_type):
    ssot_config = load_ssot_config()

    if is_derived_file(file_path, ssot_config):
        if change_type == "direct_edit":
            return VIOLATION(
                f"{file_path} is derived from {get_source(file_path)}. "
                f"Edit the source file and regenerate."
            )

    return OK
```

---

## 4. Deterministic Enforcement Architecture

### Enforcement vs Advisory

| Mode | Behavior | When to Use |
|------|----------|-------------|
| **Advisory** | Warn but allow | Initial rollout |
| **Enforced** | Block if violated | Production rules |
| **Strict** | Block + demote | Critical rules |

### Hook-Based Enforcement

```yaml
# Enforcement hook configuration
hooks:
  pre_tool_use:
    - name: autonomy_enforcer
      mode: enforced
      checks:
        - operation_within_level
        - not_protected_file
        - not_forbidden_pattern

    - name: escalation_validator
      mode: advisory  # Change to enforced after testing
      checks:
        - alternatives_documented
        - evidence_trail_complete

    - name: ssot_guardian
      mode: enforced
      checks:
        - not_editing_derived_file
        - source_file_exists
```

### Enforcement Levels by Rule

| Rule | Current Level | Target Level |
|------|--------------|--------------|
| Autonomy (L0-L4) | Advisory | Enforced |
| 5-Layer Deletion | Enforced | Enforced |
| HIPAA Guards | Enforced | Enforced |
| Escalation Hierarchy | Advisory | Enforced |
| SSOT Protection | Advisory | Enforced |
| Secret Detection | Enforced | Enforced |
| Protected Files | Advisory | Enforced |

---

## 5. Trust Registry Management

### Registry Schema

```json
{
  "schema_version": "1.0",
  "agents": {
    "{agent_id}": {
      "level": "L0|L1|L2|L3|L4",
      "promoted_at": "ISO8601",
      "tasks_completed": 0,
      "tasks_failed": 0,
      "last_active": "ISO8601",
      "violations": [],
      "reliability_score": 100
    }
  },
  "demotion_triggers": [
    "exposed_secrets",
    "production_outage",
    "governance_bypass",
    "repeated_escalation_violations"
  ]
}
```

### Reliability Score Calculation

```python
def calculate_reliability(agent):
    base_score = 100

    # Deductions
    base_score -= agent.tasks_failed * 5
    base_score -= len(agent.violations) * 10

    # Bonuses (capped)
    bonus = min(agent.tasks_completed * 0.5, 20)
    base_score += bonus

    return max(0, min(100, base_score))
```

### Session Integration

At session start:
1. Look up agent in trust registry
2. Set initial level (capped at L2 for safety)
3. Log session start

At session end:
1. Update task counts
2. Recalculate reliability score
3. Save level (if not demoted)
4. Log session end

---

## 6. Governance Philosophy

### Build Rule

> "Does this prevent production outages or golden path regressions?"

If the answer is no, don't build it.

### What We Build (Zero Tolerance Approach)

| System | Mode | Rationale |
|--------|------|-----------|
| Golden Path Lock-In | BLOCKING | Enforce known-working paths |
| Contract Validation | BLOCKING | Verify across layers |
| CI/CD Gates | BLOCKING | No bypass allowed |
| Production Monitoring | ALERTING | Continuous verification |

### What We DON'T Build

- **Warn-only checks**: Either it blocks or it doesn't exist
- **Manual processes**: If it's important, automate it
- **Nice-to-have features**: Clear ROI required
- **Redundant systems**: One system per concern

---

## 7. Cross-Repository Coordination

### Authority Hierarchy

```
1. MissionControl/governance/capsule     (Constitutional - immutable)
       ↓
2. MissionControl/governance/policies    (Global - can tighten)
       ↓
3. Repository CLAUDE.md                   (Local - can tighten)
       ↓
4. Repository constraints/                (Additional tightening)
```

### Rule Inheritance

```yaml
# Repository governance config
extends: "MissionControl/governance/policies/governance.md"

tightening:
  # These rules are STRICTER than global
  max_autonomy: L2  # Lower than default L4
  require_approval_for:
    - any_production_operation
    - any_config_change

overrides:
  # CANNOT loosen global rules
  # This section is for documentation only
  # Actual loosening attempts will be BLOCKED
```

### Conflict Resolution

When rules conflict:
1. Stricter rule wins
2. If unclear, block and ask human
3. Document decision in RIS

---

## 8. Monitoring & Metrics

### Governance Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Permission requests per session | <1 | Count of user approvals needed |
| Escalation without evidence | 0 | Count of L4 without L1-3 docs |
| SSOT violations | 0 | Edits to derived files |
| Trust registry coverage | 100% | Agents with recorded levels |
| Rule enforcement rate | 100% | Enforced / Total rules |

### Logging Requirements

All governance decisions must be logged:

```yaml
governance_log:
  timestamp: ISO8601
  agent_id: string
  action: string
  rule_checked: string
  result: ALLOWED|BLOCKED|WARNED
  reason: string
  autonomy_level: L0-L4
```

---

## 9. Repository Implementation Checklist

Each repository must implement:

- [ ] Autonomy level tracking (trust registry or session state)
- [ ] Escalation evidence collection (session log format)
- [ ] SSOT file identification (config file)
- [ ] Protected file list (documented)
- [ ] Governance hooks (or reference MissionControl hooks)
- [ ] Metrics collection (optional but recommended)
