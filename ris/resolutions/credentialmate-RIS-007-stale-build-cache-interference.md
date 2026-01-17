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

# RIS-007: Stale Build Cache Interference

**Status:** RESOLVED
**Date:** 2025-12-21
**Severity:** MEDIUM
**Category:** Build System
**Tags:** `nextjs`, `cache`, `build`, `artifacts`

---

## Incident Summary

Stale build artifacts from previous Next.js version (14.2.33) interfere with new installation (14.2.35), causing module resolution failures during SST deployment.

**Impact:**
- Build cache contains references to old module locations
- OpenNext bundle creation fails due to cached artifact conflicts
- Fresh npm install doesn't clear existing build directories

---

## Root Cause

**Cache Persistence Across Version Changes:**

When Next.js version changes, build directories retain artifacts compiled against the old version:

**Problematic Directories:**
1. `.next/` - Next.js build output
2. `.open-next/` - OpenNext bundling artifacts
3. `.sst/` - SST deployment cache
4. `node_modules/` - May contain compiled binaries for old version

**Why This Causes Issues:**
- `.next/cache/` contains webpack compilation cache with hardcoded module paths
- `.open-next/` may reference old internal module structure
- Incremental builds reuse cached artifacts that expect old module locations
- npm install alone doesn't trigger cache invalidation

**Evidence:**
- Build artifacts existed from 14.2.33 installation
- Version was updated to 14.2.35 but cache not cleared
- MODULE_NOT_FOUND error for internal Next.js module (`next/dist/compiled/unistore`)

---

## Resolution

**Required:** Clean all build artifacts before npm install after version changes

### Cleanup Commands

```bash
cd apps/frontend-web

# Remove ALL cached build artifacts
rm -rf node_modules package-lock.json .next .open-next .sst

# Fresh install with correct versions
npm install
```

### When to Clean Cache

**ALWAYS clean cache when:**
- ✅ Next.js version changes (even patches)
- ✅ Major dependency updates (React, webpack, etc.)
- ✅ Switching between branches with different dependency versions
- ✅ MODULE_NOT_FOUND errors for internal modules
- ✅ Unexplained build failures after working builds

**Usually safe to skip:**
- ❌ Adding new dependencies (no version changes)
- ❌ Code-only changes (no package.json edits)
- ❌ Environment variable changes

---

## Prevention

### Policy: Clean Reinstall for Version Changes

**Rule:** Any package.json dependency version change requires cache cleanup.

### Automated Cleanup Script

```bash
#!/bin/bash
# File: scripts/clean-install.sh

echo "=== Clean Install Script ==="
echo ""

# Navigate to frontend
cd "$(dirname "$0")/../apps/frontend-web"

echo "Removing cached artifacts..."
rm -rf node_modules package-lock.json .next .open-next .sst

echo "Installing fresh dependencies..."
npm install

echo ""
echo "✅ Clean install complete"
echo ""
echo "Verify versions:"
npm list next eslint-config-next | grep -E "next@|eslint-config-next@"
```

### Git Hooks

**Pre-pull hook to detect package.json changes:**

```bash
#!/bin/bash
# .git/hooks/post-merge

PACKAGE_CHANGED=$(git diff-tree -r --name-only --no-commit-id ORIG_HEAD HEAD | grep package.json)

if [ -n "$PACKAGE_CHANGED" ]; then
    echo "⚠️  package.json changed - consider running: bash scripts/clean-install.sh"
fi
```

### Documentation

**Add to README.md:**

```markdown
## Dependency Updates

When updating Next.js or major dependencies:

1. Clean all build artifacts:
   ```bash
   bash scripts/clean-install.sh
   ```

2. Verify versions match:
   ```bash
   npm list next eslint-config-next
   ```

3. Test build before deploying:
   ```bash
   npm run build
   ```
```

---

## Implementation in SST Deployment Fix

**Included in Phase 2 of Implementation Plan:**

```bash
# Phase 2, Step 2.1: Remove Build Artifacts
rm -rf node_modules package-lock.json .next .open-next .sst

# Verification
ls -la | grep -E "node_modules|.next|.open-next"
# Should return nothing
```

---

## Related Issues

- RIS-005: WSL filesystem deployment requirement (primary blocker)
- RIS-006: Next.js/ESLint version mismatch (version drift trigger)

---

## Testing

**Validation Steps:**

```bash
cd apps/frontend-web

# 1. Verify clean state
ls -la | grep -E "node_modules|.next|.open-next"
# Should show nothing if clean

# 2. Install dependencies
npm install

# 3. Verify build works
npm run build

# 4. Check for artifacts
ls -la .next/
# Should contain fresh build output
```

**Test Status:** Included in implementation plan, awaiting user execution

---

## Lessons Learned

1. **Cache Invalidation is Hard:** npm install doesn't automatically clean build caches
2. **Version Changes = Full Rebuild:** Even patch versions may require cache cleanup
3. **Explicit is Better:** Manual cleanup safer than assuming automatic invalidation
4. **Incremental Builds Have Trade-offs:** Speed vs correctness after dependency changes

---

## Performance Impact

**Build Times (Clean vs Cached):**

| Build Type | First Build | Subsequent Builds |
|------------|-------------|-------------------|
| **Clean** | 2-3 min | 2-3 min (no cache reuse) |
| **Cached** | N/A | 30s - 1 min (when cache valid) |
| **Stale Cache** | FAILS | FAILS (invalid cache) |

**Recommendation:** Accept 2-3 min clean build over risking failed builds from stale cache.

---

## Scope

**Affected Components:**
- Next.js webpack compilation
- OpenNext bundling process
- SST deployment pipeline
- Local development builds

**Not Affected:**
- Source code
- Git repository
- Environment variables
- AWS infrastructure

---

**Created By:** Claude Code
**Validated By:** PENDING
**Production Impact:** MEDIUM (blocks deployment with stale cache)
**Customer Impact:** None (pre-deployment)

---

## References

- Implementation Plan: `docs/plans/SST-DEPLOYMENT-FIX-IMPLEMENTATION-PLAN.md` (Phase 2, Step 2.1)
- Session Analysis: `sessions/20251221/SESSION-SST-DEPLOYMENT-FAILURE-ANALYSIS.md`
- Next.js Caching: https://nextjs.org/docs/architecture/nextjs-compiler