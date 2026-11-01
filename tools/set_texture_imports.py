#!/usr/bin/env python3
"""Sets import options: 3D textures get mipmaps + GPU (ETC2/S3TC) compression; UI stays lossless."""
import glob, os, re
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
THREE_D = ['assets/sprites/env', 'assets/sprites/witch', 'assets/sprites/enemy', 'assets/sprites/fx', 'assets/textures']
for imp in glob.glob(os.path.join(ROOT, 'assets', '**', '*.png.import'), recursive=True):
    rel = os.path.relpath(imp, ROOT)
    s = open(imp).read()
    is3d = any(rel.startswith(d) for d in THREE_D) and not rel.endswith('portrait.png.import')
    s = re.sub(r'compress/mode=\d', 'compress/mode=%d' % (2 if is3d else 0), s)
    s = re.sub(r'mipmaps/generate=\w+', 'mipmaps/generate=%s' % ('true' if is3d else 'false'), s)
    s = re.sub(r'detect_3d/compress_to=\d', 'detect_3d/compress_to=0', s)
    open(imp, 'w').write(s)
print('ok')
