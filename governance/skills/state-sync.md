# Skill: state-sync

**ID**: state-sync
**Category**: Infrastructure
**Complexity**: Medium
**Governance Level**: L2 (Higher Autonomy)
**Created**: 2026-01-18
**Status**: Production

---

## Purpose

Synchronizes STATE.md files across execution repositories (AI_Orchestrator, KareMatch, CredentialMate) to enable cross-repo context awareness and session continuity.

---

## What It Does

1. **Sync Command**: Propagates current repo's STATE.md to other repos' `.aibrain/global-state-cache.md`
2. **Pull Command**: Reads cached state from other repos into current repo's global cache
3. **Distributed Architecture**: No central registry; each repo caches state from others locally
4. **Automatic Triggering**: Integrated with checkpoint hooks to auto-sync on STATE.md updates

---

## When to Use

### Use This Skill When:
- STATE.md is updated with new session information
- Cross-repo context needs to be refreshed
- Setting up new execution repository
- Troubleshooting stale cross-repo state

### Do NOT Use When:
- Working in passive repos (Mission Control, Knowledge Vault) - these don't have STATE.md
- STATE.md hasn't changed significantly
- Testing or development work that shouldn't propagate

---

## How to Execute

### Manual Sync (Push)
```bash
# From AI_Orchestrator
.venv/bin/python utils/state_sync.py sync ai_orchestrator

# From KareMatch
python3 utils/state_sync.py sync karematch

# From CredentialMate
python3 utils/state_sync.py sync credentialmate
```

### Manual Pull (Fetch)
```bash
# Pull latest cached state from other repos
python utils/state_sync.py pull <repo_name>
```

### Automatic (via Hooks)
State sync is automatically triggered by `.claude/hooks/checkpoint_reminder.sh` when STATE.md is modified within the last 5 seconds.

---

## Prerequisites

### Required Files
- `STATE.md` in current repo (source of truth)
- `.aibrain/global-state-cache.md` in target repos (cache destination)
- `utils/state_sync.py` in all execution repos

### Required Python Packages
- Standard library only (no external dependencies)

---

## Expected Outcomes

### Success Indicators
- ✅ Console message: `[state_sync] Synced <repo> STATE.md -> <target>/.aibrain/global-state-cache.md`
- ✅ Target repos' global-state-cache.md updated with timestamp
- ✅ Full STATE.md content present in cache with section headers

### Failure Modes
- ❌ Python not found in PATH
- ❌ STATE.md doesn't exist in source repo
- ❌ Target repo directory doesn't exist
- ❌ Permission issues writing to .aibrain/

---

## Architecture

### File Structure
```
<repo>/
├── STATE.md                          # Source of truth (this repo's state)
├── .aibrain/
│   └── global-state-cache.md        # Cached state from OTHER repos
└── utils/
    └── state_sync.py                # Sync utility (identical in all repos)
```

### Sync Flow
```
Repo A: STATE.md updated
   │
   ▼
utils/state_sync.py sync repo_a
   │
   ├─→ Repo B/.aibrain/global-state-cache.md (Section: REPO_A State)
   └─→ Repo C/.aibrain/global-state-cache.md (Section: REPO_A State)

Agent in Repo B:
   1. Read STATE.md (Repo B's own state)
   2. Read .aibrain/global-state-cache.md (Repo A and C state)
   3. Has full cross-repo context
```

---

## Governance Constraints

### Allowed Operations
- ✅ Read STATE.md from any execution repo
- ✅ Write to .aibrain/global-state-cache.md in target repos
- ✅ Create .aibrain/ directory if missing
- ✅ Overwrite existing cache sections

### Forbidden Operations
- ❌ Modify STATE.md in other repos (each repo manages its own)
- ❌ Sync to passive repos (Mission Control, Knowledge Vault have no STATE.md)
- ❌ Delete global-state-cache.md entirely
- ❌ Sync sensitive data or credentials

### Approval Requirements
- No approval required (L2 autonomy)
- Automatic execution via checkpoint hooks

---

## Integration Points

### Checkpoint Hooks
`.claude/hooks/checkpoint_reminder.sh` automatically runs state-sync when:
- STATE.md modification time is within last 5 seconds
- Checkpoint threshold is reached (10-20 operations)

### Agent Startup Protocol
Agents read `.aibrain/global-state-cache.md` as part of 10-step startup protocol (step 6).

### Work Queue System
External repo work queues can reference state from cached repos.

---

## Testing & Validation

### Quick Test
```bash
# 1. Update STATE.md in any repo
echo "**Test**: $(date)" >> STATE.md

# 2. Run sync
python utils/state_sync.py sync <repo_name>

# 3. Verify in target repos
grep "Test:" /path/to/other/repo/.aibrain/global-state-cache.md
```

### Validation Checklist
- [ ] Sync completes without errors
- [ ] Timestamp updated in target global-state-cache.md
- [ ] Full STATE.md content present in cache
- [ ] Section headers correct (## REPO_NAME State)
- [ ] Multiple syncs don't create duplicate sections

---

## Troubleshooting

### Issue: "Python not found"
**Solution**: Use `.venv/bin/python` for AI_Orchestrator, `python3` for others

### Issue: "STATE.md not found"
**Solution**: Create STATE.md in source repo first

### Issue: "Permission denied writing to .aibrain/"
**Solution**: Check directory permissions: `chmod 755 .aibrain/`

### Issue: "Sync doesn't trigger automatically"
**Solution**: Verify checkpoint hook is executable: `chmod +x .claude/hooks/checkpoint_reminder.sh`

---

## Related Skills

- **checkpoint-reminder**: Triggers state-sync automatically
- **session-handoff**: Uses cached state for context reconstruction
- **auto-resume**: Relies on cross-repo state for recovery

---

## Version History

- **v1.0** (2026-01-18): Initial implementation
  - Distributed sync architecture
  - Auto-sync via checkpoint hooks
  - Support for 3 execution repos

---

## References

- ADR-012: Cross-Repo Memory Synchronization Architecture (pending)
- Implementation: `/Users/tmac/1_REPOS/AI_Orchestrator/utils/state_sync.py`
- Session: `sessions/cross-repo/active/20260118-1130-3-repo-memory-unification.md`
