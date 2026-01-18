# Skill: checkpoint-reminder

**ID**: checkpoint-reminder
**Category**: Infrastructure
**Complexity**: Low
**Governance Level**: L2 (Higher Autonomy)
**Created**: 2026-01-18
**Status**: Production

---

## Purpose

Prevents context loss during long-running sessions by reminding Claude to update STATE.md and session files after a threshold number of file operations.

---

## What It Does

1. **Operation Tracking**: Counts Write/Edit tool calls via hook system
2. **Threshold Detection**: Triggers reminder banner at configurable threshold (10-20 operations)
3. **Automatic State Sync**: Triggers cross-repo state synchronization when STATE.md is modified
4. **Session Preservation**: Ensures progress is documented before potential crashes

---

## When to Use

### Automatically Active When:
- Running long autonomous sessions (30+ tasks)
- Doing multi-file refactoring work
- Executing work queues with many tasks
- Any session longer than 30 minutes

### Manual Reset When:
- Checkpoint completed and STATE.md updated
- Session file updated with latest progress
- Want to reset operation counter after milestone

---

## How It Works

### Automatic Operation
The hook runs automatically after every Write/Edit tool call:

```bash
# Triggered by Claude Code after Write/Edit
.claude/hooks/checkpoint_reminder.sh

# Hook increments counter
COUNT=$((COUNT + 1))

# At threshold, displays banner
if [ $COUNT -ge $THRESHOLD ]; then
    echo "⏰ CHECKPOINT REMINDER"
    echo "ACTION REQUIRED: Update STATE.md with current progress"
fi
```

### Manual Reset
```bash
# Reset counter after checkpoint complete
echo 0 > .claude/hooks/.checkpoint_counter
```

---

## Configuration

### Threshold Settings

| Repo | Threshold | Rationale |
|------|-----------|-----------|
| AI_Orchestrator | 10 operations | Fast-moving development, frequent checkpoints |
| KareMatch | 20 operations | More stable, L2 autonomy |
| CredentialMate | 20 operations | L1 strict, but same threshold as KareMatch |

### Hook Location
```
<repo>/.claude/hooks/checkpoint_reminder.sh
<repo>/.claude/hooks/.checkpoint_counter
```

---

## Expected Outcomes

### Success Indicators
- ✅ Reminder banner appears after threshold operations
- ✅ STATE.md is updated with latest progress
- ✅ Session file is updated with accomplishments
- ✅ Cross-repo state sync triggered (if STATE.md modified)
- ✅ Counter resets to 0 after checkpoint

### Failure Modes
- ❌ Hook not executable (chmod +x required)
- ❌ Counter file missing or corrupted
- ❌ STATE.md becomes stale (counter not reset)

---

## Architecture

### Hook Integration
```
Claude Code: Write/Edit tool called
   │
   ▼
Post-tool hook executes
   │
   ├─→ Increment .checkpoint_counter
   ├─→ Check threshold
   └─→ If threshold reached:
       ├─→ Display reminder banner
       └─→ If STATE.md modified recently:
           └─→ Trigger state-sync automatically
```

### State Sync Integration (v6.0)
When STATE.md is modified within 5 seconds:
```bash
if [ $TIME_DIFF -le 5 ]; then
    python utils/state_sync.py sync <repo> 2>/dev/null
fi
```

---

## Governance Constraints

### Allowed Operations
- ✅ Read/write .checkpoint_counter file
- ✅ Display reminder banners
- ✅ Trigger state-sync automatically
- ✅ Check STATE.md modification time

### Forbidden Operations
- ❌ Modify STATE.md automatically (must be manual)
- ❌ Skip checkpoints entirely (defeats purpose)
- ❌ Disable hook without approval

### Approval Requirements
- No approval required (automatic infrastructure)
- Disabling hook requires L0 infrastructure team approval

---

## Integration Points

### Claude Code Hooks
Integrates with Claude Code's post-tool hook system:
```bash
# .claude/hooks/post_tool.sh
.claude/hooks/checkpoint_reminder.sh
```

### State Sync Skill
Automatically triggers `state-sync` when STATE.md is modified.

### Session Documentation
Reminds to update:
- STATE.md (current repo state)
- sessions/active/*.md (session progress)
- .aibrain/agent-loop.local.md (autonomous loop state)

---

## Testing & Validation

### Quick Test
```bash
# 1. Reset counter
echo 0 > .claude/hooks/.checkpoint_counter

# 2. Manually trigger hook 10+ times
for i in {1..11}; do .claude/hooks/checkpoint_reminder.sh; done

# 3. Verify reminder appears on 10th/11th call
```

### Validation Checklist
- [ ] Counter increments on each execution
- [ ] Reminder appears at threshold
- [ ] Reminder includes correct threshold count
- [ ] State sync triggers when STATE.md modified
- [ ] Counter persists across sessions

---

## Best Practices

### For Agents
1. **Read reminder carefully** - Don't skip checkpoints
2. **Update STATE.md first** - Before session files
3. **Reset counter** - After checkpoint complete
4. **Document decisions** - Not just what was done

### For Humans
1. **Don't disable hook** - Critical for session continuity
2. **Review STATE.md updates** - Ensure accuracy
3. **Adjust threshold if needed** - Based on workflow
4. **Monitor counter file** - Ensure not corrupted

---

## Troubleshooting

### Issue: "Reminder doesn't appear"
**Solution**: Check hook is executable: `chmod +x .claude/hooks/checkpoint_reminder.sh`

### Issue: "Counter resets unexpectedly"
**Solution**: Check for multiple processes writing to .checkpoint_counter

### Issue: "State sync doesn't trigger"
**Solution**: Verify STATE.md modification time is within 5 seconds of sync call

### Issue: "Reminder appears too frequently"
**Solution**: Increase THRESHOLD in checkpoint_reminder.sh

---

## Related Skills

- **state-sync**: Triggered automatically by this skill
- **session-handoff**: Uses checkpointed state for context
- **auto-resume**: Relies on checkpointed state for recovery

---

## Version History

- **v1.0** (2026-01-17): Initial implementation
  - Basic counter and reminder
  - Configurable threshold
- **v1.1** (2026-01-18): State sync integration
  - Auto-trigger state-sync on STATE.md modification
  - Cross-platform stat command support (macOS/Linux)

---

## References

- Implementation: `.claude/hooks/checkpoint_reminder.sh` (all repos)
- Counter file: `.claude/hooks/.checkpoint_counter`
- Related: `state-sync` skill for cross-repo synchronization
