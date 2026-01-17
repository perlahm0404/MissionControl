# Parallel Execution Research - Session Log

**Date**: 2026-01-16
**Status**: RESEARCH COMPLETE
**Executor**: AI_Orchestrator Coordinator
**Topic**: Enabling parallel agent execution in AI_Orchestrator

---

## Research Question

> How do we enable multiple agents to run in parallel on independent features in the same repo? This is the purpose of Vibe Kanban - but the infrastructure isn't wired up yet.

---

## Current Architecture Analysis

### Execution Components

| Component | Location | Purpose | Status |
|-----------|----------|---------|--------|
| **autonomous_loop.py** | AI_Orchestrator/ | Main task orchestration | Sequential only |
| **ParallelExecutor** | agents/coordinator/parallel_executor.py | File locking, wave scheduling | Built, **not wired** |
| **VibeKanban** | agents/coordinator/vibe_kanban_integration.py | Objective → ADR → Task decomposition | Built, **not wired** |
| **Traceability** | agents/coordinator/traceability.py | End-to-end audit trail | Built, **not wired** |

### autonomous_loop.py Deep Dive

**Key Finding**: The loop is fully **sequential** despite being declared `async`.

```python
# Lines 362-741: Main loop structure
async def run_autonomous_loop(...):
    for iteration in range(max_iterations):
        task = queue.get_next_pending()  # ONE task at a time
        # ... process single task
        await asyncio.sleep(3)  # Only async usage: rate limiting
```

**Why async?**
- Allows `await asyncio.sleep()` for rate limiting
- Future-proofs for concurrent operations
- But currently: **no concurrent task execution**

### ParallelExecutor Capabilities (Already Built)

**File Locking** (lines 180-276):
```python
def acquire_lock(agent_id, task_id, file_path, lock_type="exclusive"):
    """Prevent concurrent file modification"""
    # Returns False if file already locked by another agent
    # Returns True and creates lock if available
```

**Conflict Detection** (lines 281-340):
```python
def check_conflicts(agent_id, files):
    """Pre-flight conflict check"""
    # Returns: {has_conflicts, conflicts[], warnings[], can_proceed}
```

**Wave Scheduling** (lines 507-569):
```python
def coordinate_execution(tasks):
    """Group tasks into parallel execution waves"""
    # Wave 1: [TaskA, TaskB, TaskC] - no file conflicts
    # Wave 2: [TaskD, TaskE] - depends on Wave 1 or conflicts
    # Returns: {waves: [[task_ids], [task_ids]], unschedulable: []}
```

**State Persistence**:
- Saves to `board-state.json` after every mutation
- Physical lock files in `vibe-kanban/locks/*.lock`
- Heartbeat monitoring with 5-minute stale timeout

### Git Operations Constraint

**Problem**: Git operations are blocking subprocess calls
```python
# In autonomous_loop.py
subprocess.run(["git", "commit", "-m", message], cwd=project_dir)
```

**Implication**: Concurrent git commits could cause merge conflicts

**Solution**: Serialize commits via queue (one at a time)

---

## Blocking Constraints for Parallelization

| Constraint | Current | Impact |
|------------|---------|--------|
| Work queue | Single JSON file | No concurrent task reads |
| Git operations | Blocking subprocess | Concurrent commits conflict |
| State management | `.aibrain/agent-loop.local.md` | Tracks one session |
| Circuit breaker | Global 100-call limit | Not task-scoped |
| Ralph verification | Sequential per-iteration | 30-second blocking |

---

## Solution Architecture

### Recommended: ThreadPoolExecutor + Wave Scheduling

```
┌──────────────────────────────────────────────────────────────┐
│                  parallel_autonomous_loop.py                  │
│                                                              │
│   WaveOrchestrator                                           │
│   ├─ Uses ParallelExecutor.coordinate_execution()            │
│   ├─ Groups non-conflicting tasks into waves                 │
│   └─ Executes waves sequentially, tasks within parallel      │
│                                                              │
│   ThreadPoolExecutor (max_parallel workers)                  │
│   ├─ Worker 1: Task A (files: src/auth/*)                   │
│   ├─ Worker 2: Task B (files: src/utils/*)                  │
│   └─ Worker 3: Task C (files: src/matching/*)               │
│                                                              │
│   GitCommitQueue (serialized)                                │
│   └─ Commits in order as tasks complete                      │
└──────────────────────────────────────────────────────────────┘
```

### Why ThreadPoolExecutor (not asyncio.gather or multiprocessing)?

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **ThreadPoolExecutor** | True parallelism for I/O, simple sync | GIL limits CPU | **Best fit** - agents are I/O-bound |
| asyncio.gather | Clean coordination | Agents not async | Requires rewrite |
| multiprocessing | No GIL | Serialization overhead | Overkill |

