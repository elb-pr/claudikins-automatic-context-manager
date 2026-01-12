# CC-ACM: Linux (Zenity) Version

> **EXPERIMENTAL** - Not fully tested. Contributions welcome!

Native Linux version using Zenity for GTK dialogs.

## Requirements

- Claude Code CLI
- Zenity (`sudo apt install zenity`)
- Python 3
- gnome-terminal (optional, for auto new-tab)

## Installation

```bash
# Install zenity if needed
sudo apt install zenity

# Copy script
mkdir -p ~/.claude/scripts
cp handoff-prompt.sh ~/.claude/scripts/
chmod +x ~/.claude/scripts/handoff-prompt.sh
```

Then add the trigger to your `~/.claude/statusline-command.sh` - see main README.

## Notes

- Falls back to showing instructions if gnome-terminal not available
- Dialog styling is basic GTK - doesn't match Claude aesthetic
- Tested on Ubuntu with GNOME
