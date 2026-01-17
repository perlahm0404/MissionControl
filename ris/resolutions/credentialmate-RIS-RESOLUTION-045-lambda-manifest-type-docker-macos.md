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

# RIS-045: Lambda Deployment Failures Due to OCI Manifest Type on macOS

**Date:** 2025-12-28
**Severity:** CRITICAL
**Status:** ✅ RESOLVED
**Impact:** Production login broken (complete service outage)
**Resolution Time:** 90 minutes

---

## Incident Summary

**Problem:** AWS Lambda rejected Docker images built on macOS with error "The image manifest or layer media type for the source image is not supported."

**Root Cause:** Docker Desktop on macOS (version 4.x+) creates OCI manifest type (`application/vnd.oci.image.manifest.v1+json`) by default, but AWS Lambda only accepts Docker v2 manifest type (`application/vnd.docker.distribution.manifest.v2+json`).

**Impact:** Unable to deploy Lambda updates, production login broken due to separate module import issue that couldn't be fixed without deploying new Lambda image.

**Resolution:** Use `docker buildx build` with flags `--provenance=false --sbom=false --oci-mediatypes=false` to force Docker v2 manifest creation.

---

## Technical Details

### Symptom

Lambda deployment failed with error:
```
An error occurred (InvalidParameterValueException) when calling the UpdateFunctionCode operation:
The image manifest or layer media type for the source image
051826703172.dkr.ecr.us-east-1.amazonaws.com/credmate-backend:working is not supported.
```

### Root Cause Analysis

**Why Docker Desktop creates OCI manifests:**
- Docker Desktop 4.x+ includes BuildKit by default
- BuildKit creates OCI manifests when provenance/SBOM attestations are enabled (default)
- macOS Docker Desktop enables these attestations by default

**Why Lambda rejects OCI manifests:**
- AWS Lambda Runtime Interface Client expects Docker v2 manifest format
- Lambda doesn't support newer OCI image spec (as of 2025-12-28)
- Lambda documentation doesn't clearly state this requirement

**Detection:**
```bash
# Check manifest type of image in ECR
aws ecr batch-get-image --repository-name REPO_NAME \
  --image-ids imageTag=TAG \
  --query 'images[0].imageManifest' | jq -r . | jq -r '.mediaType'

# OCI manifest (BAD for Lambda):
application/vnd.oci.image.manifest.v1+json

# Docker v2 manifest (GOOD for Lambda):
application/vnd.docker.distribution.manifest.v2+json
```

### Failed Attempts

1. **Attempt: Disable BuildKit**
   ```bash
   export DOCKER_BUILDKIT=0
   docker build -t image:tag -f Dockerfile .
   ```
   **Result:** Still created OCI manifest (Docker Desktop overrides)

2. **Attempt: Use legacy builder explicitly**
   ```bash
   docker build --builder=default -t image:tag -f Dockerfile .
   ```
   **Result:** Still created OCI manifest

3. **Attempt: Build on Linux EC2 instance**
   **Result:** EC2 instance had detached root volume (separate infrastructure issue)

### Successful Solution

**Command:**
```bash
docker buildx build --platform linux/amd64 \
  --provenance=false \
  --sbom=false \
  --oci-mediatypes=false \
  -t 051826703172.dkr.ecr.us-east-1.amazonaws.com/credmate-backend:working \
  -f infra/lambda/Dockerfile.backend . \
  --load

docker push 051826703172.dkr.ecr.us-east-1.amazonaws.com/credmate-backend:working
```

**Flag Explanation:**
- `--platform linux/amd64`: Lambda runtime platform
- `--provenance=false`: Disable provenance attestation (prevents OCI manifest)
- `--sbom=false`: Disable SBOM attestation (prevents OCI manifest)
- `--oci-mediatypes=false`: Force Docker v2 manifest media types
- `--load`: Load image into local Docker (required for push)

**Verification:**
```bash
aws ecr batch-get-image --repository-name credmate-backend \
  --image-ids imageTag=working \
  --query 'images[0].imageManifest' | jq -r . | jq -r '.mediaType'

# Output: application/vnd.docker.distribution.manifest.v2+json ✅
```

---

## Timeline

