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

# RIS-050: Lambda Lazy App Regression - Dual Entry Point Fragility

**Date:** 2025-12-30
**Status:** RESOLVED
**Severity:** P0 - CRITICAL (Complete Production Outage)
**Category:** Deployment / Architecture
**Resolution Type:** Emergency Fix + Architectural Hardening Required

---

## Executive Summary

Production login completely broken due to missing GZipMiddleware in `lazy_app.py`. Root cause: CREDMATE has dual entry points (main.py + lazy_app.py) without synchronization enforcement.

**Impact:** 100% of users unable to log in for ~37 minutes

**Fix:** Added GZipMiddleware to lazy_app.py (3 commits deployed)

**Critical Finding:** Dual entry point architecture is FRAGILE and MUST be hardened

---

## Problem Statement

### Symptoms

**User Impact:**
- All login attempts return "Service Unavailable" (502)
- Dashboard completely inaccessible
- JWT token generation failing

**Technical Observations:**
- Lambda timing out with 60+ second initialization
- ImportError: `cannot import name 'CMEActivityTopic'`
- SQLAlchemy: `failed to locate a name ('CMEActivity')`
- Missing GZipMiddleware in Lambda deployment

### Impact Assessment

| Metric | Value |
|--------|-------|
| Users affected | 100% (complete outage) |
| Duration | ~37 minutes |
| Business impact | CRITICAL - no access to platform |
| Revenue impact | All user sessions blocked |
| Data loss | None |

---

## Root Cause Analysis

### The Dual Entry Point Problem

CREDMATE backend has **TWO separate application entry points** that must be kept in sync MANUALLY:

```
1. apps/backend-api/src/main.py
   - Used by: Local development, EC2 deployment
   - Loads: All 30 routers eagerly at startup
   - Middleware: Full stack (CORS, GZip, Tracing, Audit)

2. apps/backend-api/src/lazy_app.py
   - Used by: AWS Lambda ONLY (via handler.py)
   - Loads: Routers on-demand (lazy loading)
   - Middleware: MUST mirror main.py (NO ENFORCEMENT)
```

### What Happened

**RIS-049 (commit 7feba3f)** added GZipMiddleware to `main.py`:
```python
# main.py - UPDATED ✓
app.add_middleware(GZipMiddleware, minimum_size=500)
```

**BUT:** Did NOT update `lazy_app.py`:
```python
# lazy_app.py - FORGOTTEN ✗
# NO GZipMiddleware!
```

**Result:**
- Local testing worked (uses main.py)
- Lambda deployment broke (uses lazy_app.py)
- Production completely down

### Why This Happened

1. **No Documentation:** RIS-049 didn't mention lazy_app.py exists
2. **No Automation:** No pre-commit check for parity
3. **No Testing:** Lambda not tested before production deployment
4. **Implicit Knowledge:** "Lambda uses lazy_app" not written anywhere
5. **No Checklist:** "Did you update lazy_app too?" not in workflow

### 5 Whys

**Why #1:** Login failed → Lambda timing out
**Why #2:** Lambda timeout → Missing GZipMiddleware + model import errors
**Why #3:** Missing from lazy_app → Developer only updated main.py
**Why #4:** Only updated main.py → Didn't know lazy_app exists
**Why #5:** Didn't know → **NO ENFORCEMENT of dual entry point parity**

**ROOT CAUSE:** Dual entry point architecture without synchronization enforcement

---

## Solution Implementation

### Emergency Fixes (Deployed)

**Commit 2d7e95e:** Add GZipMiddleware to lazy_app.py
```python
from fastapi.middleware.gzip import GZipMiddleware
app.add_middleware(GZipMiddleware, minimum_size=500)
print("[LAZY_APP] GZipMiddleware enabled (minimum_size=500)")
```

**Commit 69dab2d:** Add CME model imports
```python
from contexts.cme.models import CMEActivity, CMETopic  # noqa: F401
```

