# Skills Governance Classification

**Date**: 2026-01-16
**Assessment Type**: READ-ONLY Policy Mapping
**Scope**: AI_Orchestrator, KareMatch, CredentialMate repositories
**Total Skills Classified**: 36

---

## Section A — Classification Table

| Skill Name | Domain | Authority Level | Governance Boundary | Rationale |
|------------|--------|-----------------|---------------------|-----------|
| **AI_Orchestrator** |||||
| autonomous-credentialmate | Orchestration | L2 | APP-LOCAL | Explicitly coupled to CredentialMate agent session lifecycle |
| autonomous-karematch | Orchestration | L2 | APP-LOCAL | Explicitly coupled to KareMatch agent session lifecycle |
| app-advisor | Advisory | L1 | MISSION-CONTROL | Generic architecture consultation with no app coupling |
| data-advisor | Advisory | L1 | MISSION-CONTROL | Generic database/schema consultation with no app coupling |
| uiux-advisor | Advisory | L1 | MISSION-CONTROL | Generic UI/UX consultation with no app coupling |
| session-close | Session Mgmt | L2 | MISSION-CONTROL | Generic session termination workflow applicable across apps |
| **KareMatch** |||||
| auto-investigator | Diagnostics | Unknown | MISSION-CONTROL | Generic issue investigation pattern with no app-specific logic |
| autonomous-playwright-testing | Testing | L2 | APP-LOCAL | Tied to KareMatch E2E test suite and user flows |
| blog | Content | L1 | APP-LOCAL | KareMatch-specific content generation requirements |
| context-monitor | Session Mgmt | L1 | MISSION-CONTROL | Pure utility for context window tracking across any session |
| database-migrations | Database | L3 | APP-LOCAL | Prisma-specific migration workflow tied to KareMatch schema |
| deploy-production | Deployment | L3 | APP-LOCAL | KareMatch-specific deployment pipeline and infrastructure |
| deploy-seed-data | Database | L2 | APP-LOCAL | KareMatch-specific seed data and test fixtures |
| dev-auth | Auth | L1 | APP-LOCAL | KareMatch-specific authentication helpers and test users |
| diagnose-build | Diagnostics | L1 | MISSION-CONTROL | Generic build failure diagnosis applicable to any monorepo |
| diagnose-docker | Diagnostics | L1 | MISSION-CONTROL | Generic Docker troubleshooting with no app dependencies |
| diagnose-schema | Database | L2 | APP-LOCAL | Prisma-specific schema drift detection for KareMatch |
| governance-enforcer | Governance | L2 | MISSION-CONTROL | Generic policy enforcement pattern reusable across apps |
| handoff-builder | Session Mgmt | L1 | MISSION-CONTROL | Generic session handoff generation for any project |
| impersonate | Testing | L2 | APP-LOCAL | KareMatch-specific user impersonation for testing |
| local-dev-hybrid | Development | L1 | APP-LOCAL | KareMatch-specific Docker/local hybrid with hardcoded ports |
| plan-optimizer | Planning | L1 | MISSION-CONTROL | Generic token-budget-aware planning applicable anywhere |
| rebuild | Development | L2 | APP-LOCAL | KareMatch-specific error patterns and environment setup |
| resolve-test-ticket | Testing | L2 | APP-LOCAL | KareMatch-specific test escalation workflow |
| session-close | Session Mgmt | L2 | MISSION-CONTROL | Generic session close with verification applicable across apps |
| signup-debugger | Auth | L2 | APP-LOCAL | KareMatch-specific authentication flow debugging |
| tdd-enforcer | Testing | L2 | MISSION-CONTROL | Generic RED-GREEN-REFACTOR enforcement for any codebase |
| therapist-ui-refactor | Development | L2 | APP-LOCAL | KareMatch-specific multi-phase UI refactor project |
| ui-changes | Development | L1 | APP-LOCAL | KareMatch-specific React/Vite preflight checklist |
| **CredentialMate** |||||
| dash | Documentation | L1 | APP-LOCAL | CredentialMate-specific dashboard documentation generator |
| deploy-lambda | Deployment | L3 | APP-LOCAL | CredentialMate-specific SAM Lambda deployment |
| deploy-ec2-fallback | Deployment | L4 | EMERGENCY-ONLY | Production EC2 fallback with break-glass authority |
| lambda-deploy-chain | Deployment | L4 | APP-LOCAL | CredentialMate-specific orchestrated deployment chain |
| rollback-lambda | Deployment | L4 | EMERGENCY-ONLY | Production rollback capability with immediate effect |
| hotfix-chain | Deployment | L4 | EMERGENCY-ONLY | Emergency hotfix workflow bypassing standard validation |

