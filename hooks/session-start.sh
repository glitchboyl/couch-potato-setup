#!/bin/sh
# session-start.sh — runs at Claude Code session start
# Checks if a newer version of Couch Potato is available on GitHub.

LOCAL_VERSION_FILE="${CLAUDE_PLUGIN_ROOT}/VERSION"
REMOTE_VERSION_URL="https://raw.githubusercontent.com/glitchboyl/couch-potato/main/VERSION"

# Read local version
if [ ! -f "$LOCAL_VERSION_FILE" ]; then
  exit 0
fi
LOCAL_VERSION=$(cat "$LOCAL_VERSION_FILE" | tr -d '[:space:]')

# Fetch remote version (fail silently — no network = no notification)
REMOTE_VERSION=$(curl -sf --max-time 3 "$REMOTE_VERSION_URL" 2>/dev/null | tr -d '[:space:]')
if [ -z "$REMOTE_VERSION" ]; then
  exit 0
fi

# Compare (simple string compare works for semver X.Y.Z if zero-padded or same length)
# For robust comparison, use sort -V if available
if command -v sort > /dev/null 2>&1; then
  LATEST=$(printf '%s\n%s' "$LOCAL_VERSION" "$REMOTE_VERSION" | sort -V | tail -n1)
else
  LATEST="$REMOTE_VERSION"
fi

if [ "$LATEST" != "$LOCAL_VERSION" ]; then
  echo "Couch Potato update available: $LOCAL_VERSION -> $REMOTE_VERSION"
  echo "Run /couch-potato:update to upgrade."
fi
