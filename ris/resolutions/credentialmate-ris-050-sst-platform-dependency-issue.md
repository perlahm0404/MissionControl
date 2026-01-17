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

# RIS-050: SST Platform Dependency Issue

**Status:** IDENTIFIED - BLOCKING FRONTEND STARTUP
**Date:** 2025-12-30
**Severity:** HIGH (blocks local development)
**Type:** Configuration Error
**Owner:** Infrastructure

---

## Issue Summary

The frontend container fails to start because `sst-darwin-arm64` is listed as a **required dependency** instead of an **optional dependency** in `package.json`. This causes npm install to fail in the Linux Docker container.

---

## Technical Details

### Root Cause

**File:** `apps/frontend-web/package.json`

**Problem:**
```json
{
  "dependencies": {
    "sst-darwin-arm64": "^3.17.25",  // ❌ WRONG - listed as required
    ...
  },
  "devDependencies": {
    "sst": "3.9.37",  // ✅ Correct - main SST package
    ...
  },
  "optionalDependencies": {
    "sst-win32-x64": "^3.17.25"  // ✅ Correct - Windows binary is optional
  }
}
```

**Error Message:**
```
npm error code EBADPLATFORM
npm error notsup Unsupported platform for sst-darwin-arm64@3.17.25:
  wanted {"os":"darwin","cpu":"arm64"}
  current: {"os":"linux","cpu":"arm64"}
npm error notsup Valid os:   darwin
npm error notsup Actual os:  linux
```

### Platform Mismatch

| Component | OS | Architecture | Expected |
|-----------|-----|--------------|----------|
| **Host Machine** | Darwin (macOS) | arm64 | ✅ |
| **Docker Container** | Linux | arm64 | ✅ |
| **sst-darwin-arm64 Package** | Darwin only | arm64 only | ❌ Rejects Linux |

The `sst-darwin-arm64` package has platform constraints:
- **Requires OS:** `darwin` (macOS only)
- **Requires CPU:** `arm64` (Apple Silicon)
- **Rejects:** Linux (even Linux arm64)

### Why This Happens

SST (Serverless Stack) is a deployment framework that uses platform-specific native binaries for performance. The SST maintainers publish separate packages for each platform:

- `sst` - Main package (platform-agnostic JavaScript)
- `sst-darwin-arm64` - macOS Apple Silicon binary
- `sst-darwin-x64` - macOS Intel binary
- `sst-linux-arm64` - Linux ARM64 binary
- `sst-linux-x64` - Linux x64 binary
- `sst-win32-x64` - Windows binary

**Correct behavior:** Platform-specific binaries should be `optionalDependencies` so npm only installs the matching platform binary.

---

## Impact Analysis

### 🔴 CRITICAL - Frontend Cannot Start

**Affected:**
- ✅ DC state licensing integration (COMPLETE but unreachable)
- ✅ All frontend features (blocked)
- ✅ Local development workflow (blocked)
- ✅ Hot reload (blocked)
- ✅ UI testing (blocked)

**Not Affected:**
- ✅ Backend API (still runs)
- ✅ Worker tasks (still runs)
- ✅ Database (still runs)
- ✅ Production deployments (uses different build process)

### Runtime Impact

**During Development (Docker):**
```
npm install → FAILS
↓
Frontend container crashes
↓
No UI accessible at http://localhost:3000
↓
Cannot test DC state licensing page
Cannot test ANY frontend features
```

**In Production (Lambda/SST):**
- ✅ **NO IMPACT** - Production uses pre-built Next.js bundles
- ✅ SST only runs during **deployment time**, not runtime
- ✅ Production runtime uses `open-next` adapter (no SST binaries)

### Why Production is Unaffected

**Production Deployment Flow:**
1. **Build Time** (CI/CD on macOS/Linux):
   - `next build` → Creates optimized bundles
   - `sst deploy` → Uploads to Lambda (runs on deployment machine)
   - Platform-specific SST binary matches deployment machine

2. **Runtime** (AWS Lambda):
   - Runs pre-built Next.js bundles
   - No `npm install` happens in Lambda
   - No SST binaries needed at runtime
   - Uses Lambda's Node.js runtime only

**Key Insight:** SST is a **deployment tool**, not a **runtime dependency**. The frontend app doesn't need SST to run, only to deploy.

---

## When Was This Introduced?

**Likely Cause:** Accidental `npm install --save` instead of `--save-dev` or `--save-optional`

**Evidence:**
- `sst` is correctly in `devDependencies` (line 60)
- `sst-win32-x64` is correctly in `optionalDependencies` (line 67)
- `sst-darwin-arm64` is **incorrectly** in `dependencies` (line 28)

**Hypothesis:** Developer ran this on macOS:
```bash
npm install sst-darwin-arm64
# Default behavior: adds to dependencies ❌
# Should have been: npm install --save-optional sst-darwin-arm64
```

---

## Fix Options

### Option 1: Move to optionalDependencies (RECOMMENDED)

**Change:**
```json
{
  "dependencies": {
    // Remove from here
  },
  "optionalDependencies": {
    "sst-darwin-arm64": "^3.17.25",  // ✅ Add here
    "sst-win32-x64": "^3.17.25"
  }
}
```

**Pros:**
- ✅ Follows SST best practices
- ✅ Works on all platforms (macOS, Linux, Windows)
- ✅ npm auto-selects correct platform binary
- ✅ No breaking changes

**Cons:**
- None

