#!/usr/bin/env python3
"""Dialogue portrait and app icons from the reference close-up of Asterion's face.

Outputs:
  assets/sprites/witch/portrait.png      512x512, painted backdrop + face (bottom fades out)
  assets/sprites/witch/portrait.json     eye rectangles (for blinking) in portrait pixels
  assets/icon.png                        512x512 project icon
  assets/icons/icon_192.png              legacy launcher icon
  assets/icons/adaptive_fg.png           432x432 adaptive foreground (art in the safe zone)
  assets/icons/adaptive_bg.png           432x432 adaptive background
  assets/icons/adaptive_mono.png         432x432 monochrome (themed icons)
"""
import json
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
import sys
sys.path.insert(0, HERE)
from build_witch_sprites import despeckle  # noqa: E402

# Eye centres and sizes in the 320x320 close-up (measured on the source).
EYES = [(125.0, 175.0, 42.0, 24.0), (207.0, 174.0, 46.0, 25.0)]


def face_rgba():
    im = np.asarray(Image.open(os.path.join(HERE, 'source', 'face.png')).convert('RGBA'), dtype=np.float32) / 255.0
    im = despeckle(im)
    return Image.fromarray((np.clip(im, 0, 1) * 255).astype(np.uint8), 'RGBA')


def painted_backdrop(size, seed=3, warm=1.0):
    rnd = random.Random(seed)
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    d = np.sqrt((x - 0.52) ** 2 + (y - 0.36) ** 2)
    c0 = np.array([0.98, 0.82, 0.52]) * warm + np.array([0.3, 0.45, 0.4]) * (1 - warm)
    c1 = np.array([0.33, 0.5, 0.38])
    c2 = np.array([0.05, 0.12, 0.1])
    t1 = np.clip(d / 0.45, 0, 1)[..., None]
    t2 = np.clip((d - 0.45) / 0.4, 0, 1)[..., None]
    col = c0 * (1 - t1) + c1 * t1
    col = col * (1 - t2) + c2 * t2
    img = Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8), 'RGB').convert('RGBA')
    # Bokeh: soft discs of leaf-filtered light.
    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    dr = ImageDraw.Draw(layer)
    for _ in range(int(size / 9)):
        cx, cy = rnd.random() * size, rnd.random() * size * 0.85
        r = size * (0.015 + rnd.random() * 0.05)
        tone = rnd.choice([(255, 226, 150), (255, 200, 120), (170, 220, 160), (255, 245, 210)])
        dr.ellipse([cx - r, cy - r, cx + r, cy + r], fill=tone + (int(30 + rnd.random() * 60),))
    layer = layer.filter(ImageFilter.GaussianBlur(size * 0.008))
    img.alpha_composite(layer)
    # Light rays from the upper left.
    rays = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    dr = ImageDraw.Draw(rays)
    for i in range(5):
        x0 = size * (0.05 + i * 0.16)
        dr.polygon([(x0, 0), (x0 + size * 0.06, 0), (x0 + size * 0.35, size), (x0 + size * 0.22, size)], fill=(255, 240, 200, 26))
    img.alpha_composite(rays.filter(ImageFilter.GaussianBlur(size * 0.02)))
    return img


def place_face(canvas, face, scale, eyes_to):
    w = int(face.width * scale)
    f = face.resize((w, w), Image.LANCZOS)
    mid = ((EYES[0][0] + EYES[1][0]) * 0.5 * scale, (EYES[0][1] + EYES[1][1]) * 0.5 * scale)
    off = (int(eyes_to[0] - mid[0]), int(eyes_to[1] - mid[1]))
    # Fade the straight cut at the bottom of the source into the backdrop.
    a = np.asarray(f, dtype=np.float32)
    h = a.shape[0]
    yy = np.arange(h, dtype=np.float32)[:, None]
    cut = 296 * scale
    fade = np.clip((cut - yy) / (36 * scale), 0, 1)
    a[..., 3] *= fade
    f = Image.fromarray(a.astype(np.uint8), 'RGBA')
    shadow = Image.new('RGBA', f.size, (0, 0, 0, 0))
    shadow.putalpha(f.getchannel('A').point(lambda v: v * 0.45))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(6)), (off[0] + 4, off[1] + 8))
    canvas.alpha_composite(f, off)
    return off


