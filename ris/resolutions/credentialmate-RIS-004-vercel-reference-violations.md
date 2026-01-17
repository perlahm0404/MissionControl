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

# RIS-004: Vercel Reference Violations in Planning Documents

**Date:** 2025-12-21
**Severity:** Medium
**Category:** Governance / Documentation Quality
**Status:** RESOLVED

---

## Incident Summary

During AWS Amplify migration planning session (20251221), Claude Code persisted in referencing Vercel deployment workflows despite explicit user instructions that Vercel was NEVER used and should NOT be referenced.

---

## Timeline

**14:00** - User clarifies: NO Vercel, use AWS-native solutions only
**14:15** - Plan created with Vercel references in architecture diagram
**14:30** - User corrects: "NO vercel--use gh and manual via local cli"
**14:35** - Plan updated, but Vercel references remain in Rollback Plan
**14:45** - User escalates: "ELIMINATE ALL REFERENCES OF VERCEL NOW"
**14:50** - All Vercel references removed, RIS created

---

## Root Cause

**Primary:** Claude Code's context carried over "Vercel experience" from user's question about deployment similarities, incorrectly inferring Vercel as a deployment option.

**Secondary:** Insufficient validation of plan content before presenting to user.

**Tertiary:** No automated checks for forbidden technology references in planning documents.

---

## Impact

- **Time wasted:** ~30 minutes of corrections
- **User frustration:** Multiple rounds of clarification required
- **Plan quality:** Degraded by irrelevant references
- **Trust impact:** Moderate - user had to explicitly demand compliance

---

## Violations

1. **Referenced Vercel in architecture** despite "NO Vercel" requirement
2. **Referenced `vercel rollback`** in Rollback Plan
3. **Referenced Vercel build logs** in error handling
4. **Referenced Vercel Pro pricing** in cost comparisons

---

## Resolution

### Immediate Actions Taken

1. ✅ Removed ALL Vercel references from plan file
2. ✅ Updated architecture diagram (Route 53 → Amplify only)
3. ✅ Updated rollback procedures (Amplify Console only)
4. ✅ Updated risk mitigation (Amplify build logs only)
5. ✅ Verified no remaining Vercel references via grep

### Documentation Updates

1. ✅ Created session file: `SESSION-AMPLIFY-MIGRATION-PLAN.md`
2. ✅ Created KB entry: `aws-amplify-deployment.md`
3. ✅ Created this RIS entry
4. ✅ Updated governance rules

---

## Prevention Measures

### Rule Additions

Add to `.claude/rules/governance.md`:

**Technology Exclusion Protocol:**
```markdown
When user explicitly excludes a technology:
1. Add to exclusion list for session
2. Validate all plans for forbidden references
3. Use grep/search before presenting plans
4. If mentioned, explain WHY it appears (e.g., comparison only)
```

### Validation Checklist

Before presenting any plan:
- [ ] No forbidden technologies referenced
- [ ] Architecture matches stated requirements
- [ ] Commands use only approved tools
- [ ] Cost comparisons exclude forbidden options

---

## Lessons Learned

### What Went Wrong

1. **Context confusion:** "Vercel experience" question ≠ "use Vercel"
2. **Insufficient validation:** Didn't grep for "vercel" before presenting
3. **Assumption persistence:** Kept assuming Vercel was an option

### What Went Right

1. **User caught it:** Clear escalation path
2. **Quick fix:** Able to remove references rapidly
3. **Documentation:** Created proper RIS + KB entries

---

## Recommendations

### For Claude Code

1. **Explicit exclusion tracking:** Maintain "forbidden tech" list per session
2. **Pre-presentation validation:** Always grep for excluded terms
3. **Clear labeling:** If comparing to excluded tech, prefix with "NOT USING:"

### For Governance

1. **Add validation hook:** Check plans for excluded technologies
2. **Technology matrix:** Document approved vs forbidden per project
3. **Session summary:** Always include "Technologies NOT used"

---

## Verification

**Verified clean:**
```bash
grep -i "vercel" C:\Users\mylai\.claude\plans\radiant-imagining-pudding.md
# Result: Only in "- ✅ Deployment: Manual CLI (NO auto-deploy, NO Vercel)"
# Context: Stating what we're NOT using ✓
```

---

## Related Documents

- Session: `sessions/20251221/SESSION-AMPLIFY-MIGRATION-PLAN.md`
- KB: `docs/kb/solutions/aws-amplify-deployment.md`
- Plan: `C:\Users\mylai\.claude\plans\radiant-imagining-pudding.md`

---

**Resolution:** ALL Vercel references removed. AWS Amplify is the ONLY deployment platform referenced in workflows.

**Status:** CLOSED - Corrective actions complete