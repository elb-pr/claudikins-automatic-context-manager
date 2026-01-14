```
 ██████╗██╗      █████╗ ██╗   ██╗██████╗ ██╗██╗  ██╗██╗███╗   ██╗███████╗
██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██║██║ ██╔╝██║████╗  ██║██╔════╝
██║     ██║     ███████║██║   ██║██║  ██║██║█████╔╝ ██║██╔██╗ ██║███████╗
██║     ██║     ██╔══██║██║   ██║██║  ██║██║██╔═██╗ ██║██║╚██╗██║╚════██║
╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝██║██║  ██╗██║██║ ╚████║███████║
 ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚══════╝
                     █████╗  ██████╗███╗   ███╗
                    ██╔══██╗██╔════╝████╗ ████║
                    ███████║██║     ██╔████╔██║
                    ██╔══██║██║     ██║╚██╔╝██║
                    ██║  ██║╚██████╗██║ ╚═╝ ██║
                    ╚═╝  ╚═╝ ╚═════╝╚═╝     ╚═╝
            ░▒▓ Automatic Context Manager ▓▒░
```

Automatic context handoff for Claude Code. When context usage hits 60%, a dialog prompts you to generate a summary and continue in a fresh session.

**Requirements**: Claude Code CLI, WSL, Warp terminal, Python 3.

## What It Does

1. Statusline monitors context usage
2. At 60% (configurable), a dialog appears
3. Click YES - generates a summary via `claude -p`
4. Summary saved to `.claude/claudikins-acm/handoff.md` (project-local)
5. New Warp tab opens with `claude`
6. SessionStart hook auto-loads the handoff

## Installation

### As a Plugin (Recommended)

```bash
claude --plugin-dir /path/to/claudikins-acm
```

Or add to your project's `.claude/settings.json`:

```json
{
  "plugins": ["/path/to/claudikins-acm"]
}
```

### Manual Installation

```bash
./install.sh
```

## How It Works

```
Statusline runs every 300ms
    │
    └─ Context >= 60%?
           │
           YES → handoff-prompt.sh (background)
                    │
                    ├─ Dialog appears (retro ASCII style)
                    │
                    ├─ [YES] → claude -p generates summary
                    │          → Writes to .claude/claudikins-acm/handoff.md
                    │          → Opens new Warp tab
                    │          → SessionStart hook fires
                    │          → Claude auto-invokes /acm:handoff
                    │
                    ├─ [SNOOZE] → Asks again in 5 min (configurable)
                    │
                    └─ [DISMISS] → Won't ask again this session
```

## Plugin Structure

```
claudikins-acm/
├── .claude-plugin/
│   └── plugin.json           # Plugin manifest
├── hooks/
│   ├── hooks.json            # SessionStart hook config
│   └── scripts/
│       └── session-start.sh  # Detects handoff, tells Claude to load it
├── skills/
│   ├── acm-config/           # /acm:config - interactive settings
│   └── acm-handoff/          # /acm:handoff - loads handoff content
├── scripts/
│   ├── handoff-prompt.sh     # Dialog + handoff generation
│   └── statusline-command.sh # Statusline with trigger logic
└── platforms/                # Platform-specific implementations
```

## Project-Local State

Handoff state is stored per-project, so handoffs only load in the same project:

```
your-project/
└── .claude/
    └── claudikins-acm/
        └── handoff.md        # Project-specific handoff content

~/.claude/
└── claudikins-acm.conf       # Global configuration
```

## Configuration

Use `/acm:config` in Claude for interactive setup, or edit `~/.claude/claudikins-acm.conf`:

```bash
THRESHOLD=60           # Context % to trigger (50-90)
SNOOZE_DURATION=300    # Seconds before re-prompting (60-3600)
SUMMARY_TOKENS=500     # Max tokens for summary (200-2000)
```

## Technical Details

**Handoff Trigger**: When context hits threshold, a hookify rule is injected into `.claude/hookify.handoff-request.local.md`. On your next message, Claude asks you via native `AskUserQuestion` dialog - no external popups needed.

**Summary Generation**: Extracts recent conversation from transcript, includes git context if available, sends to `claude -p` for summarisation.

**SessionStart Hook**: Checks if `.claude/claudikins-acm/handoff.md` exists in the current project. If so, injects context telling Claude to immediately invoke `/acm:handoff`.

## Platform Support

| Platform | Terminal | New Tab Method |
|----------|----------|----------------|
| Windows native | Windows Terminal | `wt.exe new-tab` (Git Bash or PowerShell) |
| Windows native | Git Bash | New window via `start git-bash` |
| Windows native | PowerShell | New window via `Start-Process` |
| WSL | Windows Terminal | `wt.exe new-tab wsl` |
| WSL | Warp | SendKeys* |
| macOS | iTerm2 | osascript |
| macOS | Terminal.app | osascript (Cmd+T) |
| macOS | Warp | osascript |
| Linux | GNOME Terminal | `--tab` flag |
| Linux | Konsole | `--new-tab` flag |
| Linux | XFCE Terminal | `--tab` flag |
| Linux | Kitty | `@ launch --type=tab` |
| Fallback | Any | Clipboard + instructions |

### *Warp on WSL (SendKeys)

Warp doesn't expose a CLI for opening new tabs, so we use PowerShell SendKeys automation:
1. Focus Warp window
2. Send Ctrl+Shift+T (new tab)
3. Paste command from clipboard
4. Send Enter

This is fragile but works reliably. If Warp adds proper CLI support in future, we'll update.

## Uninstall

```bash
./uninstall.sh
```

## Part of the Claudikins Framework

This is one component of the broader Claudikins ecosystem for Claude Code enhancement.
