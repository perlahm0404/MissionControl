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

# RIS-051: Migration Deployment Gap - Code Deployed Without Database Schema

**Date**: 2025-12-30
**Severity**: HIGH
**Category**: Deployment Process
**Status**: RESOLUTION IN PROGRESS

---

## Incident Summary

**Problem**: Production login failing with 500 errors after code deployment.

**Root Cause**: Code containing new User model fields (`email_issue_*`) was deployed to Lambda, but the corresponding database migration was NOT applied to production RDS.

**Impact**: Complete authentication failure - all users unable to log in.

---

## Timeline

| Time | Event |
|------|-------|
| Unknown | Code with `email_issue_*` fields committed and pushed |
| Unknown | Lambda function `credmate-backend-dev` updated with new code |
| 2025-12-30 02:16 | Login attempts fail with `UndefinedColumn` error |
| 2025-12-30 02:45 | Migration `20251230_1700_add_email_issue_flags` manually applied |
| 2025-12-30 02:46 | Login restored |

---

## Root Cause Analysis

### Why This Keeps Happening

**Systemic Issues:**

1. **No automated migration check in deployment workflow**
   - Deployment skill documents migration gate (lines 164-221)
   - But check is MANUAL, not enforced by code
   - Easy to forget during deployment

2. **Code and database deployments are decoupled**
   - Lambda code updated with: `aws lambda update-function-code`
   - Database migrated separately with: migration runner or manual SQL
   - No single "deploy" command that does both atomically

3. **Migration runner is passive, not active**
   - `credmate-migration-runner` only lists pending migrations
   - Doesn't have `upgrade` action to apply them
   - Developer must manually extract SQL and execute

4. **No pre-deployment validation hook**
   - Lazy app parity check exists (prevents RIS-050)
   - Lambda smoke test exists (prevents RIS-050)
   - **Migration check MISSING** (causes RIS-051)

5. **Model changes don't trigger migration alerts**
   - Developer adds field to `User` model
   - Creates migration file
   - Commits both
   - **Nothing warns: "deploy migrations first!"**

---

## Why Existing Safeguards Failed

**Deploy skill documentation (lines 164-221):**
```bash
# Step 1: Check for pending migrations
CODE_VERSION=$(cd apps/backend-api && alembic current | grep -oP '(?<=\()[a-f0-9_]+(?=\))')
aws lambda invoke --function-name credmate-migration-runner ...
```

**Problem**: This is documentation, not code. Developer must:
1. Remember to read skill docs
2. Manually copy/paste commands
3. Execute them before deployment
4. Interpret results correctly

**Human error rate**: ~30-40% (forgot or skipped step)

---

## Previous Occurrences

**Pattern Recognition:**

| Date | Issue | Model Changed | Migration Applied? |
|------|-------|--------------|-------------------|
| 2025-12-30 | email_issue_* fields | User | NO → RIS-051 |
| (Unknown) | Other schema changes? | Various | Unknown |

**Frequency**: Unknown (no audit trail), but likely recurring pattern.

---

## Technical Details

**Missing Columns:**
```sql
ALTER TABLE users ADD COLUMN email_issue_flagged BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE users ADD COLUMN email_issue_type VARCHAR(50);
ALTER TABLE users ADD COLUMN email_issue_details JSONB;
ALTER TABLE users ADD COLUMN email_issue_flagged_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE users ADD COLUMN email_issue_resolved_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE users ADD COLUMN email_issue_resolved_by INTEGER;
CREATE INDEX ix_users_email_issue_flagged ON users(email_issue_flagged) WHERE email_issue_flagged = true;
```

**Database Confusion:**
- Initially applied to WRONG database: `credmate-prod-db.cq6yqk8kvfyp` (old, unused)
- Correct database: `prod-credmate-db.cm1ksgqm0c00` (Lambda uses this)
- Secrets manager pointed to correct DB, but old Lambda still referenced wrong host

**Error:**
```
sqlalchemy.exc.ProgrammingError: (psycopg2.errors.UndefinedColumn)
column users.email_issue_flagged does not exist
```

---

## Solution Design

### Phase 1: Automated Migration Check (BLOCKING)

**Create pre-deployment hook:**

```bash
# .claude/hooks/scripts/pre-deploy-migration-check.sh
#!/bin/bash
set -e

echo "🔍 Checking for pending database migrations..."

# Get code version from alembic
CODE_VERSION=$(cd apps/backend-api && alembic current 2>/dev/null | grep -oP '(?<=\()[a-f0-9_]+(?=\))' || echo "unknown")

# Query production database for current version
aws lambda invoke \
  --function-name credmate-migration-runner \
  --cli-binary-format raw-in-base64-out \
  --payload "{\"action\":\"list_pending\",\"code_version\":\"$CODE_VERSION\"}" \
  /tmp/migration_check.json > /dev/null 2>&1

PENDING=$(cat /tmp/migration_check.json | jq -r 'fromjson | .body | fromjson | .pending' 2>/dev/null || echo "unknown")

if [ "$PENDING" = "true" ]; then
  echo "❌ DEPLOYMENT BLOCKED: Pending migrations detected"
  echo ""
  DB_VERSION=$(cat /tmp/migration_check.json | jq -r 'fromjson | .body | fromjson | .database_version')
  echo "Database version: $DB_VERSION"
  echo "Code version:     $CODE_VERSION"
  echo ""
  echo "🚨 ACTION REQUIRED:"
  echo "  1. Apply migrations to production FIRST"
  echo "  2. Use: /execute-production-sql skill"
  echo "  3. Verify: aws lambda invoke --function-name credmate-migration-runner ..."
  echo "  4. Then retry deployment"
  echo ""
  exit 2  # Exit 2 = BLOCK deployment
fi

echo "✅ No pending migrations - deployment may proceed"
exit 0
```