### Key Design Decisions

1. **New file**: Create `parallel_autonomous_loop.py` (don't modify working sequential loop)
2. **Wave-based**: Use existing `coordinate_execution()` from ParallelExecutor
3. **Serialized commits**: Queue-based git commit processing
4. **Per-worker state**: `.aibrain/worker-{N}/` directories for isolation
5. **File locking**: Use existing `acquire_lock()`/`release_lock()` from ParallelExecutor

---

## Implementation Requirements

### New File: parallel_autonomous_loop.py

Components needed:
- `GitCommitQueue` - Thread-safe queue for serialized commits
- `WorkerContext` - Per-worker state isolation
- `WaveOrchestrator` - Plans and executes waves
- `run_parallel_loop()` - Main async entry point
- CLI with `--max-parallel N` flag

### Modifications to Existing Files

| File | Change Needed |
|------|---------------|
| `tasks/work_queue.py` | Add `threading.Lock()` to mark_* methods |
| `agents/coordinator/parallel_executor.py` | Add `get_available_slots()`, `wait_for_completion()` |
| `orchestration/iteration_loop.py` | Support parameterized state directories |

---

## Usage After Implementation

```bash
# Run up to 3 agents in parallel on same repo
python parallel_autonomous_loop.py --project karematch --max-parallel 3

# Sequential fallback
python parallel_autonomous_loop.py --project karematch --max-parallel 1

# Multi-repo parallel (already works - different repos, no conflicts)
python autonomous_loop.py --project karematch &
python autonomous_loop.py --project credentialmate &
```

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Git merge conflicts | Serialized commit queue |
| File corruption | Exclusive file locking via ParallelExecutor |
| State file conflicts | Per-worker state directories |
| Deadlocks | Timeout + stale agent cleanup (existing in ParallelExecutor) |
| Memory exhaustion | Limit max_parallel (default 3) |

---

## Verification Plan

1. **Unit test**: Wave planning with file conflicts
2. **Integration test**: 2 parallel tasks, verify no git conflicts
3. **Manual test**: Run `--max-parallel 2`, observe parallel logs
4. **Verify**: State files isolated per worker
5. **Verify**: Git commits serialized

---

## Key Files Reference

| File | Lines | Purpose |
|------|-------|---------|
| `autonomous_loop.py` | 362-741 | Current sequential main loop |
| `parallel_executor.py` | 180-276 | File locking |
| `parallel_executor.py` | 281-340 | Conflict detection |
| `parallel_executor.py` | 507-569 | Wave scheduling |
| `vibe_kanban_integration.py` | full | Objective → Task decomposition |
| `traceability.py` | full | Audit trail |
| `iteration_loop.py` | 111-309 | Wiggum iteration control |

---

## Next Steps

1. Create `parallel_autonomous_loop.py` with wave orchestration
2. Add thread-safety to `WorkQueue`
3. Enhance `ParallelExecutor` with helper methods
4. Test with `--max-parallel 2` on karematch
5. Document in AI_Orchestrator CLAUDE.md

---

---

## Bonus Finding: Claude Code Hooks for Auto-Documentation

### Available Hook Events

| Event | When | Can Block? |
|-------|------|-----------|
| `PreToolUse` | Before tool executes | Yes |
| `PostToolUse` | After tool completes | No |
| `UserPromptSubmit` | When user sends message | Yes |
| `Stop` | When Claude finishes responding | No |
| `SessionEnd` | When session ends | No |
| `SessionStart` | When session begins | No |
| `PreCompact` | Before context compaction | No |

### SessionEnd Hook for Auto-Save

**Key Insight**: `SessionEnd` hook receives `session_id`, `transcript_path`, `cwd`, and `reason` - perfect for auto-saving session notes.

**Hook Input Format**:
```json
{
  "session_id": "abc-123-def",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/Users/tmac/1_REPOS/AI_Orchestrator",
  "reason": "normal" | "error" | "interrupted"
}
```

### Solution: Two-Part Approach

1. **SessionEnd hook** - Creates stub file with metadata when session ends
2. **CLAUDE.md protocol** - Instructs Claude to write TO the session file AS IT WORKS (not terminal)

This means:
- Claude writes research findings directly to session file during work
- SessionEnd hook ensures file exists even if Claude forgot
- No more "walls of text" in terminal that get lost

---

## Session Artifacts

- Plan file: `/Users/tmac/.claude/plans/humble-spinning-leaf.md`
- This research doc: `/Users/tmac/1_REPOS/MissionControl/sessions/active/2026-01-16-parallel-execution-research.md`
