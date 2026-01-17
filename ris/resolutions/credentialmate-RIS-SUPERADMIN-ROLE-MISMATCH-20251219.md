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

# RIS-SUPERADMIN-ROLE-MISMATCH-20251219

**Date:** 2025-12-19
**Severity:** HIGH
**Status:** ✅ RESOLVED
**Category:** Authentication & Authorization
**Lane:** Backend + Frontend

---

## Incident Summary

Super admin users were unable to access the Medical License page, receiving "Failed to load your credentials" error. The page attempted to load provider-only endpoints, causing 403 Forbidden errors and poor UX.

**User Impact:**
- Super admin users saw generic error instead of admin license view
- No access to organization-wide license management
- Confusing error messages (CORS/500 errors shown in console)

**Affected Users:**
- All users with role `super_admin`
- Also affected: `org_admin`, `admin` (if they existed)

---

## Root Cause Analysis

### Primary Issue: Role Enum Mismatch

**Backend Code** (`apps/backend-api/src/api/v1/admin/licenses.py:208`):
```python
if current_user.role not in [UserRole.ADMIN, UserRole.ORG_ADMIN, UserRole.SUPER_ADMIN]:
    raise HTTPException(status_code=403, detail="Admin access required")
```

**Actual UserRole Enum** (`contexts/auth/models/user.py:30-36`):
```python
class UserRole(enum.Enum):
    SUPER_ADMIN = "super_admin"
    ORG_ADMIN = "org_admin"
    PRACTICE_ADMIN = "practice_admin"
    CREDENTIALING_COORDINATOR = "credentialing_coordinator"
    PROVIDER = "provider"
    READ_ONLY = "read_only"
```

❌ **Problem:** `UserRole.ADMIN` does not exist in the enum!

**Result:** `AttributeError: ADMIN` when super_admin user accessed `/api/v1/admin/licenses/matrix`

### Secondary Issue: Frontend Role Check Incomplete

**Frontend Code** (`apps/frontend-web/src/app/dashboard/credentials/page.tsx:90`):
```typescript
// Missing 'super_admin' check initially
if (currentUser.role === 'admin' || currentUser.role === 'org_admin') {
    router.push('/dashboard/admin/licenses');
}
```

**Result:** Super admin users fell through to provider-only code path

### Tertiary Issue: Sidebar Link Mismatch

**Sidebar** linked to `/dashboard/credentials/medical-license` for all users
- Route doesn't exist (no page.tsx)
- Falls back to `/dashboard/credentials` (provider-only page)
- Admin users see error instead of admin view

---

## Timeline

**19:41** - User "Mylai Viet" (super_admin) clicks "Medical License" in sidebar
**19:41** - Frontend loads `/dashboard/credentials/medical-license` → redirects to `/dashboard/credentials`
**19:41** - Page calls `apiClient.getCredentialHealth()` and `apiClient.getMyProvider()`
**19:41** - Backend returns 403 Forbidden (super_admin role not allowed for `/api/v1/providers/me`)
**19:41** - Generic error shown: "Failed to load your credentials. Please try again."

**[Investigation begins]**

**19:45** - Identified: User has `super_admin` role, not `provider`
**19:50** - Added frontend redirect logic for admin roles
**19:55** - Fixed sidebar to link admins to `/dashboard/admin/licenses`
**20:00** - Backend endpoint still returning 500 error
**20:05** - **Root cause found:** `UserRole.ADMIN` doesn't exist (AttributeError)
**20:10** - Fixed: Changed to `UserRole.SUPER_ADMIN, UserRole.ORG_ADMIN, UserRole.PRACTICE_ADMIN`
**20:15** - Backend restarted → Issue resolved ✅

---

## Resolution

### Fix 1: Backend - Correct UserRole Enum Values

**File:** `apps/backend-api/src/api/v1/admin/licenses.py`

**Before:**
```python
if current_user.role not in [UserRole.ADMIN, UserRole.ORG_ADMIN, UserRole.SUPER_ADMIN]:
```

**After:**
```python
if current_user.role not in [UserRole.SUPER_ADMIN, UserRole.ORG_ADMIN, UserRole.PRACTICE_ADMIN]:
```

**Applied to 3 endpoints:**
- `GET /admin/licenses/matrix`
- `POST /admin/licenses/bulk-verify`
- `PATCH /admin/licenses/bulk-edit`

### Fix 2: Frontend - Add Super Admin to Redirect Logic

**File:** `apps/frontend-web/src/app/dashboard/credentials/page.tsx:90`

**Before:**
```typescript
if (currentUser.role === 'admin' || currentUser.role === 'org_admin') {
```

**After:**
```typescript
if (currentUser.role === 'admin' || currentUser.role === 'org_admin' || currentUser.role === 'super_admin') {
```

### Fix 3: Sidebar - Role-Based Medical License Link

**File:** `apps/frontend-web/src/components/layout/Sidebar.tsx:198-207`

