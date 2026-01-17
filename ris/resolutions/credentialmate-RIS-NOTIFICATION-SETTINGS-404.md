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

# RIS-NOTIFICATION-SETTINGS-404: Notification Settings 404 Error

**RIS ID**: RIS-NOTIFICATION-SETTINGS-404
**Created**: 2025-12-17
**Severity**: HIGH
**Status**: RESOLVED
**Category**: Bug Fix

---

## Issue Summary

Notification settings page (`/dashboard/notifications/settings`) returned 404 errors despite 6 fix attempts over 3 hours. Root cause was dual bug: backend repository attribute didn't exist (`pref_repo.model`) AND frontend used wrong localStorage key for auth token.

---

## Root Causes

### Backend Bug (CRITICAL)
**File**: `apps/backend-api/src/contexts/notifications/api/preference_endpoints.py:130`

```python
# BROKEN
db.query(pref_repo.model).filter_by(user_id=current_user.id).delete()
```

**Problem**: `PreferenceRepository` has no `.model` attribute → `AttributeError` at runtime.

### Frontend Bug (CRITICAL)
**File**: `apps/frontend-web/src/app/dashboard/notifications/settings/page.tsx`

```typescript
// BROKEN
localStorage.getItem('access_token')  // Wrong key

// CORRECT
authStorage.getAccessToken()  // Uses 'credmate_access_token'
```

**Problem**: Token stored as `'credmate_access_token'` but page read `'access_token'` → 401 errors.

---

## Resolution

### Backend Fix
```python
# Replace manual implementation with repository method
preferences = pref_repo.reset_to_defaults(current_user.id)
```

### Frontend Fix
```typescript
import { authStorage } from '@/lib/auth'

// All fetch calls
'Authorization': `Bearer ${authStorage.getAccessToken()}`
```

---

## Investigation Methodology

**What worked**: 3 parallel explore agents traced complete flows

| Agent | Focus | Finding |
|-------|-------|---------|
| Backend Tracer | Router → Endpoint → Repository → Model | `pref_repo.model` doesn't exist |
| Frontend Tracer | API_BASE_URL → Fetch → Auth | Token key mismatch |
| Pattern Comparer | Working vs Broken | Direct model imports work |

**Time**: 30 min investigation vs 3h of failed symptom-based fixes.

---

## Preventive Measures

### 1. Pre-Commit Hooks (NEW)
- `validate-auth-token-usage.py` - Block direct `localStorage.getItem('*token*')`
- `validate-repository-usage.py` - Block `*_repo.model` usage

### 2. Coding Standards (UPDATED)
- **Auth tokens**: MUST use `authStorage.getAccessToken()`, never direct localStorage
- **Repositories**: MUST use methods, never `.model` attribute

### 3. Debugging Checklist (NEW)
Before ANY bug fix:
- [ ] Check backend logs for actual error
- [ ] Inspect browser Network tab
- [ ] Test endpoint with curl
- [ ] Verify database state
- [ ] Find working comparison
- [ ] Read actual code (don't assume)

---

## Files Changed

- `apps/backend-api/src/contexts/notifications/api/preference_endpoints.py` - Fixed line 130 bug
- `apps/frontend-web/src/app/dashboard/notifications/settings/page.tsx` - Fixed auth token key

---

## Lessons Learned

1. **Evidence before solutions**: Diagnose BEFORE prescribing
2. **Parallel exploration**: 3 agents > 6 sequential attempts
3. **Read code, don't assume**: Repository had no `.model` attribute
4. **Check actual keys**: Token stored as `credmate_access_token`, not `access_token`
5. **Escalate after 2 failures**: Don't repeat failing methodology

---

## Related Documentation

- **Postmortem**: `sessions/20251216/POSTMORTEM-20251217-0000-notification-settings-404.md`
- **Session**: `sessions/20251216/SESSION-20251216-2055-notification-settings-404.md`
- **KB-009**: Debugging Complex Issues
- **KB-010**: Auth Token Patterns

---

## Git Commit

```
fix(notifications): resolve 404 error on notification settings page

Root causes identified and fixed:
1. Backend: pref_repo.model attribute didn't exist (line 130)
2. Frontend: Wrong localStorage key for auth token

Commit: 94b7c69
```

---

## Status

**RESOLVED** - 2025-12-17 00:15

Both backend and frontend bugs fixed. Notification settings page now loads correctly with proper auth.