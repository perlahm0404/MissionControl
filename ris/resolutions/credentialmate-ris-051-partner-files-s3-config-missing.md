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

# RIS-051: Partner File Exchange 503 Error - S3 Configuration Missing

**Date:** 2025-12-30
**Severity:** P0 CRITICAL
**Status:** RESOLVED - Awaiting Browser Verification
**Affected System:** Lambda Production (credmate-backend-dev)
**Impact:** Partner File Exchange completely unavailable (503 errors)

---

## Incident Summary

Partner File Exchange endpoint returned persistent 503 Service Unavailable errors in Lambda production due to missing S3 configuration in AWS Secrets Manager. The S3Service initialization failed during lazy router loading, blocking the entire `/api/v1/partner/files` endpoint.

**Duration:** ~3 hours (investigation + fix + deployment)
**User Impact:** Partner File Exchange page showed "Failed to fetch file list" error
**Resolution:** Added S3 config to combined secret, updated handler.py to load S3 config, deployed to Lambda

---

## Root Cause

### Triple Root Cause

1. **S3Service Fail-Fast Initialization (PRIMARY)**
   - S3Service verifies bucket accessibility in `__init__` (line 129)
   - Raises RuntimeError if bucket verification fails (lines 151-155)
   - This blocks lazy router loading when partner files endpoint is first accessed

