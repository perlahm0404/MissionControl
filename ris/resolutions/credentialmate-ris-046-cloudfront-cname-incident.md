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

# RIS-046: CloudFront CNAME Misconfiguration Incident

**ID:** RIS-046
**Status:** RESOLVED
**Severity:** P1 (Production Down)
**Date Created:** 2025-12-30
**Date Resolved:** 2025-12-30
**Resolution Time:** 45 minutes

---

## Incident Summary

Production login was broken after database reseed. Initial assumption was database/authentication issue, but actual root cause was CloudFront CNAME misconfiguration.

## Timeline

| Time | Event |
|------|-------|
| T+0 | User reports login not working after DB reseed |
| T+15 | Database investigation shows user exists, is_active=true |
| T+20 | Direct API test reveals backend works perfectly |
| T+22 | `curl -I https://credentialmate.com` returns 403 |
| T+25 | CloudFront investigation reveals CNAME mismatch |
| T+35 | Removed aliases from canary distribution |
| T+40 | Added aliases to production distribution |
| T+45 | Site verified working, login functional |

## Root Cause Analysis

### The Problem
Route53 DNS pointed `credentialmate.com` to CloudFront distribution `EEICV00FJ3IRJ`, but the CNAME aliases (`credentialmate.com`, `www.credentialmate.com`) were configured on a different distribution (`E150YA2CG0NJUL`).

### Why It Happened
1. SST deployment created a new production CloudFront distribution
2. The new distribution had no CNAME aliases configured
3. The old canary distribution still had all the aliases
4. DNS was updated to point to new distribution
5. CloudFront rejected requests because domain wasn't in its alias list

### Contributing Factors
- SST `sst.config.ts` only configured custom domain for canary stage, not production
- No automated verification that CloudFront aliases match DNS
- Assumption that "login broken after DB change" = database issue

## Impact

| Metric | Value |
|--------|-------|
| Duration | ~45 minutes |
| Users Affected | All production users |
| Services Affected | Frontend (credentialmate.com) |
| Data Loss | None |
| Revenue Impact | Unknown |

## Resolution Steps

### Immediate Fix
```bash
# 1. Remove aliases from old distribution
aws cloudfront update-distribution --id E150YA2CG0NJUL \
  --if-match EFS3EUH4LIIH2 \
  --distribution-config file:///tmp/cf-canary-update.json

# 2. Add aliases to production distribution
aws cloudfront update-distribution --id EEICV00FJ3IRJ \
  --if-match ETVOH9J5XGVS3 \
  --distribution-config file:///tmp/cf-prod-update.json
```

### Verification
```bash
curl -I https://credentialmate.com
# HTTP/2 200

curl -X POST https://credentialmate.com/api/v1/auth/login ...
# Returns JWT tokens (via backend proxy)
```

## Lessons Learned

### What Went Well
1. Direct API testing quickly isolated the problem
2. CloudFront CLI commands worked smoothly
3. No data loss or corruption

### What Went Poorly
1. 15 minutes wasted investigating database (wrong assumption)
2. No pre-deploy check for CloudFront alias configuration
3. SST config didn't include production custom domain

### Corrective Actions

| Action | Owner | Due Date | Status |
|--------|-------|----------|--------|
| Add HTTP check to login troubleshooting flow | Documented | 2025-12-30 | DONE |
| Create KB for CloudFront CNAME management | Documented | 2025-12-30 | DONE |
| Add hot pattern for "login broken = check infra first" | Documented | 2025-12-30 | DONE |
| Update SST config to include production domain | TODO | 2025-01-05 | PENDING |
| Add pre-deploy CloudFront alias verification | TODO | 2025-01-10 | PENDING |

## Prevention Measures

### Short-term
- Added Hot Pattern #12: "Login broken" triggers HTTP check first
- Added Hot Pattern #13: CloudFront CNAME migration procedure
- Created KB articles for reference

### Long-term
1. **Automated Verification:** Add pre-deploy script to verify CloudFront aliases match Route53
2. **SST Config Fix:** Update `sst.config.ts` to configure custom domain for production stage
3. **Monitoring:** Add CloudWatch alarm for 403 responses on production domain

## Related Documents

- [KB: CloudFront CNAME Management](../05-kb/infrastructure/kb-cloudfront-cname-management.md)
- [KB: Login Troubleshooting Guide](../05-kb/infrastructure/kb-login-troubleshooting-guide.md)
- [Session: CloudFront Login Fix](../09-sessions/2025-12-30/session-20251230-001-cloudfront-login-fix.md)
- [Hot Patterns #12, #13](../../.claude/memory/hot-patterns.md)

---

## Appendix: Infrastructure State

### Before Incident
| Distribution | Aliases |
|--------------|---------|
| EEICV00FJ3IRJ (prod) | None |
| E150YA2CG0NJUL (canary) | credentialmate.com, www, v1, canary |

### After Resolution
| Distribution | Aliases |
|--------------|---------|
| EEICV00FJ3IRJ (prod) | credentialmate.com, www, v1 |
| E150YA2CG0NJUL (canary) | canary.credentialmate.com |

### Key Commands for Future Reference
```bash
# Check which distribution has a CNAME
aws cloudfront list-distributions --query \
  "DistributionList.Items[?Aliases.Items[?contains(@,'credentialmate.com')]].{Id:Id,Domain:DomainName}"

# Get distribution config
aws cloudfront get-distribution-config --id DIST_ID

# Update distribution (requires ETag for optimistic locking)
aws cloudfront update-distribution --id DIST_ID --if-match ETAG --distribution-config file://config.json
```