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

# RIS-SUPERADMIN-PROVIDER-VISIBILITY-20251217

**Status**: RESOLVED ✅
**Date**: 2025-12-17
**Severity**: MEDIUM (P2)
**Category**: User Management / Data Architecture
**Impact**: Super admin could only see 1 provider instead of all 40 in production

---

## Problem Statement

After creating test users in production (super admin, org admin, provider), the super admin dashboard only showed 1 provider instead of all 40 providers in the database.

**Symptoms**:
- Super admin logged in and saw "1 Total Providers" on Organization Dashboard
- API `/api/v1/providers/` correctly returned 40 providers
- Frontend dashboard showed org-specific data limited to 1 provider

---

## Root Cause

**Two issues combined**:

### Issue 1: Provider Self-Registration Pattern
Each user who self-registered created their own organization, resulting in:
- 40 providers spread across 40 separate organizations
- Each organization had exactly 1 provider
- Organization Dashboard is org-scoped, showing only 1 provider per org

### Issue 2: Super Admin Org Binding
Super admin user had:
- `organization_id = 1` (Perla) - locked dashboard to Perla org view
- `provider_id = 1` - linked to a specific provider (Tricia Jones)

**Dashboard Logic** (from `dashboard_endpoints.py:1217-1221`):
```python
org_id = current_user.organization_id

# Superusers see all organizations - for now, show first org with providers
if current_user.is_superuser and org_id is None:
    # Get first org with providers...
```

The super admin had `org_id = 1`, so the "show all" logic never triggered.

---

## Resolution

### Step 1: Consolidate All Providers to Perla Organization

Moved all 40 providers from their individual orgs to the Perla organization:

```sql
UPDATE providers
SET organization_id = 1  -- Perla org
WHERE is_deleted = false AND organization_id != 1
```

### Step 2: Update User Org Assignments

Moved all users (except super admin) to Perla org:

```sql
UPDATE users
SET organization_id = 1  -- Perla org
WHERE is_deleted = false
AND role != 'super_admin'
AND organization_id != 1
```

### Step 3: Set Super Admin Org to Perla

Set super admin's org to Perla so dashboard shows all providers:

```sql
UPDATE users
SET organization_id = 1, provider_id = NULL
WHERE email = 'mylaiviet@gmail.com'
```

**Result**: Super admin dashboard now shows all 40 providers.

---

## Users Created

| Email | Role | Password | Access |
|-------|------|----------|--------|
| mylaiviet@gmail.com | super_admin | Test1234 | All providers, all data, Accuracy Dashboard, Observability |
| perla@test.com | org_admin | Test1234 | All providers in Perla org |
| seabreeze@test.com | provider | Test1234 | Own provider data only |

---

## Key Learnings

1. **Organization Dashboard is Org-Scoped**: Shows data for ONE organization, not all data
2. **Super Admin Needs Org Context**: Even super admins need an `organization_id` for the dashboard to display data
3. **Self-Registration Creates Silos**: Each self-registered user creates their own org, fragmenting data
4. **Local Dev vs Production**: Local dev seeds all users into one org; production had 1:1 org:provider ratio

---

## Prevention

### For Future User Creation

When creating admin users in production:

1. **Super Admin**: Set `organization_id` to the main org (not NULL)
2. **Remove Provider Linkage**: Set `provider_id = NULL` to avoid filtering
3. **Consolidate Data**: Ensure providers belong to accessible organizations

### Recommended Seed Script Pattern

```python
super_admin = User(
    email="admin@example.com",
    role=UserRole.SUPER_ADMIN,
    is_superuser=True,
    organization_id=main_org.id,  # Set to main org, not NULL
    provider_id=None,  # No provider linkage
)
```

---

## Related Files

