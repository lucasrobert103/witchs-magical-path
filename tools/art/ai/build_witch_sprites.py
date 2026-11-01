#!/usr/bin/env python3
"""Builds Asterion's animated sprite sheets from the author's character sheet.

Source art: tools/art/ai/source/{front,side,back}.png — the reference views,
upscaled 4x with Real-ESRGAN (anime) and cut out with ISNet-anime
(see prepare_reference.py). Animation is done by deforming regions of the
painting (legs, hair, skirt, cloak, arm) — a cut-out / mesh-warp technique —
so the character stays identical to the reference.

Output: assets/sprites/witch/<anim>.png with 3 rows (front, side→right, back).
"""
import json
import math
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, '..', '..', '..', 'assets', 'sprites', 'witch'))
FW, FH, FOOT = 256, 384, 18
CHAR_H = 348            # pixels from sole to top of hair in a frame
ANIMS = {'idle': 8, 'walk': 8, 'run': 8, 'cast': 6, 'jump': 4, 'kneel': 6, 'hurt': 1}


def ss(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


PAD = 160


def load(name):
    im = np.asarray(Image.open(os.path.join(HERE, 'source', name + '.png')).convert('RGBA'), dtype=np.float32) / 255.0
    im = np.pad(im, ((0, 0), (PAD, PAD), (0, 0)))
    im[..., :3] *= im[..., 3:4]  # premultiply for clean interpolation
    return im


def sample(src, X, Y):
    h, w = src.shape[:2]
    x0 = np.floor(X).astype(np.int32)
    y0 = np.floor(Y).astype(np.int32)
    fx = (X - x0)[..., None]
    fy = (Y - y0)[..., None]
    out = np.zeros(X.shape + (4,), np.float32)
    for dy, wy in ((0, 1 - fy), (1, fy)):
        for dx, wx in ((0, 1 - fx), (1, fx)):
            xi = x0 + dx
            yi = y0 + dy
            ok = (xi >= 0) & (xi < w) & (yi >= 0) & (yi < h)
            v = np.zeros(X.shape + (4,), np.float32)
            v[ok] = src[yi[ok], xi[ok]]
            out += v * wx * wy
    return out


def hair_mask(src):
    rgb = src[..., :3] / np.maximum(src[..., 3:4], 1e-3)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    m = ((r > g + 0.012) & (r < 0.5) & (src[..., 3] > 0.3)).astype(np.float32)
    # Blur to a soft region.
    k = 9
    for axis in (0, 1):
        acc = np.zeros_like(m)
        for s in range(-k, k + 1):
            acc += np.roll(m, s, axis=axis)
        m = acc / (2 * k + 1)
    return np.clip(m * 1.6, 0, 1)


class View:
    def __init__(self, name, cfg):
        self.name = name
        self.src = load(name)
        self.h, self.w = self.src.shape[:2]
        self.c = cfg
        self.Y, self.X = np.mgrid[0:self.h, 0:self.w].astype(np.float32)
        self.hair = hair_mask(self.src) * (self.Y < cfg['hair_bottom'] + 40)

    def render(self, p):
        """p: pose dict of deformation parameters. Returns premultiplied RGBA."""
        c, X, Y = self.c, self.X, self.Y
        dx = np.zeros_like(X)
        dy = np.zeros_like(Y)
        foot, hip = c['foot'], c['hip']
        # Body bob / crouch: everything above the feet moves, soles stay planted.
        body_w = 1 - ss(c['knee'], foot, Y)
        dy += -p.get('bob', 0.0) * body_w
        crouch = p.get('crouch', 0.0)
        if crouch:
            dy += -crouch * (1 - ss(hip - 60, foot, Y)) - crouch * 0.0
        # Lean (shear around the feet).
        lean = p.get('lean', 0.0)
        if lean:
            dx += lean * (foot - Y) / (foot - c['top'])
        # Breathing: tiny vertical stretch of the torso.
        br = p.get('breathe', 0.0)
        if br:
            dy += br * ss(c['shoulder'] - 80, c['waist'], Y) * (1 - ss(c['waist'], c['waist'] + 60, Y)) * 3.0
        # Hair sway / lift.
        t = np.clip((Y - c['top']) / (c['hair_bottom'] - c['top']), 0, 1)
        hx = p.get('hair_x', 0.0) * t ** 1.6
        hw = p.get('hair_wave', 0.0)
        if hw:
            hx += hw * np.sin(p.get('phase', 0.0) - t * 2.5) * t ** 1.3
        dx += -hx * self.hair
        dy += -p.get('hair_y', 0.0) * t ** 1.5 * self.hair
        # Skirt and cloak sway.
        sk = np.clip((Y - c['waist']) / (c['hem'] - c['waist']), 0, 1)
        skirt_region = (Y > c['waist']) * (1 - ss(c['hem'] + 10, c['hem'] + 40, Y))
        dx += -p.get('skirt_x', 0.0) * sk ** 2 * skirt_region
        dy += -p.get('skirt_y', 0.0) * sk ** 2 * skirt_region
        # Arm swing (profile view only).
        if 'arm' in c and p.get('arm', 0.0):
            ax0, ax1, ay0, ay1 = c['arm']
            m = ss(ax0 - 20, ax0 + 10, X) * (1 - ss(ax1 - 10, ax1 + 20, X)) * ss(ay0, ay0 + 40, Y) * (1 - ss(ay1, ay1 + 30, Y))
            dx += -p['arm'] * ss(ay0, ay1, Y) * m
        # Leg lifts (front/back views): lower the sampling so the foot rises.
        if 'legs' in c:
            for i, lx in enumerate(c['legs']):
                lift = p.get('lift', (0.0, 0.0))[i]
                if lift:
                    mx = 1 - ss(c['leg_w'] * 0.7, c['leg_w'] * 1.3, np.abs(X - lx))
                    dy += lift * ss(c['knee'] - 70, foot + 10, Y) * mx
        base = sample(self.src, X + dx, Y + dy)
        # Profile legs: cut below the hem and swing as two layers behind the skirt.
        if 'leg_box' in c and ('swing' in p):
            x0, x1, y0 = c['leg_box']
            legs = self.src.copy()
            a = self.src[..., 3]
            rgb = self.src[..., :3] / np.maximum(a[..., None], 1e-3)
            legcol = (rgb[..., 0] > rgb[..., 1] - 0.008) & (a > 0.05) & ((X >= 100 + PAD) | (Y >= 890))
            keep = (X >= x0) & (X <= x1) & (Y >= y0 - 30) & legcol
            legs[~keep] = 0
            # Extend the top of the legs upward (hidden by the skirt) to avoid gaps when rotating.
            top_row = legs[int(y0 + 6)].copy()
            for yy in range(int(y0 - 40), int(y0 + 6)):
                legs[yy] = np.where(keep[yy][:, None], top_row, 0)
            base_wo = base.copy()
            # Remove original legs from the body layer (below the hem only).
            cut = (X >= x0) & (X <= x1) & (Y >= y0 + 8) & legcol
            # Dilate the cut a little so no outline of the original legs remains.
            cutd = cut.copy()
            for sh in (-3, 3):
                cutd |= np.roll(cut, sh, axis=1)
            cutd &= (Y >= y0 + 8)
            base_wo[cutd] = 0
            px, py = c['pivot']
            layers = []
            for k, (ang, shade, lift) in enumerate(p['swing']):
                a = math.radians(ang)
                ca, sa = math.cos(a), math.sin(a)
                # inverse rotation about the hip pivot
                rx = X - px
                ry = Y - py
                sx = ca * rx + sa * ry + px
                sy = -sa * rx + ca * ry + py
                sy = sy + lift * ss(y0, foot, sy)
                lay = sample(legs, sx, sy)
                lay[..., :3] *= shade
                layers.append(lay)
            out = np.zeros_like(base)
            for lay in layers:  # back leg first
                out = lay + out * (1 - lay[..., 3:4])
            out = base_wo + out * (1 - base_wo[..., 3:4])
            return out
        return base


CFG = {
    # Coordinates in the 4x source images.
    'front': {'top': 23, 'shoulder': 228, 'waist': 368, 'hip': 428, 'hem': 728, 'knee': 760, 'foot': 965,
              'hair_bottom': 330, 'legs': (168 + PAD, 272 + PAD), 'leg_w': 40},
    'back': {'top': 23, 'shoulder': 228, 'waist': 380, 'hip': 440, 'hem': 748, 'knee': 770, 'foot': 965,
             'hair_bottom': 400, 'legs': (180 + PAD, 280 + PAD), 'leg_w': 40},
    'side': {'top': 24, 'shoulder': 260, 'waist': 380, 'hip': 430, 'hem': 790, 'knee': 760, 'foot': 965,
             'hair_bottom': 410, 'arm': (78 + PAD, 156 + PAD, 290, 540), 'leg_box': (40 + PAD, 182 + PAD, 744), 'pivot': (116 + PAD, 600)},
}


def pose(view, anim, f, n):
    ph = 2 * math.pi * f / max(n, 1)
    s, co = math.sin(ph), math.cos(ph)
    side = view == 'side'
    back = view == 'back'
    # Positive hair_x pushes hair to the image right; in profile (source faces left) that's backward.
    if anim == 'idle':
        return {'breathe': s, 'bob': 2 * s, 'hair_wave': 4.0, 'phase': ph, 'skirt_x': 2.5 * math.sin(ph + 1.0),
                'arm': 2.0 * s if side else 0.0, **({'swing': [(0, 0.82, 0), (0, 1.0, 0)]} if side else {})}
    if anim in ('walk', 'run'):
        run = anim == 'run'
        amp = 1.7 if run else 1.0
        p = {'bob': (10 if run else 5) * abs(s), 'phase': ph, 'hair_wave': 6.0 * amp,
             'hair_y': -6 * amp * abs(co), 'skirt_x': 7 * amp * s if not side else 6 * amp * co}
        if side:
            p['hair_x'] = 18 * amp
            p['skirt_x'] = 10 * amp + 4 * co
            p['lean'] = -(26 if run else 8)
            p['arm'] = 16 * amp * s
            sw = (24 if run else 15) * s
            lift_a = (60 if run else 26) * max(0.0, co)
            lift_b = (60 if run else 26) * max(0.0, -co)
            p['swing'] = [(sw, 0.78, lift_b), (-sw, 1.0, lift_a)]
        else:
            L = (85 if run else 55)
            p['lift'] = (L * max(0.0, s), L * max(0.0, -s))
            p['hair_x'] = 0.0
        return p
    if anim == 'cast':
        k = [0, 0.45, 0.85, 1.0, 1.0, 0.5][f]
        p = {'bob': -6 * k, 'crouch': 10 * k, 'hair_x': (14 if side else 6) * k, 'hair_y': 10 * k, 'skirt_x': 8 * k,
             'lean': (-12 if side else 0) * k, 'arm': -30 * k if side else 0.0, 'phase': ph, 'hair_wave': 5 * k}
        if side:
            p['swing'] = [(-8 * k, 0.8, 0), (10 * k, 1.0, 0)]
        return p
    if anim == 'jump':
        J = [
            {'bob': 10, 'lift': (70, 40), 'hair_y': -22, 'skirt_y': -10, 'swing': [(-14, 0.8, 50), (24, 1.0, 70)]},
            {'bob': 14, 'lift': (90, 80), 'hair_y': 6, 'skirt_y': 8, 'swing': [(-20, 0.8, 90), (20, 1.0, 90)]},
            {'bob': 0, 'lift': (10, 0), 'hair_y': 26, 'skirt_y': 22, 'swing': [(-8, 0.8, 0), (10, 1.0, 10)]},
            {'bob': -6, 'crouch': 26, 'hair_y': -14, 'skirt_y': -8, 'swing': [(-6, 0.8, 0), (8, 1.0, 0)]},
        ][f]
        if side:
            J['hair_x'] = 10
            J.pop('lift', None)
        else:
            J.pop('swing', None)
        return J
    if anim == 'kneel':
        k = 1.0 - f / (n - 1)
        k = k * k * (3 - 2 * k)
        p = {'crouch': 120 * k, 'lean': (-40 if side else 0) * k, 'hair_y': -20 * k, 'bob': 0}
        if side:
            p['swing'] = [(-40 * k, 0.8, 0), (45 * k, 1.0, 60 * k)]
        else:
            p['lift'] = (0.0, 0.0)
        return p
    if anim == 'hurt':
        p = {'lean': 30 if side else 0, 'bob': -8, 'crouch': 14, 'hair_x': -16 if side else 8, 'hair_y': 12, 'skirt_x': -8}
        if side:
            p['swing'] = [(10, 0.8, 0), (-6, 1.0, 0)]
        return p
    return {}


def to_frame(img, view_cfg, mirror):
    """Scale a premultiplied RGBA image into a frame with the sole at the bottom."""
    a = img.copy()
    alpha = a[..., 3:4]
    a[..., :3] = np.where(alpha > 1e-3, a[..., :3] / np.maximum(alpha, 1e-3), 0)
    pil = Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGBA')
    if mirror:
        pil = pil.transpose(Image.FLIP_LEFT_RIGHT)
    scale = CHAR_H / (view_cfg['foot'] - view_cfg['top'])
    w, h = pil.size
    # Resize premultiplied to avoid dark fringes.
    pm = np.asarray(pil, dtype=np.float32) / 255
    pm[..., :3] *= pm[..., 3:4]
    chans = [Image.fromarray((pm[..., i] * 255 + 0.5).astype(np.uint8)).resize((round(w * scale), round(h * scale)), Image.LANCZOS) for i in range(4)]
    rs = np.dstack([np.asarray(ch, dtype=np.float32) / 255 for ch in chans])
    rs[..., :3] = np.where(rs[..., 3:4] > 1e-3, rs[..., :3] / np.maximum(rs[..., 3:4], 1e-3), 0)
    small = Image.fromarray((np.clip(rs, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGBA')
    frame = Image.new('RGBA', (FW, FH), (0, 0, 0, 0))
    cx = view_cfg.get('cx', w / 2) * scale
    if mirror:
        cx = small.width - cx
    fx = int(round(FW / 2 - cx))
    fy = int(round(FH - FOOT - view_cfg['foot'] * scale))
    frame.alpha_composite(small, (fx, fy)) if fx >= 0 and fy >= 0 else frame.paste(small, (fx, fy), small)
    return frame


def main():
    os.makedirs(OUT, exist_ok=True)
    views = {k: View(k, v) for k, v in CFG.items()}
    CFG['front']['cx'] = 222 + PAD
    CFG['back']['cx'] = 230 + PAD
    CFG['side']['cx'] = 120 + PAD
    rows = [('front', False), ('side', True), ('back', False)]
    for anim, n in ANIMS.items():
        sheet = Image.new('RGBA', (FW * n, FH * len(rows)), (0, 0, 0, 0))
        for r, (vname, mirror) in enumerate(rows):
            v = views[vname]
            for f in range(n):
                img = v.render(pose(vname, anim, f, n))
                sheet.alpha_composite(to_frame(img, CFG[vname], mirror), (f * FW, r * FH))
        sheet.save(os.path.join(OUT, anim + '.png'), optimize=True)
        print('sheet', anim)
    # Dialogue portrait from the three-quarter bust.
    bust = Image.open(os.path.join(HERE, 'source', 'bust.png')).convert('RGBA')
    bb = bust.getbbox()
    bust = bust.crop(bb)
    side = max(bust.size)
    canvas = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    canvas.alpha_composite(bust, ((side - bust.width) // 2, 0))
    canvas.resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, 'portrait.png'))
    meta = {'frame_width': FW, 'frame_height': FH, 'foot_offset': FOOT, 'rows': ['front', 'side', 'back'],
            'char_height_px': CHAR_H, 'animations': ANIMS}
    with open(os.path.join(OUT, 'witch.json'), 'w') as fh:
        json.dump(meta, fh, indent=2)


if __name__ == '__main__':
    main()
