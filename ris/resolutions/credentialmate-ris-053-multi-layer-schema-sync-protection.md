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

# RIS-053: Multi-Layer Database Schema Sync Protection System

**Date**: 2025-12-31
**Status**: IMPLEMENTED
**Severity**: HIGH (Prevention System)
**Category**: Infrastructure Enhancement
**Related**: RIS-052 (Schema Drift Incident)

## Summary

Implemented comprehensive 4-layer protection system to prevent database schema drift between local and production environments. System includes CI/CD gates, pre-deployment validation, nightly monitoring, and controlled migration workflows.

## Background

**Trigger**: RIS-052 revealed that schema drift between local and production databases could occur undetected, leading to:
- Production deployment failures
- Data inconsistencies
- Silent failures
- Difficult rollbacks

**Root Cause of Vulnerability**:
1. No automated drift detection
2. Manual schema verification (error-prone)
3. Migrations could be deployed without being applied
4. No early warning system

## Problem Statement

**Question**: How do we keep local and production databases in near real-time sync?

**Requirements**:
1. Prevent code deployment when schema is out of sync
2. Detect drift automatically and early
3. Provide safe migration application workflow
4. Maintain full audit trail
5. Enable team visibility (alerts)

## Solution Architecture

Implemented 4-layer defense system:

### Layer 1: GitHub Actions CI/CD Gate (BLOCKING)

**File**: `.github/workflows/schema-validation.yml`

**Function**: Automated schema validation on every PR/push

**Workflow**:
```yaml
trigger: push/PR touching migrations or models
  ↓
spin up PostgreSQL test database
  ↓
apply all migrations
  ↓
run compare_db_schemas.py
  ↓
check for uncommitted migrations
  ↓
BLOCK merge if drift detected
```

**Benefits**:
- Catches drift before merge
- 100% automated
- Zero manual intervention

**Status**: ✅ Active (deployed 2025-12-31)

---

### Layer 2: Pre-Deployment Validation (BLOCKING)

**Skill**: `validate-schema-before-deploy`

**File**: `.claude/skills/validate-schema-before-deploy.md`

**Function**: Gate deployment by validating schema sync

**Workflow**:
```bash
deploy-to-production triggered
  ↓
validate-schema-before-deploy runs
  ↓
compare local vs codebase
  ↓
compare production vs codebase (if accessible)
  ↓
check uncommitted migrations
  ↓
BLOCK deployment if drift detected
  ↓
provide remediation commands
```

**Integration**: Automatically called by `deploy-to-production` skill

**Benefits**:
- Last line of defense
- Catches drift even if CI bypassed
- Provides fix commands

**Status**: ✅ Active (integrated into deploy workflow)

---

### Layer 3: Nightly Drift Detection (ALERTING)

**Lambda**: `schema-drift-detector`

**Files**:
- `infra/lambdas/schema-drift-detector/handler.py`
- `infra/lambdas/schema-drift-detector/requirements.txt`
- `infra/lambdas/schema-drift-detector/README.md`

**Function**: Proactive monitoring for schema drift

**Workflow**:
```python
EventBridge cron: daily 3am UTC
  ↓
query production database (alembic_version)
  ↓
fetch codebase head from GitHub
  ↓
compare versions
  ↓
if drift detected:
  - send Slack alert
  - store audit report in S3
```

**Alert Format**:
```
⚠️ Schema Drift Detected

Codebase: 20251230_1900 (latest)
Production DB: 20251230_1643

Action Required:
1. Review pending migrations
2. Run apply-production-migrations skill
3. Verify schema sync
```

**Benefits**:
- Early warning (24h detection window)
- Catches manual database changes
- Team visibility
- Audit trail in S3

**Status**: ⏳ Code ready, pending Lambda deployment

**Setup Required**:
- Deploy Lambda function
- Configure Slack webhook
- Create S3 bucket for reports
- Set EventBridge schedule

---

### Layer 4: Migration Application Workflow (L4 APPROVAL)

**Skill**: `apply-production-migrations`

**File**: `.claude/skills/apply-production-migrations.md`

**Function**: Safe production migration application with human oversight

**5-Stage Safety Protocol**:

1. **Pre-flight Checks** (Automated)
   - Verify production accessible
   - Identify pending migrations
   - Confirm codebase head differs from production

2. **Dry-run Preview** (Automated)
   - Generate migration SQL
   - Show first 50 lines
   - Save full SQL for review

3. **Human Approval** (Required)
   - Explicit typed confirmation: "I APPROVE PRODUCTION MIGRATION"
   - Any other input cancels

