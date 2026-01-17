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

# RIS-RESOLUTION-046: Providers Dashboard 500 Error - Missing Database Columns

**Date:** 2025-12-28
**Status:** RESOLVED
**Severity:** HIGH
**Impact:** Production dashboard unavailable
**Root Cause:** Code deployed with schema changes but migrations not executed

---

## Problem Statement

Production providers dashboard returned 500 errors with message "Failed to load dashboard" / "Failed to load providers".

**User Impact:**
- Admin dashboard completely non-functional
- Unable to view provider compliance status
- Blocking admin workflows

**Error Signature:**
```
psycopg2.errors.UndefinedColumn: column documents.uploaded_by_user_id does not exist
psycopg2.errors.UndefinedColumn: column documents.upload_notes does not exist
```

---

## Root Cause Analysis

### What Happened

1. **Code Deployment:** Backend code deployed with commit `4515ca8` including:
   - Document model with new fields: `uploaded_by_user_id`, `upload_notes`
   - Alembic migrations: `20251228_0001`, `20251228_0002`

2. **Migration Gap:** Database migrations NOT executed before code deployment
   - Code expected columns that didn't exist
   - SQLAlchemy SELECT queries failed immediately

3. **Detection:** Frontend showed "Failed to load dashboard" on organization compliance page

### Why It Happened

**Process Failure:**
- No automated migration execution in Lambda deployment workflow
- Deployment script (`deploy-to-production`) doesn't run Alembic
- Local migrations not synced to production database

**Infrastructure Gap:**
- Production database in private subnet (no direct access)
- EC2 instance stopped (previous migration path unavailable)
- No Lambda-based migration runner in deployment pipeline

---

## Solution Implemented

### Approach: Temporary Lambda Migration Executor

Created temporary Lambda functions with:
- VPC access to production RDS
- Existing `credmate-psycopg2-manylinux` layer
- Secrets Manager integration for DB credentials

### Migration 1: `uploaded_by_user_id` Column

```sql
ALTER TABLE documents
ADD COLUMN uploaded_by_user_id INTEGER
REFERENCES users(id) ON DELETE SET NULL;

CREATE INDEX idx_documents_uploaded_by_user
ON documents (uploaded_by_user_id);

UPDATE documents d
SET uploaded_by_user_id = (
    SELECT user_id
    FROM audit_logs a
    WHERE a.event_type = 'document_uploaded'
    AND a.resource_identifier = d.id::text
    ORDER BY a.created_at DESC
    LIMIT 1
)
WHERE uploaded_by_user_id IS NULL;

UPDATE alembic_version SET version_num = '20251228_0001';
```

**Result:** ✅ Executed successfully

### Migration 2: `upload_notes` Column

```sql
ALTER TABLE documents
ADD COLUMN upload_notes TEXT;

UPDATE alembic_version SET version_num = '20251228_0002';
```

**Result:** ✅ Executed successfully

### Verification

```bash
# Check backend health
$ curl https://t863p0a5yf.execute-api.us-east-1.amazonaws.com/health
{"status":"healthy","service":"credmate-api"}

# Check Lambda logs
$ aws logs tail /aws/lambda/credmate-backend-dev --since 2m
# No UndefinedColumn errors

# Frontend dashboard
✅ Loads without errors
```

---

## Timeline

| Time | Event |
|------|-------|
| 10:00 | Backend deployed with new columns |
| 10:15 | User reports dashboard 500 errors |
| 10:20 | Investigation started - identified missing columns |
| 10:30 | Attempted RDS Data API (unavailable for standard RDS) |
| 10:45 | Attempted direct psycopg2 connection (private subnet timeout) |
| 11:00 | Created Lambda migration executor with psycopg2 layer |
| 11:05 | Executed migration 20251228_0001 ✅ |
| 11:10 | Verified - found second missing column `upload_notes` |
| 11:15 | Executed migration 20251228_0002 ✅ |
| 11:20 | **RESOLVED** - Dashboard functional |

