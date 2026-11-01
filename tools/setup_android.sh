#!/usr/bin/env bash
# Prepares a Gradle-free Android debug export for Asterion (Linux x86_64).
# Needs: Godot 4.6.3 on PATH as `godot`, Java 17+ (keytool), curl, unzip and `apksigner`
# (Ubuntu/Debian: `sudo apt install apksigner`, or Android SDK build-tools).
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tools="${ASTERION_TOOL_ROOT:-$HOME/.asterion-tools}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
for dep in curl unzip java keytool godot apksigner sha512sum; do
    command -v "$dep" >/dev/null || { echo "Falta o pré-requisito: $dep" >&2; exit 1; }
done
case "$(godot --version)" in
    4.6.3.stable*) ;;
    *) echo 'Use o Godot 4.6.3 (mesma versão dos templates).' >&2; exit 1 ;;
esac
tpl_dir="$XDG_DATA_HOME/godot/export_templates/4.6.3.stable"
mkdir -p "$tools/downloads" "$tools/keys" "$tools/android/build-tools/35.0.0" "$tools/android/platform-tools" "$tpl_dir" "$XDG_CONFIG_HOME/godot"
if ! [ -f "$tpl_dir/android_debug.apk" ]; then
    tpz="$tools/downloads/Godot_v4.6.3-stable_export_templates.tpz"
    hash='da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404faa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68'
    if ! [ -f "$tpz" ] || ! printf '%s  %s\n' "$hash" "$tpz" | sha512sum --check --status; then
        curl --fail --location --retry 2 --proto '=https' -o "$tpz.part" \
            'https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz'
        printf '%s  %s\n' "$hash" "$tpz.part" | sha512sum --check
        mv "$tpz.part" "$tpz"
    fi
    unzip -j -o "$tpz" templates/android_debug.apk templates/android_release.apk templates/version.txt -d "$tpl_dir"
fi
# Minimal SDK layout that Godot expects: build-tools/<ver>/apksigner and platform-tools/adb.
printf '#!/usr/bin/env bash\nexec %q "$@"\n' "$(command -v apksigner)" > "$tools/android/build-tools/35.0.0/apksigner"
if command -v adb >/dev/null; then
    printf '#!/usr/bin/env bash\nexec %q "$@"\n' "$(command -v adb)" > "$tools/android/platform-tools/adb"
else
    printf '#!/usr/bin/env bash\necho "adb não instalado" >&2\nexit 1\n' > "$tools/android/platform-tools/adb"
fi
chmod +x "$tools/android/build-tools/35.0.0/apksigner" "$tools/android/platform-tools/adb"
if ! [ -f "$tools/keys/asterion-debug.keystore" ]; then
    # Public, standard Android debug identity — never use for store publishing.
    keytool -genkeypair -keystore "$tools/keys/asterion-debug.keystore" -storepass android -keypass android \
        -alias androiddebugkey -dname 'CN=Android Debug,O=Android,C=US' -keyalg RSA -keysize 2048 -validity 10000
fi
java_home="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
python3 - "$XDG_CONFIG_HOME/godot/editor_settings-4.6.tres" "$java_home" "$tools" <<'PY'
import json, pathlib, sys
path, java, tools = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
text = path.read_text() if path.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
updates = {
    'export/android/java_sdk_path': java,
    'export/android/android_sdk_path': tools + '/android',
    'export/android/debug_keystore': tools + '/keys/asterion-debug.keystore',
    'export/android/debug_keystore_user': 'androiddebugkey',
    'export/android/debug_keystore_pass': 'android',
}
lines = [l for l in text.splitlines() if l.split(' = ', 1)[0] not in updates]
lines += [k + ' = ' + json.dumps(v) for k, v in updates.items()]
path.write_text('\n'.join(lines) + '\n')
PY
echo "Pronto para exportar: ./tools/export_android.sh"