| Time | Event |
|------|-------|
| 0:00 | User reports login failure with CORS errors |
| 0:20 | Identified root cause: Lambda ModuleNotFoundError (separate issue) |
| 0:25 | Fixed Dockerfile to copy correct paths |
| 0:30 | Built image, pushed to ECR |
| 0:35 | Lambda deployment FAILED: "manifest media type not supported" |
| 0:40 | Investigated manifest type, discovered OCI vs Docker v2 issue |
| 0:45 | Attempted DOCKER_BUILDKIT=0 fix (failed) |
| 0:50 | Attempted legacy builder (failed) |
| 0:55 | Considered EC2 build environment (infrastructure blocked) |
| 1:00 | Discovered `docker buildx` with provenance/sbom flags |
| 1:05 | Rebuilt with correct flags, verified manifest type |
| 1:10 | Deployed to Lambda successfully |
| 1:15 | Discovered secondary issue (missing Form import) |
| 1:20 | Fixed import, rebuilt, redeployed |
| 1:25 | Verified health and login endpoints working |
| 1:30 | Committed fixes, deployment complete |

---

## Resolution

### Immediate Fix (Deployed)

**1. Updated build process to use docker buildx:**
```bash
# New standard Lambda build command (macOS)
docker buildx build --platform linux/amd64 \
  --provenance=false --sbom=false --oci-mediatypes=false \
  -t $ECR_REGISTRY/credmate-backend:$TAG \
  -f infra/lambda/Dockerfile.backend . --load

docker push $ECR_REGISTRY/credmate-backend:$TAG
```

**2. Verified manifest type post-build:**
```bash
aws ecr batch-get-image --repository-name credmate-backend \
  --image-ids imageTag=$TAG \
  --query 'images[0].imageManifest' | jq -r . | jq -r '.mediaType'
```

### Long-Term Fixes (Recommended)

**1. Create Lambda build script** (`infra/scripts/build-lambda-image.sh`):
```bash
#!/bin/bash
set -e

SERVICE=$1  # backend, worker, frontend
TAG=${2:-latest}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com"

echo "Building Lambda image for $SERVICE with tag $TAG..."

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR_REGISTRY

# Build with Lambda-compatible manifest
docker buildx build --platform linux/amd64 \
  --provenance=false --sbom=false --oci-mediatypes=false \
  -t $ECR_REGISTRY/credmate-$SERVICE:$TAG \
  -f infra/lambda/Dockerfile.$SERVICE . --load

# Push to ECR
docker push $ECR_REGISTRY/credmate-$SERVICE:$TAG

# Verify manifest type
MANIFEST_TYPE=$(aws ecr batch-get-image \
  --repository-name credmate-$SERVICE \
  --image-ids imageTag=$TAG \
  --query 'images[0].imageManifest' | jq -r . | jq -r '.mediaType')

if [[ "$MANIFEST_TYPE" == "application/vnd.docker.distribution.manifest.v2+json" ]]; then
  echo "✅ Lambda-compatible Docker v2 manifest created"
else
  echo "❌ ERROR: Invalid manifest type: $MANIFEST_TYPE"
  exit 1
fi

echo "✅ Lambda image built and pushed: $ECR_REGISTRY/credmate-$SERVICE:$TAG"
```

**Usage:**
```bash
bash infra/scripts/build-lambda-image.sh backend working
bash infra/scripts/build-lambda-image.sh worker latest
bash infra/scripts/build-lambda-image.sh frontend v1.2.3
```

**2. Update build-containers skill** to use this script

**3. Add manifest type validation** to deployment workflow

**4. Document in KB** (see kb-lambda-docker-builds.md)

---

## Prevention Measures

### 1. Standardize Lambda Build Process

**Action:** Always use `infra/scripts/build-lambda-image.sh` for Lambda builds

**Enforcement:** Update `.claude/skills/build-containers/README.md` to use script by default

**Benefit:** Consistent manifest type across all environments

### 2. Pre-Deploy Validation

**Action:** Add manifest type check to pre-deploy checklist

**Implementation:**
```bash
# In deploy-to-production skill, before deployment:
echo "Verifying Lambda manifest type..."
MANIFEST_TYPE=$(aws ecr batch-get-image \
  --repository-name credmate-backend \
  --image-ids imageTag=$TAG \
  --query 'images[0].imageManifest' | jq -r . | jq -r '.mediaType')

if [[ "$MANIFEST_TYPE" != "application/vnd.docker.distribution.manifest.v2+json" ]]; then
  echo "❌ BLOCKED: Invalid manifest type for Lambda"
  echo "Rebuild with: bash infra/scripts/build-lambda-image.sh backend $TAG"
  exit 1
fi
```

### 3. Documentation

**Action:** Create KB entry documenting Lambda Docker requirements

**Location:** `docs/05-kb/infrastructure/kb-lambda-docker-builds.md`

**Content:** See KB section below

### 4. CI/CD Integration

**Action:** Add manifest type validation to GitHub Actions container-build workflow