**Added logic:**
```typescript
// Admin role: update Medical License link to admin view
if (isAdmin && section.title === 'Credentials') {
  return {
    ...section,
    items: section.items.map((item) =>
      item.label === 'Medical License'
        ? { ...item, href: '/dashboard/admin/licenses' }
        : item
    ),
  };
}
```

**Also updated `isAdmin` check to include `'admin'` role:**
```typescript
const isAdmin = user?.role === 'admin' || user?.role === 'super_admin' ||
                user?.role === 'org_admin' || user?.role === 'practice_admin';
```

---

## Verification

**Test Steps:**
1. ✅ Login as super_admin user
2. ✅ Click "Medical License" in sidebar
3. ✅ Redirected to `/dashboard/admin/licenses`
4. ✅ Admin license matrix loads successfully
5. ✅ No errors in console
6. ✅ Backend returns 200 OK

**Tested Roles:**
- ✅ `super_admin` - Access granted, matrix loads
- ✅ `org_admin` - Access granted (expected)
- ✅ `practice_admin` - Access granted (expected)
- ⏭️ `provider` - Redirects to provider view (expected)

---

## Prevention

### Immediate Actions

1. ✅ **Fixed:** Backend enum mismatch corrected
2. ✅ **Fixed:** Frontend role checks updated
3. ✅ **Fixed:** Sidebar navigation role-aware

### Long-Term Prevention

**1. Type Safety for Roles**

Create shared TypeScript/Python role constants:

```typescript
// apps/frontend-web/src/types/roles.ts
export const USER_ROLES = {
  SUPER_ADMIN: 'super_admin',
  ORG_ADMIN: 'org_admin',
  PRACTICE_ADMIN: 'practice_admin',
  PROVIDER: 'provider',
  // ...
} as const;

export type UserRole = typeof USER_ROLES[keyof typeof USER_ROLES];
```

**2. Backend Testing**

Add unit test for admin endpoints:

```python
def test_admin_license_matrix_super_admin_access():
    """Super admin should access admin license matrix"""
    user = create_user(role=UserRole.SUPER_ADMIN)
    response = client.get("/api/v1/admin/licenses/matrix", headers=auth_headers(user))
    assert response.status_code == 200
```

**3. Frontend E2E Testing**

Add Playwright test:

```typescript
test('super admin can access admin licenses page', async ({ page }) => {
  await loginAs(page, 'super_admin');
  await page.click('text=Medical License');
  await expect(page).toHaveURL('/dashboard/admin/licenses');
  await expect(page.locator('text=License Matrix')).toBeVisible();
});
```

**4. Pre-Commit Hook**

Validate UserRole enum usage:

```python
# .claude/hooks/scripts/validate-user-roles.py
# Check that code doesn't use UserRole.ADMIN (doesn't exist)
if re.search(r'UserRole\.ADMIN(?!ISTRATOR)', content):
    print("ERROR: UserRole.ADMIN doesn't exist. Use UserRole.SUPER_ADMIN")
    sys.exit(1)
```

---

## Lessons Learned

### What Went Well
- ✅ Error logs clearly showed `AttributeError: ADMIN`
- ✅ Enum definition was easy to find
- ✅ Fix was straightforward once root cause identified
- ✅ Session documentation captured entire investigation

### What Could Be Better
- ❌ No type checking caught the invalid enum value
- ❌ No tests for admin role access
- ❌ Role string values scattered across frontend/backend
- ❌ No enum value validation in development

### Action Items

| Action | Owner | Priority | Deadline |
|--------|-------|----------|----------|
| Add UserRole type safety (shared constants) | Backend | HIGH | 2025-12-20 |
| Add admin endpoint unit tests | Backend | HIGH | 2025-12-20 |
| Add role-based E2E tests | Frontend | MEDIUM | 2025-12-22 |
| Create pre-commit role validation hook | DevOps | MEDIUM | 2025-12-23 |
| Document role hierarchy in KB | Docs | LOW | 2025-12-24 |

---

## Related

- **Session:** `sessions/20251219/SESSION-20251219-1941-superadmin-license-fix.md`
- **KB Article:** `docs/kb/USER-ROLE-HIERARCHY.md`
- **Admin Feature:** `sessions/20251218/SESSION-20251218-admin-license-view.md`
- **User Model:** `contexts/auth/models/user.py`

---

## Severity Justification

**HIGH Severity** because:
- Blocked all super_admin users from license management
- Showed confusing error messages (poor UX)
- Affected newly deployed admin feature (Dec 18)
- Required backend restart (service disruption)

**Not CRITICAL** because:
- No data loss
- Provider users unaffected
- Workaround available (direct URL navigation)
- Fixed within 30 minutes

---

**Resolution Confirmed:** 2025-12-19 20:15 UTC
**Deployed:** Backend restart applied fixes immediately
**Monitoring:** No further incidents reported