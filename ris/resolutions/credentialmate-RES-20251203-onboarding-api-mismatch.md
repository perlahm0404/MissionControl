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

# RIS Resolution: Onboarding API Endpoint Mismatch

**ID:** RES-20251203-onboarding-api-mismatch
**Date:** 2025-12-03
**Severity:** High
**Category:** API Integration
**Status:** Resolved

---

## Problem

Onboarding wizard "Complete Setup" button did nothing - data was not saving to backend.

## Root Cause

Frontend was calling incorrect API endpoints:
- Called `/api/v1/dea` but backend mounts at `/api/v1/dea-registrations`
- Called `/api/v1/csr` but backend mounts at `/api/v1/csrs`
- Called `PATCH /api/v1/providers/me` but endpoint didn't exist

## Solution

1. **Fixed frontend API URLs** in `apps/frontend-web/src/app/onboarding/page.tsx`:
   ```typescript
   // Before
   '/api/v1/dea'
   '/api/v1/csr'

   // After
   '/api/v1/dea-registrations'
   '/api/v1/csrs'
   ```

2. **Created missing PATCH endpoint** in `apps/backend-api/src/contexts/provider/api/provider_endpoints.py`:
   - Added `ProviderSelfUpdateRequest` schema
   - Added `PATCH /api/v1/providers/me` endpoint
   - Allows NPI update only when current NPI starts with "TEMP"

## Verification

```bash
# Check backend routes in main.py
grep -n "prefix=" apps/backend-api/src/main.py | grep -E "dea|csr|license"
# Output shows actual prefixes: /api/v1/dea-registrations, /api/v1/csrs, /api/v1/licenses
```

## Prevention

- Always verify API endpoint paths match between frontend and backend
- Check `main.py` router prefixes when adding new API calls
- Add integration tests for onboarding flow

## Related Files

- `apps/frontend-web/src/app/onboarding/page.tsx`
- `apps/backend-api/src/main.py` (router prefixes)
- `apps/backend-api/src/contexts/provider/api/provider_endpoints.py`

## Tags

`api` `onboarding` `endpoint-mismatch` `epic-1`