**Benefit:** Catch incompatible manifests before manual deployment

---

## Related Issues

### Primary Incident
- **RIS-045-primary:** Lambda ModuleNotFoundError (Dockerfile COPY paths incorrect)
- **Resolution:** Fixed in same deployment as manifest type issue

### Similar Patterns
- **None found in RIS log** - First occurrence of manifest type issue

### Upstream AWS Issues
- AWS Lambda should document Docker v2 manifest requirement clearly
- Lambda could provide better error messages ("Use Docker v2 manifest" vs "media type not supported")

---

## Documentation Created

1. **Session File:** `docs/09-sessions/2025-12-28/SESSION-20251228-001-login-cors-lambda-deployment-fix.md`
2. **RIS Entry:** `docs/06-ris/resolutions/RIS-RESOLUTION-045-lambda-manifest-type-docker-macos.md` (this file)
3. **KB Article:** `docs/05-kb/infrastructure/kb-lambda-docker-builds.md` (pending)

---

## Lessons Learned

### 1. macOS Docker Desktop and Lambda Are Incompatible by Default

**Problem:** Docker Desktop enables provenance/SBOM by default → OCI manifests → Lambda rejects

**Solution:** ALWAYS use `docker buildx` with `--provenance=false --sbom=false --oci-mediatypes=false`

**Alternative:** Build on Linux (GitHub Actions, EC2, etc.)

### 2. Manifest Type Is Not Visible Without Inspection

**Problem:** `docker images` doesn't show manifest type, only visible via ECR API

**Solution:** Always verify manifest type after pushing to ECR:
```bash
aws ecr batch-get-image --repository-name REPO \
  --image-ids imageTag=TAG \
  --query 'images[0].imageManifest' | jq -r . | jq -r '.mediaType'
```

### 3. Lambda Error Messages Are Cryptic

**Problem:** "manifest media type not supported" doesn't mention Docker v2 vs OCI

**Solution:** Document this pattern in KB for future reference

### 4. Build Environment Matters

**Key insight:** Same Dockerfile + different build environment = different manifest type

**Recommendation:** Standardize build environment (Linux) or build flags (--provenance=false, etc.)

---

## Hot Pattern Entry

**Add to `.claude/memory/hot-patterns.md`:**

```markdown
## Lambda Deployment: "manifest media type not supported"

**Keywords:** lambda, manifest, media type, OCI, docker v2, InvalidParameterValueException

**Symptom:**
```
An error occurred (InvalidParameterValueException) when calling the UpdateFunctionCode operation:
The image manifest or layer media type for the source image is not supported.
```

**Root Cause:** Docker Desktop on macOS creates OCI manifest, Lambda requires Docker v2 manifest

**Solution:**
```bash
# Build with Lambda-compatible manifest
docker buildx build --platform linux/amd64 \
  --provenance=false --sbom=false --oci-mediatypes=false \
  -t $ECR_REGISTRY/credmate-backend:$TAG \
  -f infra/lambda/Dockerfile.backend . --load

# Verify manifest type
aws ecr batch-get-image --repository-name credmate-backend \
  --image-ids imageTag=$TAG \
  --query 'images[0].imageManifest' | jq -r . | jq -r '.mediaType'

# Should return: application/vnd.docker.distribution.manifest.v2+json
```

**Related:** RIS-045, kb-lambda-docker-builds.md
**Hit Count:** 1
**Last Used:** 2025-12-28
```

---

## References

**AWS Documentation:**
- [Lambda Container Images](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html)
- [Docker Image Manifest V2](https://docs.docker.com/registry/spec/manifest-v2-2/)

**Docker Documentation:**
- [docker buildx build](https://docs.docker.com/engine/reference/commandline/buildx_build/)
- [Provenance Attestations](https://docs.docker.com/build/attestations/slsa-provenance/)

**OCI Specification:**
- [OCI Image Format Spec](https://github.com/opencontainers/image-spec/blob/main/manifest.md)

**Internal Documentation:**
- Session: `docs/09-sessions/2025-12-28/SESSION-20251228-001-login-cors-lambda-deployment-fix.md`
- KB: `docs/05-kb/infrastructure/kb-lambda-docker-builds.md` (pending)
- Skills: `.claude/skills/build-containers/`, `.claude/skills/deploy-to-production/`

---

**Created By:** Claude Code Agent
**Reviewed By:** Pending
**Sign-Off:** Pending user confirmation
**Impact Assessment:** CRITICAL (production outage resolved)
**Recurrence Risk:** LOW (with prevention measures implemented)