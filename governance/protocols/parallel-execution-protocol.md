# Parallel Execution Protocol

**Authority**: MissionControl Governance Protocol
**Version**: 1.0
**Last Updated**: 2026-01-16
**Status**: MANDATORY

---

## Overview

This protocol defines rules for multiple AI agents operating concurrently across the same or different repositories. The goal is to prevent context collision, resource conflicts, and conflicting modifications.

---

## Core Principle

> **Parallel agents MUST operate in isolated contexts with explicit coordination points.**

No two agents should modify the same file simultaneously. Conflicts are prevented through lane assignment and lock mechanisms.

---

## Agent Isolation Model

```
┌─────────────────────────────────────────────────────────────────┐
│                     PARALLEL EXECUTION MODEL                     │
│                                                                 │
│  ┌───────────────┐    ┌───────────────┐    ┌───────────────┐   │
│  │   AGENT A     │    │   AGENT B     │    │   AGENT C     │   │
│  │   (Lane 1)    │    │   (Lane 2)    │    │   (Lane 3)    │   │
│  │               │    │               │    │               │   │
│  │  feature/*    │    │  fix/*        │    │  docs/*       │   │
│  │  frontend/    │    │  backend/     │    │  docs/        │   │
│  └───────┬───────┘    └───────┬───────┘    └───────┬───────┘   │
│          │                    │                    │           │
│          ▼                    ▼                    ▼           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    COORDINATION LAYER                    │   │
│  │                                                         │   │
│  │  - File locks                                           │   │
│  │  - Lane boundaries                                      │   │
│  │  - Merge coordination                                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
│                              ▼                                  │
│                    ┌─────────────────┐                         │
│                    │   SHARED STATE  │                         │
│                    │   (main branch) │                         │
│                    └─────────────────┘                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Lane Assignment

### What is a Lane?

A lane is an isolated execution context with:
- Dedicated branch prefix
- Assigned file patterns
- Exclusive modification rights

### Lane Types

| Lane | Branch Pattern | File Patterns | Purpose |
|------|----------------|---------------|---------|
| **Feature** | `feature/*` | `src/`, `lib/`, `components/` | New functionality |
| **Fix** | `fix/*` | Anywhere (scoped) | Bug fixes |
| **QA** | `qa/*` | `tests/`, config files | Quality assurance |
| **Docs** | `docs/*` | `docs/`, `*.md` | Documentation |
| **Ops** | `ops/*` | `.github/`, `infra/` | Operations |

### Lane Assignment Rules

1. **Exclusive Files**: Each agent gets exclusive rights to specific files
2. **No Cross-Lane Edits**: Agents cannot edit files outside their lane
3. **Shared Read**: All agents can READ any file
4. **Merge Coordination**: Merges require coordination layer approval

---

## File Locking

### Lock Mechanism

Before modifying a file, agent must acquire a lock:

```yaml
# .aibrain/locks/file-locks.yaml
locks:
  - file: "src/auth/login.ts"
    agent: "agent-A"
    lane: "feature/user-auth"
    acquired: "2026-01-16T12:00:00Z"
    expires: "2026-01-16T13:00:00Z"
    reason: "Implementing OAuth flow"

  - file: "src/api/users.py"
    agent: "agent-B"
    lane: "fix/user-validation"
    acquired: "2026-01-16T12:05:00Z"
    expires: "2026-01-16T12:35:00Z"
    reason: "Fixing validation bug"
```

### Lock Acquisition

```python
# Pseudocode for lock acquisition
def acquire_lock(file_path, agent_id, lane, reason, duration_minutes=30):
    locks = load_locks()

    # Check for existing lock
    existing = locks.get(file_path)
    if existing and not existing.expired:
        if existing.agent != agent_id:
            raise LockConflict(
                f"File {file_path} is locked by {existing.agent} "
                f"until {existing.expires}. "
                f"Reason: {existing.reason}"
            )

    # Acquire lock
    locks[file_path] = Lock(
        file=file_path,
        agent=agent_id,
        lane=lane,
        acquired=now(),
        expires=now() + duration_minutes,
        reason=reason
    )
    save_locks(locks)
    return True
```

### Lock Rules

| Rule | Description |
|------|-------------|
| **Timeout** | Locks expire after 30 minutes (configurable) |
| **Renewal** | Agent can renew if still working |
| **Release** | Agent must release on completion |
| **Steal** | Cannot steal lock (wait for expiry or ask human) |

---

## Conflict Prevention

### Pre-Modification Check

Before any file modification:

```python
def pre_modification_check(file_path, agent_id, lane):
    # 1. Check lane boundaries
    if not file_in_lane(file_path, lane):
        return BLOCK(f"File {file_path} is outside lane {lane}")

    # 2. Check file lock
    if not has_lock(file_path, agent_id):
        if lock_available(file_path):
            acquire_lock(file_path, agent_id, lane)
        else:
            return BLOCK(f"File {file_path} is locked by another agent")

    # 3. Check for merge conflicts
    if has_pending_changes(file_path, other_lanes):
        return WARN(f"File {file_path} has pending changes in other lanes")

    return ALLOW()
```

### Conflict Resolution

If conflict detected:

1. **Block Modification**: Don't proceed with conflicting edit
2. **Notify Human**: Alert about the conflict
3. **Document**: Log conflict in coordination layer
4. **Wait**: Either wait for other agent or escalate

---

## Coordination Points

### When Agents Coordinate

| Trigger | Action |
|---------|--------|
| Both agents need same file | Negotiate via lock system |
| PR ready to merge | Check for conflicting PRs |
| Shared dependency updated | Notify affected agents |
| Database schema change | Block all DB agents until complete |

### Coordination Messages

Agents communicate via coordination layer:

```yaml
# .aibrain/coordination/messages.yaml
messages:
  - id: "msg-001"
    from: "agent-A"
    to: "agent-B"
    type: "file_intent"
    timestamp: "2026-01-16T12:00:00Z"
    content:
      file: "src/shared/utils.ts"
      action: "modify"
      eta: "10 minutes"

  - id: "msg-002"
    from: "agent-B"
    to: "agent-A"
    type: "ack"
    timestamp: "2026-01-16T12:00:30Z"
    content:
      response: "proceed"
      notes: "I'll wait for your changes"
```

---

## Work Queue Coordination

### Queue Ownership

Each task in work queue has owner assignment:

```json
{
  "tasks": [
    {
      "id": "TASK-001",
      "description": "Implement OAuth",
      "owner": "agent-A",
      "lane": "feature/oauth",
      "status": "in_progress",
      "files_claimed": ["src/auth/*"]
    },
    {
      "id": "TASK-002",
      "description": "Fix login validation",
      "owner": "agent-B",
      "lane": "fix/login-validation",
      "status": "in_progress",
      "files_claimed": ["src/api/login.py"]
    }
  ]
}
```

### Task Assignment Rules

1. **One Owner**: Each task has exactly one owning agent
2. **File Claims**: Tasks can claim file patterns
3. **No Overlap**: Claims cannot overlap between active tasks
4. **Release on Complete**: Claims released when task completes

---

## Merge Coordination

### Merge Order

When multiple branches ready to merge:

```
Priority Order:
1. fix/* branches (bug fixes first)
2. qa/* branches (tests)
3. docs/* branches (documentation)
4. feature/* branches (new features)
```

### Pre-Merge Checklist

Before merging any branch:

1. **Lock Check**: Ensure no active locks on affected files
2. **Conflict Check**: Verify no merge conflicts
3. **Test Check**: All tests passing
4. **Dependent Check**: Dependencies already merged

### Merge Protocol

```yaml
merge_protocol:
  pre_merge:
    - notify_affected_agents
    - acquire_merge_lock
    - run_conflict_check
    - run_test_suite

  merge:
    - perform_merge
    - verify_successful

  post_merge:
    - release_merge_lock
    - notify_agents
    - update_coordination_state
```

---

## Cross-Repository Coordination

### When Working Across Repos

| Scenario | Coordination Required |
|----------|----------------------|
| Shared library update | Notify all dependent repos |
| API contract change | Coordinate frontend/backend |
| Database migration | Lock DB operations across repos |
| Deployment | Sequential deployment order |

### Cross-Repo Lock

```yaml
# MissionControl/.aibrain/cross-repo-locks.yaml
cross_repo_locks:
  - resource: "shared-database-schema"
    owner: "credentialmate/agent-A"
    repos_affected:
      - credentialmate
      - karematch
    acquired: "2026-01-16T12:00:00Z"
    expires: "2026-01-16T13:00:00Z"
    reason: "Database migration in progress"
```

---

## State Tracking

### Coordination State File

```yaml
# .aibrain/coordination/state.yaml
coordination_state:
  version: "1.0"
  last_updated: "2026-01-16T12:30:00Z"

  active_agents:
    - id: "agent-A"
      lane: "feature/oauth"
      started: "2026-01-16T10:00:00Z"
      last_activity: "2026-01-16T12:30:00Z"
      files_locked: ["src/auth/oauth.ts"]

    - id: "agent-B"
      lane: "fix/login-validation"
      started: "2026-01-16T11:00:00Z"
      last_activity: "2026-01-16T12:25:00Z"
      files_locked: ["src/api/login.py"]

  pending_merges:
    - branch: "fix/login-validation"
      ready: true
      conflicts: []

  recent_merges:
    - branch: "fix/typo"
      merged: "2026-01-16T11:45:00Z"
```

---

## Failure Handling

### Agent Crash

If an agent crashes:

1. **Detect**: Coordination layer detects inactivity
2. **Timeout**: Locks expire automatically (30 min)
3. **Clean**: Orphaned state cleaned up
4. **Resume**: New agent can take over

### Conflict Detected at Merge

If merge conflict detected:

1. **Block**: Merge blocked
2. **Notify**: Human notified
3. **Document**: Conflict documented
4. **Resolve**: Human or designated agent resolves

---

## Monitoring

### Parallel Execution Dashboard

Track:
- Active agents and their lanes
- Current file locks
- Pending merges
- Conflict history
- Coordination messages

### Alerts

| Alert | Trigger |
|-------|---------|
| Lock timeout | Lock held >1 hour |
| Lane violation | Agent edited outside lane |
| Merge conflict | Conflict detected |
| Stale agent | No activity >30 min |

---

## Implementation Status

| Component | Status |
|-----------|--------|
| Lane assignment | Documented |
| File locking | Planned |
| Coordination messages | Planned |
| Merge coordination | Planned |
| Cross-repo locks | Planned |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-16 | Initial protocol |
