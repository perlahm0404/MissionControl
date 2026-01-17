# Handoff Protocol

**Authority**: MissionControl Governance Protocol
**Version**: 1.0
**Last Updated**: 2026-01-16
**Status**: MANDATORY

---

## Overview

This protocol defines how AI agents document their work and pass context between sessions. Proper handoffs prevent knowledge loss and enable seamless session continuity.

---

## Core Principle

> **Sessions are stateless. All memory is externalized. Future agents cannot read your mind - only your artifacts.**

Every session must leave a trail that enables the next agent to continue work without human re-explanation.

---

## Session Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│                     SESSION LIFECYCLE                        │
│                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌───────┐ │
│  │  START   │───→│  WORK    │───→│ DOCUMENT │───→│  END  │ │
│  │          │    │          │    │          │    │       │ │
│  │ - Read   │    │ - Execute│    │ - Summary│    │ - Log │ │
│  │   context│    │   tasks  │    │ - Blockers│   │ - Commit│
│  │ - Load   │    │ - Track  │    │ - Next   │    │       │ │
│  │   state  │    │   progress│   │   steps  │    │       │ │
│  └──────────┘    └──────────┘    └──────────┘    └───────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Session Startup Checklist

Every session MUST start by reading these files (in order):

| Order | File | Purpose |
|-------|------|---------|
| 1 | `CLAUDE.md` or `CONTEXT.md` | Project rules and constraints |
| 2 | `STATE.md` | Current implementation state |
| 3 | `DECISIONS.md` | Past decisions with rationale |
| 4 | `sessions/latest.md` | Most recent handoff (if exists) |
| 5 | Relevant task/work queue | What needs to be done |

### Startup Confirmation

Agent should confirm context loaded:
```
Session started. Loaded context from:
- CLAUDE.md (project rules)
- STATE.md (current state: feature X in progress)
- DECISIONS.md (14 decisions documented)
- sessions/2026-01-15-session.md (previous session handoff)

Ready to continue work on: [current task]
```

---

## Handoff Document Structure

Every session MUST create a handoff document at session end.

### Required Sections

```markdown
# Session Handoff: [Date] - [Brief Description]

## Session Summary
- **Duration**: X hours
- **Focus**: What was worked on
- **Agent**: Agent identifier (if applicable)
- **Autonomy Level**: L0-L4

## Accomplished
- [ ] Task 1 (COMPLETE/PARTIAL/BLOCKED)
- [ ] Task 2 (COMPLETE/PARTIAL/BLOCKED)

## NOT Done (Important)
- Task X: Why not done
- Task Y: Blocked by Z

## Blockers
- Blocker 1: Description, attempted resolution
- Blocker 2: Description, needs human input

## Decisions Made
- Decision 1: Rationale
- Decision 2: Rationale

## Files Modified
- `path/to/file1.ts` - What changed
- `path/to/file2.py` - What changed

## Test Status
- Unit tests: PASS/FAIL (X of Y)
- Integration tests: PASS/FAIL (X of Y)
- E2E tests: PASS/FAIL (X of Y)

## Risk Assessment
- [ ] No known regressions
- [ ] Breaking changes: None / [list]
- [ ] Security implications: None / [list]

## Next Steps
1. Next step 1 (priority)
2. Next step 2
3. Next step 3

## Context for Next Session
[Any important context the next agent needs to know]
```

---

## Handoff Triggers

### Automatic Handoff Triggers

| Trigger | Action |
|---------|--------|
| Session timeout | Generate handoff |
| User says "end session" | Generate handoff |
| Critical blocker hit | Generate partial handoff |
| Major milestone complete | Generate checkpoint handoff |

### Manual Handoff Triggers

- `/handoff` command
- "create handoff", "document session"
- Explicit user request

---

## What MUST Be Documented

### Always Document

