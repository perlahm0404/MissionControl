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

# RIS-CLOUDWATCH-LOGGING-GAP-20251217

**Date**: 2025-12-17
**Severity**: HIGH
**Status**: OPEN
**Category**: Infrastructure / Observability

---

## Incident Summary

Production backend and worker application logs are not flowing to CloudWatch, blocking production debugging and incident investigations.

---

## Discovery Context

**Session**: SESSION-20251217-1922-cme-autocreate-investigation
**Trigger**: Attempted to trace duplicate CME credential creation in production
**Blocker**: No application logs available in CloudWatch (only RDS logs)

---

## Current State

### What's Working
- CloudWatch log groups exist: `/credmate/backend`, `/credmate/worker`
- RDS PostgreSQL logs flowing to CloudWatch
- Docker logs available on EC2 (but rotate quickly)

### What's Broken
- Backend application logs NOT in CloudWatch (38MB stored but no accessible events)
- Worker application logs NOT in CloudWatch
- Cannot query production execution traces via CloudWatch Insights
- Docker logs on EC2 rotate too quickly for historical investigation

---

## Impact

**Production Debugging**: BLOCKED
- Cannot trace execution flow for production bugs
- Cannot investigate duplicate creation, race conditions, etc.
- Forced to SSH into EC2 and grep rotated Docker logs (inefficient)

**Incident Response**: DEGRADED
- Limited visibility into production issues
- Cannot correlate logs across services
- No historical logs for post-incident analysis

**Compliance/Audit**: AT RISK
- No centralized audit trail
- Logs may be lost before capture
- Cannot prove compliance with logging requirements

---

## Root Cause

Docker containers on EC2 are not configured to send logs to CloudWatch.

**Missing Configuration**:
- Docker log driver not set to `awslogs`
- No CloudWatch Logs agent installed
- Application logs only go to stdout (captured by Docker, not forwarded)

---

## Cost Analysis

### CloudWatch Logs Pricing (US-East-1)
- Ingestion: $0.50 per GB
- Storage: $0.03 per GB/month
- Insights Queries: $0.005 per GB scanned

### Estimated Production Volume
- Backend: ~100MB/day
- Worker: ~50MB/day
- **Total**: ~150MB/day = ~4.5GB/month

### Monthly Cost (7-day retention)
- Ingestion: 4.5 GB × $0.50 = $2.25/month
- Storage: 1.05 GB × $0.03 = $0.03/month
- Queries: ~$0.01/month
- **Total: ~$2.30/month** (essentially free)

### ROI
- **Cost**: $2.30/month
- **Time saved**: 2+ hours per investigation (this incident alone)
- **Billable engineering time**: $200+/hour
- **Break-even**: First incident

---

## Resolution Plan

### Phase 1: Configure Docker Log Driver (IMMEDIATE)

**File**: `docker-compose.prod.yml`

Add logging configuration to all services:

```yaml
services:
  backend:
    logging:
      driver: awslogs
      options:
        awslogs-region: us-east-1
        awslogs-group: /credmate/backend
        awslogs-stream: backend-prod
        awslogs-create-group: "true"

  worker:
    logging:
      driver: awslogs
      options:
        awslogs-region: us-east-1
        awslogs-group: /credmate/worker
        awslogs-stream: worker-prod
        awslogs-create-group: "true"

  frontend:
    logging:
      driver: awslogs
      options:
        awslogs-region: us-east-1
        awslogs-group: /credmate/frontend
        awslogs-stream: frontend-prod
        awslogs-create-group: "true"
```

### Phase 2: Set Log Retention (COST CONTROL)

```bash
# Set 7-day retention on log groups
aws logs put-retention-policy \
  --log-group-name /credmate/backend \
  --retention-in-days 7 \
  --region us-east-1

aws logs put-retention-policy \
  --log-group-name /credmate/worker \
  --retention-in-days 7 \
  --region us-east-1

aws logs put-retention-policy \
  --log-group-name /credmate/frontend \
  --retention-in-days 7 \
  --region us-east-1
```

### Phase 3: Verify IAM Permissions

EC2 instance role must have CloudWatch Logs permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": "arn:aws:logs:us-east-1:*:log-group:/credmate/*"
    }
  ]
}
```

### Phase 4: Deploy & Restart

```bash
# Deploy updated docker-compose.prod.yml
./infra/scripts/deploy-direct.sh

# Restart containers to pick up new logging config
docker compose -f docker-compose.prod.yml restart
```

### Phase 5: Validate

```bash
# Check logs are flowing
aws logs tail /credmate/backend --follow --region us-east-1

# Query via Insights
# AWS Console → CloudWatch → Logs Insights → Select log group → Run query
```

---

## Testing

### Validation Steps
1. ✅ Logs appear in CloudWatch within 1 minute
2. ✅ Can query logs via CloudWatch Insights
3. ✅ Retention policy applied (7 days)
4. ✅ No errors in Docker logs about log driver
5. ✅ Cost tracking shows expected volume (~150MB/day)

### Rollback Plan
If CloudWatch logging causes issues:
1. Remove `logging:` sections from docker-compose.prod.yml
2. Redeploy: `./infra/scripts/deploy-direct.sh`
3. Logs revert to Docker default (json-file)

---

## Prevention

### Documentation
- [ ] Update deployment docs with CloudWatch requirement
- [ ] Add CloudWatch validation to pre-deployment checklist
- [ ] Document log retention policy in infra/README.md

### Monitoring
- [ ] Add CloudWatch cost alert (>$10/month)
- [ ] Monitor log ingestion rate (alert if >500MB/day)
- [ ] Dashboard for log volume by service

### Governance
- [ ] Add to deploy-validator skill: Check CloudWatch logging enabled
- [ ] Pre-commit hook: Validate docker-compose.prod.yml has logging config

---

## Related Issues

- **Duplicate CME Creation**: Investigation blocked by missing logs
- **SESSION-20251217-1922-cme-autocreate-investigation**: Triggered this RIS

---

## Implementation Checklist

- [ ] Update docker-compose.prod.yml with awslogs driver
- [ ] Verify EC2 IAM role has CloudWatch permissions
- [ ] Set 7-day retention on log groups
- [ ] Deploy to production
- [ ] Validate logs flowing to CloudWatch
- [ ] Update documentation
- [ ] Add cost monitoring alert
- [ ] Close RIS

---

## Owner

**Assigned To**: Infrastructure / DevOps
**Priority**: HIGH (blocks production debugging)
**ETA**: 30 minutes (simple configuration change)

---

**Resolution Date**: TBD
**Verified By**: TBD