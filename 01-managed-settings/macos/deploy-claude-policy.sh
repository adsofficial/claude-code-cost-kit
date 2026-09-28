#!/bin/bash
# Installs the Claude Code managed settings (company policy) on a Mac.
#
# Run as root, for example as a Jamf / Kandji / Intune-for-Mac policy script.
# Claude Code reads: /Library/Application Support/ClaudeCode/managed-settings.json
# Developers cannot override these settings. To check on a machine, run /status in
# Claude Code: "Setting sources" should show "Enterprise managed settings (file)".
#
# Usage: sudo ./deploy-claude-policy.sh [path/to/managed-settings.json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="${1:-$SCRIPT_DIR/../managed-settings.json}"
TARGET_DIR="/Library/Application Support/ClaudeCode"
TARGET="$TARGET_DIR/managed-settings.json"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root (sudo, or from your MDM)." >&2
  exit 1
fi

if [[ ! -f "$SOURCE" ]]; then
  echo "Policy file not found: $SOURCE" >&2
  exit 1
fi

# Validate JSON first. A managed file that is not valid JSON stops Claude Code from starting.
# (osascript's JavaScript engine ships with every macOS, so no python needed.)
if ! /usr/bin/osascript -l JavaScript \
     -e 'function run(a){ JSON.parse($.NSString.stringWithContentsOfFileEncodingError(a[0], $.NSUTF8StringEncoding, null).js); return "ok" }' \
     "$SOURCE" >/dev/null 2>&1; then
  echo "managed-settings.json is not valid JSON" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"
cp "$SOURCE" "$TARGET"
chown root:wheel "$TARGET"
chmod 644 "$TARGET"   # readable by everyone, writable only by root

echo "Claude Code policy installed at $TARGET"
