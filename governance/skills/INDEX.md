# MissionControl Skill Registry

**Authority**: MissionControl Governance
**Version**: 1.1
**Last Updated**: 2026-01-18

---

## Overview

This registry defines skill SPECIFICATIONS - what each skill does, its constraints, and autonomy requirements. Implementations live in their respective repositories.

**Key Distinction**:
- **Definition** (here): WHAT a skill does, constraints, required behaviors
- **Implementation** (app repos): HOW the skill executes, repo-specific details

---

## Skill Categories

| Category | Purpose | Typical Autonomy |
|----------|---------|------------------|
| **Session Management** | Session lifecycle | L1 |
| **Validation** | Code/schema/compliance checks | L2 |
| **Golden Path** | End-to-end workflow verification | L2 |
| **Development** | Build, lint, test workflows | L2-L3 |
| **Infrastructure** | Container/environment management | L3 |
| **Deployment** | Production release workflows | L4 |
| **Database** | Database operations | L4 |
| **Emergency** | Incident response, rollback | L4 |

---

## 1. Session Management Skills (L1)

### start-session
**Purpose**: Initialize agent session with proper documentation
**Trigger**: "start session", "new session", session start
**Requirements**:
- Create session file with timestamp
- Load CONTEXT.md or CLAUDE.md
- Promote agent to L1 autonomy
**Implementations**: credentialmate, karematch

### close-session
**Purpose**: Properly close session with documentation
**Trigger**: "close session", "end session"
**Requirements**:
- Generate session summary
- Commit changes if applicable
- Create handoff notes
**Implementations**: credentialmate, karematch

### query-agent-memory
**Purpose**: Search historical context
**Trigger**: "search memory", "query memory"
**Requirements**:
- Search hot-patterns
- Search recent sessions
- Search RIS resolutions
**Implementations**: credentialmate

---

## 2. Validation Skills (L2)

### backend-validator
**Purpose**: Validate Python backend code
**Trigger**: "validate backend", "lint python"
**Requirements**:
- Run linters (ruff, flake8)
- Run type checkers (mypy)
- Report violations
**Implementations**: credentialmate

### frontend-build-validator
**Purpose**: Validate frontend build process
**Trigger**: "validate frontend build"
**Requirements**:
- Run npm/pnpm build
- Check for TypeScript errors
- Verify bundle integrity
**Implementations**: credentialmate

### validate-naming
**Purpose**: Cross-layer naming consistency
**Trigger**: "validate naming", "check naming"
**Requirements**:
- Check API endpoint naming
- Check database column naming
- Check frontend prop naming
**Implementations**: credentialmate

### validate-schema-before-deploy
**Purpose**: Pre-deployment schema validation
**Trigger**: "validate schema before deploy", auto-triggered by deploy
**Requirements**:
- Compare local schema to production
- BLOCK deployment if drift detected
- Report specific differences
**Implementations**: credentialmate

### config-drift-detector
**Purpose**: Environment configuration parity
**Trigger**: "config drift", "env mismatch"
**Requirements**:
- Compare local .env to production
- Report missing/different variables
- BLOCK deployment if critical drift
**Implementations**: credentialmate

### cors-checker
**Purpose**: CORS configuration validation
**Trigger**: "check cors", "cors error"
**Requirements**:
- Validate CORS origins
- Check allowed headers
- Test preflight requests
**Implementations**: credentialmate

### tdd-enforcer
**Purpose**: Enforce RED-GREEN-REFACTOR workflow
**Trigger**: Auto-activated on "implement", "create", "fix"
**Requirements**:
- BLOCK code changes without failing test first
- Verify test passes after implementation
- Allow refactor only with passing tests
**Implementations**: karematch

### governance-enforcer
**Purpose**: Proactive governance compliance
**Trigger**: Auto-activated on governance-related tasks
**Requirements**:
- Check naming conventions
- Validate file locations
- Verify document headers
**Implementations**: karematch

