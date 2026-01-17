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

# RIS-052: Schema Drift Between Local and Production Databases

**Date**: 2025-12-31
**Status**: RESOLVED (Local), TOOLS READY (Production pending access)
**Severity**: MEDIUM
**Reporter**: Database Schema Comparison Tool

## Issue Summary

Local database had divergent migration state from codebase:
- Local DB: `394c8c3cbf42` (old hash-based revision format)
- Codebase head: `20251230_1900` (timestamp-based revision format)
- Gap: 2 migrations behind (20251230_1700 and 20251230_1900)

**Note**: Production database comparison not performed due to infrastructure changes (production secrets deleted, psql not installed locally).

## Root Cause

1. **Naming Convention Mismatch**: Merge migration `20251230_1643_394c8c3cbf42` introduced timestamp-based revision IDs, but local database was not updated
2. **Migration Gap**: Local database had migrations applied manually but alembic_version not updated to latest
3. **No Automated Drift Detection**: No tooling existed to detect schema divergence before deployment

## Impact

- Risk of deployment failures due to schema mismatches
- Manual verification required for database operations
- Uncertainty about database state consistency
- Local development environment out of sync with codebase

## Resolution

### Actions Taken

1. **Created Schema Comparison Tool** ([compare_db_schemas.py](../../apps/backend-api/scripts/compare_db_schemas.py))
   - Hybrid approach: Alembic migration tracking + SQL schema comparison
   - Direct production database access capability via Secrets Manager + psql
   - Automated drift detection and reporting
   - Supports `--skip-production` for local-only comparison
   - Generates markdown reports for audit trail

2. **Created Production Database Access Helpers** ([db_comparison_helpers.py](../../infra/scripts/db_comparison_helpers.py))
   - `DirectPsqlConnector` class for production schema queries
   - Read-only SQL validation (blocks INSERT/UPDATE/DELETE)
   - Schema metadata extraction (tables, columns, indexes, constraints)
   - Graceful fallback when production access unavailable

3. **Fixed Local Database**
   - Updated alembic_version: `394c8c3cbf42` → `20251230_1643`
   - Skipped migration `20251230_1700` (columns already existed)
   - Applied migration `20251230_1900` (superuser role constraint)
   - Verified schema at canonical state: `20251230_1900`

4. **Verified Local Canonical State**
   - Local: ✅ `20251230_1900`
   - Codebase: ✅ `20251230_1900`
   - Schema comparison: ✅ All elements match

## Prevention

### Immediate Actions

- [x] Schema comparison tool committed to codebase
- [x] Local database at canonical state (20251230_1900)
- [x] RIS entry created for audit trail
- [x] Production access helpers ready for future use

### Future Improvements

- [ ] Install psql locally for production schema comparison
- [ ] Restore production database credentials in AWS Secrets Manager
- [ ] Add pre-deployment schema comparison check (CI/CD gate)
- [ ] Schedule nightly drift detection (cron job or Lambda)
- [ ] Alert on schema divergence (Slack notification)
- [ ] Update seed scripts to match current codebase structure (separate task)

## Related Incidents

- **20251228-dashboard-500-missing-migrations** - Similar issue where code deployed without migrations applied
- **RIS-051-migration-deployment-gap** - Production migrations not applied during December 30 deployment

## Files Created

| File | Purpose |
|------|---------|
| [apps/backend-api/scripts/compare_db_schemas.py](../../apps/backend-api/scripts/compare_db_schemas.py) | Main comparison tool with CLI |
| [infra/scripts/db_comparison_helpers.py](../../infra/scripts/db_comparison_helpers.py) | Production DB access utilities |
| [docs/06-ris/resolutions/ris-052-schema-drift-local-production.md](ris-052-schema-drift-local-production.md) | This document |

## Files Used

| File | Purpose |
|------|---------|
| [apps/backend-api/scripts/fix_alembic_revision_ids.py](../../apps/backend-api/scripts/fix_alembic_revision_ids.py) | Fixed local alembic_version |
| [apps/backend-api/alembic/versions/20251230_1643_394c8c3cbf42_merge_batch_id_and_audit_index_.py](../../apps/backend-api/alembic/versions/20251230_1643_394c8c3cbf42_merge_batch_id_and_audit_index_.py) | Merge migration |
| [apps/backend-api/alembic/versions/20251230_1700_add_email_issue_flags.py](../../apps/backend-api/alembic/versions/20251230_1700_add_email_issue_flags.py) | Email flags migration (skipped - already applied) |
| [apps/backend-api/alembic/versions/20251230_1900_sync_superuser_role_constraint.py](../../apps/backend-api/alembic/versions/20251230_1900_sync_superuser_role_constraint.py) | Superuser constraint migration |

## Lessons Learned

1. **Automated drift detection is critical** - Manual verification is error-prone and doesn't scale
2. **Naming convention consistency matters** - Hash vs timestamp IDs caused confusion during transition
3. **Migration deployment must be verified** - Code can deploy without schema updates if not gated
4. **Production access tooling is valuable** - Direct psql connection enables rapid verification when available
5. **Graceful degradation** - Tools should work in local-only mode when production access unavailable

## Tool Usage

### Compare Local vs Codebase
```bash
docker exec -w /app/apps/backend-api credmate-backend-dev python scripts/compare_db_schemas.py --skip-production
```

### Compare Local vs Production (when access restored)
```bash
# Install psql locally first
brew install postgresql  # macOS
# or: sudo apt-get install postgresql-client  # Ubuntu/Debian

# Restore production credentials in AWS Secrets Manager
# Secret ID: credmate/prod/db-credentials

# Run comparison
docker exec -w /app/apps/backend-api credmate-backend-dev python scripts/compare_db_schemas.py
```

### Generate RIS Entry on Drift Detection
```bash
docker exec -w /app/apps/backend-api credmate-backend-dev python scripts/compare_db_schemas.py --create-ris
```

## Timeline

| Time | Event |
|------|-------|
| 2025-12-30 16:43 | Merge migration created with new naming convention |
| 2025-12-31 00:00 | Production seeding session - discovered revision mismatch |
| 2025-12-31 02:00 | Schema comparison tool planning started |
| 2025-12-31 16:00 | Schema comparison tool implemented |
| 2025-12-31 16:10 | Local database synchronized to canonical state |
| 2025-12-31 16:14 | RIS entry created |

## Success Criteria

- [x] Local database at codebase head (20251230_1900)
- [x] Schema comparison tool operational
- [x] Tool handles graceful degradation (skip production when unavailable)
- [x] Markdown reports generated for audit trail
- [x] RIS entry documents incident and resolution
- [ ] Production database verified (pending access restoration)

## Sign-off

- **Detected by**: Manual discovery during migration review
- **Resolved by**: Schema comparison tool + alembic fix script
- **Verified by**: Automated schema comparison (local only)
- **Documented**: RIS-052 (this document)
- **Production Status**: Tools ready, awaiting access restoration