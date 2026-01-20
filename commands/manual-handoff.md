---
name: claudikins-automatic-context-manager:manual-handoff
description: Manually trigger context handoff - skip waiting for 60% threshold
allowed-tools:
  - Bash
---

# claudikins-automatic-context-manager:manual-handoff Command

You are manually triggering a context handoff, bypassing the automatic 60% threshold.

## Workflow

1. Create the threshold flag file
2. Notify user that handoff will trigger on next prompt

## Execute

Run this Bash command to create the flag:

```bash
SESSION_ID="${CLAUDE_SESSION_ID:-manual}"
echo "manual" > "/tmp/acm-threshold-${SESSION_ID}"
echo "Handoff trigger set. Send any message to see the handoff prompt."
```

## What Happens Next

After running, send any message and the handoff popup will appear, allowing you to:
- Generate a summary of the current session
- Continue in a fresh context with the summary loaded
