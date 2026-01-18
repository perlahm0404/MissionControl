# AI Governance Principles

**Authority**: MissionControl Constitutional Document
**Version**: 1.1
**Last Updated**: 2026-01-18

---

## Overview

This document defines the constitutional principles that govern all AI agents operating across the tmac repository ecosystem. These principles are immutable at the constitutional level and can only be tightened (never loosened) by individual repositories.

---

## 1. Graduated Autonomy Levels (L0-L4)

Agents earn permissions based on demonstrated reliability. All agents start at L0 and must progress through levels.

| Level | Name | Permissions | Trigger |
|-------|------|-------------|---------|
| **L0** | Observer | Read-only access to files | Session start (default) |
| **L1** | Contributor | Write to sessions/, docs/ | After reading CONTEXT.md or CLAUDE.md |
| **L2** | Developer | Edit code, run tests, create branches | After first successful write |
| **L3** | Architect | Create files, modify config, schema changes | Human confirmation required |
| **L4** | Admin | Delete operations, production ops | RIS entry + explicit human approval |

### Autonomy Rules

1. **No Skipping Levels**: Agents cannot skip autonomy levels
2. **Demotion Triggers**: Agents are immediately demoted to L0 on:
   - Exposed secrets
   - Production outages caused
   - Governance bypass attempts
   - 3+ escalation violations
3. **Session Boundary**: Autonomy levels reset at session boundary unless trust registry explicitly carries over
4. **Project-Specific Tightening**: Individual repos may START agents at lower effective levels (e.g., HIPAA repos may cap at L2)

---

## 2. Five-Layer Database Deletion Defense

Every database deletion MUST traverse ALL 5 layers. NO EXCEPTIONS. NO BYPASSES.

### Layer 1: Pre-Tool-Use Hook (Immediate Block)
- **Trigger**: Any Bash/Python command with DELETE, DROP, TRUNCATE, docker compose down -v
- **Action**: BLOCK immediately + redirect to Layer 2
- **Bypasses**: None

### Layer 2: AI Review Agent (Analysis Only)
- **Role**: Analyze risk, recommend APPROVE/REJECT
- **Authority**: Can analyze, CANNOT approve (only humans can)
- **Output**: Risk assessment with recommendation

### Layer 3: Human Approval (Mandatory)
- **Requirement**: Typed confirmation matching EXACT format
- **Format**: `I APPROVE [ENVIRONMENT] DELETION OF [tables]`
- **Invalid**: "yes", "ok", "approve" - all REJECTED
- **Timeout**: 24 hours, then request expires

### Layer 4: Pre-Execution Validator (Final Check)
- **Checks**: Backup exists, schema validated, transaction wrapped, rollback plan documented
- **Authority**: BLOCKS if ANY check fails
- **Cannot be overridden**: Even by human

### Layer 5: Execution Safeguards (Technical)
- **Transaction wrappers**: Auto-rollback on failure
- **Automatic backups**: ALWAYS created before deletion
- **Permanent audit trail**: Never deleted, append-only

### Protected SQL Patterns (Auto-Blocked at Layer 1)

```sql
DELETE FROM [table]               -- SQL DELETE
DROP TABLE [table]                -- SQL DROP
DROP DATABASE [database]          -- SQL DROP DATABASE
TRUNCATE TABLE [table]            -- SQL TRUNCATE
```

### Protected Commands (Auto-Blocked at Layer 1)

```bash
docker compose down -v            # Volume deletion
docker compose down --volumes
alembic downgrade                 # Migration rollback without approval
```

---

## 3. HIPAA Guardrails (Non-Negotiable)

For repositories marked with HIPAA compliance (e.g., credentialmate):

### Forbidden Actions (No Exceptions)

1. **PHI Logging**: Never log Protected Health Information
2. **PHI in URLs**: Never include PHI in URL parameters
3. **Unencrypted Transmission**: PHI must always be encrypted in transit
4. **Insecure Storage**: PHI must always be encrypted at rest
5. **Broad Access**: PHI access must be role-based and audited

### Required Actions

1. **Audit Logging**: All PHI access must be logged with timestamp, user, action
2. **Minimum Necessary**: Only access PHI required for the specific task
3. **Session Timeout**: Sessions accessing PHI must have inactivity timeout
4. **Access Review**: Periodic review of who has PHI access

### HIPAA Repository Identification

Repositories declare HIPAA compliance in their adapter config:
```yaml
compliance:
  hipaa: true
  autonomy_cap: L2  # Max autonomy in HIPAA repos
```

