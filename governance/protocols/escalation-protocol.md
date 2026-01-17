# Escalation Protocol

**Authority**: MissionControl Governance Protocol
**Version**: 1.0
**Last Updated**: 2026-01-16
**Status**: MANDATORY

---

## Overview

This protocol defines when and how AI agents escalate to human operators. Escalation is a LAST RESORT - agents must exhaust all automated alternatives first.

---

## Core Principle

> **Agents MUST try at least 3 automated approaches before asking humans for help.**

The goal is to maximize agent autonomy while maintaining safety gates for truly novel situations.

---

## 4-Level Escalation Hierarchy

### Level 1: Direct Execution (PRIMARY - Try First)

**Use When**: Agent has native tool access

**Available Tools**:
- Bash commands (within sandbox)
- Python/Node execution
- File operations (Read, Write, Edit)
- MCP tools (if configured)
- Local API calls
- Git operations

**Evidence Required**: None - just try it

**Example**:
```
Task: "Query the database for user count"
Level 1 Attempt: Run SQL query directly
Result: Success OR failure (proceed to Level 2 if failed)
```

---

### Level 2: Delegated Infrastructure (SECONDARY - Try Second)

**Use When**: Direct execution failed BUT delegated mechanisms exist

**Available Mechanisms**:
| Mechanism | Use Case |
|-----------|----------|
| AWS RDS Data API | Database queries when direct connection unavailable |
| AWS SSM | Remote command execution |
| AWS Lambda | Invoke serverless functions |
| Docker exec | Execute in running containers |
| GitHub Actions | Trigger CI/CD workflows |
| Repository-specific skills | Skills that delegate to infrastructure |

**Evidence Required**: Document that Level 1 failed

**Example**:
```
Task: "Query production database"
Level 1 Attempt: Direct psql connection - FAILED (no direct access)
Level 2 Attempt: Use RDS Data API via skill
Result: Success
```

---

### Level 3: Alternative Approaches (MANDATORY - Try Third)

**CRITICAL**: Must try at least 3 creative alternatives before escalating

**Alternative Categories**:
1. **Different tools**: Try equivalent tool
2. **Different paths**: Find another way to achieve same goal
3. **Different scope**: Break problem into smaller parts
4. **Different timing**: Retry with delays or different order
5. **Different format**: Change input/output format

**Evidence Required**: Document each attempt with:
```yaml
alternative_attempt:
  attempt_number: 1|2|3
  timestamp: "2026-01-16T12:34:56Z"
  approach: "Description of what was tried"
  command_or_action: "Actual command/action taken"
  result: "What happened"
  reason_failed: "Why this didn't work"
```

**Example**:
```
Task: "Get AWS credentials"
Level 1 Attempt: Read ~/.aws/credentials - FAILED (file not found)
Level 2 Attempt: Use SSM parameter store - FAILED (not configured)
Level 3 Alternatives:
  1. Check .env files for AWS vars - FAILED (not present)
  2. Use secrets-lookup skill - FAILED (skill not available)
  3. Check docker-compose for AWS config - FAILED (no AWS config)
All alternatives exhausted with evidence → Proceed to Level 4
```

---

### Level 4: User Escalation (LAST RESORT)

**ONLY After**: Levels 1-3 exhausted with documented evidence trail

**Escalation Format** (REQUIRED):

```markdown
## Human Assistance Needed

**Task**: [What I'm trying to accomplish]

**Alternatives Tried**:

| # | Level | Approach | Result | Reason |
|---|-------|----------|--------|--------|
| 1 | L1 | [Direct attempt] | FAILED | [Reason] |
| 2 | L2 | [Delegated attempt] | FAILED | [Reason] |
| 3 | L3 | [Alternative 1] | FAILED | [Reason] |
| 4 | L3 | [Alternative 2] | FAILED | [Reason] |
| 5 | L3 | [Alternative 3] | FAILED | [Reason] |

**What I Need**: [Specific help required]

**Suggested Options**:
1. [Option A with explanation]
2. [Option B with explanation]
```

---

## Escalation Triggers by Category

### Mandatory Escalation (Even with Autonomy)

These ALWAYS require human approval regardless of agent autonomy level:

| Trigger | Why |
|---------|-----|
| Database deletions | Irreversible data loss risk |
| Production deployments | Business continuity risk |
| Schema migrations (production) | Data integrity risk |
| Security permission changes | Access control risk |
| New AWS resources | Cost and security risk |
| Force pushes | Git history risk |

### Conditional Escalation

These trigger escalation only after automated attempts fail:

| Trigger | Escalate When |
|---------|---------------|
| Access denied errors | After L1-L3 exhausted |
| Configuration not found | After L1-L3 exhausted |
| Unknown error states | After L1-L3 exhausted |
| Conflicting requirements | When cannot resolve automatically |

### Informational Escalation

These inform the human but don't block:

| Trigger | Action |
|---------|--------|
| Unusual patterns detected | Log + continue |
| Performance degradation | Log + continue |
| Minor validation warnings | Log + continue |

---

## Escalation Violations

### What Counts as a Violation

1. Asking user for help without trying Level 1
2. Asking user for help without trying Level 2
3. Asking user for help with fewer than 3 Level 3 alternatives
4. Asking user for access/credentials without checking skills first
5. Asking user "should I do X?" when X is within autonomy level

### Violation Consequences

| Violation Count | Consequence |
|-----------------|-------------|
| 1st | Warning logged to session |
| 2nd | Warning + session note |
| 3rd | Autonomy demotion by 1 level |
| 4th+ | Autonomy demotion to L0 |

### Violation Detection (Hook-Based)

```python
# Pseudocode for escalation validator hook
def validate_escalation(request):
    if is_asking_human(request):
        trail = get_evidence_trail(request)

        if not trail.level_1_attempted:
            return BLOCK(
                "Must try direct execution first. "
                f"Available tools: {list_available_tools()}"
            )

        if not trail.level_2_attempted:
            return BLOCK(
                "Must try delegated infrastructure. "
                f"Available skills: {list_relevant_skills()}"
            )

        if len(trail.level_3_alternatives) < 3:
            return BLOCK(
                f"Need 3 alternatives, only tried {len(trail.level_3_alternatives)}. "
                f"Suggestions: {suggest_alternatives(request)}"
            )

        return ALLOW("Evidence trail complete")

    return ALLOW("Not an escalation request")
```

---

## Response Time Expectations

| Escalation Type | Expected Response |
|-----------------|-------------------|
| Blocking (mandatory approval) | Wait indefinitely |
| Critical (production issue) | User should respond ASAP |
| Normal (development question) | User may respond within session |
| Informational (FYI) | No response needed |

---

## Escalation Communication Standards

### DO
- Be specific about what you need
- Provide context about what was tried
- Offer suggested solutions
- Include relevant error messages
- State expected outcome

### DON'T
- Ask vague questions ("How do I do this?")
- Omit the evidence trail
- Ask for things you could find yourself
- Request access without trying alternatives
- Make the human do your research

---

## Example: Good vs Bad Escalation

### Bad Escalation
```
"I need AWS credentials to query the database. Can you provide them?"
```

Problems:
- No evidence of trying alternatives
- Asks for credentials directly
- No context on why needed

### Good Escalation
```
## Human Assistance Needed

**Task**: Query production database to verify user count

**Alternatives Tried**:
| # | Level | Approach | Result | Reason |
|---|-------|----------|--------|--------|
| 1 | L1 | Direct psql | FAILED | No network access |
| 2 | L2 | RDS Data API | FAILED | Not configured for this repo |
| 3 | L3 | SSM + docker exec | FAILED | SSM permissions denied |
| 4 | L3 | query-production-db skill | FAILED | Skill returns access denied |
| 5 | L3 | GitHub Actions workflow | FAILED | No DB query workflow exists |

**What I Need**: Either:
1. Network access to production DB (add to allowed hosts)
2. Configure RDS Data API for this repository
3. Update IAM permissions for SSM access

**Suggested Option**: Option 2 (RDS Data API) is lowest friction
```

---

## Integration with Other Protocols

### Handoff Protocol
- Escalations that can't be resolved in session become handoff items
- Document escalation context in handoff notes

### Parallel Execution Protocol
- Multiple agents can escalate simultaneously
- Human may need to prioritize responses

---

## Enforcement Status

| Component | Status |
|-----------|--------|
| 4-Level Hierarchy | Documented |
| Evidence Trail Format | Documented |
| Violation Detection Hook | Planned |
| Automatic Suggestions | Planned |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-16 | Initial protocol |