**Commit ac92fc7:** Fix Lambda handler configuration
```bash
aws lambda update-function-configuration \
  --function-name credmate-backend-dev \
  --image-config 'Command=["handler.lambda_handler"]'
```

**Deployment:**
- Image: `credmate-backend:ac92fc7`
- Time: 2025-12-30 23:37 UTC
- Status: ✅ VERIFIED - Login working

---

## Architectural Hardening (REQUIRED)

### P0: BLOCKING (Must Deploy Within 24h)

#### 1. Automated Parity Check Hook

**File:** `.claude/hooks/scripts/lazy-app-parity-check.py`

**Purpose:** BLOCK commits if main.py and lazy_app.py diverge

**Implementation:**
```python
#!/usr/bin/env python3
"""
Verify lazy_app.py has same middleware as main.py.

BLOCKS commits if middleware added to main.py but not lazy_app.py.
"""

import re
import sys
from pathlib import Path

def check_middleware_parity():
    main_path = Path("apps/backend-api/src/main.py")
    lazy_path = Path("apps/backend-api/src/lazy_app.py")

    main_middleware = extract_middleware(main_path.read_text())
    lazy_middleware = extract_middleware(lazy_path.read_text())

    missing = set(main_middleware) - set(lazy_middleware)

    if missing:
        print("❌ LAZY APP PARITY CHECK FAILED")
        print(f"\nMiddleware in main.py but NOT in lazy_app.py:")
        for m in missing:
            print(f"  - {m}")
        print(f"\nYou MUST add these to: {lazy_path}")
        print("Lambda uses lazy_app.py - missing middleware breaks production!")
        sys.exit(1)

    print("✓ Lazy app parity check passed")

def extract_middleware(content):
    """Extract all app.add_middleware() calls."""
    pattern = r'app\.add_middleware\((\w+)'
    return re.findall(pattern, content)

if __name__ == "__main__":
    check_middleware_parity()
```

**Register:**
```json
// .claude/settings.local.json
{
  "hooks": {
    "PreCommit": [
      ".claude/hooks/scripts/lazy-app-parity-check.py"
    ]
  }
}
```

**Impact:** Prevents exact recurrence of this incident

---

#### 2. Pre-Deployment Lambda Smoke Test

**File:** `.claude/skills/pre-deploy-lambda-test.sh`

**Purpose:** Test Lambda locally before production push

**Implementation:**
```bash
#!/bin/bash
set -e

echo "🧪 Lambda Pre-Deployment Smoke Test"
echo "===================================="

# Build Lambda image
TAG=$(git rev-parse HEAD | head -c 7)
echo "Building Lambda image: $TAG"
docker build -t credmate-backend-test:$TAG -f infra/lambda/Dockerfile.backend .

# Run Lambda Runtime Interface Emulator
echo "Starting Lambda container..."
docker run -d -p 9000:8080 \
  -e DATABASE_URL="${TEST_DATABASE_URL}" \
  -e JWT_SECRET_KEY="test-secret" \
  -e REDIS_HOST="localhost" \
  -e CORS_ALLOWED_ORIGINS="http://localhost:3000" \
  --name lambda-smoke-test \
  credmate-backend-test:$TAG

sleep 5

# Test 1: Health check
echo "Test 1: Health check..."
HEALTH_RESPONSE=$(curl -s -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" \
  -d '{"httpMethod":"GET","path":"/health"}')

if echo "$HEALTH_RESPONSE" | grep -q '"status":"healthy"'; then
  echo "✓ Health check passed"
else
  echo "❌ Health check failed"
  docker logs lambda-smoke-test
  docker rm -f lambda-smoke-test
  exit 1
fi

# Test 2: GZipMiddleware active
echo "Test 2: GZipMiddleware..."
docker logs lambda-smoke-test 2>&1 | grep -q "LAZY_APP.*GZipMiddleware enabled"
if [ $? -eq 0 ]; then
  echo "✓ GZipMiddleware confirmed"
else
  echo "❌ GZipMiddleware missing"
  docker logs lambda-smoke-test
  docker rm -f lambda-smoke-test
  exit 1
fi

# Cleanup
docker rm -f lambda-smoke-test

echo "===================================="
echo "✅ ALL SMOKE TESTS PASSED"
echo "Safe to deploy to production"
```