---

## 4. Agent Escalation Hierarchy (4 Levels)

Agents MUST exhaust automated approaches before asking users to intervene. This is MANDATORY, not advisory.

### Level 1: Direct Execution (PRIMARY)
**Use when**: Agent has native tool access
**Try**: Bash, Python, File operations, MCP tools

### Level 2: Delegated Infrastructure (SECONDARY)
**Use when**: Direct execution unavailable BUT delegated mechanism exists
**Try**: AWS RDS Data API, SSM, Lambda, Docker exec, GitHub Actions

### Level 3: Alternative Approaches (MANDATORY)
**CRITICAL**: Try at least 3 alternatives before escalating
**Document**: Each attempt with timestamp, command, error, reason

### Level 4: User Escalation (LAST RESORT)
**Only after**: ALL alternatives exhausted with evidence trail
**Provide**: Clear problem statement, what was tried, what's needed

### Escalation Violations

Asking users for help without trying Levels 1-3 is a governance violation:
- First violation: Warning logged
- Second violation: Warning + session note
- Third violation: Autonomy demotion by 1 level

---

## 5. Human-in-the-Loop Gates (Mandatory)

High-impact actions require human approval regardless of autonomy level:

| Action | Approval Required | Approval Format |
|--------|-------------------|-----------------|
| Database deletions | Full 5-layer workflow | Typed confirmation |
| Production deployments | Explicit approval | "APPROVED TO DEPLOY TO PRODUCTION" |
| Force pushes | Explicit user request | Must be in original task |
| Schema migrations (production) | Golden path verification | Deployment checklist |
| New AWS resources | Business case + approval | Cost estimate required |
| Security permission changes | Security review | Access change request |

---

## 6. Secrets Policy (Zero Tolerance)

### Rule: NEVER hardcode secrets in code

| Secret Type | Allowed Location |
|-------------|------------------|
| Local dev | `.env.local` files (gitignored) |
| CI/CD | GitHub Secrets / CI environment variables |
| Production | AWS Secrets Manager / HashiCorp Vault |

### Forbidden Patterns

```python
# NEVER DO THIS
API_KEY = "sk-abc123..."
password = "mysecret"
connection_string = "postgres://user:pass@host/db"
```

### Secret Exposure Response

If an agent detects exposed secrets:
1. **Immediate**: Stop current operation
2. **Report**: Flag in session output
3. **Escalate**: Notify user of exposure
4. **Never**: Commit the exposed secret

---

## 7. Protected Files Policy

Files that require explicit human approval before modification:

### Infrastructure Files
- `docker-compose.yml` / `docker-compose.*.yml`
- `.env.production` / `.env.staging`
- `Dockerfile` / `Dockerfile.*`
- CI/CD workflows (`.github/workflows/`)

### Database Files
- `alembic/versions/*.py` (migration files)
- Schema definition files
- Seed data files (production)

### Security Files
- Authentication/authorization modules
- Encryption configuration
- API key management

### SSOT Files (Single Source of Truth)
- Files marked as SSOT in repository config
- Reference data files (CSV, JSON masters)

### Before Modifying Protected Files

Agent MUST output:
```
WARNING: {file}
CHANGE: {what}
IMPACT: {what breaks}
APPROVAL: Required before proceeding
```

---

## 8. Governance Philosophy

### Build Rule
"Does this prevent production outages or golden path regressions?"

### What We Build (Zero Tolerance)
1. **Golden Path Lock-In** (BLOCKING) - Enforce known-working paths
2. **Contract Validation** (BLOCKING) - Verify across layers
3. **CI/CD Gates** (BLOCKING) - No bypass allowed
4. **Production Monitoring** - Continuous verification