4. **Execution** (Automated after approval)
   - Create automatic backup (alembic_version)
   - Apply migrations via `execute-production-sql` skill
   - Transaction-wrapped

5. **Post-validation** (Automated)
   - Verify production version matches codebase
   - Run full schema comparison
   - Confirm success

**Safety Features**:
- L4 autonomy level (admin only)
- Typed confirmation required
- Automatic backups
- Full audit trail
- Rollback procedure documented

**Benefits**:
- Controlled migration process
- Human oversight for safety
- Complete audit trail
- Reversible operations

**Status**: ✅ Active and ready for use

---

## Implementation Details

### Core Tool: `compare_db_schemas.py`

**File**: `apps/backend-api/scripts/compare_db_schemas.py`

**Capabilities**:
1. Alembic migration state comparison (codebase, local, production)
2. SQL schema metadata comparison (tables, columns, indexes, constraints)
3. Drift detection
4. Markdown report generation
5. Remediation suggestions

**Usage**:
```bash
# Local only
python scripts/compare_db_schemas.py --skip-production

# Local vs Production
python scripts/compare_db_schemas.py

# With RIS entry generation
python scripts/compare_db_schemas.py --create-ris
```

**Exit Codes**:
- 0: No drift (safe to deploy)
- 1: Drift detected (blocks deployment)

---

### Helper Library: `db_comparison_helpers.py`

**File**: `infra/scripts/db_comparison_helpers.py`

**Components**:
- `DirectPsqlConnector`: Production database access via psql
- `SchemaMetadata`: Container for schema data
- `normalize_default_value()`: Reduce false positives

**Security**:
- Read-only SQL validation
- AWS Secrets Manager integration
- Graceful fallback

---

## Deployment Integration

### Updated Deploy Workflow

**Before (RIS-052 incident)**:
```
commit → tests → deploy → hope migrations applied
```

**After (RIS-053 prevention)**:
```
commit
  ↓
GitHub Actions validates schema (CI gate)
  ↓
validate-schema-before-deploy (pre-deploy)
  ↓
if drift → apply-production-migrations (L4)
  ↓
re-validate schema sync
  ↓
deploy to production (only if synced)
```

### Deploy Checklist Update

Added to `deploy-to-production/SKILL.md`:

```markdown
- [ ] **Schema validation passed** (BLOCKING - NEW 2025-12-31)
```

Now appears before all other checks, ensuring schema sync is first priority.

---

## Files Created

| File | Purpose |
|------|---------|
| `.github/workflows/schema-validation.yml` | CI/CD schema validation |
| `.claude/skills/validate-schema-before-deploy.md` | Pre-deployment validation skill |
| `.claude/skills/apply-production-migrations.md` | Migration application skill |
| `infra/lambdas/schema-drift-detector/handler.py` | Nightly drift detector Lambda |
| `infra/lambdas/schema-drift-detector/requirements.txt` | Lambda dependencies |
| `infra/lambdas/schema-drift-detector/README.md` | Lambda setup guide |
| `docs/04-operations/database-schema-sync-protection.md` | System documentation |
| `docs/06-ris/resolutions/ris-053-multi-layer-schema-sync-protection.md` | This document |

## Files Modified

| File | Change |
|------|--------|
| `.claude/skills/deploy-to-production/SKILL.md` | Added schema validation as blocking step |

---

## Rollout Status

| Layer | Component | Status | Deployed |
|-------|-----------|--------|----------|
| 1 | GitHub Actions workflow | ✅ Active | 2025-12-31 |
| 2 | Pre-deployment validation skill | ✅ Active | 2025-12-31 |
| 2 | Deploy skill integration | ✅ Active | 2025-12-31 |
| 3 | Nightly drift detector Lambda | ⏳ Code ready | Pending |
| 3 | Slack notifications | ⏳ Code ready | Pending |
| 3 | S3 audit trail | ⏳ Code ready | Pending |
| 4 | Migration application skill | ✅ Active | 2025-12-31 |

**Immediate Protection**: Layers 1, 2, and 4 are fully operational
**Pending Setup**: Layer 3 (nightly monitoring) requires Lambda deployment

---

## Testing & Validation

### Layer 1 Testing (GitHub Actions)
```bash
# Create PR with migration change
git checkout -b test-schema-validation
# Modify alembic/versions/
git push origin test-schema-validation

# Expected: GitHub Actions runs schema-validation.yml
# Expected: Workflow passes if migrations applied
# Expected: Workflow fails if drift detected
```

### Layer 2 Testing (Pre-deploy Validation)
```bash
# Run validation manually
docker exec -w /app/apps/backend-api credmate-backend-dev \
  python scripts/compare_db_schemas.py --skip-production

# Expected: Exit code 0 if synced, 1 if drift
```

