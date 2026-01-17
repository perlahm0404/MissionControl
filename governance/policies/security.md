# Security Policy

**Authority**: MissionControl Governance Policy
**Version**: 1.0
**Last Updated**: 2026-01-16
**Applies To**: All managed repositories

---

## Overview

This policy defines security requirements for AI agent operations across all managed repositories. These rules implement the Constitutional Principles for secrets management, protected files, and human-in-the-loop gates.

---

## 1. Secrets Management

### Rule: NEVER Hardcode Secrets

| Secret Type | Allowed Location | Enforcement |
|-------------|------------------|-------------|
| Local development | `.env.local` files (gitignored) | Pre-commit hook |
| CI/CD pipelines | GitHub Secrets / CI environment | Workflow validation |
| Staging | AWS Secrets Manager / equivalent | Deployment check |
| Production | AWS Secrets Manager / HashiCorp Vault | Deployment check |

### Secret Patterns (Auto-Detected)

```python
# Patterns that trigger secret detection
SECRET_PATTERNS = [
    r'(?i)(api[_-]?key|apikey)\s*[=:]\s*["\']?[a-zA-Z0-9]{20,}',
    r'(?i)(secret|password|passwd|pwd)\s*[=:]\s*["\'][^"\']+',
    r'(?i)(token)\s*[=:]\s*["\']?[a-zA-Z0-9_-]{20,}',
    r'(?i)(connection[_-]?string|connstr)\s*[=:]\s*["\'][^"\']+',
    r'(?i)(private[_-]?key)\s*[=:]\s*["\'][^"\']+',
    r'sk-[a-zA-Z0-9]{20,}',  # OpenAI-style keys
    r'ghp_[a-zA-Z0-9]{36}',  # GitHub PAT
    r'AKIA[A-Z0-9]{16}',     # AWS Access Key
]
```

### Secret Exposure Response Protocol

If an agent detects exposed secrets:

1. **STOP**: Halt current operation immediately
2. **ALERT**: Output warning to session
3. **NEVER COMMIT**: Block any commit containing secret
4. **REPORT**: Log detection to security audit
5. **RECOMMEND**: Suggest remediation steps

```markdown
## SECURITY ALERT: Exposed Secret Detected

**File**: {filename}
**Line**: {line_number}
**Type**: {secret_type}

**Action Required**:
1. Remove the secret from the file
2. Use environment variable instead: `os.getenv('{ENV_VAR_NAME}')`
3. If secret was previously committed, rotate the credential immediately
4. Add file pattern to .gitignore if appropriate

**This commit has been BLOCKED.**
```

---

## 2. Human-in-the-Loop Gates

High-impact actions MUST require human approval regardless of agent autonomy level.

### Mandatory Approval Actions

| Action | Approval Format | Timeout |
|--------|-----------------|---------|
| Database deletions | Full 5-layer workflow | 24 hours |
| Production deployments | "APPROVED TO DEPLOY TO PRODUCTION" | 1 hour |
| Force pushes | Explicit in original task | N/A |
| Schema migrations (prod) | Deployment checklist signed | 24 hours |
| New AWS resources | Business case approved | 24 hours |
| Security permission changes | Access change request | 24 hours |
| API key rotation | Explicit approval | 1 hour |
| User data export | Data access request | 24 hours |

### Approval Validation

```python
# Valid approval must match exact pattern
APPROVAL_PATTERNS = {
    "production_deploy": r"APPROVED TO DEPLOY TO PRODUCTION",
    "database_delete": r"I APPROVE \w+ DELETION OF .+",
    "schema_migration": r"MIGRATION APPROVED FOR \w+",
    "aws_provision": r"AWS RESOURCE APPROVED: .+",
}

# These are NEVER valid
INVALID_APPROVALS = ["yes", "ok", "approved", "y", "sure", "do it"]
```

---

## 3. Protected Files Policy

Certain files require explicit approval before modification due to their system-wide impact.

### Category 1: Infrastructure Files

| Pattern | Impact if Modified |
|---------|-------------------|
| `docker-compose.yml` | All containers |
| `docker-compose.*.yml` | Environment-specific containers |
| `Dockerfile*` | Build process |
| `.github/workflows/*.yml` | CI/CD pipelines |
| `*.tf` / `*.tfvars` | Infrastructure as code |
| `serverless.yml` | Serverless deployments |

### Category 2: Database Files

| Pattern | Impact if Modified |
|---------|-------------------|
| `alembic/versions/*.py` | Database schema |
| `migrations/*.py` | Database schema |
| `**/schema.prisma` | Database schema |
| `seeds/*.sql` | Reference data |

