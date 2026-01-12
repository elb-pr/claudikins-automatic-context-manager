# CC-ACM: macOS Version

> **EXPERIMENTAL** - Not fully tested. Contributions welcome!

Native macOS version using osascript/AppleScript for dialogs.

## Requirements

- Claude Code CLI
- Python 3
- macOS (tested on Sonoma)

## Installation

```bash
# Copy script
mkdir -p ~/.claude/scripts
cp handoff-prompt.sh ~/.claude/scripts/
chmod +x ~/.claude/scripts/handoff-prompt.sh
```

Then add the trigger to your `~/.claude/statusline-command.sh` - see main README.

## Supported Terminals

- **iTerm2** - Opens new tab automatically
- **Apple Terminal** - Opens new window
- **Other** - Shows instructions dialog

## Notes

- Uses native macOS dialogs via osascript
- May require accessibility permissions on first run
- Dialog styling is standard macOS - doesn't match Claude aesthetic
