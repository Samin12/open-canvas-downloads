#!/usr/bin/env bash
set -euo pipefail

REPO="Samin12/open-canvas-downloads"
LATEST_RELEASE_API="https://api.github.com/repos/${REPO}/releases/latest"
APP_NAME="Open Canvas.app"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Open Canvas currently ships as a macOS build only."
  exit 1
fi

ARCH="$(uname -m)"

case "$ARCH" in
  arm64|aarch64)
    ASSET_SUFFIX="-arm64.dmg"
    ;;
  x86_64)
    echo "An Intel macOS build is not published yet."
    exit 1
    ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

require_command curl
require_command python3
require_command hdiutil
require_command ditto

echo "Resolving latest Open Canvas release..."
release_json="$(curl -fsSL "$LATEST_RELEASE_API")"

asset_url="$(
  RELEASE_JSON="$release_json" python3 - "$ASSET_SUFFIX" <<'PY'
import json
import os
import sys

suffix = sys.argv[1]
release = json.loads(os.environ["RELEASE_JSON"])

for asset in release.get("assets", []):
    url = asset.get("browser_download_url", "")
    if url.endswith(suffix):
        print(url)
        break
PY
)"

if [[ -z "$asset_url" ]]; then
  echo "Could not find a release asset ending in $ASSET_SUFFIX"
  exit 1
fi

tmp_dir="$(mktemp -d)"
cleanup() {
  if mount | grep -q "$tmp_dir/mount"; then
    hdiutil detach "$tmp_dir/mount" -quiet || true
  fi
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

dmg_path="$tmp_dir/Open-Canvas.dmg"
mkdir -p "$tmp_dir/mount"

echo "Downloading DMG..."
curl -fL "$asset_url" -o "$dmg_path"

echo "Mounting DMG..."
mount_output="$(hdiutil attach "$dmg_path" -mountpoint "$tmp_dir/mount" -nobrowse -quiet 2>&1 || true)"
if ! mount | grep -Fq "on $tmp_dir/mount "; then
  echo "$mount_output"
  echo "Failed to mount DMG."
  exit 1
fi

app_path="$tmp_dir/mount/$APP_NAME"
if [[ ! -d "$app_path" ]]; then
  echo "Could not find $APP_NAME in the mounted DMG."
  exit 1
fi

echo "Installing to /Applications..."
rm -rf "/Applications/$APP_NAME"
ditto "$app_path" "/Applications/$APP_NAME"

echo "Installed Open Canvas."
echo "If macOS warns that the app is unsigned, right-click it and choose Open once."

open -a "/Applications/$APP_NAME" || true
