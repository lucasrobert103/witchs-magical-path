#!/usr/bin/env bash
# Exports build/asterion.apk (debug-signed, ARM64, Android 7.0+).
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tools="${ASTERION_TOOL_ROOT:-$HOME/.asterion-tools}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
if ! [ -f "$XDG_DATA_HOME/godot/export_templates/4.6.3.stable/android_debug.apk" ] || ! [ -x "$tools/android/build-tools/35.0.0/apksigner" ]; then
    "$repo/tools/setup_android.sh"
fi
mkdir -p "$repo/build"
touch "$repo/build/.gdignore"
apk="$repo/build/asterion.apk"
godot --headless --path "$repo" --import >/dev/null 2>&1 || true
godot --headless --path "$repo" --export-debug Android "$apk" 2>&1 | tee "$repo/build/android-export.log"
apksigner verify --verbose "$apk" | tee "$repo/build/android-signature.txt"
python3 "$repo/tools/inspect_apk.py" "$apk" --expect-version 1.0.0 --require-game-assets | tee "$repo/build/android-metadata.json"
sha256sum "$apk" | tee "$apk.sha256"
ls -lh "$apk"
