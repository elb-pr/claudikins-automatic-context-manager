#!/bin/bash
# Claudikins ACM - Run handoff
# Called by Claude after user confirms handoff
# Generates summary and opens new session

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load config
CONFIG_FILE="$HOME/.claude/claudikins-acm.conf"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

SUMMARY_TOKENS="${SUMMARY_TOKENS:-500}"

# Find most recent transcript
TRANSCRIPT=$(find ~/.claude/projects -name "*.jsonl" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
    echo "ERROR: Could not find transcript file" >&2
    exit 1
fi

echo "Generating handoff summary..."

# Extract recent conversation
CONVERSATION=$(cat "$TRANSCRIPT" | grep -E '"type":"(user|assistant)"' | tail -50 | \
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

# Get git context
GIT_CONTEXT=""
if command -v git &> /dev/null && git rev-parse --is-inside-work-tree &> /dev/null; then
    GIT_CONTEXT=$(cat <<EOF

GIT CONTEXT:
- Branch: $(git branch --show-current 2>/dev/null)
- Recent commits: $(git log --oneline -3 2>/dev/null | tr '\n' '; ')
- Modified files: $(git status --short 2>/dev/null | head -5 | tr '\n' '; ')
EOF
)
fi

# Generate summary via claude -p
SUMMARY=$(echo "$CONVERSATION$GIT_CONTEXT" | claude -p "Generate a concise handoff summary (under $SUMMARY_TOKENS tokens) for continuing this conversation in a new session.

Include:
1. Current objective - what we're working on
2. Progress so far - what's been done
3. Active work - what was in progress
4. Key decisions - important choices made
5. Next steps - what to do next

Format as markdown. Be specific and actionable.

CONVERSATION:
" 2>/dev/null)

if [ -z "$SUMMARY" ]; then
    echo "ERROR: Failed to generate summary" >&2
    exit 1
fi

# Save to project-local location
HANDOFF_DIR=".claude/claudikins-acm"
mkdir -p "$HANDOFF_DIR"
HANDOFF_FILE="$HANDOFF_DIR/handoff.md"

cat > "$HANDOFF_FILE" << EOF
# Claudikins ACM Handoff

*Generated: $(date)*

$SUMMARY

---
*Use /acm:handoff to review this context*
EOF

echo "Handoff saved to: $HANDOFF_FILE"

# Clean up the hook that triggered this
rm -f ".claude/hookify.handoff-request.local.md"

# Launch new terminal with claude
echo "Opening new session..."

CWD="$(pwd)"
LAUNCHED=false

launch_terminal() {
    # Windows (native - Git Bash, PowerShell, etc.)
    if [ -n "$WINDIR" ] && [ -z "$WSL_DISTRO_NAME" ]; then
        if command -v wt.exe &> /dev/null; then
            # Windows Terminal - new tab (works with Git Bash, PowerShell, etc.)
            if [ -n "$MSYSTEM" ]; then
                # Running in Git Bash/MSYS2 - open Git Bash tab
                wt.exe -w 0 new-tab --title "Claude" -d "$CWD" bash -c "claude"
            else
                # PowerShell
                wt.exe -w 0 new-tab --title "Claude" -d "$CWD" pwsh -NoExit -c "claude"
            fi
            LAUNCHED=true
        elif [ -n "$MSYSTEM" ]; then
            # Git Bash without Windows Terminal - new window
            start "" "git-bash" -c "cd '$CWD' && claude && exec bash"
            LAUNCHED=true
        else
            # Plain PowerShell - new window
            powershell.exe -Command "Start-Process pwsh -ArgumentList '-NoExit','-c','cd \"$CWD\"; claude'"
            LAUNCHED=true
        fi
        return
    fi

    # WSL
    if grep -qi microsoft /proc/version 2>/dev/null; then
        if command -v wt.exe &> /dev/null; then
            # Windows Terminal with WSL tab
            wt.exe -w 0 new-tab --title "Claude" -- wsl.exe bash -c "cd '$CWD' && claude"
            LAUNCHED=true
        elif pgrep -x "warp" > /dev/null 2>&1 || pgrep -f "Warp.exe" > /dev/null 2>&1; then
            # Warp on WSL - uses SendKeys (see README for details)
            powershell.exe -Command "
                Add-Type -AssemblyName System.Windows.Forms
                \$warp = Get-Process -Name 'Warp' -ErrorAction SilentlyContinue
                if (\$warp) {
                    [Microsoft.VisualBasic.Interaction]::AppActivate(\$warp.Id)
                    Start-Sleep -Milliseconds 300
                    [System.Windows.Forms.SendKeys]::SendWait('^+t')
                    Start-Sleep -Milliseconds 500
                    Set-Clipboard 'cd $CWD && claude'
                    [System.Windows.Forms.SendKeys]::SendWait('^v')
                    Start-Sleep -Milliseconds 200
                    [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
                }
            " 2>/dev/null
            LAUNCHED=true
        fi
        return
    fi

    # macOS
    if [ "$(uname)" = "Darwin" ]; then
        case "$TERM_PROGRAM" in
            "iTerm.app")
                osascript <<EOF
tell application "iTerm"
    tell current window
        create tab with default profile
        tell current session
            write text "cd '$CWD' && claude"
        end tell
    end tell
end tell
EOF
                LAUNCHED=true
                ;;
            "Apple_Terminal"|"")
                osascript <<EOF
tell application "Terminal"
    activate
    tell application "System Events" to keystroke "t" using command down
    delay 0.3
    do script "cd '$CWD' && claude" in front window
end tell
EOF
                LAUNCHED=true
                ;;
            "WarpTerminal")
                # Warp supports CLI
                open -a "Warp" "$CWD"
                sleep 0.5
                osascript -e 'tell application "System Events" to keystroke "t" using command down'
                LAUNCHED=true
                ;;
        esac
        return
    fi

    # Linux
    if [ "$(uname)" = "Linux" ]; then
        if command -v gnome-terminal &> /dev/null; then
            gnome-terminal --tab --working-directory="$CWD" -- bash -c "claude; exec bash"
            LAUNCHED=true
        elif command -v konsole &> /dev/null; then
            konsole --new-tab --workdir "$CWD" -e bash -c "claude; exec bash"
            LAUNCHED=true
        elif command -v xfce4-terminal &> /dev/null; then
            xfce4-terminal --tab --working-directory="$CWD" -e "bash -c 'claude; exec bash'"
            LAUNCHED=true
        elif command -v kitty &> /dev/null; then
            kitty @ launch --type=tab --cwd="$CWD" bash -c "claude; exec bash"
            LAUNCHED=true
        fi
        return
    fi
}

launch_terminal

# Fallback - copy to clipboard and show message
if [ "$LAUNCHED" = false ]; then
    CMD="cd '$CWD' && claude"

    # Try to copy to clipboard
    if command -v pbcopy &> /dev/null; then
        echo "$CMD" | pbcopy
    elif command -v xclip &> /dev/null; then
        echo "$CMD" | xclip -selection clipboard
    elif command -v xsel &> /dev/null; then
        echo "$CMD" | xsel --clipboard
    elif command -v clip.exe &> /dev/null; then
        echo "$CMD" | clip.exe
    fi

    echo ""
    echo "Open a new terminal and run:"
    echo "  $CMD"
    echo ""
    echo "(Command copied to clipboard if available)"
    echo "The handoff will load automatically via SessionStart hook."
fi

echo "Handoff complete!"
