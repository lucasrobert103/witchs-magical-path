#!/usr/bin/env python3
"""Builds Asterion's animated sprite sheets from the author's character sheet.

Source art: tools/art/ai/source/{front,side,back}.png — the reference views,
upscaled 4x with Real-ESRGAN (anime) and cut out with ISNet-anime
(see prepare_reference.py).

Animation uses a 2D skeleton (cut-out rig): each view is split into pieces cut
from the painting itself — upper arms, forearms + hands, thighs, shins + boots and
the body — and every piece rotates around its joint (shoulder, elbow, hip, knee).
Holes uncovered by a moving limb are inpainted from the surrounding colours. On
top of the rig, soft deformations add follow-through: hair and skirt lag behind,
the torso rolls, the head tilts, the body bobs and shifts its weight.

Output: assets/sprites/witch/<anim>.png with 3 rows (front, side→right, back).
"""
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, '..', '..', '..', 'assets', 'sprites', 'witch'))
FW, FH, FOOT = 256, 384, 18
CHAR_H = 348            # pixels from sole to top of hair in a frame
ANIMS = {'idle': 12, 'walk': 12, 'run': 10, 'sigh': 12, 'wind': 12, 'shift': 12,
         'cast': 6, 'jump': 4, 'kneel': 6, 'hurt': 1}
PAD = 160


