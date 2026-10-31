#!/usr/bin/env bash
set -euo pipefail
asterion_repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
asterion_tools="${ASTERION_TOOL_ROOT:-/workspace/.tools}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-/workspace/.local/share}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/workspace/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/workspace/.cache}"
case "$(godot --version)" in
    4.6.3.stable*) ;;
    *) echo 'Use Godot 4.6.3 to match the installed Android templates.' >&2; exit 1 ;;
esac
if ! [ -x "$asterion_tools/android/build-tools/35.0.2/apksigner" ] || \
   ! [ -f "$XDG_DATA_HOME/godot/export_templates/4.6.3.stable/android_debug.apk" ]; then
    "$asterion_repo/tools/setup_android.sh"
fi
mkdir -p "$asterion_repo/build"
asterion_apk="$asterion_repo/build/asterion-debug.apk"
godot --headless --path "$asterion_repo" --export-debug Android "$asterion_apk" \
    2>&1 | tee "$asterion_repo/build/android-export.log"
"$asterion_tools/android/build-tools/35.0.2/apksigner" verify --verbose "$asterion_apk" \
    | tee "$asterion_repo/build/android-signature.txt"
python3 "$asterion_repo/tools/inspect_apk.py" "$asterion_apk" \
    | tee "$asterion_repo/build/android-metadata.json"
sha256sum "$asterion_apk" | tee "$asterion_repo/build/asterion-debug.apk.sha256"