---

## 3. Golden Path Skills (L2)

### verify-golden-path
**Purpose**: End-to-end workflow validation
**Trigger**: "verify golden path", "smoke test"
**Requirements**:
- Execute critical user journey
- Validate each step
- Report failures with diagnostics
**Implementations**: credentialmate

### pipeline-test-chain
**Purpose**: Comprehensive pipeline testing
**Trigger**: "test pipeline", "comprehensive check"
**Requirements**:
- Run golden path verification
- Run debug diagnostics
- Run API tests
**Implementations**: credentialmate

### debug-pipeline
**Purpose**: Pipeline issue diagnosis
**Trigger**: "debug pipeline", "diagnose pipeline"
**Requirements**:
- Trace request flow
- Identify failure points
- Suggest remediation
**Implementations**: credentialmate

### health-check-monitor
**Purpose**: Service health monitoring
**Trigger**: "check health", "monitor services"
**Requirements**:
- Check all service endpoints
- Report unhealthy services
- Provide recovery suggestions
**Implementations**: credentialmate

---

## 4. Development Skills (L2-L3)

### rebuild (L2)
**Purpose**: Development environment rebuild
**Trigger**: "/rebuild", "rebuild dev"
**Requirements**:
- Clean caches
- Reinstall dependencies
- Start services
- Validate health
**Implementations**: karematch

### rebuild-docker (L2)
**Purpose**: Docker-based environment rebuild
**Trigger**: "/rebuild --docker"
**Requirements**:
- Stop containers
- Optionally remove volumes
- Rebuild images if needed
- Start and validate
**Implementations**: karematch

### lint-ui (L2)
**Purpose**: Frontend code linting
**Trigger**: "lint ui", "check ui code"
**Requirements**:
- Run ESLint
- Run Prettier
- Auto-fix where possible
**Implementations**: credentialmate

### scaffold-ui (L3)
**Purpose**: Generate UI components from patterns
**Trigger**: "scaffold ui", "build form"
**Requirements**:
- Select appropriate pattern
- Generate component code
- Wire to render path
**Implementations**: credentialmate

### ui-changes (L1)
**Purpose**: Safe UI modification workflow
**Trigger**: Auto-activated on UI changes
**Requirements**:
- Locate route → page → component chain
- Document modification plan
- Wire new components properly
**Implementations**: karematch

### dev-auth (L1)
**Purpose**: Development authentication role switching
**Trigger**: "/dev-auth <role>"
**Requirements**:
- Validate development environment
- Update .env safely
- Refuse in production
**Implementations**: karematch

### impersonate (L1)
**Purpose**: Actor impersonation for testing
**Trigger**: "/impersonate <role> <id>"
**Requirements**:
- Validate development environment
- Set impersonation variables
- Maintain audit trail
**Implementations**: karematch

---

## 5. Infrastructure Skills

### Session Infrastructure (L2)

#### checkpoint-reminder
**Purpose**: Prevent context loss by reminding Claude to checkpoint progress
**Trigger**: Automatic after N file operations (threshold: 10-20)
**Requirements**:
- Track Write/Edit operation count
- Display reminder banner at threshold
- Auto-trigger state-sync when STATE.md modified
- Reset counter after checkpoint complete
**Implementations**: ai_orchestrator, karematch, credentialmate
**Version**: v1.1 (2026-01-18)

#### state-sync
**Purpose**: Cross-repo memory synchronization
**Trigger**: Manual (`python utils/state_sync.py sync <repo>`), Auto (via checkpoint hook)
**Requirements**:
- Sync STATE.md to other repos' .aibrain/global-state-cache.md
- Support distributed architecture (no central registry)
- Preserve section formatting in cache files
- Update timestamps on sync
**Implementations**: ai_orchestrator, karematch, credentialmate
**Version**: v1.0 (2026-01-18)

---

### Development Environment (L3)