# ---------------------------------------------------------------- image helpers
def ss(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def box_blur(a, k):
    out = a.copy()
    for axis in (0, 1):
        acc = np.zeros_like(out)
        for s in range(-k, k + 1):
            acc += np.roll(out, s, axis=axis)
        out = acc / (2 * k + 1)
    return out


def despeckle(im):
    """Removes the light specks the background cut left inside the dark hair."""
    a = im[..., 3]
    lum = im[..., :3].mean(axis=2)
    dark = (lum < 0.4) & (a > 0.5)
    nb_dark = box_blur(dark.astype(np.float32), 4)
    speck = (lum > 0.5) & (nb_dark > 0.32) & (a > 0.1)
    if speck.any():
        w = dark.astype(np.float32)[..., None]
        col = box_blur(im[..., :3] * w, 4) / np.maximum(box_blur(w, 4), 1e-3)
        im[..., :3] = np.where(speck[..., None], col, im[..., :3])
        im[..., 3] = np.where(speck, np.maximum(a, 0.95), a)
    fringe = (lum > 0.7) & (a < 0.6)
    im[..., 3] = np.where(fringe, a * 0.3, im[..., 3])
    return im


def load(name):
    im = np.asarray(Image.open(os.path.join(HERE, 'source', name + '.png')).convert('RGBA'), dtype=np.float32) / 255.0
    im = despeckle(im)
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


def over(dst, src):
    return src + dst * (1 - src[..., 3:4])


def poly_mask(shape, pts, feather=2):
    h, w = shape
    m = Image.new('L', (w, h), 0)
    ImageDraw.Draw(m).polygon([(x + PAD, y) for x, y in pts], fill=255)
    a = np.asarray(m, np.float32) / 255
    return box_blur(a, feather) if feather else a


def auto_arm_mask(src, which, top, gap, bottom):
    """Front/back arms hang free of the body below the elbow: in each row the arm is the
    run of opaque pixels outside the widest (body) run. Above the gap the sleeve keeps the
    x-range found at the first free row."""
    a = src[..., 3] > 0.15
    h, w = a.shape
    m = np.zeros((h, w), np.float32)
    first = None
    for y in range(gap, bottom):
        xs = np.nonzero(a[y])[0]
        if len(xs) == 0:
            continue
        br = np.nonzero(np.diff(xs) > 2)[0]
        starts = np.concatenate([[xs[0]], xs[br + 1]])
        ends = np.concatenate([xs[br], [xs[-1]]])
        body = int(np.argmax(ends - starts))
        for k, (s_, e_) in enumerate(zip(starts, ends)):
            if (which == 'left' and k < body) or (which == 'right' and k > body):
                m[y, s_:e_ + 1] = 1.0
                if first is None:
                    first = (s_, e_)
    if first is not None:
        for y in range(top, gap):
            xs = np.nonzero(a[y])[0]
            if len(xs) == 0:
                continue
            if which == 'left':
                m[y, xs[0]:first[1] + 3] = 1.0
            else:
                m[y, first[0] - 2:xs[-1] + 1] = 1.0
    return np.clip(box_blur(m, 1) * 1.5, 0, 1)


def hair_mask(src):
    rgb = src[..., :3] / np.maximum(src[..., 3:4], 1e-3)
    r, g = rgb[..., 0], rgb[..., 1]
    m = ((r > g + 0.012) & (r < 0.5) & (src[..., 3] > 0.3)).astype(np.float32)
    return np.clip(box_blur(m, 9) * 1.6, 0, 1)


def limb_color(src):
    """Skin and leather (reddish) vs. the green dress: used to cut legs from the skirt."""
    a = src[..., 3]
    rgb = src[..., :3] / np.maximum(a[..., None], 1e-3)
    return ((rgb[..., 0] > rgb[..., 1] + 0.01) & (a > 0.05)).astype(np.float32)


def _runs_fill(img, hb):
    """Row-wise fill of hole runs that have solid body on both ends."""
    h, w = hb.shape
    out = np.zeros_like(img)
    ok = np.zeros(hb.shape, np.float32)
    for y in range(h):
        row = hb[y]
        if not row.any():
            continue
        xs = np.nonzero(row)[0]
        breaks = np.nonzero(np.diff(xs) > 1)[0]
        starts = np.concatenate([[xs[0]], xs[breaks + 1]])
        ends = np.concatenate([xs[breaks], [xs[-1]]])
        for a, b in zip(starts, ends):
            if a == 0 or b + 1 >= w:
                continue
            left, right = img[y, a - 1], img[y, b + 1]
            if left[3] < 0.5 or right[3] < 0.5:
                continue
            n = b - a + 1
            t = (np.arange(n, dtype=np.float32) + 1) / (n + 1)
            out[y, a:b + 1] = left[None] * (1 - t)[:, None] + right[None] * t[:, None]
            ok[y, a:b + 1] = 1.0
    return out, ok


def inpaint(img, hole):
    """Fills holes that are enclosed by the body, blending the colours found around them
    horizontally and vertically, then softens the patch."""
    hb = hole > 0.5
    rows, rok = _runs_fill(img, hb)
    cols_t, cok_t = _runs_fill(np.transpose(img, (1, 0, 2)), hb.T)
    cols, cok = np.transpose(cols_t, (1, 0, 2)), cok_t.T
    wsum = rok + cok
    out = (rows * rok[..., None] + cols * cok[..., None]) / np.maximum(wsum, 1e-3)[..., None]
    out = box_blur(out, 4)
    return out * ((wsum > 0) & hb)[..., None]


# ---------------------------------------------------------------- affine pieces
def M_rot(px, py, deg, sx=1.0, sy=1.0, tx=0.0, ty=0.0):
    """Forward transform: scale+rotate about (px, py), then translate."""
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    T1 = np.array([[1, 0, -px], [0, 1, -py], [0, 0, 1]], np.float64)
    S = np.array([[sx, 0, 0], [0, sy, 0], [0, 0, 1]], np.float64)
    R = np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]], np.float64)
    T2 = np.array([[1, 0, px + tx], [0, 1, py + ty], [0, 0, 1]], np.float64)
    return T2 @ R @ S @ T1


def warp_piece(img, M, X, Y):
    Mi = np.linalg.inv(M)
    sx = Mi[0, 0] * X + Mi[0, 1] * Y + Mi[0, 2]
    sy = Mi[1, 0] * X + Mi[1, 1] * Y + Mi[1, 2]
    return sample(img, sx, sy)


