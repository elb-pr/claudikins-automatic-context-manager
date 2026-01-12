# CC-ACM: Generic Version

> **EXPERIMENTAL** - Works anywhere but requires manual new terminal.

Terminal-agnostic version using simple text prompts. Works on any system but doesn't auto-open new terminal tabs.

## Requirements

- Claude Code CLI
- Python 3
- Bash

## Installation

```bash
# Copy script
mkdir -p ~/.claude/scripts
cp handoff-prompt.sh ~/.claude/scripts/
chmod +x ~/.claude/scripts/handoff-prompt.sh
```

Then add the trigger to your `~/.claude/statusline-command.sh` - see main README.

## How It Works

1. Shows text-based menu in terminal
2. On handoff, generates summary and saves to `/tmp/claude-handoff.txt`
3. Prints command to run in new terminal
4. Copies command to clipboard if possible (pbcopy/xclip/xsel)

## Notes

- No GUI dependencies
- Works over SSH
- Works in tmux/screen
- Manual step required to open new terminal
