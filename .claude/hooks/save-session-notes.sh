#!/bin/bash
#
# SessionEnd Hook - Auto-saves session metadata when session ends
#
# This hook creates a stub session file in AI_Orchestrator/sessions/{repo}/active/
# which can be populated during the session by Claude following the session
# documentation protocol.
#
# Part of: AI_Orchestrator v6.0 - Automatic Session Documentation
#

set -e

# Read input from stdin (JSON from Claude Code)
INPUT=$(cat)

# Parse session info (gracefully handle missing jq)
if command -v jq &> /dev/null; then
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
    CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
else
    SESSION_ID="unknown"
    CWD=""
fi

DATE=$(date '+%Y-%m-%d')
TIME=$(date '+%H-%M-%S')
TIMESTAMP=$(date '+%Y%m%d-%H%M')

# Determine project from CWD
PROJECT="cross-repo"
[[ "$CWD" == *"AI_Orchestrator"* ]] && PROJECT="ai-orchestrator"
[[ "$CWD" == *"karematch"* ]] && PROJECT="karematch"
[[ "$CWD" == *"credentialmate"* ]] && PROJECT="credentialmate"
[[ "$CWD" == *"MissionControl"* ]] && PROJECT="mission-control"

# Determine target directory based on project
SESSIONS_BASE="/Users/tmac/1_REPOS/AI_Orchestrator/sessions"
case "$PROJECT" in
    karematch)
        NOTES_DIR="${SESSIONS_BASE}/karematch/active"
        ;;
    credentialmate)
        NOTES_DIR="${SESSIONS_BASE}/credentialmate/active"
        ;;
    ai-orchestrator)
        NOTES_DIR="${SESSIONS_BASE}/ai-orchestrator/active"
        ;;
    mission-control)
        NOTES_DIR="${SESSIONS_BASE}/cross-repo/active"
        ;;
    *)
        NOTES_DIR="${SESSIONS_BASE}/cross-repo/active"
        ;;
esac

mkdir -p "$NOTES_DIR"

# Create session stub file (only if doesn't exist)
SESSION_FILE="${NOTES_DIR}/${TIMESTAMP}-session.md"

if [[ ! -f "$SESSION_FILE" ]]; then
    cat > "$SESSION_FILE" << EOF
---
session:
  id: "${TIMESTAMP}"
  topic: "session"
  type: implementation
  status: active
  repo: ${PROJECT}

initiated:
  timestamp: "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  context: "Auto-created by SessionEnd hook"

governance:
  autonomy_level: L2
  human_interventions: 0
  escalations: []
---

# Session: ${DATE} ${TIME} - ${PROJECT}

## Objective
<!-- Session auto-created by hook - update with actual objective -->


## Progress Log

### Phase 1: Session Work
**Status**: in_progress
- Auto-created session stub


## Next Steps
1. Update this file with session details
EOF
fi

exit 0
