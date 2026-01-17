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
created: '2026-01-13'
project: credentialmate
updated: '2026-01-13'
version: '1.0'
---

# RIS-008: CME Fidelity Fix - FL-M Total Hours and YAML-JSON Sync

**Status:** RESOLVED
**Date:** 2026-01-13
**Severity:** CRITICAL
**Category:** Data Accuracy / Compliance
**Tags:** `cme`, `rules-engine`, `data-accuracy`, `compliance`, `fsmb`, `florida`

---

## Incident Summary

Florida MD (FL-M) CME rule pack had incorrect total hours (40h instead of 38h per FSMB specification). FSMB clearly states "38 hours NOT including the 2-hour medical errors course," meaning medical errors are a separate requirement that does NOT count toward the base 38h total.

**Impact:**
- Providers shown incorrect compliance requirements
- Gap calculations potentially overstating requirements
- 67-board sync validation failing (61 tests)
- Legal liability risk for incorrect compliance guidance

---

## Root Cause

### Primary Issue: FL-M Total Hours

The JSON rule pack stated 40h total, but FSMB October 2025 specifies:
> "38 hours NOT including 2-hour medical errors"

**Correct interpretation:**
- Base CME requirement: 38 hours
- Medical errors: 2 hours (SEPARATE, does not count toward 38h)
- Provider must earn 40h total, but tracked as 38h base + 2h additional

### Secondary Issues

1. **FL-M YAML Missing Topics:** YAML SSOT was missing 3 topics present in JSON (risk_management, fl_laws_rules, controlled_substances)
2. **NC Category Requirements:** Empty `accepted_categories` when NC requires 100% Category 1
3. **Rollover Schema Mismatch:** 59 boards had YAML null vs JSON false for rollover (semantically equivalent)
4. **Period Years for No-CME States:** Test comparing wrong fields for states with no CME requirement

---

## Resolution

### Fixes Applied

| Issue | File | Before | After |
|-------|------|--------|-------|
| FL-M Total Hours | JSON | `value: 40` | `value: 38` |
| FL-M Medical Errors | JSON | (no flag) | `counts_toward_total: false` |
| FL-M Missing Topics | YAML | 5 topics | 8 topics (added risk_management, fl_laws_rules, controlled_substances) |
| NC Categories | JSON | `accepted_categories: []` | `accepted_categories: ["AMA_Category_1"]` |
| Rollover Tests | Test | Strict equality | Normalize null to false |
| Period Years Tests | Test | Compare all states | Skip no-CME states (IN, MT, NY, SD) |

### Test Results

```
Before: 804 passed, 61 failed
After:  865 passed, 0 failed
```

---

## Verification Steps

1. **Unit Tests:** `pytest apps/rules-engine/rules_engine/tests/accuracy/test_yaml_to_json_sync.py` - All 865 passed
2. **FL-M JSON:** Verified total_hours.value = 38, counts_toward_total = false for medical_errors
3. **FL-M YAML:** Verified 8 topics match JSON
4. **NC JSON:** Verified accepted_categories contains AMA_Category_1

---

## Prevention Measures

1. **Automated Sync Validation:** Add YAML-JSON sync tests to CI/CD pipeline
2. **FSMB Reference Check:** Require FSMB citation for any total hours change
3. **counts_toward_total Audit:** Review all states for similar separate-requirement patterns
4. **Golden Test Coverage:** Add explicit FL-M total hours test case

---

## Related Documents

- Session: SESSION-20260113-CME-FIDELITY-FIX.md
- KB: KB-011-CME-YAML-JSON-SYNC-FIDELITY.md
- Previous: RIS-007-cme-data-accuracy-discrepancies.md
- ADR: ADR-009-populate-gap-metadata-in-service-responses.md

---

## Commit Reference

```
Commit: 80ca75e9
Branch: CME-Update
Message: fix(cme): FL-M total hours and YAML-JSON sync fidelity
```