def ring(draw, c, r, width, color):
    draw.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], outline=color, width=width)


def crescent(size_px):
    im = Image.new('L', (size_px, size_px), 0)
    d = ImageDraw.Draw(im)
    d.ellipse([0, 0, size_px - 1, size_px - 1], fill=255)
    d.ellipse([size_px * 0.32, -size_px * 0.12, size_px * 1.22, size_px * 0.78], fill=0)
    return im


def leaf(size_px):
    im = Image.new('L', (size_px, size_px), 0)
    d = ImageDraw.Draw(im)
    pts = []
    for i in range(41):
        t = i / 40
        pts.append((size_px * (0.5 + 0.36 * math.sin(math.pi * t)), size_px * (0.05 + 0.9 * t)))
    for i in range(41):
        t = 1 - i / 40
        pts.append((size_px * (0.5 - 0.36 * math.sin(math.pi * t)), size_px * (0.05 + 0.9 * t)))
    d.polygon(pts, fill=255)
    d.line([(size_px * 0.5, size_px * 0.12), (size_px * 0.5, size_px * 0.95)], fill=0, width=max(2, size_px // 22))
    return im


def gold(mask, glow=True):
    """Colours a mask with a warm metallic gradient."""
    w, h = mask.size
    y = np.linspace(0, 1, h)[:, None]
    base = np.zeros((h, w, 4), np.float32)
    base[..., 0] = 0.98 - 0.25 * y
    base[..., 1] = 0.86 - 0.32 * y
    base[..., 2] = 0.55 - 0.3 * y
    base[..., 3] = np.asarray(mask, np.float32) / 255
    return Image.fromarray((np.clip(base, 0, 1) * 255).astype(np.uint8), 'RGBA')


def main():
    face = face_rgba()
    # --- Dialogue portrait.
    S = 512
    por = painted_backdrop(S, seed=3)
    scale = 1.56
    off = place_face(por, face, scale, (256, 232))
    os.makedirs(os.path.join(ROOT, 'assets', 'sprites', 'witch'), exist_ok=True)
    por.save(os.path.join(ROOT, 'assets', 'sprites', 'witch', 'portrait.png'))
    eyes = []
    for (ex, ey, ew, eh) in EYES:
        eyes.append([ex * scale + off[0], ey * scale + off[1], ew * scale, eh * scale])
    with open(os.path.join(ROOT, 'assets', 'sprites', 'witch', 'portrait.json'), 'w') as fh:
        json.dump({'size': S, 'eyes': eyes}, fh, indent=1)
    # --- App icon layers (adaptive icon: 432 px, safe zone = central 288 px circle).
    os.makedirs(os.path.join(ROOT, 'assets', 'icons'), exist_ok=True)
    A = 432
    bg = painted_backdrop(A, seed=8, warm=0.75)
    vign = Image.new('L', (A, A), 0)
    ImageDraw.Draw(vign).ellipse([-A * 0.2, -A * 0.25, A * 1.2, A * 1.15], fill=255)
    vign = vign.filter(ImageFilter.GaussianBlur(A * 0.12))
    dark = Image.new('RGBA', (A, A), (6, 16, 12, 255))
    dark.putalpha(vign.point(lambda v: 255 - v))
    bg.alpha_composite(dark)
    bg.save(os.path.join(ROOT, 'assets', 'icons', 'adaptive_bg.png'))
    fg = Image.new('RGBA', (A, A), (0, 0, 0, 0))
    c = (A / 2, A / 2 + 4)
    R = 128
    # Inner painted disc with the face.
    disc = painted_backdrop(2 * R, seed=12)
    place_face(disc, face, 0.86, (R + 2, R - 4))
    m = Image.new('L', (2 * R, 2 * R), 0)
    ImageDraw.Draw(m).ellipse([0, 0, 2 * R - 1, 2 * R - 1], fill=255)
    disc.putalpha(Image.fromarray(np.minimum(np.asarray(disc.getchannel('A')), np.asarray(m))))
    halo = Image.new('RGBA', (A, A), (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse([c[0] - R - 14, c[1] - R - 14, c[0] + R + 14, c[1] + R + 14], fill=(255, 220, 140, 150))
    fg.alpha_composite(halo.filter(ImageFilter.GaussianBlur(12)))
    fg.alpha_composite(disc, (int(c[0] - R), int(c[1] - R)))
    ring_mask = Image.new('L', (A, A), 0)
    rd = ImageDraw.Draw(ring_mask)
    ring(rd, c, R + 2, 9, 255)
    ring(rd, c, R + 10, 3, 255)
    fg.alpha_composite(gold(ring_mask))
    # Crescent moon at the top right and the leaf emblem at the bottom.
    cm = crescent(64)
    cmo = gold(cm)
    fg.alpha_composite(cmo, (int(c[0] + R * 0.52), int(c[1] - R * 1.0)))
    lm = leaf(44)
    plate = Image.new('L', (78, 78), 0)
    ImageDraw.Draw(plate).regular_polygon((39, 39, 37), 4, rotation=45, fill=255)
    pl = Image.new('RGBA', (78, 78), (18, 34, 26, 255))
    pl.putalpha(plate)
    fg.alpha_composite(pl, (int(c[0] - 39), int(c[1] + R - 32)))
    pmask = Image.new('L', (78, 78), 0)
    ImageDraw.Draw(pmask).regular_polygon((39, 39, 37), 4, rotation=45, outline=255, width=4)
    fg.alpha_composite(gold(pmask), (int(c[0] - 39), int(c[1] + R - 32)))
    fg.alpha_composite(gold(lm), (int(c[0] - 22), int(c[1] + R - 15)))
    fg.save(os.path.join(ROOT, 'assets', 'icons', 'adaptive_fg.png'))
    mono = Image.new('RGBA', (A, A), (0, 0, 0, 0))
    white = Image.new('RGBA', (A, A), (255, 255, 255, 255))
    mm = Image.new('L', (A, A), 0)
    md = ImageDraw.Draw(mm)
    ring(md, c, R + 2, 12, 255)
    mm.paste(crescent(64), (int(c[0] + R * 0.52), int(c[1] - R * 1.0)), crescent(64))
    big_leaf = leaf(150)
    mm.paste(big_leaf, (int(c[0] - 75), int(c[1] - 75)), big_leaf)
    mono.paste(white, (0, 0), mm)
    mono.save(os.path.join(ROOT, 'assets', 'icons', 'adaptive_mono.png'))
    # Legacy/full icon: background + foreground, rounded square.
    full = bg.copy()
    full.alpha_composite(fg)
    rr = Image.new('L', (A, A), 0)
    ImageDraw.Draw(rr).rounded_rectangle([0, 0, A - 1, A - 1], radius=96, fill=255)
    full.putalpha(rr)
    # Crop toward the safe zone so the art fills the legacy icon nicely.
    crop = full.crop((40, 40, A - 40, A - 40))
    rr2 = Image.new('L', crop.size, 0)
    ImageDraw.Draw(rr2).rounded_rectangle([0, 0, crop.width - 1, crop.height - 1], radius=80, fill=255)
    crop.putalpha(rr2)
    crop.resize((512, 512), Image.LANCZOS).save(os.path.join(ROOT, 'assets', 'icon.png'))
    crop.resize((192, 192), Image.LANCZOS).save(os.path.join(ROOT, 'assets', 'icons', 'icon_192.png'))
    print('portrait + icons')


if __name__ == '__main__':
    main()