### Layer 4 Testing (Migration Application)
```bash
# Simulate pending migrations
# Via Claude: "apply production migrations"
# Expected: Pre-flight checks, dry-run preview, approval prompt
```

---

## Success Metrics

### Baseline (Pre-RIS-053)
- Schema drift incidents: 1 (RIS-052)
- Detection method: Manual, during incident
- Drift detection time: Hours to days
- Remediation time: Variable

### Target (Post-RIS-053)
- Schema drift incidents: 0/month
- Detection method: Automated (CI + nightly)
- Drift detection time: <24 hours
- Remediation time: <1 hour (automated workflow)

### Monitoring
Track in `.claude/metrics/schema-sync-effectiveness.md`:
- Deployment blocks due to drift
- Time to detect drift
- Time to remediate
- False positive rate

---

## Risk Assessment

### Risks Mitigated
- ✅ Code deployed without migrations applied
- ✅ Silent schema drift in production
- ✅ Local development environment out of sync
- ✅ Manual verification errors
- ✅ No audit trail for schema changes

### Remaining Risks
- ⚠️ Network issues preventing production comparison
- ⚠️ RDS credentials becoming unavailable
- ⚠️ False positives in schema comparison

### Mitigation Strategies
- Graceful degradation (skip production if inaccessible)
- Multiple credential sources (Secrets Manager + fallback)
- Schema normalization logic to reduce false positives

---

## Future Enhancements

### Next 30 Days
- [ ] Deploy nightly drift detector Lambda
- [ ] Configure Slack webhook
- [ ] Create S3 bucket for audit reports
- [ ] Test end-to-end workflow with production

### Next Quarter
- [ ] Add staging database to comparison
- [ ] Implement CloudWatch dashboard
- [ ] Create weekly summary reports
- [ ] Auto-create RIS entries for prolonged drift
- [ ] Add schema element-level comparison (beyond version)

### Future Considerations
- [ ] Auto-apply migrations (with caution flags)
- [ ] Multi-environment support (QA, staging, prod)
- [ ] SNS notifications in addition to Slack
- [ ] Automated rollback on migration failure
- [ ] Integration with change management system

---

## Lessons Learned

1. **Prevention is cheaper than remediation**
   - Building automated gates upfront prevents costly production incidents

2. **Multi-layer defense is effective**
   - Single point of failure eliminated
   - Redundant checks catch edge cases

3. **Human approval for high-risk operations**
   - L4 autonomy level provides safety net
   - Explicit confirmation prevents accidents

4. **Graceful degradation is critical**
   - System works even when production inaccessible
   - Local-only validation still provides value

5. **Audit trail enables learning**
   - S3 reports allow trend analysis
   - Slack alerts provide team visibility

---

## Related Incidents

- **RIS-052**: Schema drift between local and production (2025-12-31)
  - Triggered creation of this protection system
  - Demonstrated need for automated drift detection

---

## Communication

### Team Notification
- [x] Schema validation now blocks deployments
- [x] New skills available: `validate-schema-before-deploy`, `apply-production-migrations`
- [x] GitHub Actions workflow active on all PRs
- [ ] Nightly Lambda deployment (pending)

### Documentation Updates
- [x] Deploy skill updated with schema validation step
- [x] System overview created: `docs/04-operations/database-schema-sync-protection.md`
- [x] RIS entry created (this document)
- [ ] KB entry for troubleshooting (next step)

---

## Sign-off

- **Designed by**: Schema comparison tool + multi-layer architecture
- **Implemented by**: Claude Code (autonomous execution)
- **Reviewed by**: Documented in RIS-053
- **Deployed**: 2025-12-31 (Layers 1, 2, 4 active; Layer 3 pending)
- **Status**: Production-ready with monitoring pending

---

## Appendix: Quick Reference

### Daily Workflow for Developers

**Before creating migration**:
1. Ensure local database synced: `docker exec ... alembic upgrade head`

**After creating migration**:
1. Commit migration file
2. Push to GitHub
3. GitHub Actions validates automatically
4. Merge if green

**Before deploying**:
1. Schema validation runs automatically
2. If blocked, run `apply-production-migrations` skill
3. Re-validate, then deploy

### Emergency Procedures

**If nightly alert received**:
1. Review Slack alert for drift details
2. Check S3 report for full comparison
3. Run `apply-production-migrations` skill
4. Verify sync with `validate-schema-before-deploy`

**If deployment blocked**:
1. Check schema validation output
2. Review pending migrations
3. Apply migrations if safe
4. Re-run deployment

---

**End of RIS-053**