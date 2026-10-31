#!/usr/bin/env bash
# Reproducible cloud-only APK tooling: Godot templates + open-source AOSP tools.
# Does not install the Google SDK, accept its terms, or create a production key.
set -euo pipefail
asterion_repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
asterion_tools="${ASTERION_TOOL_ROOT:-/workspace/.tools}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-/workspace/.local/share}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/workspace/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/workspace/.cache}"
for dependency in curl python3 unzip dpkg-deb java keytool godot; do
    command -v "$dependency" >/dev/null || { echo "Missing prerequisite: $dependency" >&2; exit 1; }
done
case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) ;;
    *) echo 'This minimal cloud toolchain targets a Linux x86_64 build host.' >&2; exit 1 ;;
esac
case "$(godot --version)" in
    4.6.3.stable*) ;;
    *) echo 'Use the official Godot 4.6.3 editor to match these export templates.' >&2; exit 1 ;;
esac
mkdir -p "$asterion_tools/downloads" "$asterion_tools/aosp-tools" "$asterion_tools/keys" \
    "$asterion_tools/android/build-tools/35.0.2" "$asterion_tools/android/platform-tools" \
    "$XDG_DATA_HOME/godot/export_templates/4.6.3.stable" "$XDG_CONFIG_HOME/godot" "$XDG_CACHE_HOME"

# Digests below were verified against Debian's signed trixie package index.
python3 - "$asterion_repo/tools/android-tools.lock.json" "$asterion_tools" <<'PY'
import hashlib, json, pathlib, subprocess, sys
manifest, root = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
for package in json.loads(manifest.read_text()):
    archive = root / 'downloads' / package['url'].rsplit('/', 1)[1]
    def verified():
        return archive.exists() and hashlib.sha256(archive.read_bytes()).hexdigest() == package['sha256']
    if not verified():
        temporary = archive.with_suffix(archive.suffix + '.part')
        subprocess.run(['curl', '--fail', '--location', '--retry', '2', '--proto', '=https', package['url'], '-o', str(temporary)], check=True)
        temporary.replace(archive)
    if not verified():
        raise SystemExit(f'Checksum mismatch: {archive.name}')
    subprocess.run(['dpkg-deb', '-x', str(archive), str(root / 'aosp-tools')], check=True)
PY

asterion_template="$asterion_tools/downloads/Godot_v4.6.3-stable_export_templates.tpz"
asterion_template_hash='da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404faa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68'
# Verify all retained templates against the official archive on every setup run.
if ! [ -f "$asterion_template" ] || ! printf '%s  %s\n' "$asterion_template_hash" "$asterion_template" | sha512sum --check --status; then
    curl --fail --location --retry 2 --proto '=https' \
        'https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz' \
        -o "$asterion_template.part"
    printf '%s  %s\n' "$asterion_template_hash" "$asterion_template.part" | sha512sum --check
    mv "$asterion_template.part" "$asterion_template"
fi
unzip -j -o "$asterion_template" templates/android_debug.apk templates/android_release.apk templates/version.txt \
    -d "$XDG_DATA_HOME/godot/export_templates/4.6.3.stable"

# Wrappers only relocate the Debian/AOSP executables; licensing notices stay in aosp-tools/usr/share/doc.
python3 - "$asterion_tools" "$XDG_CONFIG_HOME" <<'PY'
import json, pathlib, shutil, sys
root, config = pathlib.Path(sys.argv[1]).resolve(), pathlib.Path(sys.argv[2])
import shlex
q = shlex.quote
signer = root / 'android/build-tools/35.0.2/apksigner'
signer.write_text('#!/usr/bin/env bash\nset -euo pipefail\nexec java -cp ' + q(str(root / 'aosp-tools/usr/share/java/apksigner.jar') + ':' + str(root / 'aosp-tools/usr/share/java/apksig.jar')) + ' com.android.apksigner.ApkSignerTool "$@"\n')
adb = root / 'android/platform-tools/adb'
libraries = str(root / 'aosp-tools/usr/lib/x86_64-linux-gnu/android') + ':' + str(root / 'aosp-tools/usr/lib/x86_64-linux-gnu')
adb.write_text('#!/usr/bin/env bash\nset -euo pipefail\nexec env LD_LIBRARY_PATH=' + q(libraries) + ' ' + q(str(root / 'aosp-tools/usr/lib/android-sdk/platform-tools/adb')) + ' "$@"\n')
signer.chmod(0o755)
adb.chmod(0o755)
java = pathlib.Path(shutil.which('java')).resolve().parent.parent
settings = config / 'godot/editor_settings-4.6.tres'
text = settings.read_text() if settings.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
updates = {
    'export/android/java_sdk_path': str(java),
    'export/android/android_sdk_path': str(root / 'android'),
    'export/android/debug_keystore': str(root / 'keys/asterion-debug.keystore'),
    'export/android/debug_keystore_user': 'androiddebugkey',
    'export/android/debug_keystore_pass': 'android',  # Public, standard Android debug credential.
    'export/android/shutdown_adb_on_exit': False,
}
lines = [line for line in text.splitlines() if line.split(' = ', 1)[0] not in updates]
for name, value in updates.items():
    lines.append(name + ' = ' + json.dumps(value, ensure_ascii=False))
settings.write_text('\n'.join(lines) + '\n')
PY
if ! [ -f "$asterion_tools/keys/asterion-debug.keystore" ]; then
    # Standard public debug identity; never use this key/password for publication.
    keytool -genkeypair -keystore "$asterion_tools/keys/asterion-debug.keystore" \
        -storepass android -keypass android -alias androiddebugkey \
        -dname 'CN=Android Debug,O=Android,C=US' -keyalg RSA -keysize 2048 -validity 10000
fi
"$asterion_tools/android/build-tools/35.0.2/apksigner" --version
"$asterion_tools/android/platform-tools/adb" version
echo 'Android debug export tools ready. No Google SDK terms were accepted.'