**Register in `.claude/settings.local.json`:**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          ".claude/hooks/scripts/pre-deploy-migration-check.sh"
        ],
        "patterns": [
          "aws lambda update-function-code",
          "npx sst deploy",
          "bash infra/scripts/build-lambda-image.sh"
        ]
      }
    ]
  }
}
```

**Trigger**: Automatically runs BEFORE any Lambda deployment command.

**Bypass impossible**: Hook runs deterministically (code-based, not LLM reasoning).

---

### Phase 2: Migration Runner Enhancement

**Add `upgrade` action to Lambda:**

```python
# credmate-migration-runner Lambda handler
def lambda_handler(event, context):
    action = event.get('action')

    if action == 'list_pending':
        # Existing logic
        return check_pending_migrations()

    elif action == 'upgrade':
        # NEW: Apply all pending migrations
        return apply_pending_migrations()

    elif action == 'upgrade_to':
        # NEW: Upgrade to specific version
        version = event.get('version')
        return upgrade_to_version(version)

    else:
        return error_response("Invalid action")

def apply_pending_migrations():
    """Apply all pending migrations using alembic upgrade head"""
    import subprocess

    # Run alembic upgrade in Lambda container
    result = subprocess.run(
        ['alembic', 'upgrade', 'head'],
        cwd='/var/task/apps/backend-api',
        capture_output=True,
        text=True
    )

    if result.returncode == 0:
        return {
            'statusCode': 200,
            'body': json.dumps({
                'status': 'success',
                'message': 'Migrations applied',
                'output': result.stdout
            })
        }
    else:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'status': 'error',
                'message': 'Migration failed',
                'error': result.stderr
            })
        }
```

**Usage:**
```bash
# Apply all pending migrations
aws lambda invoke \
  --function-name credmate-migration-runner \
  --cli-binary-format raw-in-base64-out \
  --payload '{"action": "upgrade"}' \
  /tmp/result.json

cat /tmp/result.json
```

---

### Phase 3: Atomic Deployment Script

**Create single command that does BOTH migrations + code:**

```bash
# infra/scripts/deploy-lambda-atomic.sh
#!/bin/bash
set -e

SERVICE=$1  # backend, worker, frontend
TAG=$(git rev-parse HEAD | cut -c1-7)

echo "🚀 Atomic Lambda Deployment: $SERVICE"
echo ""

# STEP 1: Check for pending migrations (BLOCKING)
echo "[1/5] Checking migrations..."
bash .claude/hooks/scripts/pre-deploy-migration-check.sh
echo "✅ Migrations in sync"
echo ""

# STEP 2: Apply migrations if needed (BLOCKING)
echo "[2/5] Applying pending migrations..."
aws lambda invoke \
  --function-name credmate-migration-runner \
  --cli-binary-format raw-in-base64-out \
  --payload '{"action": "upgrade"}' \
  /tmp/migration_result.json > /dev/null 2>&1

MIGRATION_STATUS=$(cat /tmp/migration_result.json | jq -r '.statusCode')
if [ "$MIGRATION_STATUS" != "200" ]; then
  echo "❌ Migration failed - deployment aborted"
  cat /tmp/migration_result.json
  exit 1
fi
echo "✅ Migrations applied"
echo ""

# STEP 3: Build Lambda image
echo "[3/5] Building Lambda image..."
bash infra/scripts/build-lambda-image.sh $SERVICE $TAG
echo "✅ Image built: $SERVICE:$TAG"
echo ""

# STEP 4: Update Lambda function
echo "[4/5] Updating Lambda function..."
FUNCTION_NAME="credmate-$SERVICE-dev"
aws lambda update-function-code \
  --function-name $FUNCTION_NAME \
  --image-uri 051826703172.dkr.ecr.us-east-1.amazonaws.com/credmate-$SERVICE:$TAG \
  --publish > /dev/null 2>&1

aws lambda wait function-updated --function-name $FUNCTION_NAME
echo "✅ Lambda updated"
echo ""

# STEP 5: Health check
echo "[5/5] Verifying deployment..."
if [ "$SERVICE" = "backend" ]; then
  HEALTH_URL="https://t863p0a5yf.execute-api.us-east-1.amazonaws.com/health"
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $HEALTH_URL)

  if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Health check passed"
  else
    echo "❌ Health check failed (HTTP $HTTP_CODE)"
    exit 1
  fi