2. **Missing S3 Configuration in Lambda Secrets (CRITICAL)**
   - Combined secret (`credmate/production/secrets`) had no `s3` section
   - handler.py didn't load S3 config from secrets (lines 136-144 were missing)
   - S3Service fell back to config.py default: `credmate-documents-dev` (doesn't exist)

3. **Missing PartnerFile Model Import (MINOR)**
   - lazy_app.py didn't import PartnerFile model (line 107)
   - Could cause SQLAlchemy relationship resolution issues
   - NOT the cause of 503 errors (S3Service failure happened first)

### Chain of Failure

```
User → /api/v1/partner/files
  → Lazy router loads api.v1.partner_files module
    → PartnerFileService() instantiated
      → S3Service() with no parameters
        → _verify_bucket_accessible()
          → head_bucket("credmate-documents-dev") fails
            → RuntimeError raised
              → Router loading fails
                → FastAPI returns 503
```

### Why Local Works but Lambda Fails

| Environment | S3_DOCUMENTS_BUCKET | Bucket Exists? | Result |
|-------------|---------------------|----------------|--------|
| Local Docker | `credmate-documents-local` | ✅ (LocalStack) | Works |
| Lambda Production | `credmate-documents-dev` | ❌ (doesn't exist) | 503 Error |

---

## Technical Details

### S3Service Fail-Fast Code

**File:** `apps/backend-api/src/shared/storage/s3_service.py` lines 151-155

```python
raise RuntimeError(
    f"S3 bucket '{self.bucket_name}' is not accessible (error: {error_code}). "
    f"Backend cannot start without valid S3 storage. "
    f"Check bucket name, region ({self.region}), and IAM permissions."
) from e
```

**Design Intent:** Fail early in `main.py` if S3 is misconfigured
**Unintended Consequence:** Blocks lazy router loading in `lazy_app.py`

### Missing S3 Config in handler.py

**File:** `apps/backend-api/src/handler.py` lines 86-137

Handler loaded from secrets:
- ✅ Database (lines 95-107)
- ✅ JWT (lines 109-117)
- ✅ Redis (lines 119-126)
- ✅ Encryption (lines 128-134)
- ❌ **S3 (missing lines 136-144)**

### Secrets Manager Structure Before Fix

```json
{
  "database": {
    "username": "credmate_admin",
    "password": "...",
    "host": "prod-credmate-db.cm1ksgqm0c00.us-east-1.rds.amazonaws.com",
    "port": "5432",
    "database": "credmate"
  },
  "jwt": {
    "secret_key": "credmate-jwt-secret-prod-2025",
    "algorithm": "HS256"
  },
  "redis": {
    "host": "redis",
    "port": "6379",
    "password": "credmate_redis_prod",
    "db": "0"
  },
  "encryption": {
    "master_key": "oowg1EvF5l56NvrILl5qpS85GQiZqWmfHBlDhGzf/eA="
  }
  // NO "s3" section
}
```

---

## Resolution

### Fix #1: Add S3 Configuration to Secrets Manager

**Action:** Updated `credmate/production/secrets` in AWS Secrets Manager

```bash
aws secretsmanager get-secret-value \
  --secret-id credmate/production/secrets \
  --query SecretString --output text > /tmp/secret.json

cat /tmp/secret.json | jq '. + {"s3": {"bucket_name": "credmate-deployment-artifacts", "region": "us-east-1"}}' > /tmp/secret_updated.json

aws secretsmanager update-secret \
  --secret-id credmate/production/secrets \
  --secret-string file:///tmp/secret_updated.json
```

**Result:**
- Secret version: `a3f2f1f7-a766-49e1-a2d0-38ed3d37ac4b`
- S3 section added with `credmate-deployment-artifacts` bucket

### Fix #2: Update handler.py to Load S3 Config

**File:** `apps/backend-api/src/handler.py`

**Added lines 136-144:**
```python
# Extract S3 config (if present)
s3_secret = secrets.get('s3', {})
if s3_secret:
    os.environ['S3_DOCUMENTS_BUCKET'] = s3_secret.get('bucket_name', '')
    # AWS_REGION already set, but override if S3 has different region
    if 'region' in s3_secret and s3_secret['region']:
        os.environ['AWS_REGION'] = s3_secret['region']
    print(f"[DIAGNOSTIC] S3 bucket set to: {s3_secret.get('bucket_name')}")
    logger.info(f"S3 config loaded from combined secret: {s3_secret.get('bucket_name')}")
```

### Fix #3: Update config.py for Environment Variable

**File:** `apps/backend-api/src/shared/infrastructure/config.py`

**Line 83 changed:**
```python
# Before:
s3_documents_bucket: str = Field(default="credmate-documents-dev")

# After:
s3_documents_bucket: str = Field(default_factory=lambda: os.getenv("S3_DOCUMENTS_BUCKET", "credmate-documents-dev"))
```

### Fix #4: Add PartnerFile Model Import

**File:** `apps/backend-api/src/lazy_app.py`

**Line 107 added:**
```python
from contexts.partner_files.models import PartnerFile, FileDirection, FileStatus  # noqa: F401
```

### Fix #5: Update Lambda Environment

**Action:** Set `COMBINED_SECRET_ARN` in Lambda configuration

```bash
aws lambda update-function-configuration \
  --function-name credmate-backend-dev \
  --environment "Variables={
    COMBINED_SECRET_ARN=arn:aws:secretsmanager:us-east-1:051826703172:secret:credmate/production/secrets-Pc35aq,
    CORS_ALLOWED_ORIGINS=https://credentialmate.com;https://www.credentialmate.com;https://d3juzrt692pzvc.cloudfront.net,
    IS_LAMBDA=true,
    APP_ENV=production,
    ENVIRONMENT=production
  }"
```

**Result:** Lambda now uses combined secret (1 API call instead of 4)

---

## Verification

### CloudWatch Logs After Fix

```
[DIAGNOSTIC] Fetching COMBINED secret: arn:aws:secretsmanager:us-east-1:051826703172:secret:credmate/production/secrets-Pc35aq
[DIAGNOSTIC] COMBINED secret fetched successfully
[DIAGNOSTIC] DATABASE_URL constructed from combined secret
[DIAGNOSTIC] JWT_SECRET_KEY set from combined secret
[DIAGNOSTIC] REDIS config set from combined secret
[DIAGNOSTIC] ENCRYPTION config set from combined secret
[DIAGNOSTIC] S3 bucket set to: credmate-deployment-artifacts
[DIAGNOSTIC] All secrets loaded from combined secret (1 API call)
```

### API Endpoint Testing

**Health endpoint:**
```bash
$ curl https://t863p0a5yf.execute-api.us-east-1.amazonaws.com/health
{"status":"healthy","mode":"lazy"}
```

**Partner files endpoint:**
```bash
$ curl https://t863p0a5yf.execute-api.us-east-1.amazonaws.com/api/v1/partner/files
{"detail":{"error":"UnauthorizedError","message":"Authentication required","trace_id":"f773b208-d5dc-43fd-9d5e-5a3432796805"}}
```

**HTTP Status:** 401 Unauthorized (was 503 Service Unavailable before fix)

✅ **Endpoint now returns 401 (auth required) instead of 503 (service error)**

---

## Impact Assessment

### Before Fix

- ❌ Partner File Exchange completely unavailable
- ❌ All requests to `/api/v1/partner/files/*` returned 503
- ❌ Browser showed "Failed to fetch file list" error
- ❌ S3Service RuntimeError in CloudWatch logs on every access attempt

### After Fix

- ✅ Endpoint returns 401 (Unauthorized) for unauthenticated requests
- ✅ S3 config loading from combined secret
- ✅ No S3 bucket access errors in CloudWatch logs
- ⏳ Browser verification pending (user unable to log in due to outage)

---

## Prevention Measures

### Immediate

1. **Add S3 Config to Lambda Deployment Checklist**
   ```bash
   # Pre-deployment verification
   aws secretsmanager get-secret-value \
     --secret-id credmate/production/secrets \
     --query SecretString --output text | jq '.s3'

   # Expected output:
   # {
   #   "bucket_name": "credmate-deployment-artifacts",
   #   "region": "us-east-1"
   # }
   ```

2. **Update Lambda Smoke Test**
   - Verify S3_DOCUMENTS_BUCKET environment variable set
   - Test S3Service initialization succeeds
   - Check partner files endpoint returns 401 (not 503)

3. **Document Combined Secret Structure**
   - Required sections: database, jwt, redis, encryption, **s3**
   - Add to `docs/05-kb/infrastructure/kb-lambda-secrets-manager.md`

### Future

1. **Lazy S3 Bucket Verification (ARCHITECTURAL)**
   - Move `_verify_bucket_accessible()` from `__init__` to first upload/download
   - Prevents blocking endpoint loading
   - Fail on actual upload attempt, not initialization

2. **S3 Config Validation in CI/CD**
   - Pre-deployment check: S3 section exists in secrets
   - Pre-deployment check: S3_DOCUMENTS_BUCKET matches production bucket
   - Block deployment if S3 config missing

3. **CloudWatch Alerts**
   - Alert on "S3 bucket NOT accessible" log pattern
   - Alert on RuntimeError in Lambda logs
   - Slack notification for production S3 issues

---

## Related Incidents

- **RIS-050:** Lambda lazy_app regression (CME models) - Similar pattern of missing imports in lazy_app.py
- **Session 20251230-004:** Lambda lazy app regression - GZipMiddleware missing
- **Session 20251230-005:** Notifications system completion - Related Lambda deployment

---

## Files Modified

| File | Change | Commit |
|------|--------|--------|
| `apps/backend-api/src/handler.py` | Added S3 config loading (lines 136-144) | 65a4266 |
| `apps/backend-api/src/shared/infrastructure/config.py` | S3 bucket from env var (line 83) | 65a4266 |
| `apps/backend-api/src/lazy_app.py` | Added PartnerFile import (line 107) | 65a4266 |
| AWS Secrets Manager | Added s3 section | Infrastructure |
| Lambda Environment | Set COMBINED_SECRET_ARN | Infrastructure |

---

## Lessons Learned

1. **Infrastructure gaps can hide behind code issues** - Missing S3 config in secrets was the real blocker, not missing imports
2. **Fail-fast patterns need context awareness** - S3Service fail-fast is appropriate for main.py but blocks lazy router loading
3. **Combined secrets reduce operational complexity** - 1 API call vs 4, easier to manage, fewer failure points
4. **CloudWatch log monitoring is critical** - S3 error message would have revealed root cause immediately
5. **Lambda smoke tests prevent production surprises** - Test service initialization before deploying
6. **Web research validates patterns** - FastAPI + Lambda 503 errors from initialization failures is a known pattern

---

## References

**Web Research:**
- [API + Lambda has #503 error 20% of the time | AWS re:Post](https://repost.aws/questions/QUZcPTP5TGSCq9pX24fAdrFg/api-lambda-has-503-error-20-of-the-time)
- [Lazy loading of SQLAlchemy AsyncAttrs causes MissingGreenlet exception](https://github.com/fastapi/fastapi/discussions/13125)
- [Deploying FastAPI on Serverless with Cold Start Optimization](https://medium.com/@hadiyolworld007/deploying-fastapi-on-serverless-with-cold-start-optimization-a5b84f68fe6e)

**Internal Documentation:**
- Session: session-20251230-006-partner-files-503-s3-config.md
- RIS-050: Lambda lazy_app regression (CME models)
- Runbook: docs/05-kb/infrastructure/kb-lazy-app-maintenance.md

---

**Resolution Date:** 2025-12-30
**Resolved By:** Claude Code (AI Agent)
**Status:** RESOLVED - Awaiting browser verification by user