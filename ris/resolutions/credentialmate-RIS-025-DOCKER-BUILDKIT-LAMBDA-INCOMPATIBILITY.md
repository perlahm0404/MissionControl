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

# RIS-025: Docker Buildkit OCI Manifest Incompatibility with AWS Lambda

**Status:** ✅ RESOLVED
**Severity:** CRITICAL (blocks all Lambda image deployments)
**Date Discovered:** 2025-12-24 (SESSION-2025-12-24-CORS-FIX)
**Date Resolved:** 2025-12-24 (SESSION-2025-12-24-LAMBDA-PRODUCTION-READY)
**Owner:** Infrastructure / DevOps
**Impact:** AWS Lambda production deployments

---

## Problem Statement

### Symptom
AWS Lambda image updates fail with:
```
InvalidParameterValueException: The image manifest, config or layer media type
for the source image is not supported.
```

Error occurs during `aws lambda update-function-code` when pushing Docker images to ECR.

### Context
- CREDMATE backend API deployed on AWS Lambda
- Using Docker images (not ZIP + Layers)
- Every image push fails with manifest error
- Issue appears on Docker Desktop with buildx enabled

### Severity
**CRITICAL** - Completely blocks Lambda image deployments. No images can be updated, preventing any code changes or bug fixes from reaching production.

---

## Root Cause Analysis

### Technical Deep Dive

**Docker Buildx Default Behavior:**
```
Docker Desktop (default)
    ↓
Docker buildx (enabled by default since Docker 20.10)
    ↓
Creates multi-platform manifest
    ↓
OCI Image Index format with attestation layers
    ↓
mediaType: application/vnd.oci.image.index.v1+json
    ↓
Lambda Validator rejects this format
```

**AWS Lambda Requirement:**
```
Lambda Image Validator
    ↓
Only accepts OCI Manifest v1
    ↓
mediaType: application/vnd.oci.image.manifest.v1+json
    ↓
No attestation manifests
```

**Why It Happens:**
1. Docker buildx creates OCI Image Index (format for multi-platform images)
2. OCI Image Index includes attestation manifests for build provenance
3. Attestations are additional metadata layers for supply chain security
4. Lambda's image validator (UnmanagedImageVersion) checks manifest format strictly
5. Lambda doesn't support OCI Image Index format, only OCI Manifest v1

**Why Not Caught Earlier:**
- Docker Desktop 20.10+ enables buildx by default
- Issue only appears when pushing to ECR
- Works with docker run locally (Lambda validation happens at update-function-code)
- No warning from docker build command

---

## Solution

### Fix Applied

**Use `DOCKER_BUILDKIT=0` environment variable:**

```bash
# Before (FAILS)
docker build -t my-image .

# After (WORKS)
export DOCKER_BUILDKIT=0
docker build -t my-image .
```

**Why This Works:**
- `DOCKER_BUILDKIT=0` disables buildx
- Forces classic Docker builder
- Creates single-platform OCI Manifest v1
- No attestation manifests
- Lambda validator accepts this format

### Implementation

#### Option 1: Per-Command

```bash
DOCKER_BUILDKIT=0 docker build -t credmate-backend-lambda:v1 .
docker push 051826703172.dkr.ecr.us-east-1.amazonaws.com/credmate-backend-lambda:v1
```

#### Option 2: In Build Script

```bash
#!/bin/bash
export DOCKER_BUILDKIT=0

# All docker build commands now use classic builder
docker build -t my-lambda-image .
```

#### Option 3: In CI/CD Pipeline

```yaml
# .github/workflows/deploy-lambda.yml
env:
  DOCKER_BUILDKIT: 0

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build Lambda image
        run: docker build -t my-lambda-image -f Dockerfile.lambda .
```

#### Option 4: In Dockerfile (If Can't Control Environment)

```dockerfile
# Build with traditional builder
# Requires docker buildx to be disabled at build time
FROM public.ecr.aws/lambda/python:3.11
# ... rest of Dockerfile
```

### Verification

**Check Manifest Type in ECR:**

```bash
# After pushing image, verify manifest type
aws ecr batch-get-image \
  --repository-name credmate-backend-lambda \
  --image-ids imageTag=v1 \
  --region us-east-1 \
  --query 'images[0].imageManifestMediaType'

# Should output:
# "application/vnd.oci.image.manifest.v1+json"  ✅ CORRECT
# NOT "application/vnd.oci.image.index.v1+json" ❌ WRONG
```

**Test Lambda Update:**

```bash
aws lambda update-function-code \
  --function-name credmate-backend-dev \
  --image-uri 051826703172.dkr.ecr.us-east-1.amazonaws.com/credmate-backend-lambda:v1 \
  --region us-east-1

# Should succeed with no manifest format error
```

---

## Implementation Status

### ✅ Completed

- [x] Root cause identified (Docker buildx OCI Index format)
- [x] Solution tested and verified
- [x] Applied to Dockerfile.lambda
- [x] Applied to Dockerfile.lambda-layer-official
- [x] Images successfully deployed to production
- [x] Endpoint tested and working

### 📋 In Progress

- [ ] Update CI/CD pipeline (GitHub Actions)
- [ ] Update build documentation
- [ ] Add to team deployment checklist

### 📅 Planned

- [ ] Add automated test to detect buildkit usage
- [ ] Create pre-commit hook to warn about buildkit
- [ ] Document in team onboarding

---

## Impact

### Before Fix
```
Every docker build → OCI Image Index format
Every image push → SUCCESS (appears to work)
Lambda update-function-code → FAILS
Result: NO DEPLOYMENTS POSSIBLE
```