def extend_up(piece, mask, top, rows=40):
    """Copies the first rows of a piece upward so a rotating limb never shows a gap
    where it disappears under the cloak or the skirt."""
    out = piece.copy()
    m = mask.copy()
    src_row = int(top) + 4
    for y in range(max(0, int(top) - rows), src_row):
        out[y] = np.where(mask[src_row][:, None] > 0.3, piece[src_row], out[y])
        m[y] = np.maximum(m[y], mask[src_row])
    return out, m


# ---------------------------------------------------------------- rig per view
class View:
    def __init__(self, name, cfg):
        self.name = name
        self.c = cfg
        self.src = load(name)
        self.h, self.w = self.src.shape[:2]
        self.Y, self.X = np.mgrid[0:self.h, 0:self.w].astype(np.float32)
        self.hair = hair_mask(self.src) * (self.Y < cfg['hair_bottom'] + 40)
        shape = (self.h, self.w)
        limbs = np.zeros(shape, np.float32)
        self.arms = []
        for arm in cfg.get('arms', []):
            if 'auto' in arm:
                m = auto_arm_mask(self.src, arm['auto'], arm['top'], arm['gap'], arm['bottom'])
            else:
                m = poly_mask(shape, arm['poly'])
            elbow_y = arm['elbow'][1]
            up = m * (1 - ss(elbow_y - 6, elbow_y + 6, self.Y))
            low = m * ss(elbow_y - 6, elbow_y + 6, self.Y)
            arm_top = arm['top'] if 'auto' in arm else arm['poly'][0][1]
            up_img, up_m = extend_up(self.src * up[..., None], up, arm_top, 50)
            # Forearm pieces overlap the upper arm a little at the elbow (no seam when bent).
            low_m = m * ss(elbow_y - 22, elbow_y - 8, self.Y)
            self.arms.append({'cfg': arm, 'up': up_img, 'low': self.src * low_m[..., None]})
            limbs = np.maximum(limbs, m)
        self.legs = []
        for leg in cfg.get('legs', []):
            x0, x1 = leg['box']
            box = ((self.X >= x0 + PAD) & (self.X <= x1 + PAD) & (self.Y >= leg['top'])).astype(np.float32)
            if leg.get('keep_x'):
                kx, ky = leg['keep_x']
                box *= ((self.X >= kx + PAD) | (self.Y >= ky)).astype(np.float32)
            m = box * limb_color(self.src)
            m = np.clip(box_blur(m, 1) * 1.3, 0, 1) * box
            knee_y = leg['knee'][1]
            thigh = m * (1 - ss(knee_y - 4, knee_y + 4, self.Y))
            shin = m * ss(knee_y - 24, knee_y - 10, self.Y)
            th_img, th_m = extend_up(self.src * thigh[..., None], thigh, leg['top'], 60)
            self.legs.append({'cfg': leg, 'thigh': th_img, 'shin': self.src * shin[..., None]})
            limbs = np.maximum(limbs, m)
        cut = np.clip(box_blur(limbs, 3) * 3.0, 0, 1)
        self.body = self.src * (1 - cut[..., None])
        # The cloak hem stays in front of the shoulders: a cap of body pixels drawn after the arms.
        cap = np.zeros(shape, np.float32)
        for arm in cfg.get('arms', []):
            if arm.get('far'):
                continue
            if 'auto' in arm:
                am = auto_arm_mask(self.src, arm['auto'], arm['top'], arm['gap'], arm['bottom'])
                cols = np.nonzero(am.max(axis=0) > 0.5)[0]
                x_lo, x_hi, top = cols.min() - 30, cols.max() + 30, arm['top']
            else:
                xs = [x + PAD for x, _ in arm['poly']]
                x_lo, x_hi, top = min(xs) - 30, max(xs) + 30, min(y for _, y in arm['poly'])
            box = ((self.X >= x_lo) & (self.X <= x_hi) & (self.Y >= top - 110) & (self.Y <= top + 2)).astype(np.float32)
            cap = np.maximum(cap, box)
        self.cap = self.body * box_blur(cap, 2)[..., None]
        # Hole fill behind moving limbs: only where the hole is surrounded by the body.
        hole = (cut > 0.2).astype(np.float32)
        fill_region = hole * (self.Y < cfg.get('fill_below', 99999))
        self.fill = inpaint(self.body, fill_region) if fill_region.any() else np.zeros_like(self.body)

    def compose(self, p):
        """Poses the skeleton and composites the pieces (before soft deformations)."""
        X, Y = self.X, self.Y
        side = self.name == 'side'
        layers_back, layers_front = [], []
        # Legs.
        for i, leg in enumerate(self.legs):
            lc = leg['cfg']
            hx, hy = lc['hip'][0] + PAD, lc['hip'][1]
            kx, ky = lc['knee'][0] + PAD, lc['knee'][1]
            if side:
                hip = p.get('hips', (0.0, 0.0))[i]
                knee = p.get('knees', (0.0, 0.0))[i]
                Mt = M_rot(hx, hy, hip)
                Ms = Mt @ M_rot(kx, ky, -knee)
            else:
                lift = p.get('lifts', (0.0, 0.0))[i]
                ldx = p.get('leg_dx', (0.0, 0.0))[i]
                # A stepping leg: the knee comes up, the shin foreshortens.
                Mt = M_rot(hx, hy, 0.0, 1.0, 1.0 - 0.0012 * lift, ldx, -lift * 0.35)
                Ms = M_rot(hx, hy, 0.0, 1.0, 1.0 - 0.0016 * lift, ldx, -lift)
            shade = lc.get('shade', 1.0) if not (side and i == 0) else 0.72
            th = warp_piece(leg['thigh'], Mt, X, Y)
            sh = warp_piece(leg['shin'], Ms, X, Y)
            piece = over(th, sh)
            piece[..., :3] *= shade
            layers_back.append(piece)
        # Arms.
        for i, arm in enumerate(self.arms):
            ac = arm['cfg']
            sx_, sy_ = ac['shoulder'][0] + PAD, ac['shoulder'][1]
            ex, ey = ac['elbow'][0] + PAD, ac['elbow'][1]
            sh_deg, el_deg, fs = p.get('arms', [(0.0, 0.0, 1.0)] * 4)[i] if i < len(p.get('arms', [])) else (0.0, 0.0, 1.0)
            Mu = M_rot(sx_, sy_, sh_deg, 1.0, fs, float(ac.get('offset', 0.0)), 0.0)
            Ml = Mu @ M_rot(ex, ey, el_deg)
            piece = over(warp_piece(arm['up'], Mu, X, Y), warp_piece(arm['low'], Ml, X, Y))
            if ac.get('far'):
                piece[..., :3] *= 0.7
                layers_back.insert(0, piece)
            else:
                layers_front.append(piece)
        out = np.zeros_like(self.body)
        # Order: far arm (side) → hole fill → legs → body → arms.
        far = [l for l in layers_back if l is not None]
        if side and len(self.arms) > 1:
            out = over(out, far[0])
            far = far[1:]
        out = over(out, self.fill)
        for l in far:
            out = over(out, l)
        out = over(out, self.body)
        for l in layers_front:
            out = over(out, l)
        return over(out, self.cap)

    def render(self, p):
        img = self.compose(p)
        c, X, Y = self.c, self.X, self.Y
        dx = np.zeros_like(X)
        dy = np.zeros_like(Y)
        foot, hip = c['foot'], c['hip']
        body_w = 1 - ss(c['knee'], foot, Y)
        dy += -p.get('bob', 0.0) * body_w
        crouch = p.get('crouch', 0.0)
        if crouch:
            dy += -crouch * (1 - ss(hip - 60, foot, Y))
        lean = p.get('lean', 0.0)
        if lean:
            dx += lean * (foot - Y) / (foot - c['top'])
        # Torso roll around the hips and a counter-tilt of the head.
        roll = math.radians(p.get('roll', 0.0))
        if roll:
            w_t = 1 - ss(hip - 60, hip + 20, Y)
            dx += (Y - hip) * roll * w_t
        tilt = math.radians(p.get('tilt', 0.0))
        if tilt:
            neck = c['neck']
            w_h = 1 - ss(neck - 30, neck + 30, Y)
            dx += (Y - neck) * tilt * w_h
        br = p.get('breathe', 0.0)
        if br:
            dy += br * ss(c['shoulder'] - 80, c['waist'], Y) * (1 - ss(c['waist'], c['waist'] + 60, Y)) * 3.0
        t = np.clip((Y - c['top']) / (c['hair_bottom'] - c['top']), 0, 1)
        hx = p.get('hair_x', 0.0) * t ** 1.6
        hw = p.get('hair_wave', 0.0)
        if hw:
            hx += hw * np.sin(p.get('phase', 0.0) - t * 2.5) * t ** 1.3
        dx += -hx * self.hair
        dy += -p.get('hair_y', 0.0) * t ** 1.5 * self.hair
        sk = np.clip((Y - c['waist']) / (c['hem'] - c['waist']), 0, 1)
        skirt_region = (Y > c['waist']) * (1 - ss(c['hem'] + 10, c['hem'] + 40, Y))
        dx += -p.get('skirt_x', 0.0) * sk ** 2 * skirt_region
        dy += -p.get('skirt_y', 0.0) * sk ** 2 * skirt_region
        sway = p.get('sway', 0.0)
        if sway:
            dx += -sway * (1 - ss(c['knee'] - 60, foot - 20, Y))
        return sample(img, X + dx, Y + dy)