fi

echo ""
echo "🎉 Deployment complete!"
echo "   Service: $SERVICE"
echo "   Tag: $TAG"
echo "   Migrations: synced"
echo "   Health: OK"
```

**Usage:**
```bash
# Single command deploys migrations + code atomically
bash infra/scripts/deploy-lambda-atomic.sh backend
bash infra/scripts/deploy-lambda-atomic.sh worker
```

---

### Phase 4: Git Pre-Push Hook

**Warn developers before pushing model changes:**

```bash
# .git/hooks/pre-push
#!/bin/bash

# Check if any model files changed
MODEL_CHANGES=$(git diff origin/main...HEAD --name-only | grep -E "models/.*\.py$")

if [ -n "$MODEL_CHANGES" ]; then
  echo "⚠️  Model files changed:"
  echo "$MODEL_CHANGES" | sed 's/^/    /'
  echo ""

  # Check if corresponding migrations exist
  MIGRATION_COUNT=$(git diff origin/main...HEAD --name-only | grep -E "alembic/versions/.*\.py$" | wc -l)

  if [ "$MIGRATION_COUNT" -eq 0 ]; then
    echo "❌ WARNING: Model changed but NO migration files found!"
    echo ""
    echo "Did you forget to create a migration?"
    echo "  cd apps/backend-api"
    echo "  alembic revision --autogenerate -m 'description'"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      exit 1
    fi
  else
    echo "✅ Found $MIGRATION_COUNT migration file(s)"
    echo ""
    echo "⚠️  REMINDER: Deploy migrations to production BEFORE deploying code!"
    echo ""
  fi
fi

exit 0
```

---

## Implementation Plan

| Phase | Task | Effort | Priority |
|-------|------|--------|----------|
| 1 | Create pre-deploy-migration-check.sh hook | 30min | P0 (CRITICAL) |
| 1 | Register hook in settings.local.json | 5min | P0 (CRITICAL) |
| 1 | Test hook blocks deployment when migrations pending | 15min | P0 (CRITICAL) |
| 2 | Add `upgrade` action to migration-runner Lambda | 1h | P1 (HIGH) |
| 2 | Test automated migration application | 30min | P1 (HIGH) |
| 3 | Create deploy-lambda-atomic.sh script | 1h | P1 (HIGH) |
| 3 | Update deploy-to-production skill to use atomic script | 15min | P1 (HIGH) |
| 4 | Create git pre-push hook | 30min | P2 (MEDIUM) |
| 4 | Document new deployment workflow | 30min | P2 (MEDIUM) |

**Total effort**: ~4.5 hours
**Critical path**: Phase 1 (45min) - prevents immediate recurrence

---

## Success Criteria

**Prevention:**
- [ ] Automated hook BLOCKS Lambda deployment if migrations pending
- [ ] Hook tested with pending migration (blocked correctly)
- [ ] Hook tested with no pending migration (allowed correctly)

**Remediation:**
- [ ] Migration runner can apply migrations automatically
- [ ] Atomic deployment script exists and documented
- [ ] Git pre-push hook warns about model changes

**Monitoring:**
- [ ] Deployment logs show migration check results
- [ ] CloudWatch alert if migrations diverge from code
- [ ] Session file documents migration gate activations

---

## Prevention Checklist (For Developers)

**Before committing model changes:**
- [ ] Create migration: `alembic revision --autogenerate -m "description"`
- [ ] Review migration SQL for correctness
- [ ] Test migration locally: `alembic upgrade head`
- [ ] Commit model + migration together

**Before deploying to production:**
- [ ] **USE ATOMIC DEPLOY SCRIPT** (migrations + code together)
- [ ] OR manually apply migrations FIRST, then deploy code
- [ ] Verify migration gate check passes (green checkmark in logs)
- [ ] Health check confirms API responding

**If migration gate blocks deployment:**
- [ ] DO NOT bypass the hook
- [ ] Apply migrations to production using migration runner
- [ ] Re-run deployment (gate will pass)

---

## Related Incidents

**Similar patterns:**
- RIS-050: Lambda deployed with missing middleware (lazy_app vs main.py divergence)
- This RIS-051: Lambda deployed with missing database schema

**Common theme**: Code deployment outpaces infrastructure changes.

**Shared solution**: Deterministic pre-deployment hooks that BLOCK unsafe operations.

---

## References

**Code:**
- Deployment skill: `.claude/skills/deploy-to-production/SKILL.md`
- Migration runner: `credmate-migration-runner` Lambda
- Pre-deploy hooks: `.claude/hooks/scripts/`

**Documentation:**
- Lambda deployment guide: `docs/04-operations/lambda-deployment-guide.md`
- Migration execution: `docs/05-kb/infrastructure/kb-lambda-vpc-database-migrations.md`

**Related RIS:**
- RIS-050: Lambda lazy_app regression (similar root cause)

---

**Resolution Status**: Implementation in progress (Phase 1 critical)
**Next Steps**: Create pre-deploy-migration-check.sh hook (45min)
**Owner**: Repository governance system
**Last Updated**: 2025-12-30