#### start-local-dev
**Purpose**: Start local development environment
**Trigger**: "start dev", "spin up"
**Requirements**:
- Verify prerequisites
- Start containers/services
- Validate health
**Implementations**: credentialmate

### local-dev-hybrid
**Purpose**: Hybrid Docker + local development
**Trigger**: "/local-dev-hybrid", "start hybrid dev"
**Requirements**:
- Start Docker infrastructure
- Start local application servers
- Enable hot reload
**Implementations**: karematch

### build-containers
**Purpose**: Build and push Docker images
**Trigger**: "build containers", "push to ECR"
**Requirements**:
- Build images with correct tags
- Push to registry
- Verify image manifests
**Implementations**: credentialmate

### rebuild-frontend
**Purpose**: Targeted frontend container rebuild
**Trigger**: "rebuild frontend"
**Requirements**:
- Rebuild only frontend container
- Preserve other containers
- Validate after rebuild
**Implementations**: credentialmate

### switch-frontend-mode
**Purpose**: Toggle frontend dev/prod mode
**Trigger**: "switch to hot reload"
**Requirements**:
- Update configuration
- Restart frontend container
- Validate mode switch
**Implementations**: credentialmate

---

## 6. Deployment Skills (L4)

### deploy-to-production
**Purpose**: Full production deployment
**Trigger**: "deploy to prod", "ship to prod"
**Requirements**:
- Validate schema (BLOCKING)
- Build artifacts
- Deploy with health checks
- Document in RIS
**Constraint**: REQUIRES human approval
**Implementations**: credentialmate

### deploy-lambda
**Purpose**: AWS Lambda deployment
**Trigger**: "deploy lambda", "sam deploy"
**Requirements**:
- Build with container
- Deploy via SAM
- Verify function health
**Implementations**: credentialmate

### deploy-production (karematch)
**Purpose**: Karematch production deployment
**Trigger**: "deploy production"
**Requirements**:
- Run validation chain
- Deploy infrastructure
- Verify health
**Implementations**: karematch

### lambda-deploy-chain
**Purpose**: Validated Lambda deployment workflow
**Trigger**: "deploy lambda chain", "validated lambda deploy"
**Requirements**:
- Backend validation
- Schema validation
- Deploy
- Verify
- Auto-rollback on failure
**Implementations**: credentialmate

### full-release-chain
**Purpose**: Complete release workflow
**Trigger**: "full release", "production release"
**Requirements**:
- Frontend + backend validation
- Schema validation
- Deploy all components
- Full verification
**Implementations**: credentialmate

---

## 7. Database Skills (L4)

### query-production-db
**Purpose**: Read-only production queries
**Trigger**: "query production", "what's in prod"
**Requirements**:
- SELECT queries only
- No modification allowed
- Audit logging
**Implementations**: credentialmate

### execute-production-sql
**Purpose**: Production SQL with audit
**Trigger**: "execute production sql"
**Requirements**:
- INSERT/UPDATE only (no DELETE)
- Full audit trail
- Human approval required
**Implementations**: credentialmate

### apply-production-migrations
**Purpose**: Production database migrations
**Trigger**: "apply production migrations"
**Requirements**:
- 5-stage safety protocol
- Backup before migration
- Human approval required
**Implementations**: credentialmate

### request-database-deletion-approval
**Purpose**: Database deletion workflow
**Trigger**: Auto-triggered by deletion attempt
**Requirements**:
- Full 5-layer workflow
- Typed human approval
- Audit trail
**Constraint**: MANDATORY for all deletions
**Implementations**: credentialmate

### database-migrations (karematch)
**Purpose**: Karematch database migration management
**Trigger**: "run migrations", "database migrations"
**Requirements**:
- Validate migration files
- Run in transaction
- Verify schema after
**Implementations**: karematch

---

## 8. Emergency Skills (L4)

