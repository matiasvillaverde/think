#!/bin/bash
#
# Generate 3 stable screenshots for README.md using the App-Screenshots UI harness
# (does not require building/running the full Think app UI).
#
# Output:
#   docs/readme/chat.png
#   docs/readme/models.png
#   docs/readme/stats.png
#   docs/readme/personalities.png
#

set -euo pipefail
trap 'echo "Error at line $LINENO: $BASH_COMMAND" >&2' ERR

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

OUT_DIR="docs/readme"
mkdir -p "$OUT_DIR"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required tool: $1" >&2
    exit 1
  fi
}

require_tool xcrun
require_tool xcodebuild

pick_simulator_udid() {
  local name
  local line
  local udid

  for name in "iPhone 17 Pro Max" "iPhone 17 Pro" "iPhone 16 Pro Max" "iPhone 16 Pro" "iPhone 15 Pro Max" "iPhone 15 Pro" "iPhone 14 Plus"; do
    line="$(xcrun simctl list devices available | grep -F "    $name (" | head -n 1 || true)"
    if [ -n "$line" ]; then
      udid="$(echo "$line" | awk -F '[()]' '{print $2}')"
      if [ -n "$udid" ]; then
        echo "$udid"
        return 0
      fi
    fi
  done

  # Fallback: first available iPhone
  line="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/{print; exit}')"
  udid="$(echo "$line" | awk -F '[()]' '{print $2}')"
  if [ -n "$udid" ]; then
    echo "$udid"
    return 0
  fi

  return 1
}

UDID="$(pick_simulator_udid || true)"
if [ -z "${UDID:-}" ]; then
  echo "No available iPhone simulator found. Install a simulator in Xcode." >&2
  exit 1
fi

DERIVED_DATA="build/DerivedData-ReadmeShots"
rm -rf "$DERIVED_DATA"
mkdir -p "$DERIVED_DATA"

cleanup() {
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Start from a known-clean simulator state.
xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
xcrun simctl erase "$UDID" >/dev/null 2>&1 || true
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true

# Make screenshots look like App Store marketing shots.
xcrun simctl ui "$UDID" appearance dark >/dev/null 2>&1 || true
xcrun simctl status_bar "$UDID" override \
  --time '9:41' \
  --dataNetwork wifi \
  --wifiMode active \
  --wifiBars 3 \
  --cellularMode active \
  --operatorName '' \
  --cellularBars 4 \
  --batteryState charged \
  --batteryLevel 100 >/dev/null 2>&1 || true

# Build the lightweight screenshot harness.
xcodebuild build \
  -workspace "./Think.xcworkspace" \
  -scheme "App-Screenshots" \
  -destination "platform=iOS Simulator,id=$UDID" \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  -quiet \
  | xcbeautify --is-ci

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/App-Screenshots.app"
if [ ! -d "$APP_PATH" ]; then
  echo "Failed to locate built app at: $APP_PATH" >&2
  exit 1
fi

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist" 2>/dev/null || true)"
if [ -z "${BUNDLE_ID:-}" ]; then
  echo "Failed to read CFBundleIdentifier from: $APP_PATH/Info.plist" >&2
  exit 1
fi

xcrun simctl install "$UDID" "$APP_PATH" >/dev/null 2>&1 || true

take_shot() {
  local screen_arg="$1"
  local out_file="$2"

  # Ensure a clean launch between shots.
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

  xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID" \
    -AppleLanguages "(en-US)" \
    -AppleLocale "en_US" \
    "-$screen_arg" >/dev/null

  # Give SwiftUI time to lay out and render.
  sleep 2

  xcrun simctl io "$UDID" screenshot --type=png "$out_file" >/dev/null
}

take_shot "SHOW_CHAT_MESSAGES" "$OUT_DIR/chat.png"
take_shot "SHOW_MODEL_SELECTION" "$OUT_DIR/models.png"
take_shot "SHOW_STATISTICS" "$OUT_DIR/stats.png"
take_shot "SHOW_PERSONALITIES" "$OUT_DIR/personalities.png"

# Keep file sizes reasonable for GitHub rendering.
for f in "$OUT_DIR/chat.png" "$OUT_DIR/models.png" "$OUT_DIR/stats.png" "$OUT_DIR/personalities.png"; do
  if command -v sips >/dev/null 2>&1; then
    sips -Z 1400 "$f" >/dev/null 2>&1 || true
  fi
done

echo "Wrote:"
echo "  $OUT_DIR/chat.png"
echo "  $OUT_DIR/models.png"
echo "  $OUT_DIR/stats.png"
echo "  $OUT_DIR/personalities.png"