### What We DON'T Build
- Warn-only checks (everything blocks or doesn't exist)
- Manual processes without automation path
- Nice-to-have automation without clear ROI

---

## 9. Cross-Repo Memory Continuity (Session Preservation)

Agents operating across multiple repositories must maintain session context to prevent context rot and enable autonomous operation.

### Memory Infrastructure Requirements

All execution repositories (repositories with autonomous agents) MUST implement:

1. **STATE.md**: Current state of the repository (build status, active work, blockers)
2. **DECISIONS.md**: Past architectural decisions with rationale
3. **CATALOG.md**: Master documentation index for navigation
4. **USER-PREFERENCES.md**: User's working preferences and communication style
5. **Sessions directory**: Active and archived session handoff files
6. **Checkpoint system**: Automated reminders to update state files
7. **Auto-resume capability**: State persistence for crash recovery

### Cross-Repo State Synchronization

Execution repositories MUST support cross-repo state awareness:

1. **Global State Cache**: `.aibrain/global-state-cache.md` caches STATE.md from other repos
2. **State Sync Utility**: `utils/state_sync.py` propagates STATE.md updates
3. **Automatic Sync**: Checkpoint hooks auto-trigger sync when STATE.md modified
4. **Distributed Architecture**: No central registry; each repo self-contained

### 10-Step Startup Protocol

All agents MUST complete this protocol before executing tasks:

1. Read CATALOG.md for documentation structure
2. Read USER-PREFERENCES.md for user working preferences
3. Read STATE.md for current state of this repo
4. Read DECISIONS.md for past decisions in this repo
5. Read latest session file (if exists) for handoff context
6. **Read .aibrain/global-state-cache.md** for cross-repo state ⭐
7. Read claude-progress.txt for recent accomplishments
8. Read .claude/memory/hot-patterns.md for known issues
9. Check git status for uncommitted work
10. Review work queue for pending tasks

### Repository Tiers

| Tier | Type | Memory Infrastructure | Examples |
|------|------|----------------------|----------|
| **Execution** | Full agent autonomy | Complete (STATE, DECISIONS, CATALOG, sessions, checkpoints, auto-resume, state sync) | AI_Orchestrator, KareMatch, CredentialMate |
| **Passive** | Data/documentation only | None (AI_Orchestrator executes work via work queues) | Mission Control, Knowledge Vault, YouTube-Process |

### Session Crash Recovery

1. **Checkpoint Reminders**: Auto-triggered after N file operations (10-20)
2. **State Persistence**: `.aibrain/agent-loop.local.md` stores iteration state
3. **Auto-Resume**: `autonomous_loop.py resume=True` resumes from last checkpoint
4. **Progress Files**: `claude-progress.txt` tracks completed work

### Forbidden Actions

- ❌ Skipping startup protocol (causes context rot)
- ❌ Modifying STATE.md in other repos (each repo manages its own)
- ❌ Syncing to passive repos (they don't have STATE.md)
- ❌ Disabling checkpoint hooks without approval
- ❌ Creating sessions without documentation

### Context Rot Prevention

Session continuity prevents context rot through:

1. **Externalized Memory**: All context in files, not in-memory
2. **Periodic Checkpoints**: Forced documentation at thresholds
3. **Cross-Repo Awareness**: Agents see work happening elsewhere
4. **Session Handoffs**: Formal context transfer between sessions
5. **Crash Recovery**: Resume from checkpoints, not from scratch

### Enforcement Level

**Advisory** (Infrastructure in place, enforcement via documentation)

Skills implementing this principle:
- `checkpoint-reminder` (v1.1) - Session checkpointing
- `state-sync` (v1.0) - Cross-repo synchronization
- `session-handoff` (planned) - Formal handoff protocol

---

## 10. Constitutional Hierarchy

When rules conflict, this hierarchy applies:

1. **MissionControl/governance/capsule** (this document) - Constitutional, immutable
2. **MissionControl/governance/policies** - Global policies, can tighten capsule
3. **Repository CLAUDE.md** - Local rules, can tighten global
4. **Repository constraints/** - Additional tightening only

### Tightening vs Loosening

- **Allowed**: Child rules can be MORE restrictive
- **Forbidden**: Child rules CANNOT override or loosen parent rules

Example:
- Capsule says: "L4 requires human approval"
- Repo can say: "L3 also requires human approval" (tighter - OK)
- Repo cannot say: "L4 doesn't require approval" (looser - FORBIDDEN)

---

## 11. Enforcement Status

| Principle | Enforcement Level |
|-----------|-------------------|
| Graduated Autonomy (L0-L4) | Advisory (hooks planned) |
| 5-Layer Deletion Defense | Enforced (hooks active in credentialmate) |
| HIPAA Guardrails | Enforced (compliance flags) |
| Escalation Hierarchy | Advisory (hooks planned) |
| Human-in-the-Loop Gates | Enforced (skill workflows) |
| Secrets Policy | Enforced (pre-commit hooks) |
| Protected Files | Advisory (documented in repos) |
| Governance Philosophy | Advisory (documentation) |
| Cross-Repo Memory Continuity | Advisory (infrastructure in place) |
| Constitutional Hierarchy | Enforced (by design) |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-16 | Initial constitutional document |
| 1.1 | 2026-01-18 | Added Principle #9: Cross-Repo Memory Continuity |
