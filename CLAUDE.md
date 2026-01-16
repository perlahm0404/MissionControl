# Claude Code Operating Contract for MissionControl

## Role

You are operating within **MissionControl**, the constitutional authority for AI governance across all repositories.

MissionControl is NOT an app repo. It is the **Single Source of Truth (SSOT)** for:
- Governance policies
- Skill definitions
- Inter-agent protocols
- Strategic objectives
- RIS audit trail

---

## Architecture Position

```
AI_Orchestrator (Strategic HQ) ← Imports from MissionControl
         │
         ▼
┌─────────────────────────────────────────┐
│  MISSIONCONTROL (You Are Here)          │
│  Role: Constitutional Authority         │
│  Contains: Policies, Skills, RIS, KB    │
└─────────────────────────────────────────┘
         │
         ▼
App Repos (credentialmate, karematch) ← Inherit policies
```

---

## Authority Hierarchy

1. **Human/Owner** - Ultimate authority
2. **This CLAUDE.md** - MissionControl governance
3. **governance/capsule/** - Core principles (immutable)
4. **governance/policies/** - Global rules
5. **meta/conventions.md** - Standards

---

## What You CAN Do (L2 Autonomy)

| Action | Allowed | Notes |
|--------|---------|-------|
| Read any file | ✅ | Full read access |
| Create KB articles | ✅ | In `/kb/` |
| Create RIS entries | ✅ | In `/ris/` with proper format |
| Update session files | ✅ | In `/sessions/` |
| Update repo docs | ✅ | In `/repos/{repo}/` |
| Update planning docs | ✅ | In `/meta/planning/` |

---

## What You CANNOT Do (Requires Human Approval)

| Action | Blocked | Reason |
|--------|---------|--------|
| Modify governance/capsule/ | ❌ | Constitutional - immutable |
| Modify governance/policies/ | ❌ | Requires RIS entry + approval |
| Modify governance/skills/ | ❌ | Requires RIS entry + approval |
| Modify governance/protocols/ | ❌ | Requires RIS entry + approval |
| Delete any RIS entry | ❌ | Audit trail - never delete |
| Modify meta/conventions.md | ❌ | Standards - requires approval |
| Modify meta/linking-rules.md | ❌ | Standards - requires approval |

---

## Protected Files (ASK BEFORE EDITING)

| File/Directory | Impact | Required |
|----------------|--------|----------|
| `governance/capsule/*` | Constitutional principles | Human approval + RIS |
| `governance/policies/*` | All repos affected | Human approval + RIS |
| `governance/skills/*` | Agent capabilities | Human approval + RIS |
| `governance/protocols/*` | Inter-agent behavior | Human approval + RIS |
| `CLAUDE.md` | This file | Human approval |
| `meta/conventions.md` | Standards | Human approval |

---

## Creating Governance Content

### To Add a New Policy

1. **Draft** in `/meta/planning/` first (not in governance/)
2. **Get approval** from human
3. **Create RIS entry** documenting the decision
4. **Move** to `/governance/policies/` after approval

### To Add a New Skill Definition

1. **Draft** skill definition with:
   - Purpose
   - Constraints
   - Escalation rules
   - Implementation references (which repo)
2. **Get approval** from human
3. **Create RIS entry**
4. **Add** to `/governance/skills/`

### To Add a New Objective

1. Objectives go in `/governance/objectives/`
2. Format: `OBJ-NNN-short-name.md`
3. Include:
   - Goal statement
   - Success criteria
   - Constraints
   - Target repos

---

## RIS Entry Format

All governance changes require RIS entries:

```markdown
# RIS-YYYY-MM-DD-short-description

## Summary
[What changed]

## Rationale
[Why it changed]

## Impact
[Which repos/agents affected]

## Approval
- Requested by: [agent/human]
- Approved by: [human]
- Date: [YYYY-MM-DD]
```

---

## Directory Purpose

| Directory | Purpose | Mutability |
|-----------|---------|------------|
| `governance/capsule/` | Core principles | Human-only, versioned |
| `governance/objectives/` | Strategic goals | Human-only |
| `governance/policies/` | Global rules | Human-only, RIS required |
| `governance/skills/` | Skill definitions | Human-only, RIS required |
| `governance/protocols/` | Inter-agent rules | Human-only, RIS required |
| `ris/` | Audit trail | Append-only, never delete |
| `kb/` | Shared knowledge | Agent-editable |
| `repos/` | Per-repo namespaces | Agent-editable |
| `sessions/` | Session tracking | Agent-editable |
| `meta/` | Standards | Human-only |
| `meta/planning/` | Planning docs | Agent-editable |

---

## Communication Protocol

Same as app repos:
- **Verbose analysis** → Write to session files or planning docs
- **Chat responses** → Keep concise (3 sentences max)
- **Progress updates** → 3 bullets max

---

## Pre-Task Checklist

Before any task in MissionControl:

1. ✅ Identify which directory you're working in
2. ✅ Check if it's protected (see table above)
3. ✅ If protected, ask human before proceeding
4. ✅ If creating governance content, draft first in `/meta/planning/`

---

## Integration Points

### AI_Orchestrator Reads From

```
governance/objectives/  → Vibe Kanban inputs
governance/policies/    → Ralph verification rules
governance/skills/      → Skill registry
governance/protocols/   → Coordination rules
```

### App Repos Read From

```
governance/capsule/     → Authority hierarchy
governance/policies/    → Rules to follow
governance/skills/      → Skill definitions to implement
ris/                    → Decision history
```

---

## Key Invariants

1. **MissionControl is read-mostly** - Changes are rare and deliberate
2. **Governance changes cascade** - All repos inherit changes
3. **RIS is permanent** - Never delete audit trail
4. **Capsule is immutable** - Core principles don't change
5. **App repos can only tighten** - Never loosen MissionControl policies

---

## Quick Commands

| Task | Action |
|------|--------|
| Add KB article | Write to `/kb/` |
| Add RIS entry | Write to `/ris/resolutions/` |
| Draft new policy | Write to `/meta/planning/` first |
| Update planning | Write to `/meta/planning/` |
| Check conventions | Read `/meta/conventions.md` |

---

## Remember

**MissionControl defines WHAT is allowed. AI_Orchestrator decides WHO does it. App repos define HOW it's done.**

You are in the constitutional layer. Changes here affect everything downstream.