- **RLS Logic**: `apps/backend-api/src/contexts/compliance/security.py`
- **Dashboard Endpoint**: `apps/backend-api/src/contexts/compliance/api/dashboard_endpoints.py:1205-1260`
- **Seed Script (Local)**: `apps/backend-api/scripts/seed_admin_users.py`
- **Production Fix Script**: `temp_consolidate_providers.py` (run via SSM)
- **KB Article**: `docs/kb/infra/production-user-management.md`

---

## Verification Commands

```bash
# Check provider count via API
curl -s "https://api.credentialmate.com/api/v1/providers/?page_size=100" \
  -H "Authorization: Bearer $TOKEN" | python -c "import sys,json; print('Providers:', json.load(sys.stdin).get('total'))"

# Check user details in production
python temp_run_ssm.py temp_check_user_linkage.py
```

---

## Related Fix: Provider Dashboard 500 Error

**Date**: 2025-12-17
**File**: `apps/backend-api/src/contexts/compliance/api/dashboard_endpoints.py`

### Problem

Viewing individual provider dashboard (`/dashboard/compliance/provider/1110`) returned 500 error for provider 1110 (test99 test99).

**Investigation Findings**:
- Provider 1110 has ZERO credentials (no licenses, DEA, CSR, CME cycles)
- The dashboard endpoint didn't properly handle providers with completely empty data
- Additionally, superadmin bypass was missing for provider lookup

### Fix Applied

1. **Added logging** (line 963):
   ```python
   logger.info(f"Provider dashboard requested: provider_id={provider_id}, user={current_user.email}, org_id={current_user.organization_id}, is_superuser={current_user.is_superuser}")
   ```

2. **Added superadmin bypass** (lines 968-979):
   ```python
   if current_user.is_superuser:
       provider = db.query(Provider).filter(
           Provider.id == provider_id,
           Provider.is_deleted == False,
       ).first()
   else:
       # org-scoped query for regular users
   ```

3. **Fixed org context for superadmin** (lines 987-993):
   - Use provider's org_id for subsequent queries when superadmin views any provider

4. **Added try/except around widget calls** (lines 1131-1153):
   - CME widget and Document widget calls now wrapped with error handling
   - Detailed error messages help identify which widget failed

### Files Modified

- `apps/backend-api/src/contexts/compliance/api/dashboard_endpoints.py`
  - Added `import logging, traceback`
  - Added `logger = logging.getLogger(__name__)`
  - Added superadmin bypass at provider lookup
  - Added try/except with detailed error messages

---

## Related Fix: Provider Dashboard Fallback View

**Date**: 2025-12-17
**File**: `apps/frontend-web/src/app/dashboard/compliance/provider/[id]/page.tsx`

### Problem

Even after backend fixes, the provider dashboard still returned 500 errors for providers with empty data. The generic error state showed "Failed to load provider dashboard" without useful context.

### Solution: Context-Aware Fallback View

When the API fails but admin context data exists (from clicking the provider in the list), display a fallback view instead of a generic error:

1. **Uses provider context data** (stored when admin clicks provider):
   - Provider name, NPI, specialty
   - Compliance level badge (compliant/at_risk/non_compliant/unknown)
   - Compliance score with visual ring

2. **Context-aware error message** explaining:
   - "Detailed data unavailable"
   - May happen for providers with no credential data yet

3. **Actionable buttons**:
   - "Try Again" - refetch dashboard data
   - "Back to Admin Dashboard" - returns to provider list

4. **Next steps guidance** for new providers:
   - Upload credential documents
   - Wait for processing
   - Return to view complete dashboard

### Implementation

Added `activeProvider` and `closeProviderContext` from `useProviderContext()` hook.

Lines 734-901: New fallback view that renders when:
- `error || !data` condition is true
- AND `isAdminContext && activeProvider` is true

Shows the provider header with basic info from context, an amber warning box, and guidance instead of a blank error screen.

---

## Tags

`super-admin` `provider-visibility` `organization-dashboard` `rls` `user-management` `production-data` `provider-dashboard` `500-error` `fallback-view`