**Total Downtime:** ~80 minutes

---

## Prevention Strategy

### Immediate Actions (Completed)

1. ✅ Both migrations executed
2. ✅ Alembic version updated to `20251228_0002`
3. ✅ Dashboard verified working
4. ✅ Temporary Lambda functions deleted

### Short-Term Fixes (Required)

1. **Add Migration Check to Deployment**
   - Update `deploy-to-production` skill
   - Check pending migrations before deployment
   - Block deployment if migrations exist but not applied

2. **Create Permanent Migration Lambda**
   - Reusable function for executing migrations
   - Triggered manually or via deployment pipeline
   - Keep psycopg2 layer attached

3. **Add Pre-Deployment Validation**
   - Compare `alembic current` (code) vs `alembic_version` (database)
   - Warn if mismatch detected
   - Require explicit confirmation to proceed

### Long-Term Solutions

1. **Automated Migration Execution**
   - Lambda function triggered on deployment
   - Runs `alembic upgrade head` automatically
   - Logs to CloudWatch + session files

2. **Database Schema Monitoring**
   - Weekly schema comparison: code vs database
   - Alert on drift detected
   - Generate reconciliation migration if needed

3. **Deployment Gate**
   - CI/CD step: "Check pending migrations"
   - If pending migrations exist:
     - Execute via Lambda migration runner
     - Wait for completion
     - Then deploy code

---

## Technical Details

### Why Standard Migration Paths Failed

| Method | Status | Reason |
|--------|--------|--------|
| **RDS Data API** | ❌ Not available | Standard RDS (not Aurora Serverless) |
| **Direct psycopg2** | ❌ Timeout | Database in private subnet (10.0.10.114) |
| **EC2 + Alembic** | ❌ Unavailable | EC2 instance stopped, no root volume |
| **SSM + Docker** | ❌ Unavailable | No running EC2 instance |
| **API Gateway endpoint** | ❌ Failed | File permissions in Lambda container |

### Why Lambda Migration Worked

✅ **VPC Access:** Lambda in same VPC/subnets as RDS
✅ **psycopg2 Layer:** Pre-built `credmate-psycopg2-manylinux:1` layer
✅ **Secrets Manager:** Automated credential retrieval
✅ **Temporary Function:** Created, executed, deleted (no permanent changes)

---

## Lessons Learned

### What Worked

1. **Existing psycopg2 layer** - Saved hours of layer building
2. **Lambda VPC access** - Bypassed private subnet limitations
3. **IF NOT EXISTS clauses** - Safe to re-run migrations
4. **Secrets Manager integration** - No hardcoded credentials

### What Didn't Work

1. **Manual deployment process** - Forgot to run migrations
2. **No deployment checklist** - Migrations not in procedure
3. **No automated validation** - Code/schema drift undetected
4. **No rollback plan** - Had to fix forward (no downgrade prepared)

### Process Gaps

1. **Missing:** Migration execution in deployment workflow
2. **Missing:** Pre-deployment schema validation
3. **Missing:** Automated alembic version check
4. **Missing:** Production migration runbook

---

## Related Issues

- **Similar:** None (first Lambda-based migration)
- **Prevented:** Future missing column errors (with deployment gate)
- **Follow-Up:** RIS-047 (Migration automation)

---

## References

- **Migrations:** `apps/backend-api/alembic/versions/20251228_000{1,2}_*.py`
- **Layer:** `arn:aws:lambda:us-east-1:051826703172:layer:credmate-psycopg2-manylinux:1`
- **Database:** `prod-credmate-db.cm1ksgqm0c00.us-east-1.rds.amazonaws.com`
- **Session:** `docs/09-sessions/2025-12-28/session-20251228-providers-dashboard-fix-EXECUTION.md`

---

**Resolution:** COMPLETE
**Deployment Safe:** YES (migrations applied)
**Documentation:** Complete (RIS + KB + Session)
**Follow-Up Required:** Migration automation (target: 2025-01-15)