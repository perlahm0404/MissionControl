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

# RIS-005: WSL Filesystem Deployment Requirement

**Status:** RESOLVED
**Date:** 2025-12-21
**Severity:** CRITICAL
**Category:** Infrastructure / Deployment
**Tags:** `wsl`, `sst`, `opennext`, `filesystem`, `performance`

---

## Incident Summary

SST deployment of Next.js frontend fails with `MODULE_NOT_FOUND` error for 'next/dist/compiled/unistore' when project located on Windows filesystem mount (`/mnt/c/`).

**Impact:**
- Frontend deployment completely blocked
- Build times 10-20x slower than expected (654 seconds vs ~60 seconds)
- Module resolution failures preventing OpenNext from bundling correctly

---

## Root Cause

**Primary Issue:** Running Node.js projects from WSL's Windows filesystem mount (`/mnt/c/`) causes:

1. **Module Resolution Failures:**
   - Windows path translation interferes with Node.js module resolution
   - Symlinks don't work correctly across filesystem boundary
   - npm packages may not install completely/correctly

2. **Extreme Performance Degradation:**
   - File I/O is 10-20x slower on /mnt/c vs native WSL filesystem
   - npm install: seconds → minutes
   - Build times: 2-3 min → 10+ min

**Evidence:**
- Microsoft official documentation: "Store project files in WSL filesystem, not Windows mount"
- Next.js GitHub issue #55697: Windows build path issues
- Observed build time: 654 seconds (abnormal)
- Module exists in node_modules but resolution fails

**Sources:**
- [Microsoft Learn - React on WSL](https://learn.microsoft.com/en-us/windows/dev-environment/javascript/react-on-wsl)
- [Next.js Windows build issues #55697](https://github.com/vercel/next.js/issues/55697)
- [OpenNext Common Issues](https://opennext.js.org/aws/v2/common_issues)

---

## Resolution

**Required Change:** Move project from `/mnt/c/CREDMATE/CredentialMate` to `~/CredentialMate`

### Implementation Steps

```bash
# 1. Copy project to native WSL filesystem
cd ~
cp -r /mnt/c/CREDMATE/CredentialMate ~/CredentialMate

# 2. Navigate to frontend
cd ~/CredentialMate/apps/frontend-web

# 3. Clean all artifacts
rm -rf node_modules package-lock.json .next .open-next .sst

# 4. Fresh install
npm install

# 5. Deploy
npx sst deploy --stage dev
```

**Expected Results:**
- Build time: <3 minutes (vs 10+ on /mnt/c)
- npm install: <1 minute (vs several minutes)
- Module resolution: Works correctly
- Deployment: Succeeds

---

## Prevention

**Policy:** All WSL Node.js projects MUST be located in WSL native filesystem (`~/`), NOT Windows mounts (`/mnt/c/`).

### Checklist for New Projects

- [ ] Project directory: `~/project-name/` (NOT `/mnt/c/...`)
- [ ] Verify with: `pwd` should show `/home/username/...`
- [ ] Git clone directly to `~/` directory
- [ ] Never symlink from Windows to WSL for active development

### Documentation Updates

- ✅ Updated `docs/runbooks/SST-DEPLOYMENT-WSL-SETUP.md` - Added filesystem requirement
- ✅ Created `docs/kb/solutions/wsl-filesystem-best-practices.md`
- ✅ Added to `.claude/memory/hot-patterns.md` under "WSL Deployment"

---

## Related Issues

- RIS-006: Next.js/ESLint version mismatch
- RIS-007: Stale build cache interference

---

## Testing

**Validation Required:**
1. Move project to ~/CredentialMate/
2. Time npm install (should be <60s)
3. Time build (should be <180s)
4. Verify module resolution works
5. Deploy successfully to dev stage

**Test Status:** PENDING user execution

---

## Lessons Learned

1. **WSL Filesystem Performance Matters:** Always check project location before troubleshooting module issues
2. **Microsoft Documentation is Authoritative:** WSL best practices should be consulted for all Node.js WSL projects
3. **Performance Anomalies Signal Location Issues:** 10+ minute builds on modern hardware indicate filesystem problem
4. **Module Resolution != Module Presence:** Module can exist in node_modules but still fail to resolve due to path translation

---

**Created By:** Claude Code
**Validated By:** PENDING
**Production Impact:** BLOCKING (deployment impossible from /mnt/c)
**Customer Impact:** None (pre-deployment)

---

## References

- Implementation Plan: `docs/plans/SST-DEPLOYMENT-FIX-IMPLEMENTATION-PLAN.md`
- Session Analysis: `sessions/20251221/SESSION-SST-DEPLOYMENT-FAILURE-ANALYSIS.md`
- Runbook: `docs/runbooks/SST-DEPLOYMENT-WSL-SETUP.md`