# ---------------------------------------------------------------- skeleton per view
def _mirror_poly(poly, width):
    return [(width - x, y) for x, y in poly]


ARM_FRONT_L = [(58, 372), (128, 372), (122, 398), (102, 445), (86, 562), (12, 562), (34, 440), (56, 398)]
ARM_BACK_L = [(78, 352), (150, 352), (142, 400), (118, 446), (102, 562), (26, 562), (46, 440), (68, 400)]
ARM_SIDE = [(117, 306), (166, 298), (168, 372), (164, 450), (171, 500), (166, 560), (142, 574), (108, 566), (107, 500), (113, 450), (115, 372)]

CFG = {
    # Coordinates are in the 4x source images (before padding).
    'front': {'top': 23, 'neck': 215, 'shoulder': 228, 'waist': 368, 'hip': 428, 'hem': 728, 'knee': 760, 'foot': 965,
              'hair_bottom': 330, 'cx': 222, 'fill_below': 790,
              'arms': [{'auto': 'left', 'top': 372, 'gap': 388, 'bottom': 566, 'shoulder': (115, 300), 'elbow': (90, 402), 'side': -1},
                       {'auto': 'right', 'top': 372, 'gap': 388, 'bottom': 566, 'shoulder': (330, 300), 'elbow': (356, 402), 'side': 1}],
              'legs': [{'box': (128, 221), 'top': 560, 'hip': (178, 560), 'knee': (172, 796)},
                       {'box': (222, 314), 'top': 560, 'hip': (264, 560), 'knee': (270, 796)}]},
    'back': {'top': 23, 'neck': 230, 'shoulder': 228, 'waist': 380, 'hip': 440, 'hem': 748, 'knee': 770, 'foot': 965,
             'hair_bottom': 400, 'cx': 230, 'fill_below': 780,
             'arms': [{'auto': 'left', 'top': 352, 'gap': 360, 'bottom': 566, 'shoulder': (120, 300), 'elbow': (95, 402), 'side': -1},
                      {'auto': 'right', 'top': 352, 'gap': 360, 'bottom': 566, 'shoulder': (335, 300), 'elbow': (367, 402), 'side': 1}],
             'legs': [{'box': (132, 226), 'top': 724, 'hip': (180, 600), 'knee': (180, 796)},
                      {'box': (232, 330), 'top': 724, 'hip': (284, 600), 'knee': (284, 796)}]},
    'side': {'top': 24, 'neck': 170, 'shoulder': 260, 'waist': 380, 'hip': 430, 'hem': 790, 'knee': 760, 'foot': 965,
             'hair_bottom': 410, 'cx': 120, 'fill_below': 99999,
             # Far arm first (a darker copy behind the body), then the near arm.
             'arms': [{'poly': ARM_SIDE, 'shoulder': (141, 278), 'elbow': (140, 374), 'far': True, 'offset': 12},
                      {'poly': ARM_SIDE, 'shoulder': (141, 278), 'elbow': (140, 374)}],
             'legs': [{'box': (40, 182), 'top': 744, 'keep_x': (100, 890), 'hip': (116, 600), 'knee': (126, 806)},
                      {'box': (40, 182), 'top': 744, 'keep_x': (100, 890), 'hip': (116, 600), 'knee': (126, 806)}]},
}