### Option 2: Remove Entirely (ALSO VALID)

**Change:**
```json
{
  "dependencies": {
    // Remove sst-darwin-arm64
  },
  "devDependencies": {
    "sst": "3.9.37"  // Keep only main package
  }
}
```

**Pros:**
- ✅ Simpler dependencies
- ✅ SST will auto-install platform binary when needed
- ✅ Works on all platforms

**Cons:**
- ⚠️ First SST command might be slower (downloads binary on-demand)

### Option 3: Add All Platform Binaries as Optional

**Change:**
```json
{
  "optionalDependencies": {
    "sst-darwin-arm64": "^3.17.25",
    "sst-darwin-x64": "^3.17.25",
    "sst-linux-arm64": "^3.17.25",
    "sst-linux-x64": "^3.17.25",
    "sst-win32-x64": "^3.17.25"
  }
}
```

**Pros:**
- ✅ Explicit control over all platforms
- ✅ Pre-downloads binaries for all team members

**Cons:**
- ⚠️ More verbose
- ⚠️ Must update when SST adds new platforms

---

## Recommended Solution

**Use Option 1: Move to optionalDependencies**

**Implementation:**
```bash
# Step 1: Edit package.json
# Move "sst-darwin-arm64": "^3.17.25" from dependencies to optionalDependencies

# Step 2: Clean install
cd apps/frontend-web
rm -rf node_modules package-lock.json
npm install

# Step 3: Verify
npm list sst-darwin-arm64
# Should show: (optional)
```

**Docker Fix:**
```bash
# After fixing package.json:
docker compose down frontend
docker compose up -d frontend
# Frontend will now start successfully
```

---

## Verification Steps

### 1. Check package.json
```bash
grep -A5 "optionalDependencies" apps/frontend-web/package.json
# Should show sst-darwin-arm64
```

### 2. Test Local Install (macOS)
```bash
cd apps/frontend-web
npm install
npm list sst-darwin-arm64
# Should install successfully and show (optional)
```

### 3. Test Docker Install (Linux container)
```bash
docker compose up frontend
# Should start without EBADPLATFORM error
```

### 4. Test DC Page
```bash
curl http://localhost:3000/resources/state-licensing/washington-dc
# Should return 200 OK (after frontend starts)
```

---

## Why This Wasn't Caught Earlier

**Possible Reasons:**

1. **Direct Development on macOS:**
   - Developer runs `npm install` on macOS host (not in Docker)
   - macOS matches `sst-darwin-arm64` platform requirements
   - Dependency installs successfully
   - Issue not noticed

2. **Using node_modules Volume Mount:**
   - `docker-compose.yml` line 193: `frontend_node_modules:/app/node_modules`
   - If node_modules populated on host first, Docker uses that
   - Masks the platform issue

3. **Production Uses Different Path:**
   - Production builds on CI/CD (likely Linux x64 or macOS)
   - SST correctly in devDependencies, so only dev installs it
   - Production build may skip dev dependencies

---

## Prevention

### 1. Add Pre-commit Hook
```bash
# .claude/hooks/scripts/validate-package-json.js
// Check for platform-specific deps in dependencies (not optionalDependencies)
const platformPackages = ['sst-darwin-', 'sst-linux-', 'sst-win32-'];
// Block commit if found
```

### 2. CI Validation
```yaml
# .github/workflows/validate-deps.yml
- name: Check for platform dependencies
  run: |
    if grep -q '"sst-darwin-\|sst-linux-\|sst-win32-' package.json | grep -v optional; then
      echo "ERROR: Platform-specific dependencies must be optional"
      exit 1
    fi
```

### 3. Update Documentation
```markdown
# docs/kb/development/dependency-management.md
## Platform-Specific Dependencies

ALWAYS use optionalDependencies for platform-specific binaries:
- sst-darwin-* (macOS)
- sst-linux-* (Linux)
- sst-win32-* (Windows)
```

---

## Related Issues

- **DC State Licensing Integration:** Complete but blocked by this issue
- **Frontend Hot Reload:** Blocked
- **Storybook:** May also be affected
- **E2E Tests (Playwright):** Blocked (requires frontend)

---

## Timeline

| Time | Event |
|------|-------|
| Unknown | `sst-darwin-arm64` added to dependencies (incorrect) |
| 2025-12-30 17:23 | DC state licensing integration committed |
| 2025-12-30 17:25 | Frontend restart attempted |
| 2025-12-30 17:25 | EBADPLATFORM error discovered |
| 2025-12-30 17:30 | Issue analyzed and documented |

---

## Action Items

- [ ] Fix package.json (move sst-darwin-arm64 to optionalDependencies)
- [ ] Test frontend startup in Docker
- [ ] Verify DC state licensing page loads
- [ ] Add pre-commit validation for platform dependencies
- [ ] Document in troubleshooting guide
- [ ] Consider removing all platform-specific SST deps (let SST auto-install)

---

## Lessons Learned

1. **Platform-specific dependencies MUST be optional**
2. **Test in Docker, not just on host machine**
3. **CI should validate dependency categories**
4. **SST binaries are deployment-time, not runtime dependencies**
5. **Volume mounts can mask dependency issues**

---

## References

- **SST Docs:** https://docs.sst.dev/
- **npm optionalDependencies:** https://docs.npmjs.com/cli/v10/configuring-npm/package-json#optionaldependencies
- **Docker Multi-platform:** https://docs.docker.com/build/building/multi-platform/