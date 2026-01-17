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

# RIS-049: Lambda Cold Start Optimization

**Date:** 2025-12-31
**Status:** RESOLVED
**Severity:** P1 - HIGH (User-facing performance degradation)
**Category:** Performance / Lambda / Infrastructure
**Resolution Type:** Configuration + Code Fix

---

## Problem Summary

Lambda cold starts taking 10-12 seconds due to VPC + RDS connection overhead, causing slow login experience even after API consolidation (RIS-048).

---

## Impact Assessment

**User Impact:**
- **HIGH:** 10-12 second wait on first login after Lambda idle (15min)
- **MODERATE:** 5-6 second wait after memory optimization
- **LOW:** 1 second wait when Lambda warm

**Business Impact:**
- User abandonment during sign-in
- Poor first impression for new users
- Support tickets about "slow login"

---

## Root Cause Analysis

### 5 Whys Analysis

**Why #1:** Why does login still take 10+ seconds after API consolidation?
- Lambda cold start includes VPC + RDS overhead

**Why #2:** Why does VPC add so much latency?
- Lambda must attach to VPC ENI (Elastic Network Interface) on cold start

**Why #3:** Why does RDS connection take so long?
- First connection requires TLS handshake + auth through VPC

**Why #4:** Why wasn't this caught before?
- RIS-048 focused on API call count, not infrastructure latency

**Why #5:** Why is memory set to 512MB?
- Default configuration, never optimized for performance

**ROOT CAUSE:** Lambda VPC + RDS cold start overhead combined with undersized memory allocation.

---

## Technical Details

### Cold Start Breakdown

| Component | Time | Notes |
|-----------|------|-------|
| Lambda Init | 250-330ms | FastAPI app bootstrap |
| VPC ENI Attach | 3-5s | Network interface setup |
| RDS Connection | 3-5s | TLS + auth + first query |
| SQLAlchemy Init | 1-2s | ORM session creation |
| **Total** | **10-12s** | Before optimization |

### Memory Impact on Cold Start

Lambda CPU is proportional to memory. More memory = more CPU = faster init.

| Memory | Cold Start | Improvement |
|--------|------------|-------------|
| 512 MB | 10-12s | Baseline |
| 1024 MB | 5-6s | 50% faster |
| 2048 MB | 3-4s | Est. 65% faster |

---

## Resolution

### Fix 1: Dockerfile Permission Issue

**Problem:** Lambda failing with `PermissionError: [Errno 13] Permission denied`

**Solution:**
```dockerfile
# Added to infra/lambda/Dockerfile.backend
RUN chmod -R 755 ${LAMBDA_TASK_ROOT}/
```

### Fix 2: Memory Increase

**Command:**
```bash
aws lambda update-function-configuration \
  --function-name credmate-backend-dev \
  --memory-size 1024
```

**Result:** Cold start reduced from 10-12s to 5-6s

---

## Files Changed

| File | Change |
|------|--------|
| `infra/lambda/Dockerfile.backend` | Added chmod for file permissions |

---

## Performance Impact

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Lambda Memory | 512 MB | 1024 MB | 2x |
| Cold Start | 10-12s | 5-6s | **50% faster** |
| Warm Response | ~1s | ~1s | No change |
| Monthly Cost | ~$20 | ~$25 | +$5 |

---

## Additional Optimization Options

### Option 1: Provisioned Concurrency (Recommended)

Keeps Lambda instances warm, eliminating cold starts entirely.

```bash
# Publish version
aws lambda publish-version --function-name credmate-backend-dev

# Set provisioned concurrency
aws lambda put-provisioned-concurrency-config \
  --function-name credmate-backend-dev \
  --qualifier 1 \
  --provisioned-concurrent-executions 2
```

**Cost:** ~$15-30/month for 2 instances
**Benefit:** Consistent sub-second login

### Option 2: Backend Warmer

EventBridge rule to ping Lambda every 5 minutes.

```bash
aws events put-rule --name credmate-backend-warmer \
  --schedule-expression "rate(5 minutes)"
```

**Cost:** Free (Lambda invocations minimal)
**Benefit:** Reduces cold start frequency

### Option 3: RDS Proxy

Managed connection pooling, reduces connection time.

**Cost:** ~$15/month
**Benefit:** Faster DB connections, better scaling

---

## Monitoring

### CloudWatch Metrics to Track

- `Duration` - Total Lambda execution time
- `InitDuration` - Cold start overhead
- Custom `login_timing` metric in logs

### Alert Thresholds

| Metric | Warning | Critical |
|--------|---------|----------|
| Cold start (P95) | > 8s | > 12s |
| Warm login (P95) | > 2s | > 5s |
| Error rate | > 1% | > 5% |

---

## Testing

- [x] Lambda permission fix deployed
- [x] Memory increase applied
- [x] Cold start verified at 5-6s
- [x] Health endpoint working
- [x] Login endpoint working
- [ ] 24h monitoring period

---

## Lessons Learned

1. **Memory affects CPU:** Lambda CPU scales with memory allocation
2. **VPC adds latency:** ENI attachment is the main cold start overhead
3. **Dockerfile permissions matter:** Lambda runtime has strict permission requirements
4. **Consolidation not enough:** Infrastructure optimization equally important as code optimization

---

## Related Documents

- **RIS-048:** Login Response Consolidation (API optimization)
- **Session:** `docs/09-sessions/2025-12-31/session-20251231-002-lambda-cold-start-optimization.md`
- **KB:** `docs/05-kb/performance/kb-lambda-cold-start-optimization.md`

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2025-12-31 | Increase memory to 1024MB | 50% cold start improvement, minimal cost increase |
| 2025-12-31 | Defer provisioned concurrency | Evaluate after monitoring period |
| 2025-12-31 | Add chmod to Dockerfile | Fix Lambda permission errors |

---

**RIS Entry Created:** 2025-12-31
**Resolution Verified:** Cold start reduced to 5-6s
**Production Deployment:** Complete