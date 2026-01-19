---
description: Manually trigger context handoff (skip waiting for 60% threshold)
---

# Manual Handoff Trigger

Create the threshold flag file to trigger handoff on next prompt.

Run this Bash command to create the flag:

```bash
# Get session ID from environment or use fallback
SESSION_ID="${CLAUDE_SESSION_ID:-manual}"
echo "manual" > "/tmp/acm-threshold-${SESSION_ID}"
echo "Handoff trigger set. Send any message to see the handoff prompt."
```

After running, send any message and the handoff popup will appear.
