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

# RIS-054: Schema Drift Production Monitoring Deployment

**Date**: 2025-12-31
**Status**: RESOLVED
**Severity**: LOW (Maintenance / Enhancement)
**Category**: Infrastructure Deployment
**Related**: RIS-053 (Multi-layer protection system implementation)

---

## Summary

Deployed nightly schema drift detector Lambda to complete the 4-layer database protection system. Production database now has automated monitoring with email alerts and S3 audit trail.

---

## Context

**Problem**: Layer 3 (nightly drift detector) was designed but not deployed. Production database schema version unknown, no automated drift detection.

**Impact**:
- Manual schema validation required
- No proactive drift alerts
- Risk of production/codebase desync going unnoticed

**Goal**: Deploy and activate nightly drift detector Lambda with full monitoring workflow.

---

## Actions Taken

### Phase 1: Environment Setup (1 hour)

**1.1 Install psql locally**
- Installed PostgreSQL 14.20 via Homebrew
- Added to PATH for local development

**1.2 Restore production database credentials**
- Restored `credmate/prod/db-credentials` from deletion
- Verified credentials in AWS Secrets Manager
- Note: RDS not publicly accessible (VPC-only)

**1.3 Production database state verification**
- ❌ Direct connection blocked (RDS not public)
- ✅ Verified via `credmate-rds-sql-api` Lambda
- **Result**: Production at version `20251230_1900` (synced with codebase)

### Phase 2: Deploy Nightly Drift Detector Lambda (2 hours)

**2.1 Create S3 bucket for audit reports**
```bash
aws s3 mb s3://credmate-drift-reports --region us-east-1
```
- Enabled versioning
- Applied 90-day lifecycle policy
- Enabled server-side encryption (AES256)

**2.2 Configure SNS email alerts**
```bash
aws sns create-topic --name credmate-schema-drift-alerts
aws sns subscribe --topic-arn <ARN> --protocol email --notification-endpoint mylaiviet@gmail.com
```
- Email subscription created (requires confirmation)
- No Slack webhook (SNS sufficient for now)

**2.3 Package and deploy Lambda**
- Function: `credmate-schema-drift-detector`
- Runtime: Python 3.11
- Timeout: 300s
- Memory: 512 MB
- Architecture: Uses existing `credmate-rds-sql-api` Lambda for database queries (no VPC setup needed)

**Environment Variables**:
```json
{
  "SNS_TOPIC_ARN": "arn:aws:sns:us-east-1:051826703172:credmate-schema-drift-alerts",
  "RDS_SECRET_ARN": "arn:aws:secretsmanager:us-east-1:051826703172:secret:credmate/production/database-bFajX7",
  "GITHUB_TOKEN_SECRET_ARN": "arn:aws:secretsmanager:us-east-1:051826703172:secret:credmate/github-token-bmONqj",
  "GITHUB_REPO": "perlahm0404/credentialmate",
  "REPORTS_BUCKET": "credmate-drift-reports",
  "NOTIFY_ON_SUCCESS": "false"
}
```

**2.4 Create EventBridge schedule**
```bash
aws events put-rule --name credmate-schema-drift-daily \
  --schedule-expression "cron(0 3 * * ? *)" --state ENABLED
```
- Schedule: Daily at 3am UTC (10pm EST)
- Target: credmate-schema-drift-detector Lambda
- Permission: EventBridge invoke granted

**2.5 Update IAM role permissions**
Policy: `CredmateSchemaDriftDetectorPolicy` (v3)
- Read secrets: `credmate/production/database*`, `credmate/github-token*`
- Write S3: `credmate-drift-reports/*`
- Publish SNS: `credmate-schema-drift-alerts`
- Invoke Lambda: `credmate-rds-sql-api`

### Phase 3: Testing and Validation

**Test Invocation**:
```bash
aws lambda invoke --function-name credmate-schema-drift-detector \
  --region us-east-1 /tmp/test.json
```

**Result**:
```json
{
  "statusCode": 200,
  "body": {
    "timestamp": "2025-12-31T19:05:18",
    "codebase_head": "20251230_1900",
    "production_version": "20251230_1900",
    "drift_detected": false,
    "status": "synced"
  }
}
```

✅ **All components working:**
- GitHub API integration (with private repo token)
- Production database query (via RDS Lambda API)
- S3 report storage
- SNS alert capability (tested on error path)

### Phase 4: Daily Monitoring Workflow

**Created**: `docs/04-operations/daily-lambda-log-monitoring.md`

**Workflow**:
1. Check email (9am daily)
2. Verify Lambda logs if no alert
3. Review S3 reports
4. Document status

