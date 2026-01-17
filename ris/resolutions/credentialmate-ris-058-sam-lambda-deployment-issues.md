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

# RIS-058: SAM Lambda Deployment Infrastructure Issues

**Date:** 2026-01-08
**Status:** RESOLVED
**Severity:** P1 - HIGH (Blocked Production Deployment)
**Category:** Infrastructure / Deployment
**Resolution Type:** Multi-Issue Fix + Documentation

---

## Executive Summary

First production Lambda deployment via SAM CLI encountered multiple infrastructure issues that blocked deployment. Issues included VPC endpoint permissions, boto3 version conflicts, secret path mismatches, missing source code, and platform-incompatible binaries.

**Impact:** ~90 minutes to complete deployment (expected: ~10 minutes)

**Root Causes:**
1. SAM template not designed for existing infrastructure (VPC endpoints)
2. Python dependency hell with boto3/botocore/s3transfer
3. Stale secrets and inconsistent naming paths
4. Build process doesn't include backend source
5. Pre-installed macOS packages polluting function directory

---

## Problem Statement

### Symptoms

**Deployment Failures:**
1. `ROLLBACK_COMPLETE` - Stack couldn't be updated
2. `ec2:CreateVpcEndpoint not authorized` - Permission denied
3. `cannot import name 'six' from 'botocore.compat'` - Import error
4. Lambda timeout (30s) - VPC connectivity issue
5. `secret was marked for deletion` - Invalid secret ARN
6. `No module named 'src'` - Missing FastAPI source
7. `'os' has no attribute 'add_dll_directory'` - Wrong platform binary

### Impact Assessment

| Metric | Value |
|--------|-------|
| Deployment attempts | 8 |
| Time to successful deployment | 90 minutes |
| Production downtime | None (first Lambda deployment) |
| Developer productivity impact | High (manual troubleshooting) |

---

## Root Cause Analysis

### Issue 1: VPC Endpoint Already Exists

**What Happened:** SAM template unconditionally creates Secrets Manager VPC endpoint. One already exists in the VPC.

**Why:** Template was written assuming fresh infrastructure, not brownfield deployment.

**5 Whys:**
1. Why did deployment fail? → CloudFormation couldn't create VPC endpoint
2. Why couldn't it create? → Endpoint already exists (duplicate)
3. Why is there a duplicate? → Terraform created one, SAM tries to create another
4. Why does SAM create one? → Template has unconditional resource definition
5. Why unconditional? → **Template not designed for existing infrastructure**

---

### Issue 2: boto3/botocore Six Compatibility

**What Happened:** Lambda failed with `cannot import name 'six' from 'botocore.compat'`

**Technical Details:**
- `botocore>=1.35.72` removed `six` from `botocore.compat` module
- `s3transfer` still imports `six` from `botocore.compat`
- `aws-lambda-powertools` and `watchtower` pulled in latest boto3

**Why This Matters:**
- Lambda runtime has older, compatible boto3
- Bundled boto3 overrides runtime boto3
- Bundled boto3 is incompatible with bundled s3transfer

