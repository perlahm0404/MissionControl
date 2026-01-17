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

# RIS-007: CME Data Accuracy Discrepancies Between YAML and JSON

**Status:** RESOLVED
**Date:** 2025-12-31
**Severity:** CRITICAL
**Category:** Data Accuracy / Legal Liability
**Tags:** `cme`, `rules-engine`, `data-accuracy`, `compliance`, `legal`

---

## Incident Summary

Critical data discrepancies discovered between YAML SSOT (`fsmb_ground_truth_2025.yaml`) and JSON rule packs used by the CME compliance calculator. Incorrect data could lead to wrong compliance advice, exposing providers to license suspension and the organization to legal liability.

**Impact:**
- Providers could be told they're compliant when they're not
- Providers could be told they need recurring training that's actually one-time
- Legal liability for incorrect compliance advice
- 67 state boards affected by data accuracy

---

## Root Cause

**Multi-source data entry without validation:**

1. **FL-M HIV/AIDS** - YAML said every 2 years, but requirement is ONE-TIME for first renewal
2. **FL-M Human Trafficking** - Completely missing from YAML SSOT
3. **CA-M Rollover** - JSON said `true`, but California does NOT allow rollover
4. **NY Child Abuse** - YAML said `null`, JSON said every 2 years, reality is ONE-TIME for initial licensure

**Why This Happened:**
- No automated sync validation between YAML and JSON
- No web-validation step against authoritative sources
- Manual data entry prone to interpretation errors
- "null" vs "0" semantic confusion (null = unspecified, 0 = one-time)

---

## Resolution

### Fixes Applied

| Issue | File | Before | After |
|-------|------|--------|-------|
| FL-M HIV/AIDS | YAML | `period_years: 2` | `period_years: 0, condition: first_renewal_only` |
| FL-M Human Trafficking | YAML | Missing | Added: `period_years: 0, condition: one_time` |
| CA-M Rollover | JSON | `allows_rollover: true` | `allows_rollover: false` |
| NY Child Abuse | YAML | `period_years: null` | `period_years: 0, condition: initial_licensure` |
| NY Child Abuse | JSON | `period_years: 2` | `period_years: 0, type: one_time` |

### Web Sources for Validation

1. **AMA Ed Hub (Florida):** "1 hour of HIV/AIDS must be taken before the end of your FIRST licensure renewal"
2. **Florida Medical Association:** "1-hour CME on Human Trafficking... does not require that this course be taken again"
3. **California Medical Board:** "CME courses must have been completed during each two-year period" (no rollover)
4. **NY State Education Dept:** "This is a one-time requirement and once taken does not need to be completed again"

---

## Prevention Measures

### Immediate (Implemented)
- [x] Fixed all 4 identified discrepancies
- [x] Created audit report: `docs/audit/cme-state-requirements-comparison-2025-12-31.md`
- [x] Web-validated fixes against authoritative sources

### Short-term (Recommended)
- [ ] Add automated YAML-JSON sync test in CI/CD
- [ ] Require web source citation for any CME rule changes
- [ ] Create 67-board golden regression test suite

### Long-term (Recommended)
- [ ] Implement SSOT validation script that compares against FSMB PDF
- [ ] Add pre-commit hook requiring source citations for rule pack changes
- [ ] Annual audit against FSMB published requirements

---

## Detection

**How Discovered:**
1. Ran boundary condition tests with Hypothesis property-based testing
2. Noticed tests passing but with semantic issues
3. Manual comparison of YAML vs JSON rule packs
4. Web search validation against state board websites

**Time to Detection:** ~2 hours of systematic comparison
**Time to Resolution:** ~30 minutes after detection

---

## Affected Files

```
ssot/cme/fsmb_ground_truth_2025.yaml
apps/rules-engine/rules_engine/src/rule_packs/CME-CA-M-2025.json
apps/rules-engine/rules_engine/src/rule_packs/CME-NY-2025.json
```

---

## Verification

All fixes verified by:
1. Reading authoritative web sources
2. Updating files with correct values
3. Documenting changes in audit report

---

## Related Documents

- **Audit Report:** `docs/audit/cme-state-requirements-comparison-2025-12-31.md`
- **Session Notes:** `docs/09-sessions/2025-12-31/session-20251231-005-cme-rules-accuracy-verification.md`
- **KB Article:** `docs/05-kb/development/kb-cme-rules-accuracy-verification.md`
- **Verification Plan:** `.claude/plans/vectorized-sleeping-sunset.md`