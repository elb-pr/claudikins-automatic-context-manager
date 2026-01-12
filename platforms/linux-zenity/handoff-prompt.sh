#!/bin/bash
# CC-ACM: Linux version using Zenity for dialogs
# EXPERIMENTAL - Not fully tested

TRANSCRIPT_PATH="$1"
SESSION_ID="$2"
FLAG_FILE="/tmp/handoff-triggered-${SESSION_ID}"
SNOOZE_FILE="/tmp/handoff-snooze-${SESSION_ID}"

# Check for zenity
if ! command -v zenity &> /dev/null; then
    notify-send "CC-ACM" "Zenity required. Install with: sudo apt install zenity" 2>/dev/null
    exit 1
fi

# Show dialog
RESULT=$(zenity --question \
    --title="Claude - Context Handoff" \
    --text="Context at 60%.\nStart fresh with handoff?" \
    --ok-label="Handoff" \
    --cancel-label="Dismiss" \
    --extra-button="In 5 min" \
    --width=300 \
    2>/dev/null; echo $?)

case "$RESULT" in
    "In 5 min")
        rm -f "$FLAG_FILE"
        echo $(($(date +%s) + 300)) > "$SNOOZE_FILE"
        exit 0
        ;;
    1|252)  # Cancel/Dismiss or closed
        exit 0
        ;;
esac

# Find transcript if not provided
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    TRANSCRIPT_PATH=$(find ~/.claude/projects -name "*.jsonl" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
fi

if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    zenity --error --text="Could not find transcript file" --width=200 2>/dev/null
    exit 1
fi

# Extract conversation from JSONL
CONVERSATION=$(cat "$TRANSCRIPT_PATH" | grep -E '"type":"(user|assistant)"' | \
    python3 -c "
import sys, json
msgs = []
for line in sys.stdin:
    try:
        d = json.loads(line)
        role = d.get('type', '')
        content = d.get('message', {}).get('content', '')
        if isinstance(content, list):
            content = ' '.join([c.get('text', '') for c in content if isinstance(c, dict)])
        if role in ('user', 'assistant') and content:
            msgs.append(f'{role.upper()}: {content[:500]}')
    except: pass
print('\n'.join(msgs[-20:]))
" 2>/dev/null)

# Generate handoff via claude -p
HANDOFF=$(echo "$CONVERSATION" | claude -p "Generate a concise handoff summary (under 500 tokens) for continuing this conversation. Include: current task, progress, next steps, key decisions. Format as markdown.

CONVERSATION:
" 2>/dev/null)

if [ -z "$HANDOFF" ]; then
    zenity --error --text="Failed to generate handoff" --width=200 2>/dev/null
    exit 1
fi

# Save handoff
HANDOFF_FILE="/tmp/claude-handoff.txt"
echo "$HANDOFF" > "$HANDOFF_FILE"

# Try to open new terminal tab (gnome-terminal)
if command -v gnome-terminal &> /dev/null; then
    gnome-terminal --tab -- bash -c "claude --append-system-prompt \"\$(cat $HANDOFF_FILE)\"; exec bash"
elif command -v xterm &> /dev/null; then
    xterm -e "claude --append-system-prompt \"\$(cat $HANDOFF_FILE)\"" &
else
    # Fallback: show instructions
    zenity --info --title="Handoff Ready" \
        --text="Handoff saved to:\n$HANDOFF_FILE\n\nRun in new terminal:\nclaude --append-system-prompt \"\$(cat $HANDOFF_FILE)\"" \
        --width=400 2>/dev/null
fi

echo "Handoff complete!"
