# Database Safety Policy

**Authority**: MissionControl Governance Policy
**Version**: 1.0
**Last Updated**: 2026-01-16
**Applies To**: All repositories with database operations

---

## Overview

This policy defines mandatory safeguards for database operations across all managed repositories. It implements the 5-Layer Database Deletion Defense defined in the Constitutional Principles.

---

## 1. Database Deletion Workflow

Every database deletion MUST traverse ALL 5 layers as defined in `capsule/ai-governance-principles.md`. This section provides implementation details.

### Layer 1: Pre-Tool-Use Hook Implementation

Repository hooks MUST detect and block these patterns:

```python
# SQL Patterns (case-insensitive)
BLOCKED_SQL_PATTERNS = [
    r"DELETE\s+FROM\s+\w+",           # SQL DELETE
    r"DROP\s+TABLE\s+\w+",            # SQL DROP TABLE
    r"DROP\s+DATABASE\s+\w+",         # SQL DROP DATABASE
    r"TRUNCATE\s+TABLE\s+\w+",        # SQL TRUNCATE
    r"UPDATE\s+\w+\s+SET.*WHERE\s+1=1", # Mass UPDATE
]

# Command Patterns
BLOCKED_COMMANDS = [
    r"docker\s+compose\s+down\s+-v",
    r"docker\s+compose\s+down\s+--volumes",
    r"docker\s+volume\s+rm",
    r"alembic\s+downgrade",
]

# ORM Patterns (language-specific)
BLOCKED_ORM_PATTERNS = [
    r"session\.delete\(",              # SQLAlchemy delete
    r"session\.execute\(.*DELETE",     # SQLAlchemy raw DELETE
    r"\.destroy\(",                    # ActiveRecord/Sequelize
    r"\.truncate\(",                   # ORM truncate
]
```

### Layer 2: AI Review Agent Interface

The deletion reviewer agent MUST:
1. Accept deletion request with context
2. Analyze tables affected and row counts
3. Check for foreign key dependencies
4. Assess production impact
5. Return structured recommendation

```yaml
# Reviewer Output Schema
deletion_review:
  request_id: string
  tables_affected: list[string]
  estimated_rows: integer
  dependencies:
    foreign_keys: list[string]
    cascade_risk: low|medium|high
  recommendation: APPROVE|REJECT
  reasoning: string
  required_backup: boolean
```

### Layer 3: Human Approval Format

**Valid approval patterns:**
```
I APPROVE DEVELOPMENT DELETION OF users, sessions
I APPROVE STAGING DELETION OF temp_data
I APPROVE PRODUCTION DELETION OF audit_logs_archive
```

**Invalid patterns (ALL REJECTED):**
```
yes
ok
approve
approved
do it
y
```

### Layer 4: Pre-Execution Checklist

Before execution, ALL must pass:

| Check | Validation |
|-------|------------|
| Backup exists | `backup_created_at` within 1 hour |
| Schema validated | Tables exist in current schema |
| Transaction wrapped | DELETE inside BEGIN/COMMIT |
| Rollback documented | Recovery steps in request |
| Row count confirmed | Estimated matches actual (within 10%) |
| Foreign keys resolved | No orphan records will result |
| Audit log prepared | Deletion will be logged |

### Layer 5: Execution Safeguards

```python
# Pseudocode for safe execution
def execute_deletion(request):
    # Create backup
    backup_id = create_backup(request.tables)

    # Start transaction
    with database.transaction() as tx:
        # Execute deletion
        result = tx.execute(request.sql)

        # Verify row count
        if result.rows_affected != request.expected_rows:
            tx.rollback()
            raise RowCountMismatch()

        # Commit if valid
        tx.commit()

    # Log to audit trail (append-only)
    audit_log.append({
        "timestamp": now(),
        "backup_id": backup_id,
        "tables": request.tables,
        "rows_deleted": result.rows_affected,
        "approved_by": request.approver,
    })
```

---

## 2. Migration Safety

### Constraint Addition Policy

When adding CHECK/NOT NULL/UNIQUE constraints to existing tables:

1. **VALIDATE**: Query to find rows that violate the new constraint
2. **FIX**: UPDATE to fix violating rows (if any found)
3. **CONSTRAIN**: Add the constraint (now safe)

```python
# Pattern for safe constraint addition
def upgrade() -> None:
    # STEP 1: VALIDATE - find violations
    result = op.get_bind().execute(text("""
        SELECT id FROM table WHERE constraint_would_fail
    """))

    if result.fetchall():
        # STEP 2: FIX - repair data
        op.execute("UPDATE table SET column = valid_value WHERE constraint_would_fail")

    # STEP 3: CONSTRAIN - add constraint (now safe)
    op.execute("ALTER TABLE table ADD CONSTRAINT constraint_name CHECK (...)")
```

### Migration File Requirements

All migration files MUST have:

| Requirement | Description |
|-------------|-------------|
| `upgrade()` method | Forward migration |
| `downgrade()` method | Rollback migration (REQUIRED for production) |
| No forbidden patterns | No DROP DATABASE, no mass DELETE |
| Idempotent check | Safe to run multiple times |

### Forbidden in Production Migrations

```sql
-- NEVER ALLOWED IN PRODUCTION
DROP DATABASE
DROP TABLE (without explicit human approval)
TRUNCATE TABLE
DELETE without WHERE clause
UPDATE without WHERE clause
```

---

## 3. Backup Requirements

### Automatic Backup Triggers

| Operation | Backup Required | Retention |
|-----------|-----------------|-----------|
| Any DELETE | Yes (always) | 30 days |
| DROP TABLE | Yes (always) | 90 days |
| Schema migration | Yes (always) | 90 days |
| Bulk UPDATE (>100 rows) | Yes | 7 days |

### Backup Validation

Before any destructive operation:
1. Verify backup exists
2. Verify backup is recent (within 1 hour for deletions)
3. Verify backup is restorable (test restore path)
4. Document backup ID in audit log

---

## 4. Environment-Specific Rules

### Development
- Deletions allowed with L2+ autonomy
- Still require Layer 1 hook (can be overridden with explicit flag)
- Backups optional but recommended

### Staging
- Deletions require L3 autonomy OR human approval
- All 5 layers active
- Backups mandatory

### Production
- Deletions ALWAYS require full 5-layer workflow
- No autonomy can bypass human approval
- Backups mandatory with 90-day retention
- Audit trail permanent

---

## 5. Repository Implementation

Repositories must implement:

```yaml
# .claude/hooks/database-safety.yaml
enabled: true
layers:
  pre_hook: .claude/hooks/scripts/database-deletion-guardian.py
  reviewer: .claude/agents/database-deletion-reviewer.md
  approval: .claude/skills/request-database-deletion-approval/
  validator: .claude/agents/database-deletion-executor.md
  audit_log: ris/audit/database-deletion-approvals.yaml
```

---

## 6. Agent Guidelines

### Agents CAN:
- Analyze why deletion might be needed
- Suggest deletion as a solution option
- Explain risks and benefits
- Draft SQL/script commands for human review
- Execute deletions after full 5-layer approval

### Agents CANNOT:
- Execute deletions without full workflow
- Bypass any layer of defense
- Cache approvals across operations
- Approve their own deletion requests
- Skip backup verification