# ---------------------------------------------------------------- poses
def fb_arms(s0, s1, front, amp=1.0, bent=0.0):
    """Front/back arm swing. s = +1 when the arm swings forward."""
    out = []
    for side, s in ((-1, s0), (1, s1)):
        vis = -s if front else s          # seen from the front, forward comes toward the camera
        deg = side * (8.0 * vis) * amp
        el = side * (24.0 * max(0.0, vis) + 4.0 + bent) * amp
        fs = 1.0 - 0.16 * max(0.0, vis) * amp + 0.04 * max(0.0, -vis) * amp
        out.append((deg, el, fs))
    return out


def side_arms(swing, elbow_base, amp):
    """Profile: (far, near) arms; positive angles swing forward (toward -x in the source)."""
    near = swing * amp
    far = -swing * amp
    return [(far, elbow_base + 14.0 * max(0.0, far / max(amp, 1e-3)), 1.0),
            (near, elbow_base + 14.0 * max(0.0, near / max(amp, 1e-3)), 1.0)]


def pose(view, anim, f, n):
    ph = 2 * math.pi * f / max(n, 1)
    s, co = math.sin(ph), math.cos(ph)
    side = view == 'side'
    front = view == 'front'
    if anim == 'idle':
        p = {'breathe': s, 'bob': 2 * s, 'hair_wave': 4.0, 'phase': ph, 'skirt_x': 2.5 * math.sin(ph + 1.0),
             'tilt': 1.2 * math.sin(ph * 0.5 + 0.4)}
        if side:
            p['arms'] = side_arms(2.5 * s, 6.0, 1.0)
        else:
            p['arms'] = fb_arms(0.08 * s, -0.08 * s, front)
        return p
    if anim in ('walk', 'run'):
        run = anim == 'run'
        amp = 1.7 if run else 1.0
        lag = ph - 0.9
        p = {'bob': (9 if run else 4.5) * abs(s), 'phase': ph - 0.6, 'hair_wave': 5.0 * amp,
             'hair_y': -5 * amp * abs(math.cos(lag))}
        if side:
            hip_a = (30.0 if run else 19.0)
            knee_a = (85.0 if run else 42.0)
            # Far leg = index 0, near leg = index 1; knees fold during the swing.
            p['hips'] = (-hip_a * s, hip_a * s)
            p['knees'] = (knee_a * max(0.0, -co) ** 1.3 + 4.0, knee_a * max(0.0, co) ** 1.3 + 4.0)
            p['arms'] = side_arms(-s, 30.0 if run else 8.0, 30.0 if run else 20.0)
            p['hair_x'] = 18 * amp
            p['skirt_x'] = 10 * amp + 4 * co
            p['lean'] = -(26 if run else 8)
            p['tilt'] = 1.5 * math.sin(2 * ph)
        else:
            L = (80 if run else 44)
            p['lifts'] = (L * max(0.0, s), L * max(0.0, -s))
            p['leg_dx'] = (4.0 * max(0.0, s), -4.0 * max(0.0, -s))
            p['arms'] = fb_arms(-s, s, front, 1.35 if run else 1.0, 4.0 if run else 0.0)
            p['sway'] = (5.0 if run else 7.0) * s
            p['roll'] = (2.0 if run else 1.6) * s
            p['tilt'] = -(1.4 if run else 1.0) * s
            p['skirt_x'] = 6 * amp * math.sin(lag)
        return p
    if anim == 'sigh':
        k = math.sin(math.pi * f / (n - 1)) ** 1.5
        settle = max(0.0, (f - 7) / 4.0)
        p = {'breathe': 3.5 * k, 'bob': 7 * k - 2.5 * settle * (1 - k), 'hair_y': -6 * k + 3 * settle, 'hair_wave': 2.0,
             'phase': ph, 'skirt_x': 1.5 * math.sin(ph), 'tilt': -2.5 * k}
        p['arms'] = side_arms(-3 * k, 8.0, 1.0) if side else fb_arms(-0.15 * k, -0.15 * k, front)
        return p
    if anim == 'wind':
        g = math.sin(math.pi * f / (n - 1))
        flutter = math.sin(ph * 3.0) * g
        p = {'hair_x': 44 * g + 7 * flutter, 'hair_wave': 8 * g, 'phase': ph * 2, 'hair_y': -8 * g,
             'skirt_x': 18 * g + 5 * flutter, 'lean': 3 * g, 'breathe': g, 'tilt': 3.0 * g}
        p['arms'] = side_arms(2 * g, 8.0, 1.0) if side else fb_arms(0.1 * g, 0.1 * g, front)
        return p
    if anim == 'shift':
        sw = math.sin(ph)
        p = {'bob': 2.5 * abs(sw), 'hair_wave': 3.0, 'phase': ph - 0.7, 'skirt_x': 3 * math.sin(ph - 0.8),
             'breathe': 0.5 * math.cos(ph), 'tilt': 2.0 * sw}
        if side:
            p['lean'] = 7 * sw
            p['hips'] = (-3 * sw, 3 * sw)
            p['arms'] = side_arms(4 * sw, 8.0, 1.0)
        else:
            p['sway'] = 11 * sw
            p['roll'] = 1.5 * sw
            p['lifts'] = (10 * max(0.0, -sw), 10 * max(0.0, sw))
            p['arms'] = fb_arms(0.15 * sw, -0.15 * sw, front)
        return p
    if anim == 'cast':
        k = [0, 0.45, 0.85, 1.0, 1.0, 0.5][f]
        p = {'bob': -6 * k, 'crouch': 10 * k, 'hair_x': (14 if side else 6) * k, 'hair_y': 10 * k, 'skirt_x': 8 * k,
             'lean': (-12 if side else 0) * k, 'phase': ph, 'hair_wave': 5 * k}
        if side:
            # The near arm rises forward, palm open; the far arm draws back.
            p['arms'] = [(-20 * k, -10 * k, 1.0), (75 * k, -10 * (1 - k), 1.0)]
            p['hips'] = (-8 * k, 10 * k)
            p['knees'] = (6 * k, 10 * k)
        else:
            p['arms'] = [(-12 * k, -30 * k, 1.0 - 0.25 * k), (12 * k, 30 * k, 1.0 - 0.25 * k)] if front else \
                        [(-12 * k, -30 * k, 1.0 - 0.3 * k), (12 * k, 30 * k, 1.0 - 0.3 * k)]
        return p
    if anim == 'jump':
        J = [
            {'bob': 10, 'lifts': (70, 40), 'hair_y': -22, 'skirt_y': -10, 'hips': (-14, 24), 'knees': (50, 70), 'up': -0.6},
            {'bob': 14, 'lifts': (90, 80), 'hair_y': 6, 'skirt_y': 8, 'hips': (-20, 20), 'knees': (80, 80), 'up': 0.5},
            {'bob': 0, 'lifts': (10, 0), 'hair_y': 26, 'skirt_y': 22, 'hips': (-8, 10), 'knees': (10, 14), 'up': 1.0},
            {'bob': -6, 'crouch': 26, 'hair_y': -14, 'skirt_y': -8, 'hips': (-6, 8), 'knees': (20, 24), 'up': 0.0},
        ][f]
        up = J.pop('up')
        if side:
            J['hair_x'] = 10
            J.pop('lifts', None)
            J['arms'] = [(-30 * up, -20, 1.0), (40 * up - 10, -25, 1.0)]
        else:
            J.pop('hips', None)
            J.pop('knees', None)
            J['arms'] = [(-14 * up, -12, 1.0), (14 * up, 12, 1.0)]
        return J
    if anim == 'kneel':
        k = 1.0 - f / (n - 1)
        k = k * k * (3 - 2 * k)
        p = {'crouch': 120 * k, 'lean': (-40 if side else 0) * k, 'hair_y': -20 * k, 'bob': 0, 'tilt': -4 * k}
        if side:
            p['hips'] = (-40 * k, 45 * k)
            p['knees'] = (20 * k, 90 * k)
            p['arms'] = [(25 * k, -40 * k, 1.0), (35 * k, -50 * k, 1.0)]
        else:
            p['arms'] = fb_arms(0.6 * k, 0.6 * k, front, 1.0, 20 * k)
        return p
    if anim == 'hurt':
        p = {'lean': 30 if side else 0, 'bob': -8, 'crouch': 14, 'hair_x': -16 if side else 8, 'hair_y': 12, 'skirt_x': -8, 'tilt': -4}
        if side:
            p['hips'] = (10, -6)
            p['arms'] = [(-30, -20, 1.0), (-25, -30, 1.0)]
        else:
            p['arms'] = [(10, 25, 0.95), (-10, -25, 0.95)]
        return p
    return {}