---

## Section B — Boundary Pressure Summary

### Borderline Classifications

- **session-close** (both versions): Exists in AI_Orchestrator and KareMatch with different structures; classified MISSION-CONTROL but dual existence creates ownership ambiguity
- **diagnose-build**: Classified MISSION-CONTROL but contains some turborepo-specific patterns that may limit generalization
- **tdd-enforcer**: Classified MISSION-CONTROL but references KareMatch-specific test tooling (Vitest) in examples
- **governance-enforcer**: Classified MISSION-CONTROL but currently resides in KareMatch repository
- **database-migrations**: Classified APP-LOCAL but pattern is generalizable if Prisma references were parameterized
- **rebuild**: Classified APP-LOCAL but error pattern detection could be extracted to MISSION-CONTROL

### Authority Level Mismatches

- **lambda-deploy-chain**: L4 authority but classified APP-LOCAL (not EMERGENCY-ONLY) due to being standard deployment path
- **deploy-production** (KareMatch): L3 authority with production impact but no explicit approval gates documented
- **impersonate**: L2 authority but security/audit logging not enforced for user impersonation
- **diagnose-schema**: L2 authority but can detect production schema drift without approval

### Location vs Boundary Mismatches

| Skill | Current Location | Classified Boundary | Mismatch Type |
|-------|------------------|---------------------|---------------|
| governance-enforcer | KareMatch | MISSION-CONTROL | Should be shared |
| tdd-enforcer | KareMatch | MISSION-CONTROL | Should be shared |
| diagnose-docker | KareMatch | MISSION-CONTROL | Should be shared |
| diagnose-build | KareMatch | MISSION-CONTROL | Should be shared |
| handoff-builder | KareMatch | MISSION-CONTROL | Should be shared |
| plan-optimizer | KareMatch | MISSION-CONTROL | Should be shared |
| context-monitor | KareMatch | MISSION-CONTROL | Should be shared |
| auto-investigator | KareMatch | MISSION-CONTROL | Should be shared |
| session-close | KareMatch + AI_Orchestrator | MISSION-CONTROL | Duplicate exists |

---

## Section C — Governance Observations (Non-Directive)

### Authority Concentration

- **EMERGENCY-ONLY skills concentrated in CredentialMate**: All 3 emergency skills (deploy-ec2-fallback, rollback-lambda, hotfix-chain) belong to one application
- **No EMERGENCY-ONLY skills in KareMatch**: Production deployment exists but lacks explicit break-glass designation
- **L4 authority skills lack approval gates**: rollback-lambda and hotfix-chain can execute production changes without documented human approval checkpoints

### Boundary Distribution

| Boundary | Count | Percentage |
|----------|-------|------------|
| MISSION-CONTROL | 14 | 39% |
| APP-LOCAL | 19 | 53% |
| EMERGENCY-ONLY | 3 | 8% |

### Ownership Gaps

- **MISSION-CONTROL skills scattered across repositories**: 14 skills classified as shareable but distributed across AI_Orchestrator (6) and KareMatch (8)
- **No single MISSION-CONTROL registry**: Skills that should be shared lack central ownership or versioning
- **session-close duplication**: Two implementations exist with no designated authoritative version

### Explicit Gating Gaps

- **L3/L4 skills without approval documentation**: deploy-lambda, lambda-deploy-chain, deploy-production lack explicit human-in-the-loop gates
- **EMERGENCY-ONLY skills without audit requirements**: No skills explicitly require audit logging or post-incident review
- **Scope limits enforced by convention**: hotfix-chain defines scope limits (3 files, 50 lines) but enforcement mechanism undefined

### Cross-Boundary Dependencies

- **lambda-deploy-chain references 5 skills**: Creates implicit coupling between APP-LOCAL chain and potentially MISSION-CONTROL validation skills
- **hotfix-chain references 7 skills**: Deep dependency chain for emergency path increases failure surface
- **session-close skills reference memory files**: Cross-boundary dependency on `.claude/memory/` files

### Pattern Observations

- **Advisory skills cleanly isolated**: app-advisor, data-advisor, uiux-advisor are well-bounded MISSION-CONTROL candidates
- **Deployment skills have app-specific infrastructure**: Lambda/SAM patterns not portable to KareMatch's deployment model
- **Diagnostic skills vary in coupling**: diagnose-docker is generic; diagnose-schema is Prisma-bound
- **Testing enforcement skills are portable**: tdd-enforcer pattern applies regardless of test framework

---

*Classification complete. No modifications made. No implementations proposed.*