### Category 3: Security Files

| Pattern | Impact if Modified |
|---------|-------------------|
| `**/auth/*` | Authentication |
| `**/authorization/*` | Authorization |
| `**/permissions/*` | Access control |
| `**/encryption/*` | Data protection |
| `.env.production` | Production config |
| `*.pem` / `*.key` | Certificates |

### Category 4: SSOT Files (Single Source of Truth)

Repositories define their SSOT files in configuration. Common patterns:

| Type | Impact if Modified |
|------|-------------------|
| Master CSV/JSON files | Downstream regeneration required |
| Config YAML files | System behavior |
| Rule definition files | Business logic |

### Pre-Modification Warning Requirement

Before modifying ANY protected file, agent MUST output:

```markdown
## Protected File Modification Request

**File**: {file_path}
**Category**: {infrastructure|database|security|ssot}
**Change**: {description of change}
**Impact**: {what breaks if this goes wrong}

**Approval Required**: {yes|no based on autonomy level}
```

---

## 4. Configuration Drift Policy

### Rule: NEVER Deploy Without Configuration Sync

Production configuration MUST match repository configuration.

### Pre-Deployment Check

```bash
# Conceptual check (implementation varies)
config_drift_check:
  - Compare local .env.example with production env vars
  - Compare local docker-compose with production compose
  - Verify all required secrets exist in production
  - Check infrastructure matches terraform state
```

### Drift Response

| Drift Type | Action |
|------------|--------|
| Missing env var | BLOCK deployment |
| Extra env var (prod only) | WARN, allow deployment |
| Value mismatch | BLOCK, require sync decision |
| Infrastructure drift | BLOCK, require reconciliation |

---

## 5. Environment Variable Sync Policy

### Rule: Variables Added Locally MUST Exist in Target Before Deploy

### Critical Variable Categories

| Category | Risk if Missing |
|----------|-----------------|
| `NEXT_PUBLIC_*` | Frontend 404/undefined errors |
| `API_*` / `*_URL` | Backend connection failures |
| `CORS_*` | Cross-origin request blocks |
| `JWT_*` / `AUTH_*` | Authentication failures |
| `DATABASE_*` | Database connection failures |
| `AWS_*` | Cloud service failures |

### Sync Verification

Before deployment:
1. Extract all env vars from code
2. Compare with target environment
3. BLOCK if any REQUIRED var is missing
4. WARN if any OPTIONAL var is missing
5. Document any new vars in deployment notes

---

## 6. HIPAA-Specific Security (When Applicable)

Repositories marked with HIPAA compliance have additional requirements.

### PHI (Protected Health Information) Rules

```yaml
# HIPAA repository indicator
compliance:
  hipaa: true
  phi_patterns:
    - patient_name
    - date_of_birth
    - ssn
    - medical_record
    - diagnosis
    - treatment
```

### Forbidden Actions in HIPAA Repos

1. **PHI in logs**: Never log PHI, even at DEBUG level
2. **PHI in URLs**: Never include PHI in URL parameters
3. **PHI in errors**: Sanitize error messages
4. **Unencrypted PHI**: Always encrypt in transit and at rest
5. **PHI export**: Requires data access request approval

### Required Actions in HIPAA Repos

1. **Audit logging**: All PHI access logged
2. **Session timeout**: Auto-logout after inactivity
3. **Access review**: Periodic access audits
4. **Minimum necessary**: Only access required PHI

---

## 7. Repository Implementation Requirements

Each repository must have:

```yaml
# .claude/security.yaml
version: "1.0"
extends: "MissionControl/governance/policies/security.md"

secrets:
  detection: enabled
  pre_commit_hook: .claude/hooks/scripts/secret-scanner.py

protected_files:
  infrastructure: [docker-compose.yml, .github/workflows/*]
  database: [alembic/versions/*, migrations/*]
  security: [auth/*, .env.production]
  ssot: [] # Repository-specific

drift_check:
  enabled: true
  environments: [staging, production]

hipaa:
  enabled: false  # Set to true for HIPAA repos
```

---

## 8. Security Incident Response

If a security incident is detected (exposed secret, unauthorized access, etc.):

### Immediate Actions
1. **Stop**: Halt related operations
2. **Contain**: Prevent further exposure
3. **Document**: Log incident details
4. **Escalate**: Notify human immediately

### RIS Entry Required
```yaml
type: security-incident
severity: critical|high|medium|low
detected_at: timestamp
description: what happened
impact: what was affected
remediation: what was done
prevention: how to prevent recurrence
```