| Item | Why |
|------|-----|
| Tasks completed | Enable verification |
| Tasks NOT completed | Prevent assumption of completion |
| Blockers encountered | Prevent repeated failure |
| Decisions made | Prevent decision reversal |
| Files modified | Enable review |
| Test results | Track quality |

### Document if Applicable

| Item | When |
|------|------|
| API changes | If endpoints modified |
| Database changes | If schema touched |
| Configuration changes | If env/config modified |
| Dependencies added | If package.json/requirements changed |

---

## Handoff Quality Standards

### Good Handoff Characteristics

1. **Self-Sufficient**: Next agent can continue without asking human
2. **Specific**: Names specific files, functions, line numbers
3. **Honest**: Clearly states what wasn't done
4. **Actionable**: Next steps are concrete
5. **Traceable**: Links to relevant RIS/docs

### Bad Handoff Characteristics

1. **Vague**: "Made some progress on the feature"
2. **Incomplete**: Omits blocked items
3. **Overconfident**: Claims completion without verification
4. **Unactionable**: "Continue working on this"

---

## Handoff Storage

### Primary Location

```
{repo}/sessions/
├── active/                    # Current sessions
│   └── {date}-{description}.md
├── completed/                 # Archived sessions
│   └── {date}-{description}.md
└── latest.md                  # Symlink to most recent
```

### Naming Convention

```
{YYYY-MM-DD}-{brief-description}.md

Examples:
2026-01-16-phase1-constitutional-foundation.md
2026-01-15-bugfix-auth-timeout.md
2026-01-14-feature-user-export.md
```

---

## Cross-Repository Handoffs

When working across multiple repositories:

### Multi-Repo Handoff Structure

```markdown
# Cross-Repository Session Handoff

## Repositories Touched
- credentialmate: [changes summary]
- karematch: [changes summary]
- MissionControl: [changes summary]

## Repository-Specific Details

### credentialmate
- Files: [list]
- Changes: [summary]
- Tests: [status]

### karematch
- Files: [list]
- Changes: [summary]
- Tests: [status]

## Cross-Repo Considerations
- Dependencies between changes
- Deployment order requirements
- Shared state considerations
```

---

## Handoff Templates

### Quick Handoff (Minor Work)

```markdown
# Quick Handoff: [Date]

## Done
- [Task 1]
- [Task 2]

## Files Changed
- `file1.ts`
- `file2.py`

## Next
- [Next step]
```

### Full Handoff (Major Work)

Use the full template from "Required Sections" above.

### Emergency Handoff (Session Interrupted)

```markdown
# Emergency Handoff: [Date]

## Status at Interruption
- Was working on: [task]
- Progress: [X]% complete
- State: [describe current state]

## CRITICAL: What NOT to Do
- [Warning about incomplete state]

## To Resume
1. [Step 1]
2. [Step 2]

## Files in Flux
- `file.ts` - [state: incomplete/needs revert]
```

---

## Integration with Other Systems

### RIS Integration

Significant changes should link to RIS entries:
```markdown
## Related RIS Entries
- RIS-083: [Title]
- RIS-084: [Title]
```

### Work Queue Integration

Update work queue status:
```markdown
## Work Queue Updates
- TASK-001: COMPLETED
- TASK-002: IN_PROGRESS (40%)
- TASK-003: BLOCKED (dependency on TASK-002)
```

### Knowledge Object Integration

Reference relevant KOs:
```markdown
## Knowledge Objects Consulted
- KO-TypeScript-Strict-Mode
- KO-Database-Migration-Patterns
```

---

## Enforcement

### Required Checks

| Check | Enforcement |
|-------|-------------|
| Handoff exists | Advisory (documented) |
| Required sections present | Advisory (documented) |
| Files modified listed | Advisory (documented) |
| Test status included | Advisory (documented) |

### Future Enforcement (Planned)

- Pre-session check for previous handoff
- Session end hook to generate handoff
- Validation of handoff completeness

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-16 | Initial protocol |
