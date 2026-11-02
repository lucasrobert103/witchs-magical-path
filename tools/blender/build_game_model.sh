#!/usr/bin/env bash
# Gera assets/characters/asterion/asterion.glb (versão leve para o jogo).
# Usa o Blender instalado (variável BLENDER) ou o módulo Python "bpy".
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="$here/../../assets/characters/asterion"
mkdir -p "$out"
export ASTERION_OUT="$out" ASTERION_QUALITY=jogo
if [ -n "${BLENDER:-}" ]; then
  "$BLENDER" --background --factory-startup --python "$here/asterion_blender.py"
else
  python3 "$here/asterion_blender.py"
fi
rm -f "$out/asterion.blend" "$out/asterion.blend1"
echo "Modelo do jogo: $out/asterion.glb"