**Resolution Options:**
1. ~~Pin boto3<1.35.72~~ - Rejected (pip resolver ignores constraints)
2. **Remove boto3-pulling packages** - Chosen (use Lambda runtime's boto3)
3. ~~Upgrade s3transfer~~ - Not available yet

---

### Issue 3: VPC Connectivity

**What Happened:** Lambda timed out (30s) trying to reach Secrets Manager

**Why:** Lambda security group not in VPC endpoint's allowed ingress sources

**Evidence:**
```bash
# VPC endpoint SG allowed:
- sg-069061f2e220dc537 (self)
- sg-0388f66fc2749914a (RDS SG)
# Missing:
- sg-0ff9d7cad5283b9f9 (Lambda SG from SAM stack)
```

**Why Not Caught Earlier:** New Lambda SG created by SAM, not in existing Terraform-managed endpoint rules

---

### Issue 4: Deleted Secrets

**What Happened:** Secrets at path `/prod/` were marked for deletion

**Evidence:**
```json
{
  "Name": "credmate/prod/database",
  "DeletedDate": "2025-12-24T15:34:09.059000-06:00"
}
```

**Why:** Path naming inconsistency - active secrets at `/production/`, deleted secrets at `/prod/`

---

### Issue 5: Missing FastAPI Source

**What Happened:** Lambda couldn't find `src.lazy_app` module

**Why:** `copy_backend.py` script must run before SAM build to copy backend source into Lambda function directory

**Process Gap:** Not documented, not automated, easy to forget

---

### Issue 6: Platform Mismatch

**What Happened:** `os.add_dll_directory` error - Windows-only function

**Why:**
1. Lambda function directory had pre-installed packages from macOS
2. SAM build copied those packages instead of installing fresh
3. `psycopg2-binary` was Windows wheel (delvewheel), not Linux

**Evidence:**
```bash
# Before fix - macOS packages in function dir
ls functions/backend/ | wc -l
# 184 items (packages!)

# After fix - only source files
ls functions/backend/
# handler.py  requirements.txt  copy_backend.py  src/
```

---

## Solutions Implemented

### Fix 1: Conditional VPC Endpoint

**File:** `infra/lambda/template.yaml`

```yaml
Parameters:
  ExistingSecretsManagerVpcEndpoint:
    Type: String
    Description: Existing VPC Endpoint ID for Secrets Manager (skip creation if provided)
    Default: ''

Conditions:
  CreateSecretsManagerEndpoint: !Equals [!Ref ExistingSecretsManagerVpcEndpoint, '']

Resources:
  SecretsManagerVpcEndpoint:
    Type: AWS::EC2::VPCEndpoint
    Condition: CreateSecretsManagerEndpoint  # Only create if not provided
    Properties: ...
```

**Impact:** Template works with both fresh and existing infrastructure

---

### Fix 2: Remove boto3-Pulling Packages

**File:** `infra/lambda/functions/backend/requirements.txt`

```diff
- aws-lambda-powertools==2.28.0
+ # aws-lambda-powertools - REMOVED: pulls in incompatible boto3 version
+ # Handler.py already handles this as optional (try/except)

- watchtower>=3.0.1
+ # CloudWatch Logging - REMOVED: pulls in boto3, Lambda runtime handles logging natively
```

**Impact:** Lambda uses runtime's compatible boto3 (no bundled version)

---

### Fix 3: VPC Endpoint Security Group Rule

**Command:**
```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-069061f2e220dc537 \
  --protocol tcp --port 443 \
  --source-group sg-0ff9d7cad5283b9f9
```

**TODO:** Add to Terraform:
```hcl
resource "aws_security_group_rule" "vpc_endpoint_from_lambda" {
  type                     = "ingress"
  from_port               = 443
  to_port                 = 443
  protocol                = "tcp"
  source_security_group_id = "sg-0ff9d7cad5283b9f9"  # Lambda SG from SAM
  security_group_id       = aws_security_group.vpc_endpoint.id
}
```

---

### Fix 4: Correct Secret ARNs

**File:** `infra/lambda/samconfig.toml`

```diff
- "DatabaseSecretArn=arn:aws:secretsmanager:us-east-1:051826703172:secret:credmate/prod/database-kLfGYo",
- "JwtSecretArn=arn:aws:secretsmanager:us-east-1:051826703172:secret:credmate/prod/jwt-aexUfj",
+ "DatabaseSecretArn=arn:aws:secretsmanager:us-east-1:051826703172:secret:credmate/production/database-bFajX7",
+ "JwtSecretArn=arn:aws:secretsmanager:us-east-1:051826703172:secret:credmate/production/jwt-W9dPlQ",
```

---

### Fix 5: Copy Backend Source

**Command:**
```bash
cd infra/lambda/functions/backend
python3 copy_backend.py
```

**TODO:** Automate in Makefile:
```makefile
lambda-build:
	cd infra/lambda/functions/backend && python3 copy_backend.py
	cd infra/lambda && sam build --use-container
```

---

### Fix 6: Clean Function Directory

**Commands:**
```bash
cd infra/lambda/functions/backend
find . -maxdepth 1 -type d ! -name "src" ! -name "." ! -name ".ruff_cache" | xargs rm -rf
find . -maxdepth 1 -type f ! -name "handler.py" ! -name "requirements.txt" ! -name "copy_backend.py" | xargs rm -f
```

**TODO:** Add `.gitignore`:
```gitignore
# infra/lambda/functions/backend/.gitignore
*
!handler.py
!requirements.txt
!copy_backend.py
!src/
!.gitignore
```

---

## Architectural Improvements Required

### P0: CRITICAL (24h)

1. **Add VPC endpoint SG rule to Terraform**
   - File: `infra/iac/main.tf`
   - Prevents rule loss on infra rebuild

2. **Add .gitignore to function directory**
   - Prevents package pollution
   - Only allow source files

### P1: HIGH (1 week)

1. **Automate copy_backend.py in build**
   - Add to Makefile
   - Or integrate into SAM build hooks

2. **Create deploy-lambda skill**
   - Document SAM deployment process
   - Include all pre-deployment steps

3. **Clean up deleted secrets**
   - Remove `/prod/` secrets from Secrets Manager
   - Or restore them if they should exist

### P2: MEDIUM (1 month)

1. **CI/CD for Lambda production**
   - GitHub Actions workflow for prod
   - Currently only deploys to dev

2. **Lambda monitoring dashboard**
   - CloudWatch dashboard for Lambda metrics
   - Alarms for errors, duration, throttles

---

## Prevention Strategy

### Pre-Deployment Checklist

Before running `sam deploy --config-env prod`:

- [ ] Run `python3 functions/backend/copy_backend.py`
- [ ] Verify function directory only has source files (no packages)
- [ ] Verify `samconfig.toml` has correct secret ARNs
- [ ] Verify VPC endpoint SG allows Lambda SG
- [ ] Run `sam build --use-container` (Linux packages)

### Automated Validation

**Add to SAM build process:**
```bash
#!/bin/bash
# pre-build-validation.sh

# Check no packages in function directory
PACKAGE_COUNT=$(ls -d functions/backend/*.dist-info 2>/dev/null | wc -l)
if [ "$PACKAGE_COUNT" -gt 0 ]; then
  echo "ERROR: Found $PACKAGE_COUNT packages in function directory"
  echo "Run: cd functions/backend && find . -maxdepth 1 -type d ! -name src ! -name . | xargs rm -rf"
  exit 1
fi

# Check src directory exists
if [ ! -d "functions/backend/src" ]; then
  echo "ERROR: src/ directory missing"
  echo "Run: python3 functions/backend/copy_backend.py"
  exit 1
fi

echo "Pre-build validation passed"
```

---

## Related Documentation

**Session:**
- SESSION-20260108-LAMBDA-PROD-DEPLOYMENT-SAM.md

**KB Created:**
- KB: SAM Lambda Deployment Guide

**Skills:**
- deploy-lambda skill (new)

**Previous RIS:**
- RIS-050: Lambda Lazy App Regression (similar import issues)
- RIS-045: Lambda Manifest Type Issue

---

## Verification

```bash
# Health check
curl https://e0fj0gm9zi.execute-api.us-east-1.amazonaws.com/prod/health
# {"status":"healthy","mode":"lazy"}

# Lambda logs
aws logs tail /aws/lambda/credmate-backend-prod --since 5m
# [LAZY_APP] Initialization complete!
```

---

**Resolution:** COMPLETE - All issues fixed, Lambda deployed successfully
**Follow-up:** Implement P0/P1 automation to prevent recurrence

---

**Authored by:** Claude Opus 4.5
**Reviewed by:** (pending)
**Approved by:** TMAC