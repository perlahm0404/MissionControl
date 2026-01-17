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

# RIS Resolution: Button Component Prop Mismatch

**ID:** RES-20251203-button-prop-mismatch
**Date:** 2025-12-03
**Severity:** Medium
**Category:** TypeScript / Component API
**Status:** Resolved

---

## Problem

Frontend build failed with TypeScript error:
```
Property 'isLoading' does not exist on type 'ButtonProps'. Did you mean 'loading'?
```

## Root Cause

Multiple form components used `isLoading` prop but the Button component defines `loading`:

```typescript
// Button component defines:
export interface ButtonProps {
  loading?: boolean;  // NOT isLoading
  // ...
}
```

## Solution

Changed `isLoading` to `loading` in all affected files:

1. `apps/frontend-web/src/components/provider/LicenseForm.tsx:298`
2. `apps/frontend-web/src/components/provider/DEAForm.tsx:246`
3. `apps/frontend-web/src/components/provider/CSRForm.tsx:273`
4. `apps/frontend-web/src/components/onboarding/steps/ReviewStep.tsx:310`

```typescript
// Before
<Button type="submit" isLoading={isLoading}>

// After
<Button type="submit" loading={isLoading}>
```

## Verification

```bash
# Search for any remaining isLoading usage with Button
grep -r "isLoading=" apps/frontend-web/src/components/ | grep Button
# Should return empty
```

## Prevention

- Use consistent prop naming across components
- Consider adding TypeScript strict mode
- IDE autocomplete helps catch these during development

## Tags

`typescript` `button` `props` `build-error`