---
compliance:
  hipaa:
    access-audit-required: true
    controls:
    - 164.308(a)(1)(ii)(D)
    - 164.312(a)(1)
    encryption-required: true
    phi-contains: credential-data
    retention-period: 7-years
    review-frequency: quarterly
  iso27001:
    classification: internal
    controls:
    - A.12.1.1
    - A.18.1.3
    review-frequency: quarterly
  soc2:
    controls:
    - CC7.3
    - CC8.1
    evidence-type: documentation
    retention-period: 7-years
created: '2026-01-10'
project: credentialmate
updated: '2026-01-10'
version: '1.0'
---

# RIS-056: Local to Production Data Migration via Lambda

**Created:** 2025-12-31
**Status:** RESOLVED
**Category:** Infrastructure / Database
**Impact:** Production Data Population

---

## Problem Statement

Need to migrate test/demo data from local development database to production RDS without:
- Direct database access (RDS in private VPC)
- EC2 instance (root volume detached, unusable)
- Production downtime

---

## Context

- **Local DB:** 93 users, 85 providers, 1,255 licenses, 19,214 CME activities
- **Production DB:** 1 user, 1 provider, 22 licenses (minimal test data)
- **Constraint:** Only access via `credmate-rds-sql-api` Lambda function
- **Challenge:** Single-insert approach estimated 3+ hours for 21K records

---

## Resolution

### Approach: Batched Lambda SQL Execution

1. **Export with explicit columns** - Avoid pg_dump column mismatches
2. **Handle conflicts** - Use `ON CONFLICT DO NOTHING` for idempotency
3. **Batch inserts** - Send 50 INSERT statements per Lambda call
4. **Sequential table order** - Respect foreign key dependencies

### Implementation

```python
# Batch 50 inserts per Lambda call
batch_size = 50
for i in range(0, len(remaining), batch_size):
    batch = remaining[i:i+batch_size]
    sql = ";\n".join(batch) + ";"

    payload = {"sql": sql}
    # Invoke Lambda with batched SQL
    result = invoke_lambda(payload)
```

### Key Fixes Required

1. **Create system user (id=1)** - Required by audit triggers
   ```sql
   INSERT INTO users (id, email, password_hash, first_name, last_name, role, ...)
   VALUES (1, 'system@credmate.internal', '...', 'System', 'User', 'super_admin', ...);
   ```

2. **Handle slug conflicts** - Production had existing "perla" slug
   ```sql
   INSERT INTO organizations (id, name, slug, ...)
   VALUES (39, 'Perla Medical Group', 'perla-medical', ...);
   ```

3. **Include organization_id** - Required for licenses table (not in original export)

---

## Performance Results

| Approach | Records/sec | Time for 19K records |
|----------|-------------|---------------------|
| Single INSERT per Lambda | ~2/sec | ~2.6 hours |
| Batched (50 per Lambda) | ~100/sec | ~15 minutes |

**Improvement:** 50x faster with batching

---

## Migration Order (FK Dependencies)

```
1. organizations     (no dependencies)
2. practices         (depends on: organizations)
3. users             (depends on: organizations, practices)
4. providers         (depends on: organizations, practices)
5. licenses          (depends on: organizations, providers)
6. cme_cycles        (depends on: organizations, providers, licenses)
7. cme_activities    (depends on: organizations, providers, cme_cycles)
```

---

## Artifacts Created

| Artifact | Location |
|----------|----------|
| Export script | `/tmp/credmate-migration/export-v3.py` |
| Batch migration script | `/tmp/credmate-migration/batch_migrate.py` |
| Clean SQL export | `/tmp/credmate-migration/clean-export-v3.sql` |

---

## Recommendations

1. **For future migrations >1000 records:** Use batched Lambda approach
2. **For very large migrations (100K+):** Consider temporary bastion host or RDS Proxy
3. **Always seed system user (id=1):** Add to standard seed scripts
4. **Test export on subset first:** Verify column compatibility before full export

---

## Related

- [KB: Database Migration via Lambda](../../05-kb/infrastructure/kb-database-migration-lambda.md)
- [RIS-055: Lambda RDS SQL API](ris-055-lambda-rds-sql-api.md)
- [Postmortem: Local to Prod Migration](../../09-sessions/2025-12-31/postmortem-local-to-prod-migration.md)

---

## Tags

`database` `migration` `lambda` `rds` `production` `batch-operations`