#!/bin/bash
# CC-ACM: macOS version using osascript for dialogs
# EXPERIMENTAL - Not fully tested

TRANSCRIPT_PATH="$1"
SESSION_ID="$2"
FLAG_FILE="/tmp/handoff-triggered-${SESSION_ID}"
SNOOZE_FILE="/tmp/handoff-snooze-${SESSION_ID}"

# Show dialog using osascript
RESULT=$(osascript -e '
tell application "System Events"
    activate
    set dialogResult to display dialog "Context at 60%.\nStart fresh with handoff?" ¬
        with title "Claude - Context Handoff" ¬
        buttons {"Dismiss", "In 5 min", "Handoff"} ¬
        default button "Handoff" ¬
        with icon caution
    return button returned of dialogResult
end tell
' 2>/dev/null)

case "$RESULT" in
    "In 5 min")
        rm -f "$FLAG_FILE"
        echo $(($(date +%s) + 300)) > "$SNOOZE_FILE"
        exit 0
        ;;
    "Dismiss"|"")
        exit 0
        ;;
esac

# Find transcript if not provided
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    TRANSCRIPT_PATH=$(find ~/.claude/projects -name "*.jsonl" -type f -print0 2>/dev/null | xargs -0 ls -t | head -1)
fi

if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    osascript -e 'display alert "Error" message "Could not find transcript file" as critical' 2>/dev/null
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
    osascript -e 'display alert "Error" message "Failed to generate handoff" as critical' 2>/dev/null
    exit 1
fi

# Save handoff
HANDOFF_FILE="/tmp/claude-handoff.txt"
echo "$HANDOFF" > "$HANDOFF_FILE"

# Detect terminal and open new tab
if [ "$TERM_PROGRAM" = "iTerm.app" ]; then
    # iTerm2
    osascript -e "
    tell application \"iTerm\"
        tell current window
            create tab with default profile
            tell current session
                write text \"claude --append-system-prompt \\\"\$(cat $HANDOFF_FILE)\\\"\"
            end tell
        end tell
    end tell
    " 2>/dev/null
elif [ "$TERM_PROGRAM" = "Apple_Terminal" ]; then
    # Apple Terminal
    osascript -e "
    tell application \"Terminal\"
        activate
        do script \"claude --append-system-prompt \\\"\$(cat $HANDOFF_FILE)\\\"\"
    end tell
    " 2>/dev/null
else
    # Fallback: show instructions
    osascript -e "display dialog \"Handoff saved to:\n$HANDOFF_FILE\n\nRun in new terminal:\nclaude --append-system-prompt \\\"\\\$(cat $HANDOFF_FILE)\\\"\" with title \"Handoff Ready\" buttons {\"OK\"}" 2>/dev/null
fi

echo "Handoff complete!"