### rollback-lambda
**Purpose**: Quick Lambda version rollback
**Trigger**: "rollback lambda", "revert lambda"
**Requirements**:
- List available versions
- Update alias
- Verify rollback
**Time**: <3 minutes
**Implementations**: credentialmate

### hotfix-chain
**Purpose**: Emergency fix workflow
**Trigger**: "hotfix", "emergency fix"
**Requirements**:
- Create fix branch
- Implement fix (max 3 files, 50 lines)
- Quick validation
- Deploy
- Create PR
**Time**: ~15-20 minutes
**Implementations**: credentialmate

### incident-response-chain
**Purpose**: Production incident handling
**Trigger**: "production down", "incident", "outage"
**Requirements**:
- Assess severity
- Triage components
- Diagnose root cause
- Resolve
- Document in RIS
**Target MTTR**: <15 minutes
**Implementations**: credentialmate

---

## 9. Diagnostic Skills (L2)

### diagnose-build
**Purpose**: Build issue diagnosis
**Trigger**: "diagnose build", "build failing"
**Requirements**:
- Check build output
- Identify failure cause
- Suggest fix
**Implementations**: karematch

### diagnose-docker
**Purpose**: Docker issue diagnosis
**Trigger**: "diagnose docker", "container issues"
**Requirements**:
- Check container status
- Review logs
- Identify issues
**Implementations**: karematch

### diagnose-schema
**Purpose**: Database schema diagnosis
**Trigger**: "diagnose schema", "schema issues"
**Requirements**:
- Compare schema versions
- Identify drift
- Suggest resolution
**Implementations**: karematch

### signup-debugger
**Purpose**: User signup issue debugging
**Trigger**: "signup not working", "registration broken"
**Requirements**:
- Trace signup flow
- Check database state
- Identify blockers
**Implementations**: karematch

---

## Autonomy Level Summary

| Level | Skills |
|-------|--------|
| **L1** | start-session, close-session, query-agent-memory, dev-auth, impersonate, tdd-enforcer, governance-enforcer, ui-changes |
| **L2** | backend-validator, frontend-build-validator, validate-naming, validate-schema-before-deploy, config-drift-detector, cors-checker, verify-golden-path, pipeline-test-chain, debug-pipeline, health-check-monitor, rebuild, rebuild-docker, lint-ui, diagnose-build, diagnose-docker, diagnose-schema, signup-debugger |
| **L3** | start-local-dev, local-dev-hybrid, build-containers, rebuild-frontend, switch-frontend-mode, scaffold-ui |
| **L4** | deploy-to-production, deploy-lambda, deploy-production, lambda-deploy-chain, full-release-chain, query-production-db, execute-production-sql, apply-production-migrations, request-database-deletion-approval, database-migrations, rollback-lambda, hotfix-chain, incident-response-chain |

---

## Implementation References

### credentialmate Skills
Path: `/Users/tmac/1_REPOS/credentialmate/.claude/skills/`
Index: `/Users/tmac/1_REPOS/credentialmate/.claude/skills/INDEX.md`
Count: ~54 skills

### karematch Skills
Path: `/Users/tmac/1_REPOS/karematch/.claude/skills/`
Index: `/Users/tmac/1_REPOS/karematch/.claude/skills/INDEX.md`
Count: ~25 skills

---

## Adding New Skills

When creating a new skill:

1. **Define** in this registry first (WHAT it does)
2. **Implement** in the appropriate repo (HOW it works)
3. **Register** in the repo's local INDEX.md
4. **Document** constraints and autonomy level
5. **Test** skill execution
6. **Update** this registry with implementation reference

### Skill Definition Template

```yaml
skill_name:
  purpose: "What the skill accomplishes"
  trigger: "Commands/keywords that activate it"
  autonomy: L0-L4
  requirements:
    - Required behavior 1
    - Required behavior 2
  constraints:
    - What is NOT allowed
  human_approval: yes|no
  implementations:
    - repo: repository_name
      path: .claude/skills/skill_name/
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-16 | Initial consolidated registry |