**Add to deploy-to-production skill:**
```bash
# Before ECR push:
bash .claude/skills/pre-deploy-lambda-test.sh || {
  echo "❌ Lambda smoke test failed - BLOCKING deployment"
  exit 1
}
```

---

### P1: CRITICAL (Must Deploy Within 1 Week)

#### 3. Single Entry Point Architecture

**Problem:** Dual entry points inherently fragile

**Solution:** Deprecate main.py, use lazy_app.py everywhere

**Implementation:**
```python
# apps/backend-api/src/main.py (DEPRECATED)
"""
DEPRECATED: This file redirects to lazy_app.py.

Reason: Maintaining two entry points (main.py + lazy_app.py) is error-prone.
All environments now use lazy_app.py for consistency.

History:
- Pre-2025-12-30: main.py used for local/EC2, lazy_app.py for Lambda
- 2025-12-30: RIS-050 incident - forgot to update lazy_app.py
- Post-2025-12-30: Single entry point (lazy_app.py) for all environments

Migration:
- docker-compose.yml: uvicorn lazy_app:app
- Local dev: uvicorn lazy_app:app --reload
- Lambda: handler.py imports lazy_app
"""
from lazy_app import app

__all__ = ["app"]
```

**Update docker-compose.yml:**
```yaml
backend:
  command: uvicorn lazy_app:app --host 0.0.0.0 --port 8000 --reload
```

**Timeline:**
- Day 1: Create redirect in main.py
- Day 2-7: Test local dev with lazy_app
- Week 2: Remove main.py entirely

**Impact:** Eliminates dual entry point fragility 100%

---

#### 4. Model Import Validation

**Problem:** Missing imports only fail at runtime

**Solution:** Startup validation

**Implementation:**
```python
# apps/backend-api/src/lazy_app.py

def validate_sqlalchemy_imports():
    """
    Verify all models referenced in relationships are imported.

    Prevents: sqlalchemy.exc.InvalidRequestError: failed to locate a name
    """
    from sqlalchemy import inspect
    from shared.domain.base import Base

    missing = []
    for mapper in Base.registry.mappers:
        for rel in mapper.relationships:
            target_class = rel.mapper.class_.__name__
            if target_class not in globals():
                missing.append(
                    f"{mapper.class_.__name__} → {target_class}"
                )

    if missing:
        print("❌ MODEL IMPORT VALIDATION FAILED")
        print("Missing imports for SQLAlchemy relationships:")
        for m in missing:
            print(f"  - {m}")
        raise ImportError("Fix model imports in lazy_app.py")

    print("✓ Model import validation passed")

# Run after model imports
print("[LAZY_APP] Loading models...")
from contexts.auth.models import ...
from contexts.cme.models import CMEActivity, CMETopic
print("[LAZY_APP] Models loaded")

validate_sqlalchemy_imports()  # BLOCKS startup if invalid
```

---

## Deployment Timeline

| Time (UTC) | Event | Status |
|------------|-------|--------|
| 23:01 | User reports login broken | Incident start |
| 23:05 | Investigation: Lambda timeout identified | Diagnosing |
| 23:20 | Root cause: Missing GZipMiddleware in lazy_app | Found |
| 23:25 | Fix 1: GZipMiddleware added (2d7e95e) | Deployed |
| 23:30 | Fix 2: CME models added (69dab2d) | Deployed |
| 23:37 | Fix 3: Handler config + import fix (ac92fc7) | Deployed |
| 23:38 | Verification: Login working | ✅ RESOLVED |