# ---------------------------------------------------------------- frames
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
    pm = np.asarray(pil, dtype=np.float32) / 255
    pm[..., :3] *= pm[..., 3:4]
    chans = [Image.fromarray((pm[..., i] * 255 + 0.5).astype(np.uint8)).resize((round(w * scale), round(h * scale)), Image.LANCZOS) for i in range(4)]
    rs = np.dstack([np.asarray(ch, dtype=np.float32) / 255 for ch in chans])
    rs[..., :3] = np.where(rs[..., 3:4] > 1e-3, rs[..., :3] / np.maximum(rs[..., 3:4], 1e-3), 0)
    small = Image.fromarray((np.clip(rs, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGBA')
    frame = Image.new('RGBA', (FW, FH), (0, 0, 0, 0))
    cx = (view_cfg['cx'] + PAD) * scale
    if mirror:
        cx = small.width - cx
    fx = int(round(FW / 2 - cx))
    fy = int(round(FH - FOOT - view_cfg['foot'] * scale))
    frame.paste(small, (fx, fy), small)
    return frame


def main(only=None):
    os.makedirs(OUT, exist_ok=True)
    views = {k: View(k, v) for k, v in CFG.items()}
    rows = [('front', False), ('side', True), ('back', False)]
    for anim, n in ANIMS.items():
        if only and anim not in only:
            continue
        sheet = Image.new('RGBA', (FW * n, FH * len(rows)), (0, 0, 0, 0))
        for r, (vname, mirror) in enumerate(rows):
            v = views[vname]
            for f in range(n):
                img = v.render(pose(vname, anim, f, n))
                sheet.alpha_composite(to_frame(img, CFG[vname], mirror), (f * FW, r * FH))
        sheet.save(os.path.join(OUT, anim + '.png'), optimize=True)
        print('sheet', anim)
    meta = {'frame_width': FW, 'frame_height': FH, 'foot_offset': FOOT, 'rows': ['front', 'side', 'back'],
            'char_height_px': CHAR_H, 'animations': ANIMS}
    with open(os.path.join(OUT, 'witch.json'), 'w') as fh:
        json.dump(meta, fh, indent=2)


if __name__ == '__main__':
    import sys
    main(sys.argv[1:] or None)
