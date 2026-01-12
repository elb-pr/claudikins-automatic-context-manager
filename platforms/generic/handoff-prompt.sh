#!/bin/bash
# CC-ACM: Generic version - terminal agnostic
# EXPERIMENTAL - Works anywhere but requires manual new terminal

TRANSCRIPT_PATH="$1"
SESSION_ID="$2"
FLAG_FILE="/tmp/handoff-triggered-${SESSION_ID}"
SNOOZE_FILE="/tmp/handoff-snooze-${SESSION_ID}"

# Simple text prompt (works in any terminal)
echo ""
echo "╭─────────────────────────────────────╮"
echo "│     Context Handoff (60%)           │"
echo "╰─────────────────────────────────────╯"
echo ""
echo "Options:"
echo "  [h] Handoff - Generate summary and prepare new session"
echo "  [s] Snooze  - Remind in 5 minutes"
echo "  [d] Dismiss - Don't ask again this session"
echo ""
read -p "Choice [h/s/d]: " -n 1 CHOICE
echo ""

case "$CHOICE" in
    s|S)
        rm -f "$FLAG_FILE"
        echo $(($(date +%s) + 300)) > "$SNOOZE_FILE"
        echo "Snoozed for 5 minutes."
        exit 0
        ;;
    d|D|"")
        echo "Dismissed."
        exit 0
        ;;
esac

# Find transcript if not provided
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    # Try Linux find first, fall back to macOS compatible
    TRANSCRIPT_PATH=$(find ~/.claude/projects -name "*.jsonl" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
    if [ -z "$TRANSCRIPT_PATH" ]; then
        TRANSCRIPT_PATH=$(find ~/.claude/projects -name "*.jsonl" -type f -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -1)
    fi
fi

if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    echo "Error: Could not find transcript file"
    exit 1
fi

echo "Generating handoff summary..."

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
    echo "Error: Failed to generate handoff"
    exit 1
fi

# Save handoff
HANDOFF_FILE="/tmp/claude-handoff.txt"
echo "$HANDOFF" > "$HANDOFF_FILE"

echo ""
echo "╭─────────────────────────────────────╮"
echo "│     Handoff Ready!                  │"
echo "╰─────────────────────────────────────╯"
echo ""
echo "Saved to: $HANDOFF_FILE"
echo ""
echo "Open a new terminal and run:"
echo ""
echo "  claude --append-system-prompt \"\$(cat $HANDOFF_FILE)\""
echo ""

# Copy command to clipboard if possible
if command -v pbcopy &> /dev/null; then
    echo "claude --append-system-prompt \"\$(cat $HANDOFF_FILE)\"" | pbcopy
    echo "(Command copied to clipboard)"
elif command -v xclip &> /dev/null; then
    echo "claude --append-system-prompt \"\$(cat $HANDOFF_FILE)\"" | xclip -selection clipboard
    echo "(Command copied to clipboard)"
elif command -v xsel &> /dev/null; then
    echo "claude --append-system-prompt \"\$(cat $HANDOFF_FILE)\"" | xsel --clipboard
    echo "(Command copied to clipboard)"
fi
