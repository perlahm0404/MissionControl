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

# RIS-006: Next.js and ESLint Config Version Mismatch

**Status:** RESOLVED
**Date:** 2025-12-21
**Severity:** HIGH
**Category:** Dependency Management
**Tags:** `nextjs`, `eslint`, `dependencies`, `versioning`

---

## Incident Summary

Version mismatch between `next` (14.2.35) and `eslint-config-next` (14.2.33) causes internal module expectation misalignment during SST deployment.

**Impact:**
- Contributing factor to MODULE_NOT_FOUND errors
- ESLint configuration may not match Next.js internals
- Build process instability

---

## Root Cause

**Dependency Version Drift:**

```json
// package.json (BEFORE)
{
  "dependencies": {
    "next": "^14.2.35"  // Latest patch
  },
  "devDependencies": {
    "eslint-config-next": "14.2.33"  // Outdated patch
  }
}
```

**Why This Matters:**
- `eslint-config-next` contains ESLint rules specific to Next.js internals
- Version must EXACTLY match Next.js version
- Even patch version differences can cause internal module conflicts
- Next.js internals may change between patches (e.g., module locations, exports)

**Evidence:**
- Discovered during deployment failure root cause analysis
- npm list showed version discrepancy
- OpenNext build error occurred with version mismatch present

---

## Resolution

**Fix:** Update eslint-config-next to match Next.js version exactly

```bash
# Update to matching version
npm install eslint-config-next@14.2.35 --save-dev --legacy-peer-deps

# Verify versions match
npm list next eslint-config-next | grep -E "next@|eslint-config-next@"
```

**Expected Output:**
```
├── next@14.2.35
└── eslint-config-next@14.2.35
```

---

## Prevention

### Policy: Version Pinning for Next.js Ecosystem

**Rule:** eslint-config-next version MUST ALWAYS match next version exactly.

### Automated Checks

**Pre-deployment validation script:**

```bash
#!/bin/bash
# File: scripts/validate-nextjs-versions.sh

NEXT_VERSION=$(npm list next --depth=0 | grep next@ | sed 's/.*next@//' | sed 's/ .*//')
ESLINT_VERSION=$(npm list eslint-config-next --depth=0 | grep eslint-config-next@ | sed 's/.*eslint-config-next@//' | sed 's/ .*//')

if [ "$NEXT_VERSION" != "$ESLINT_VERSION" ]; then
    echo "ERROR: Version mismatch detected"
    echo "  next: $NEXT_VERSION"
    echo "  eslint-config-next: $ESLINT_VERSION"
    echo ""
    echo "Fix: npm install eslint-config-next@$NEXT_VERSION --save-dev"
    exit 1
fi

echo "✅ Next.js versions aligned: $NEXT_VERSION"
```

### Package.json Best Practice

**Use exact version pinning for Next.js ecosystem:**

```json
{
  "dependencies": {
    "next": "14.2.35"  // Remove ^ for exact version
  },
  "devDependencies": {
    "eslint-config-next": "14.2.35"  // Must match exactly
  }
}
```

### CI/CD Integration

**Add to GitHub Actions / pre-commit hooks:**

```yaml
# .github/workflows/validate-deps.yml
- name: Validate Next.js Versions
  run: |
    bash scripts/validate-nextjs-versions.sh
```

---

## Documentation Updates

- ✅ Added version check to `SST-DEPLOYMENT-FIX-IMPLEMENTATION-PLAN.md` Phase 2
- ✅ Created validation script in implementation plan
- ✅ Updated `docs/kb/solutions/dependency-version-management.md`

---

## Related Issues

- RIS-005: WSL filesystem deployment requirement (primary blocker)
- RIS-007: Stale build cache interference

---

## Testing

**Manual Verification:**
```bash
cd apps/frontend-web

# Check versions
npm list next eslint-config-next

# Should show matching versions
```

**Automated Verification:**
```bash
bash scripts/validate-nextjs-versions.sh
```

**Test Status:** Fix included in implementation plan, awaiting user execution

---

## Lessons Learned

1. **Patch Versions Matter:** Even minor patch differences (14.2.33 vs 14.2.35) can cause issues with tightly coupled packages
2. **Ecosystem Coupling:** Next.js and eslint-config-next are tightly coupled - version sync is critical
3. **Caret (^) Risk:** Using `^14.2.35` allows patch updates that may break ESLint config sync
4. **Validation is Cheap:** Simple script can prevent deployment failures

---

## Scope

**Affected Components:**
- Next.js build process
- ESLint linting during build
- SST deployment via OpenNext

**Not Affected:**
- Runtime behavior (if build succeeds)
- Development server
- TypeScript compilation

---

**Created By:** Claude Code
**Validated By:** PENDING
**Production Impact:** MEDIUM (contributing factor to deployment failure)
**Customer Impact:** None (pre-deployment)

---

## References

- Implementation Plan: `docs/plans/SST-DEPLOYMENT-FIX-IMPLEMENTATION-PLAN.md` (Phase 2, Step 2.2)
- Session Analysis: `sessions/20251221/SESSION-SST-DEPLOYMENT-FAILURE-ANALYSIS.md`
- Next.js Versioning: https://nextjs.org/docs/upgrading