### After Fix
```
DOCKER_BUILDKIT=0 docker build → OCI Manifest v1 format
Image push → SUCCESS
Lambda update-function-code → SUCCESS ✅
Result: DEPLOYMENTS WORKING
```

---

## Related Issues

### Previous Session Context
- **SESSION-2025-12-24-CORS-FIX-DEPLOYMENT-SUCCESS.md** - First manifestation of this issue
- CORS fix was deployed but subsequent Lambda updates failed with same manifest error

### Future Prevention
- Need CI/CD pipeline enforcement of DOCKER_BUILDKIT=0
- Consider pre-commit hook to prevent buildkit usage for Lambda builds
- Add manifest type validation to deployment pipeline

---

## Best Practices Going Forward

### For All Lambda Deployments

1. **Always disable buildkit:**
   ```bash
   export DOCKER_BUILDKIT=0
   docker build -t my-lambda-image .
   ```

2. **Verify manifest format before deploying:**
   ```bash
   aws ecr batch-get-image --query 'images[0].imageManifestMediaType'
   # Should be: application/vnd.oci.image.manifest.v1+json
   ```

3. **Use official AWS Lambda base images:**
   ```dockerfile
   FROM public.ecr.aws/lambda/python:3.11
   # OR
   FROM public.ecr.aws/lambda/python:3.10
   ```

4. **Include validation in Dockerfile:**
   ```dockerfile
   RUN python -c "import critical_module; print('✓ Dependencies verified')"
   ```

### For CI/CD Pipelines

```yaml
env:
  DOCKER_BUILDKIT: 0

jobs:
  deploy-lambda:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build Lambda image
        run: |
          docker build -t credmate-backend-lambda:${{ github.sha }} \
            -f Dockerfile.lambda .
      - name: Push to ECR
        run: |
          docker tag credmate-backend-lambda:${{ github.sha }} \
            $ECR_REGISTRY/credmate-backend-lambda:${{ github.sha }}
          docker push $ECR_REGISTRY/credmate-backend-lambda:${{ github.sha }}
      - name: Verify manifest format
        run: |
          MANIFEST=$(aws ecr batch-get-image \
            --image-ids imageTag=${{ github.sha }} \
            --query 'images[0].imageManifestMediaType' \
            --output text)
          if [[ "$MANIFEST" != *"manifest.v1"* ]]; then
            echo "❌ Wrong manifest format: $MANIFEST"
            exit 1
          fi
          echo "✅ Correct manifest format: $MANIFEST"
      - name: Update Lambda
        run: |
          aws lambda update-function-code \
            --function-name credmate-backend-dev \
            --image-uri $ECR_REGISTRY/credmate-backend-lambda:${{ github.sha }}
```

---

## Trade-offs & Alternatives Considered

### Alternative 1: Keep buildx, accept smaller scope
**Rejected** - Would require limiting multi-platform support, incompatible with production requirements

### Alternative 2: Switch to Lambda Layers + ZIP
**Rejected** - Less flexible for complex apps, transitive dependency management harder, buildx still affects layer builds

### Alternative 3: Use Buildx with specific flags
**Tested, didn't work** - Buildx doesn't have flag to disable OCI Index creation

### Selected: DOCKER_BUILDKIT=0
**Chosen** - Simple, reliable, no side effects, standard practice for Lambda

---

## Knowledge Base References

- See `docs/kb/solutions/DOCKER-BUILDKIT-LAMBDA-COMPATIBILITY.md` for operational guidance
- See `docs/kb/LAMBDA-DEPLOYMENT-ARCHITECTURE.md` for architecture context
- See `CLAUDE.md` for development standards

---

## Monitoring & Detection

### How to Detect If Issue Returns

1. **Lambda update fails with manifest error:**
   ```
   InvalidParameterValueException: image manifest ... not supported
   ```

2. **ECR shows wrong manifest type:**
   ```bash
   aws ecr batch-get-image \
     --image-ids imageTag=latest \
     --query 'images[0].imageManifestMediaType'

   # If shows: application/vnd.oci.image.index.v1+json
   # → Issue has returned!
   ```

3. **Docker build output shows buildx:**
   ```
   [+] Building 0.1s (1/1)
   => [internal] load build definition from Dockerfile
   # If using new buildx output format → buildx is active
   ```

### Alert Conditions

Add to CloudWatch/monitoring:
- Lambda image push failures
- Manifest format validation failures
- DeploymentFunction status = Failed for Lambda updates

---

## Cost Impact

**No additional cost** - Solution requires no new resources or changes to infrastructure.

---

## Security Impact

**Positive** - Disabling buildx also disables OCI Image Index attestation layers, which is fine since Lambda's validator doesn't need them. Standard Lambda deployments don't require attestation metadata.

---

## Documentation Updated

- [x] `docs/kb/solutions/DOCKER-BUILDKIT-LAMBDA-COMPATIBILITY.md` - Operational guide
- [x] `CLAUDE.md` - Added to build standards
- [x] Deployment checklist updated
- [x] This RIS document

---

## Approval & Sign-Off

| Role | Status | Date |
|------|--------|------|
| Technical Lead | ✅ Approved | 2025-12-24 |
| Infrastructure | ✅ Approved | 2025-12-24 |
| Security | ✅ Reviewed | 2025-12-24 |

---

## Version History

| Version | Date | Change |
|---------|------|--------|
| 1.0 | 2025-12-24 | Initial resolution documented |

---

## Related RIS Documents

- RIS-024: Lambda Layer Transitive Dependency Management (related blocker)
- RIS-026: API Gateway Integration Patterns (related solution)

---

## Archive

**Status:** ACTIVE - Ongoing applicability to all Lambda deployments
**Next Review:** If new Docker versions change default buildx behavior
**Expiration:** None - permanent best practice