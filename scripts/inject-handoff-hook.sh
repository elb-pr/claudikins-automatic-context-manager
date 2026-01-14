#!/bin/bash
# Claudikins ACM - Inject handoff request hook
# Called by statusline when context threshold is reached
# Creates a hookify rule that triggers on next user prompt

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
THRESHOLD="${1:-60}"

# Target location - project's .claude directory
TARGET_DIR=".claude"
TARGET_FILE="$TARGET_DIR/hookify.handoff-request.local.md"

# Don't re-inject if already exists
if [ -f "$TARGET_FILE" ]; then
    exit 0
fi

# Ensure .claude directory exists
mkdir -p "$TARGET_DIR"

# Read template and replace placeholders
TEMPLATE="$SCRIPT_DIR/handoff-request-template.md"
if [ ! -f "$TEMPLATE" ]; then
    echo "Template not found: $TEMPLATE" >&2
    exit 1
fi

# Replace placeholders and write
sed -e "s|THRESHOLD_VALUE|$THRESHOLD|g" \
    -e "s|PLUGIN_ROOT|$PLUGIN_ROOT|g" \
    "$TEMPLATE" > "$TARGET_FILE"

# Log for debugging
echo "Injected handoff hook at $THRESHOLD% threshold" >&2