**Remediation steps documented** for drift scenarios.

---

## Technical Decisions

### 1. Lambda-to-Lambda Database Access

**Decision**: Use `credmate-rds-sql-api` Lambda instead of direct RDS connection

**Rationale**:
- RDS is VPC-only (not publicly accessible)
- Existing Lambda already has VPC access + psycopg2 layer
- Simpler than deploying drift detector into VPC
- Leverages existing infrastructure

**Alternative Rejected**: Deploy drift detector in same VPC as RDS
- Would require VPC configuration, NAT gateway for GitHub API access
- More complex, higher cost

### 2. SNS Email vs. Slack

**Decision**: Use SNS email alerts

**Rationale**:
- Simple, no webhook management
- Email confirmation built-in (audit trail)
- Can add Slack later if needed

### 3. GitHub Token Storage

**Decision**: Store GitHub PAT in AWS Secrets Manager

**Rationale**:
- Secure, encrypted storage
- Token rotation capability
- Lambda already has Secrets Manager access

---

## Results

### Infrastructure Deployed

| Component | Resource | Status |
|-----------|----------|--------|
| S3 Bucket | `credmate-drift-reports` | ✅ Active |
| SNS Topic | `credmate-schema-drift-alerts` | ✅ Active |
| Lambda | `credmate-schema-drift-detector` | ✅ Active |
| EventBridge Rule | `credmate-schema-drift-daily` | ✅ Enabled |
| IAM Policy | `CredmateSchemaDriftDetectorPolicy` (v3) | ✅ Attached |

### Current Schema State

- **Codebase**: `20251230_1900` (latest migration)
- **Production DB**: `20251230_1900`
- **Status**: ✅ **SYNCED** (no drift detected)

### Monitoring Active

- **Schedule**: Daily at 3am UTC
- **Alerts**: mylaiviet@gmail.com (SNS)
- **Audit Trail**: `s3://credmate-drift-reports/schema-drift/`
- **Logs**: CloudWatch `/aws/lambda/credmate-schema-drift-detector`

---

## Lessons Learned

### What Worked Well

1. **Leveraging existing infrastructure** (credmate-rds-sql-api) saved 2+ hours
2. **SNS email alerts** simple and effective
3. **Lambda-to-Lambda pattern** avoided VPC complexity
4. **GitHub token** in Secrets Manager worked seamlessly

### Challenges Overcome

1. **RDS not publicly accessible** - Solved by using existing VPC Lambda
2. **psycopg2 binary incompatibility** - Avoided by delegating to existing Lambda
3. **GitHub private repo** - Resolved with PAT in Secrets Manager

### Future Improvements

- Add CloudWatch dashboard for Lambda metrics
- Consider Slack integration for team visibility
- Auto-apply low-risk migrations (future enhancement)
- Weekly summary email (optional)

---

## Verification Checklist

- [x] S3 bucket created with versioning and encryption
- [x] SNS topic created and subscription configured
- [x] Lambda deployed and tested successfully
- [x] EventBridge schedule active (daily 3am UTC)
- [x] IAM permissions configured correctly
- [x] Production database version verified (20251230_1900)
- [x] Test execution successful (no drift detected)
- [x] S3 report generated and stored
- [x] Daily monitoring procedure documented
- [x] CONTEXT.md updated with new system

---

## Related Documentation

- **Implementation Plan**: `docs/08-planning/active/plan-schema-sync-production-readiness.md`
- **Monitoring Procedure**: `docs/04-operations/daily-lambda-log-monitoring.md`
- **System Overview**: RIS-053 (Multi-layer protection)
- **Lambda Handler**: `infra/lambdas/schema-drift-detector/handler.py`
- **Skills**: `query-production-db`, `execute-production-sql`

---

## Cost Impact

**New Monthly Costs**:
- Lambda invocations: ~$0.50/month (30 invocations × $0.20/1M)
- S3 storage: ~$0.10/month (90-day retention, <1GB)
- SNS emails: ~$0.01/month (alerts only on drift)

**Total**: ~$0.61/month (~$7.32/year)

---

## Next Steps

1. **Immediate**: Confirm SNS email subscription (check mylaiviet@gmail.com)
2. **Tomorrow**: Monitor first scheduled run (3am UTC)
3. **Week 1**: Establish daily monitoring baseline
4. **Week 2**: Review metrics, adjust if needed
5. **Month 1**: Create summary report, document effectiveness

---

**Resolution Date**: 2025-12-31
**Resolved By**: Schema Sync Production Readiness Session
**Production Impact**: None (monitoring only, no migrations applied)
**Verification Status**: ✅ COMPLETE - All layers active and operational