**Total Outage:** 37 minutes
**MTTR (Mean Time To Repair):** 37 minutes
**MTTD (Mean Time To Detect):** <1 minute (user report)

---

## Verification & Testing

### Production Verification

```bash
# Health check
curl https://t863p0a5yf.execute-api.us-east-1.amazonaws.com/health
# Output: {"status":"healthy","mode":"lazy"}

# Login test
curl -X POST https://t863p0a5yf.execute-api.us-east-1.amazonaws.com/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"Real1@test.com","password":"Test1234"}'
# Output: {"access_token":"eyJ...","refresh_token":"eyJ..."}

# CloudWatch logs
aws logs tail /aws/lambda/credmate-backend-dev --since 5m | grep LAZY_APP
# Output: [LAZY_APP] GZipMiddleware enabled (minimum_size=500)
```

**Status:** ✅ All verifications passed

---

## Lessons Learned

### What Went Well

1. Fast diagnosis (logs clearly showed issue)
2. Iterative fixes (3 commits in 40 minutes)
3. Comprehensive investigation (found systemic issue)

### What Went Wrong

1. No pre-deployment Lambda testing
2. No documentation that Lambda uses lazy_app.py
3. No automated parity checks
4. RIS-049 didn't mention updating lazy_app.py

### Root Cause: Process Gap

**Missing from RIS-049:**
- [ ] Checklist: "Did you update lazy_app.py?"
- [ ] Pre-deployment test: Lambda smoke test
- [ ] Documentation: Which file does Lambda use?

---

## Prevention Strategy

### Immediate Actions (P0)

1. ✅ Fix deployed (login working)
2. ✅ RIS documented
3. ⏳ Implement parity check hook (24h)
4. ⏳ Implement Lambda smoke test (24h)

### Short-term Actions (P1)

1. ⏳ Deprecate main.py (1 week)
2. ⏳ Add model import validation (1 week)
3. ⏳ Lambda config as code (Terraform)

### Long-term Actions (P2)

1. ⏳ Lambda integration test suite
2. ⏳ Deployment runbook with checklists
3. ⏳ Audit all dual-file patterns

---

## Files Modified

**Emergency Fixes:**
- `apps/backend-api/src/lazy_app.py` (+10 lines)

**Commits:**
- `2d7e95e`: GZipMiddleware
- `69dab2d`: CME models
- `ac92fc7`: Import fix + handler config

**To Be Created (P0):**
- `.claude/hooks/scripts/lazy-app-parity-check.py`
- `.claude/skills/pre-deploy-lambda-test.sh`

---

## Related Documentation

**RIS:**
- RIS-050: This incident
- RIS-049: Dashboard optimization (introduced regression)
- RIS-047: Lazy loading architecture (created lazy_app.py)

**KB:**
- KB-LAZY-APP-MAINTENANCE: Parity maintenance guide
- KB-LAMBDA-DEPLOYMENT: Deployment best practices

**Sessions:**
- session-20251230-004-lambda-lazy-app-regression.md

---

## Action Items

**Critical (24h):**
- [ ] Implement lazy-app-parity-check.py hook
- [ ] Implement pre-deploy-lambda-test.sh
- [ ] Update RIS-049 with lazy_app note

**High (1 week):**
- [ ] Deprecate main.py
- [ ] Add model import validation
- [ ] Move Lambda config to Terraform

**Medium (1 month):**
- [ ] Lambda integration tests in CI
- [ ] Deployment runbook
- [ ] Audit dual-file patterns

---

**Resolution:** COMPLETE - Login restored, hardening roadmap defined

**Next Steps:** Implement P0 automation (parity check + smoke test) within 24h to prevent recurrence

---

**Authored by:** Claude Sonnet 4.5
**Reviewed by:** (pending)
**Approved by:** TMAC (emergency deployment authorized)