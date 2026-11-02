"""Asterion — personagem 3D anime (cel-shaded) gerada por script para Blender 4.2+ / 5.x.

Como usar no Blender:
    Scripting > Open > asterion_blender.py > Run Script
Ou pelo terminal:
    blender --background --python asterion_blender.py

O script apaga a cena atual e cria:
    * corpo contínuo (lofts suaves), rosto anime pintado em textura (olhos âmbar,
      cílios, sobrancelhas, boca) com 4 expressões no mesmo atlas;
    * cabelo 3A volumoso até a cintura feito de cachos em espiral (geometria real);
    * vestido verde, capa curta com capuz, mangas, corpete de couro, dois cintos
      com fivelas de bronze, bolsas, braçadeiras, luvas sem dedos e botas
      de cano alto com cadarço — bordado dourado em textura;
    * esqueleto humanoide (nomes compatíveis com o perfil humanoide do Godot e
      parecidos com o Mixamo) + correntes de ossos para cabelo, saia e capa;
    * pesos de pele calculados por região (sem "bone heat", que falha em roupas);
    * animações: idle, walk, run, jump_up, jump_fall, cast, kneel, look_around,
      sigh, hurt;
    * exporta asterion.glb (e salva asterion.blend) na mesma pasta do script ou,
      se definido, em ASTERION_OUT.

Tudo é procedural e determinístico (mesma semente = mesmo modelo).
Unidades em metros, Z para cima, a personagem olha para -Y (vista frontal do Blender).
"""
import bpy
import bmesh
import math
import os
import random
import numpy as np
from mathutils import Vector, Matrix, Quaternion, Euler

SEED = 18
HEIGHT = 1.62

# --------------------------------------------------------------------------------------
# Paleta (sRGB) — tirada da ficha de referência
# --------------------------------------------------------------------------------------
PAL = {
    "skin": "#8a5a3e",        # pele morena quente
    "skin_shadow": "#6a3f2a",
    "hair": "#24140f",        # castanho muito escuro
    "hair_hi": "#4a2c1f",
    "green": "#2f4a30",       # verde floresta (capa / saia)
    "green_dark": "#1a2c1e",  # verde profundo (vestido / forro)
    "green_light": "#36594a",
    "trim": "#a88a4a",        # bordado oliva-dourado
    "leather": "#5a3726",     # couro castanho
    "leather_dark": "#3a2219",
    "leather_light": "#7a4c33",
    "bronze": "#b88b4f",
    "sole": "#1f1512",
    "lace": "#2c1a12",
}


def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexc(h, lin=True):
    v = [int(h[i:i + 2], 16) / 255.0 for i in (1, 3, 5)]
    return tuple(srgb_to_lin(x) for x in v) if lin else tuple(v)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def sstep(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def catmull(table, x):
    """Interpolação Catmull-Rom numa tabela [(x, valores...)] ordenada por x."""
    xs = [r[0] for r in table]
    if x <= xs[0]:
        return list(table[0][1:])
    if x >= xs[-1]:
        return list(table[-1][1:])
    i = max(j for j in range(len(xs) - 1) if xs[j] <= x)
    p0 = table[max(i - 1, 0)]
    p1 = table[i]
    p2 = table[i + 1]
    p3 = table[min(i + 2, len(table) - 1)]
    t = (x - p1[0]) / (p2[0] - p1[0])
    out = []
    for k in range(1, len(p1)):
        a, b, c, d = p0[k], p1[k], p2[k], p3[k]
        out.append(0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t
                          + (-a + 3 * b - 3 * c + d) * t * t * t))
    return out


# --------------------------------------------------------------------------------------
# Cena / coleções
# --------------------------------------------------------------------------------------
def reset_scene():
    if bpy.context.object and bpy.context.object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.armatures,
                 bpy.data.actions, bpy.data.curves, bpy.data.cameras, bpy.data.lights):
        for item in list(coll):
            try:
                coll.remove(item)
            except Exception:
                pass
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)


COLL = {}


def collection(name):
    if name not in COLL:
        c = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(c)
        COLL[name] = c
    return COLL[name]


# --------------------------------------------------------------------------------------
# Materiais e texturas
# --------------------------------------------------------------------------------------
MATS = {}


def new_image(name, arr):
    """arr: float32 HxWx4 em sRGB, origem embaixo-esquerda (convenção do Blender)."""
    h, w = arr.shape[:2]
    img = bpy.data.images.new(name, width=w, height=h, alpha=True)
    img.colorspace_settings.name = 'sRGB'
    img.pixels.foreach_set(np.ascontiguousarray(arr, dtype=np.float32).ravel())
    img.pack()
    return img


def material(name, color_hex, rough=0.8, metal=0.0, image=None, alpha_clip=False, double=False):
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    bsdf = nt.nodes.get('Principled BSDF')
    if bsdf is None:
        for n in list(nt.nodes):
            nt.nodes.remove(n)
        bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled')
        out = nt.nodes.new('ShaderNodeOutputMaterial')
        nt.links.new(bsdf.outputs[0], out.inputs[0])
    col = hexc(color_hex)
    bsdf.inputs['Base Color'].default_value = (*col, 1.0)
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Metallic'].default_value = metal
    m.diffuse_color = (*col, 1.0)
    m.roughness = rough
    m.metallic = metal
    if image is not None:
        tex = nt.nodes.new('ShaderNodeTexImage')
        tex.image = image
        tex.location = (-400, 200)
        nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
        if alpha_clip:
            nt.links.new(tex.outputs['Alpha'], bsdf.inputs['Alpha'])
    if alpha_clip:
        try:
            m.blend_method = 'CLIP'
        except Exception:
            pass
    m.use_backface_culling = not double
    MATS[name] = m
    return m


# ---- pintura procedural em numpy ------------------------------------------------------
def canvas(w, h, rgb, a=1.0):
    c = np.zeros((h, w, 4), np.float32)
    c[..., :3] = rgb
    c[..., 3] = a
    return c


def blend(c, mask, rgb, alpha=1.0):
    m = (np.clip(mask, 0, 1) * alpha)[..., None]
    c[..., :3] = c[..., :3] * (1 - m) + np.array(rgb, np.float32) * m


def downsample(c, f):
    h, w = c.shape[:2]
    return c.reshape(h // f, f, w // f, f, 4).mean(axis=(1, 3))


def rgbf(h):
    return np.array(hexc(h, lin=False), np.float32)


def soft_band(d, width, feather):
    """1 dentro de |d|<width, borda suave."""
    return 1.0 - smoothstep(width - feather, width + feather, np.abs(d))


def face_atlas(size=1024):
    """Atlas 2x2 do rosto: [0] neutro, [1] piscando, [2] feliz, [3] surpresa.
    Cada quadro cobre a frente da cabeça (projeção planar frontal)."""
    S = 2
    n = size // 2 * S
    tiles = []
    for expr in ("neutral", "blink", "happy", "surprised"):
        tiles.append(downsample(face_tile(n, expr), S))
    half = size // 2
    atlas = np.zeros((size, size, 4), np.float32)
    # origem embaixo-esquerda: tile0 em cima-esquerda, tile1 em cima-direita...
    atlas[half:, :half] = tiles[0]
    atlas[half:, half:] = tiles[1]
    atlas[:half, :half] = tiles[2]
    atlas[:half, half:] = tiles[3]
    return atlas


# Região do rosto na projeção (metros, relativo ao centro da cabeça)
FACE_W = 0.24          # largura coberta pela textura
FACE_Z0 = -0.135       # base da textura (abaixo do queixo)
FACE_H = 0.24


def face_tile(n, expr):
    """Rosto pintado (projeção frontal). Coordenadas X/Z em metros a partir do centro da cabeça."""
    skin = rgbf(PAL["skin"])
    c = canvas(n, n, skin)
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    X = (xs + 0.5) / n * FACE_W - FACE_W / 2
    Z = (ys + 0.5) / n * FACE_H + FACE_Z0
    rng = np.random.default_rng(SEED + 7)

    def ell(cx, cz, rx, rz):
        return ((X - cx) / rx) ** 2 + ((Z - cz) / rz) ** 2

    # --- pintura da pele: luz na testa e maçãs, calor nas bochechas, sombra no queixo
    blend(c, np.exp(-ell(0.0, 0.07, 0.05, 0.03)), rgbf("#a06d4c"), 0.35)
    for sx in (-1, 1):
        blend(c, np.exp(-ell(sx * 0.052, -0.012, 0.022, 0.012)), rgbf("#a8775a"), 0.35)   # maçã do rosto
        blend(c, np.exp(-ell(sx * 0.05, -0.03, 0.026, 0.014) * 1.3), rgbf("#c0614c"), 0.26)  # blush
        blend(c, np.exp(-ell(sx * 0.082, -0.05, 0.02, 0.05)), rgbf(PAL["skin_shadow"]), 0.22)  # lateral
    blend(c, np.exp(-ell(0.0, -0.104, 0.03, 0.012)), rgbf(PAL["skin_shadow"]), 0.35)       # sob o queixo
    blend(c, np.exp(-ell(0.0, -0.086, 0.012, 0.006)), rgbf("#a2735a"), 0.3)                 # luz do queixo

    # --- nariz: ponte suave, sombra lateral, narinas e brilho na ponta
    blend(c, np.exp(-ell(0.0055, -0.012, 0.0035, 0.02) * 1.5), rgbf(PAL["skin_shadow"]), 0.28)
    blend(c, np.exp(-ell(-0.002, -0.02, 0.0022, 0.016) * 1.5), rgbf("#a8785c"), 0.3)
    blend(c, np.exp(-ell(0.0, -0.038, 0.0075, 0.0038) * 1.3), rgbf("#5e3423"), 0.32)
    for sx in (-1, 1):
        blend(c, np.exp(-ell(sx * 0.0048, -0.0405, 0.0022, 0.0012) * 1.4), rgbf("#3e1e15"), 0.6)
    blend(c, np.exp(-ell(-0.0015, -0.0335, 0.0026, 0.002) * 1.6), rgbf("#c0927a"), 0.45)

    # --- boca
    mouth(c, X, Z, expr)

    # --- sobrancelhas com fios
    for sx in (-1, 1):
        brow(c, X, Z, sx, expr, rng)

    # --- olhos
    for sx in (-1, 1):
        eye(c, X, Z, sx, expr)
    c[..., 3] = 1.0
    np.nan_to_num(c, copy=False)
    return c


def mouth(c, X, Z, expr):
    mz = -0.061
    lip_top = rgbf("#7a3a30")
    lip_bot = rgbf("#9c5245")
    line = rgbf("#3e1813")
    if expr == "surprised":
        d = ((X / 0.0085) ** 2 + ((Z - mz + 0.003) / 0.0085) ** 2)
        blend(c, smoothstep(1.12, 0.92, d), rgbf("#3a1512"), 1.0)
        blend(c, smoothstep(1.0, 0.6, ((X / 0.006) ** 2 + ((Z - mz + 0.008) / 0.003) ** 2)), rgbf("#8a4a44"), 0.9)
        ring = soft_band(np.sqrt(d) - 1.08, 0.12, 0.08)
        blend(c, ring, lip_bot, 0.7)
        return
    w = 0.0165 if expr != "happy" else 0.0185
    smile = 0.0016 if expr != "happy" else 0.0042
    u = np.clip(X / w, -1.2, 1.2)
    inside = np.abs(X) < w
    curve = mz + smile * (u ** 2) - smile * 0.35
    # lábio superior (arco do cupido)
    bow = 0.0011 * np.exp(-((np.abs(X) - 0.0042) / 0.003) ** 2) - 0.0008 * np.exp(-(X / 0.0018) ** 2)
    up_h = (0.0042 + bow) * (1 - np.abs(u) ** 2.2).clip(0, 1) ** 0.6
    upper = (Z > curve) & (Z < curve + up_h) & inside
    blend(c, upper.astype(np.float32) * smoothstep(0, 0.0006, curve + up_h - Z), lip_top, 0.8)
    # lábio inferior cheio
    lo_h = 0.0058 * np.clip(1 - np.abs(u) ** 2, 0, 1) ** 0.7
    lower = (Z < curve) & (Z > curve - lo_h) & inside
    blend(c, lower.astype(np.float32) * smoothstep(0, 0.0008, Z - (curve - lo_h)), lip_bot, 0.82)
    blend(c, np.exp(-(((X + 0.002) / 0.006) ** 2 + ((Z - curve + 0.0028) / 0.0014) ** 2)), rgbf("#d79a84"), 0.55)
    blend(c, np.exp(-(((X) / 0.004) ** 2 + ((Z - curve - 0.003) / 0.0009) ** 2)), rgbf("#b07060"), 0.3)
    # linha da boca, mais escura no centro, cantos levemente para cima
    ln = soft_band(Z - curve, 0.00065, 0.0005) * inside * (1 - 0.5 * np.abs(u) ** 3)
    blend(c, ln, line, 0.95)
    for sx in (-1, 1):
        corner = np.exp(-(((X - sx * w) / 0.0016) ** 2 + ((Z - curve - smile * 0.65 - 0.0006) / 0.0011) ** 2))
        blend(c, corner, line, 0.55)
    if expr == "happy":
        teeth = (Z < curve - 0.0003) & (Z > curve - 0.003) & (np.abs(X) < w * 0.7)
        blend(c, teeth.astype(np.float32), rgbf("#f3e9e0"), 0.9)
    # sombra suave sob o lábio inferior
    blend(c, np.exp(-((X / 0.011) ** 2 + ((Z - mz + 0.0105) / 0.0028) ** 2)), rgbf(PAL["skin_shadow"]), 0.3)


def brow(c, X, Z, sx, expr, rng):
    lx = X * sx
    t = (lx - 0.011) / 0.05            # 0 = início (perto do nariz), 1 = ponta
    inb = (t > -0.05) & (t < 1.02)
    raise_ = 0.006 if expr == "surprised" else (0.0025 if expr == "happy" else 0.0)
    tt = np.clip(t, 0, 1)
    arch = 0.044 + raise_ + 0.0085 * np.sin(tt * math.pi * 0.85) ** 1.2 - 0.0045 * tt ** 2
    thick = 0.0042 * (1.0 - 0.72 * tt ** 1.3) + 0.0006
    d = Z - arch
    shape = soft_band(d + 0.0008 * (1 - tt), thick, 0.00055) * inb
    shape *= smoothstep(-0.05, 0.12, t) * (1 - smoothstep(0.95, 1.02, t))
    # fios: listras finas inclinadas
    strokes = 0.6 + 0.4 * np.sin((lx * 2200.0 + d * 1400.0 * (1 - tt)) + rng.random() * 6.28)
    col = rgbf("#1d0f0a")
    blend(c, shape * (0.75 + 0.25 * strokes), col, 0.95)
    blend(c, shape * smoothstep(0.0, 0.3, t) * (1 - strokes) * 0.4, rgbf("#3a2116"), 0.6)


def eye(c, X, Z, sx, expr):
    ecx, ecz = 0.0408, 0.004
    ew, eh = 0.0272, 0.0195
    lx = (X * sx - ecx) / ew      # -1 canto interno, +1 canto externo
    lz = (Z - ecz) / eh
    ax = np.abs(lx)
    inside_x = ax <= 1.0
    lift = 0.16 * lx              # canto externo erguido (olhar amendoado)
    dark = rgbf("#130806")
    skin_sh = rgbf(PAL["skin_shadow"])

    # sombra de olho (marrom quente) acima da pálpebra
    upper_base = 0.92 * np.clip(1 - ax ** 2.4, 0, 1) ** 0.5 + lift + 0.05
    shadow_zone = np.exp(-(((lz - upper_base - 0.32) / 0.42) ** 2)) * np.exp(-((lx - 0.15) / 1.05) ** 4)
    blend(c, shadow_zone, rgbf("#6e3a26"), 0.32)

    if expr in ("blink", "happy"):
        if expr == "happy":
            curve = 0.18 - 0.6 * lx ** 2 + lift
        else:
            curve = -0.12 - 0.22 * (1 - lx ** 2) + lift
        th = 0.085 + 0.06 * np.clip(lx, 0, 1)
        lash = soft_band(lz - curve, th, 0.045) * (ax < 1.04)
        blend(c, lash, dark, 1.0)
        wing = soft_band(lz - (curve + 0.32 * (lx - 0.9)), 0.07 * np.clip(1.3 - lx, 0, 1) * 2.2, 0.04) * (lx > 0.85) * (lx < 1.3)
        blend(c, wing, dark, 1.0)
        for k in range(4):                      # cílios soltos
            px = 0.45 + 0.17 * k
            base_z = (0.18 - 0.6 * px ** 2 if expr == "happy" else -0.12 - 0.22 * (1 - px ** 2)) + 0.16 * px
            seg = soft_band((lx - px) - (lz - base_z) * 0.55, 0.025, 0.02) * (lz < base_z + 0.02) * (lz > base_z - 0.28)
            blend(c, seg, dark, 0.9)
        crease = soft_band(lz - (curve + 0.38), 0.022, 0.02) * (ax < 0.8)
        blend(c, crease, skin_sh, 0.45)
        return

    open_scale = 1.15 if expr == "surprised" else 1.0
    top = upper_base * open_scale
    bot = (-0.8 * np.clip(1 - ax ** 2.0, 0, 1) ** 0.8 + lift * 0.55) * open_scale
    edge = np.minimum(top - lz, lz - bot)
    open_mask = np.clip(edge / 0.05, 0, 1) * inside_x
    # esclera: branco quente, sombra da pálpebra, canto interno rosado
    blend(c, open_mask, rgbf("#f2e9df"), 1.0)
    blend(c, open_mask * smoothstep(top - 0.75, top, lz), rgbf("#b9a69b"), 0.6)
    blend(c, open_mask * np.exp(-((lx + 0.95) / 0.12) ** 2), rgbf("#d79a8e"), 0.7)

    # íris âmbar em camadas
    icx, icz = -0.03, -0.06
    rx_i, rz_i = 0.6, 0.9 * (1.0 if expr != "surprised" else 0.78)
    if expr == "surprised":
        rx_i *= 0.85
    dx = (lx - icx) / rx_i
    dz = (lz - icz) / rz_i
    di = np.sqrt(dx ** 2 + dz ** 2)
    iris = smoothstep(1.03, 0.96, di) * open_mask
    g = np.clip(dz * 0.5 + 0.5, 0, 1)[..., None]
    top_col, mid_col, low_col = rgbf("#4a1f08"), rgbf("#a55516"), rgbf("#f3b346")
    col = np.where(g > 0.5, mid_col + (top_col - mid_col) * ((g - 0.5) * 2), low_col + (mid_col - low_col) * (g * 2))
    m = iris[..., None]
    c[..., :3] = c[..., :3] * (1 - m) + col * m
    ang = np.arctan2(dz, dx)
    fibers = (0.5 + 0.5 * np.sin(ang * 31.0 + np.sin(ang * 7.0) * 1.5)) * smoothstep(0.3, 0.85, di)
    blend(c, fibers * iris * smoothstep(1.0, 0.8, di), rgbf("#6e2f0c"), 0.28)
    blend(c, smoothstep(0.42, 0.25, di) * iris, rgbf("#d98a2c"), 0.45)          # anel claro em volta da pupila
    blend(c, smoothstep(0.8, 0.99, di) * iris, rgbf("#2e1206"), 0.9)            # anel externo escuro
    dp = np.sqrt((dx / 0.36) ** 2 + ((dz + 0.03) / 0.42) ** 2)
    blend(c, smoothstep(1.05, 0.88, dp) * open_mask, rgbf("#160803"), 1.0)      # pupila
    blend(c, iris * smoothstep(top - 0.55, top - 0.02, lz), rgbf("#1e0b04"), 0.7)  # sombra da pálpebra
    # brilho de baixo (luz rebatida dourada)
    blend(c, iris * np.exp(-(((dx + 0.05) / 0.5) ** 2 + ((dz + 0.62) / 0.14) ** 2)), rgbf("#ffd27a"), 0.55)
    # reflexos
    dh = np.sqrt(((dx + 0.34) / 0.24) ** 2 + ((dz - 0.36) / 0.22) ** 2)
    blend(c, smoothstep(1.0, 0.75, dh) * open_mask, rgbf("#fffaf2"), 1.0)
    dh2 = np.sqrt(((dx - 0.36) / 0.11) ** 2 + ((dz + 0.36) / 0.11) ** 2)
    blend(c, smoothstep(1.0, 0.65, dh2) * open_mask, rgbf("#fff1d0"), 0.9)
    dh3 = np.sqrt(((dx - 0.1) / 0.06) ** 2 + ((dz - 0.5) / 0.06) ** 2)
    blend(c, smoothstep(1.0, 0.6, dh3) * open_mask, rgbf("#ffffff"), 0.7)

    # linha dos cílios superiores: grossa, afinando para dentro, com asa
    th = 0.1 + 0.17 * np.clip((lx + 0.3) / 1.3, 0, 1) ** 1.2
    upper = soft_band(lz - (top + th * 0.5), th * 0.62, 0.03) * (ax < 1.04)
    blend(c, upper, dark, 1.0)
    wing_c = top + 0.12 + 0.5 * (lx - 0.86)
    wing = soft_band(lz - wing_c, 0.09 * np.clip(1.42 - lx, 0, 1) * 1.9, 0.03) * (lx > 0.8) * (lx < 1.42)
    blend(c, wing, dark, 1.0)
    # cílios: pequenos tufos curvos e afinados na metade externa
    for k in range(6):
        px = 0.15 + 0.15 * k
        base_z = 0.92 * max(0.0, 1 - min(px, 1.0) ** 2.4) ** 0.5 + 0.16 * px + 0.05 + 0.14 + 0.08 * px
        length = 0.13 + 0.035 * k
        v = np.clip((lz - base_z) / length, 0, 1)
        bend = 0.18 * v ** 2 * (0.6 + 0.4 * k / 5)
        width = 0.03 * (1 - v) + 0.006
        seg = soft_band(lx - px - bend - v * length * 0.4, width, 0.012) * (lz > base_z - 0.03) * (lz < base_z + length)
        blend(c, seg, dark, 0.95)
    # cílios inferiores suaves
    lower = soft_band(lz - (bot - 0.03), 0.022, 0.02) * smoothstep(-0.2, 0.5, lx) * (lx < 1.02)
    blend(c, lower, rgbf("#3a1d14"), 0.85)
    for k in range(3):
        px = 0.45 + 0.2 * k
        bz = -0.8 * max(0.0, 1 - px ** 2) ** 0.8 + 0.16 * px * 0.55 - 0.03
        seg = soft_band((lx - px) + (lz - bz) * 0.4, 0.016, 0.012) * (lz < bz) * (lz > bz - 0.12)
        blend(c, seg, rgbf("#3a1d14"), 0.7)
    # dobra da pálpebra
    crease = soft_band(lz - (top + 0.4 + 0.05 * lx), 0.018, 0.016) * (ax < 0.88) * smoothstep(-1.0, -0.4, lx)
    blend(c, crease, rgbf("#5a2e1e"), 0.55)


def fabric_trim_texture(w=1024, h=256):
    """Faixa de bordado (nó celta simplificado) dourado sobre verde escuro.
    u repete ao longo da faixa, v atravessa a faixa."""
    S = 2
    W, H = w * S, h * S
    c = canvas(W, H, rgbf(PAL["green_dark"]))
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    u = xs / W * 8.0          # 8 módulos por textura
    v = ys / H                # 0..1 através da faixa
    gold = rgbf(PAL["trim"])
    # bordas
    for vv in (0.16, 0.84):
        blend(c, soft_band(v - vv, 0.022, 0.008), gold, 1.0)
    # entrelaçado: duas senoides cruzadas
    ph = (u % 1.0) * 2 * math.pi
    for sgn in (1, -1):
        curve = 0.5 + sgn * 0.22 * np.sin(ph)
        blend(c, soft_band(v - curve, 0.03, 0.01), gold, 1.0)
    # pontos
    d = ((u % 1.0 - 0.5) * 3.0) ** 2 + ((v - 0.5) * 8) ** 2
    blend(c, smoothstep(1.0, 0.6, d * 8), gold, 1.0)
    c = downsample(c, S)
    return c


def hair_texture(w=512, h=512):
    """Textura de mechas: base escura com fios mais claros seguindo v."""
    rng = np.random.default_rng(SEED)
    c = canvas(w, h, rgbf(PAL["hair"]))
    xs = np.arange(w, dtype=np.float32) / w
    strands = np.zeros(w, np.float32)
    for _ in range(60):
        cx = rng.random()
        wd = rng.uniform(0.004, 0.015)
        amp = rng.uniform(0.3, 1.0)
        dx = np.minimum(np.abs(xs - cx), 1 - np.abs(xs - cx))
        strands += amp * np.exp(-(dx / wd) ** 2)
    strands = np.clip(strands, 0, 1.4) / 1.4
    ys = np.arange(h, dtype=np.float32) / h
    sheen = 0.55 + 0.45 * np.sin(ys * math.pi * 6) ** 2
    m = strands[None, :] * sheen[:, None]
    blend(c, m, rgbf(PAL["hair_hi"]), 0.85)
    blend(c, (1 - strands[None, :]) * np.ones((h, 1)), rgbf("#140a07"), 0.35)
    return c


def leather_texture(w=256, h=256):
    rng = np.random.default_rng(SEED + 3)
    c = canvas(w, h, rgbf(PAL["leather"]))
    noise = rng.random((h // 8, w // 8)).astype(np.float32)
    noise = np.kron(noise, np.ones((8, 8), np.float32))
    k = np.ones(9, np.float32) / 9
    for axis in (0, 1):
        noise = np.apply_along_axis(lambda m: np.convolve(np.concatenate([m[-4:], m, m[:4]]), k, 'valid'), axis, noise)
    blend(c, noise, rgbf(PAL["leather_light"]), 0.35)
    ys = np.arange(h, dtype=np.float32) / h
    for vv in (0.08, 0.92):
        blend(c, soft_band(ys[:, None] - vv, 0.012, 0.006) * np.ones((1, w)), rgbf("#c9a77a"), 0.55)
    return c


def periodic_noise(n, sigma, rng):
    """Ruído contínuo e repetível (filtrado no domínio da frequência)."""
    w = rng.standard_normal((n, n))
    f = np.fft.fftfreq(n)
    fx, fy = np.meshgrid(f, f)
    g = np.exp(-(fx ** 2 + fy ** 2) * (sigma ** 2) * 2 * math.pi ** 2)
    out = np.real(np.fft.ifft2(np.fft.fft2(w) * g))
    out -= out.mean()
    return out / (out.std() + 1e-9)


def detail_textures(n=512):
    """Texturas de detalhe em cinza (0.5 = neutro) usadas pelo shader do jogo."""
    rng = np.random.default_rng(SEED + 11)
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32) / n
    T = {}
    # tecido: trama fina + manchas suaves + fios mais grossos de vez em quando
    weave = (np.sin(xs * 2 * math.pi * 96) * np.sin(ys * 2 * math.pi * 96))
    slub = periodic_noise(n, 2.5, rng)
    cloth = 0.5 + 0.035 * weave + 0.045 * periodic_noise(n, 22, rng) + 0.02 * slub
    cloth += 0.03 * np.sin(xs * 2 * math.pi * 48 + slub) * 0.5
    T["cloth"] = cloth
    # couro: granulado, manchas e arranhões
    grain = periodic_noise(n, 1.6, rng)
    patches = periodic_noise(n, 30, rng)
    leather = 0.5 + 0.05 * grain + 0.07 * patches
    for _ in range(40):
        x0, y0 = rng.random(2)
        ang = rng.uniform(0, math.pi)
        L = rng.uniform(0.05, 0.2)
        d = np.abs((xs - x0) * math.sin(ang) - (ys - y0) * math.cos(ang))
        along = (xs - x0) * math.cos(ang) + (ys - y0) * math.sin(ang)
        leather += 0.06 * np.exp(-(d / 0.0025) ** 2) * (np.abs(along) < L)
    T["leather"] = leather
    # cabelo: fios ao longo do comprimento (variam só em u)
    strands = np.zeros(n, np.float32)
    for _ in range(90):
        cx = rng.random()
        wd = rng.uniform(0.003, 0.012)
        dx = np.minimum(np.abs(np.arange(n) / n - cx), 1 - np.abs(np.arange(n) / n - cx))
        strands += rng.uniform(0.4, 1.0) * np.exp(-(dx / wd) ** 2)
    strands = (strands - strands.mean()) / (strands.std() + 1e-6)
    hair = 0.5 + 0.12 * strands[None, :] + 0.03 * periodic_noise(n, 3, rng)
    T["hair"] = hair
    out = {}
    for k, v in T.items():
        a = np.clip(v, 0, 1).astype(np.float32)
        img = np.zeros((n, n, 4), np.float32)
        img[..., 0] = img[..., 1] = img[..., 2] = a
        img[..., 3] = 1.0
        out[k] = img
    return out


def save_png(arr, path):
    """Salva RGBA float (origem embaixo-esquerda) como PNG pelo próprio Blender."""
    h, w = arr.shape[:2]
    img = bpy.data.images.new("tmp_save", width=w, height=h, alpha=True)
    img.pixels.foreach_set(np.ascontiguousarray(arr, dtype=np.float32).ravel())
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    bpy.data.images.remove(img)


# --------------------------------------------------------------------------------------
# Oclusão ambiente nos vértices (dobras, sob a capa, entre os cachos)
# --------------------------------------------------------------------------------------
def bake_vertex_ao(ob, rays=14, dist=0.09, strength=0.9):
    from mathutils.bvhtree import BVHTree
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    bm.normal_update()
    tree = BVHTree.FromBMesh(bm)
    # direções no hemisfério (espiral de Fibonacci, pesadas pelo cosseno)
    dirs = []
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(rays):
        z = math.sqrt(1 - (i + 0.5) / rays)
        r = math.sqrt(max(0.0, 1 - z * z))
        a = golden * i
        dirs.append((r * math.cos(a), r * math.sin(a), z))
    ao = np.ones(len(bm.verts), np.float32)
    for v in bm.verts:
        n = v.normal
        if n.length < 0.5:
            continue
        t = n.orthogonal().normalized()
        b = n.cross(t)
        o = v.co + n * 0.0015
        hit = 0.0
        for dx, dy, dz in dirs:
            d = t * dx + b * dy + n * dz
            loc, nor, idx, dd = tree.ray_cast(o, d, dist)
            if loc is not None:
                hit += 1.0 - (dd / dist) * 0.5
        ao[v.index] = 1.0 - strength * hit / rays
    bm.free()
    me = ob.data
    attr = me.color_attributes.get("AO") or me.color_attributes.new("AO", 'BYTE_COLOR', 'POINT')
    cols = np.repeat(ao[:, None], 4, axis=1)
    cols[:, 3] = 1.0
    attr.data.foreach_set("color", cols.ravel())
    me.color_attributes.active_color = attr
    try:
        me.color_attributes.render_color_index = me.color_attributes.active_color_index
    except Exception:
        pass
    return ao


# --------------------------------------------------------------------------------------
# Geometria
# --------------------------------------------------------------------------------------
PARTS = []          # (obj, skin_rule)


def mesh_object(name, verts, faces, uvs=None, mat=None, smooth=True, coll="Asterion"):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(map(float, v)) for v in verts], [], [tuple(f) for f in faces])
    if uvs is not None:
        uvl = me.uv_layers.new(name="UVMap")
        flat = np.array([uv for f in uvs for uv in f], np.float32).ravel()
        uvl.data.foreach_set("uv", flat)
    me.polygons.foreach_set("use_smooth", [smooth] * len(me.polygons))
    me.validate(clean_customdata=False)
    me.update()
    ob = bpy.data.objects.new(name, me)
    collection(coll).objects.link(ob)
    if mat is not None:
        if isinstance(mat, (list, tuple)):
            for m in mat:
                me.materials.append(m)
        else:
            me.materials.append(mat)
    return ob


UV_TILE = 0.25   # metros por repetição das texturas de detalhe (tecido, couro)


def grid_object(name, P, mat, wrap=True, cap_top=False, cap_bot=False, uv_u=1.0, uv_v=1.0,
                smooth=True, uv_override=None, flip=False, metric=False):
    """P: array (linhas, colunas, 3). Linhas descem ao longo da peça; colunas giram
    no sentido anti-horário visto de cima (normais para fora).
    metric=True: UV em metros/UV_TILE (texturas de detalhe repetem sem esticar)."""
    P = np.asarray(P, np.float64)
    R, C = P.shape[:2]
    if metric and R > 1 and C > 1:
        mid_r = P[R // 2]
        ring = np.vstack([mid_r, mid_r[:1]]) if wrap else mid_r
        circ = float(np.linalg.norm(np.diff(ring, axis=0), axis=1).sum())
        mid_c = P[:, C // 2]
        height = float(np.linalg.norm(np.diff(mid_c, axis=0), axis=1).sum())
        uv_u = max(circ / UV_TILE, 0.05)
        uv_v = max(height / UV_TILE, 0.05)
    verts = list(P.reshape(-1, 3))
    faces, uvs = [], []
    cols = C if wrap else C - 1
    for r in range(R - 1):
        for c in range(cols):
            c2 = (c + 1) % C
            a, b, d, e = r * C + c, r * C + c2, (r + 1) * C + c2, (r + 1) * C + c
            f = (a, e, d, b) if not flip else (a, b, d, e)
            faces.append(f)
            u0, u1 = c / cols * uv_u, (c + 1) / cols * uv_u
            v0, v1 = 1 - r / (R - 1) * uv_v, 1 - (r + 1) / (R - 1) * uv_v
            q = [(u0, v0), (u0, v1), (u1, v1), (u1, v0)]
            uvs.append(q if not flip else [q[0], q[3], q[2], q[1]])
    for cap, row, rev in ((cap_top, 0, True), (cap_bot, R - 1, False)):
        if not cap:
            continue
        center = P[row].mean(axis=0)
        ci = len(verts)
        verts.append(center)
        for c in range(C):
            c2 = (c + 1) % C
            a, b = row * C + c, row * C + c2
            f = (ci, b, a) if rev else (ci, a, b)
            if flip:
                f = f[::-1]
            faces.append(f)
            uvs.append([(0.5, 0.5)] * 3)
    if uv_override is not None:
        uvs = uv_override(P, faces, uvs)
    return mesh_object(name, verts, faces, uvs, mat, smooth)


def superellipse(theta, rx, ry, n=2.0):
    c, s = np.cos(theta), np.sin(theta)
    e = 2.0 / n
    return np.sign(c) * np.abs(c) ** e * rx, np.sign(s) * np.abs(s) ** e * ry


def frames_along(points):
    """Referenciais com transporte paralelo ao longo de uma polilinha."""
    pts = [Vector(p) for p in points]
    n = len(pts)
    T = []
    for i in range(n):
        if i == 0:
            t = pts[1] - pts[0]
        elif i == n - 1:
            t = pts[-1] - pts[-2]
        else:
            t = pts[i + 1] - pts[i - 1]
        T.append(t.normalized())
    ref = Vector((0, 0, 1)) if abs(T[0].z) < 0.9 else Vector((1, 0, 0))
    N = [(ref - T[0] * ref.dot(T[0])).normalized()]
    for i in range(1, n):
        v = N[-1] - T[i] * N[-1].dot(T[i])
        if v.length < 1e-8:
            v = N[-1]
        N.append(v.normalized())
    B = [T[i].cross(N[i]).normalized() for i in range(n)]
    return pts, T, N, B


def tube_points(path, radius_fn, sides, profile=None, twist=0.0):
    """Gera grade (linhas=pontos do caminho, colunas=lados) de um tubo ao longo do caminho.
    radius_fn(t, i) -> (rx, ry); profile opcional deforma o anel."""
    pts, T, N, B = frames_along(path)
    n = len(pts)
    rows = []
    for i in range(n):
        t = i / (n - 1)
        rx, ry = radius_fn(t, i)
        ring = []
        for k in range(sides):
            # anti-horário olhando contra a direção de avanço → normais para fora
            th = -2 * math.pi * k / sides + twist * t
            cx, cy = math.cos(th) * rx, math.sin(th) * ry
            if profile:
                cx, cy = profile(t, th, cx, cy)
            ring.append(pts[i] + N[i] * cx + B[i] * cy)
        rows.append([tuple(p) for p in ring])
    return np.array(rows)


def tube(name, path, radius_fn, sides, mat, cap_a=True, cap_b=True, metric=False, **kw):
    P = tube_points(path, radius_fn, sides, **kw)
    return grid_object(name, P, mat, wrap=True, cap_top=cap_a, cap_bot=cap_b, metric=metric)


def bezier(p0, p1, p2, p3, n):
    out = []
    for i in range(n):
        t = i / (n - 1)
        a = (1 - t) ** 3
        b = 3 * (1 - t) ** 2 * t
        c = 3 * (1 - t) * t * t
        d = t ** 3
        out.append(Vector(p0) * a + Vector(p1) * b + Vector(p2) * c + Vector(p3) * d)
    return out


def add_modifier_subsurf(ob, levels=1):
    m = ob.modifiers.new("Subdivisão", 'SUBSURF')
    m.levels = levels
    m.render_levels = levels
    return m


CLOTH_THICKNESS = False   # True = tecido com espessura real (mais pesado); False = material dos dois lados


def add_solidify(ob, thickness, offset=-1.0):
    if not CLOTH_THICKNESS:
        return None
    m = ob.modifiers.new("Espessura", 'SOLIDIFY')
    m.thickness = thickness
    m.offset = offset
    m.use_even_offset = True
    return m


# --------------------------------------------------------------------------------------
# Proporções / articulações
# --------------------------------------------------------------------------------------
def V(x, y, z):
    return Vector((x, y, z))


J = {}


def define_joints():
    J["hips"] = V(0, 0.0, 0.92)
    J["spine"] = V(0, 0.0, 1.01)
    J["chest"] = V(0, 0.0, 1.13)
    J["upper_chest"] = V(0, 0.002, 1.23)
    J["neck"] = V(0, 0.008, 1.345)
    J["head"] = V(0, 0.012, 1.425)
    J["head_c"] = V(0, 0.004, 1.505)       # centro da cabeça (projeção do rosto)
    J["head_top"] = V(0, 0.004, 1.625)
    # braços relaxados ao lado do corpo (como na ficha) — facilita capa e cabelo
    arm_dir = Vector((math.sin(math.radians(17)), 0.03, -math.cos(math.radians(17)))).normalized()
    fore_dir = Vector((math.sin(math.radians(9)), -0.16, -math.cos(math.radians(9)))).normalized()
    for side, s in (("L", 1), ("R", -1)):
        sh = V(s * 0.152, 0.006, 1.305)
        J["clav" + side] = V(s * 0.03, 0.0, 1.31)
        J["shoulder" + side] = sh
        el = sh + Vector((arm_dir.x * s, arm_dir.y, arm_dir.z)) * 0.245
        J["elbow" + side] = el
        wr = el + Vector((fore_dir.x * s, fore_dir.y, fore_dir.z)) * 0.222
        J["wrist" + side] = wr
        J["hand_end" + side] = wr + Vector((fore_dir.x * s * 0.6, fore_dir.y - 0.02, fore_dir.z)).normalized() * 0.165
        J["hip" + side] = V(s * 0.086, 0.0, 0.875)
        J["knee" + side] = V(s * 0.092, -0.01, 0.478)
        J["ankle" + side] = V(s * 0.088, 0.018, 0.082)
        J["toe" + side] = V(s * 0.092, -0.095, 0.026)
        J["toe_end" + side] = V(s * 0.094, -0.155, 0.02)


# --------------------------------------------------------------------------------------
# Corpo
# --------------------------------------------------------------------------------------
TORSO = [  # z, meia-largura, meia-profundidade, deslocamento y
    (0.775, 0.118, 0.094, 0.006),
    (0.84, 0.154, 0.106, 0.010),
    (0.90, 0.160, 0.106, 0.010),
    (0.96, 0.146, 0.098, 0.006),
    (1.02, 0.118, 0.082, 0.000),
    (1.08, 0.121, 0.086, -0.004),
    (1.15, 0.134, 0.094, -0.008),
    (1.21, 0.144, 0.096, -0.006),
    (1.26, 0.150, 0.093, -0.002),
    (1.295, 0.150, 0.086, 0.002),
    (1.322, 0.128, 0.072, 0.006),
    (1.345, 0.082, 0.058, 0.008),
    (1.37, 0.042, 0.042, 0.010),
    (1.41, 0.037, 0.039, 0.012),
    (1.47, 0.035, 0.037, 0.012),
]


def torso_shape(z, th, inflate=0.0):
    hw, hd, yo = catmull(TORSO, z)
    n = 2.35 if z < 1.33 else 2.0
    x, y = superellipse(th, hw + inflate, hd + inflate, n)
    # busto
    for side in (-1, 1):
        dth = th - (-math.pi / 2 + side * 0.42)
        b = 0.036 * math.exp(-((z - 1.18) / 0.048) ** 2) * math.exp(-(dth / 0.36) ** 2)
        y -= b
        x += side * b * 0.25
    # glúteos
    for side in (-1, 1):
        dth = th - (math.pi / 2 + side * 0.5)
        b = 0.016 * math.exp(-((z - 0.86) / 0.06) ** 2) * math.exp(-(dth / 0.45) ** 2)
        y += b
    return x, y + yo


def build_torso(mat, inflate=0.0, z_top=1.47, z_bot=0.775, rows=46, cols=40, name="Corpo - tronco", cap=True):
    zs = np.linspace(z_top, z_bot, rows)
    P = np.zeros((rows, cols, 3))
    for r, z in enumerate(zs):
        for c in range(cols):
            th = 2 * math.pi * c / cols
            x, y = torso_shape(z, th, inflate)
            P[r, c] = (x, y, z)
    return grid_object(name, P, mat, wrap=True, cap_top=False, cap_bot=cap)


def limb_path(points, n):
    """Caminho suave passando pelas articulações."""
    pts = [Vector(p) for p in points]
    out = []
    segs = len(pts) - 1
    for i in range(n):
        t = i / (n - 1) * segs
        k = min(int(t), segs - 1)
        f = t - k
        p0 = pts[max(k - 1, 0)]
        p1, p2 = pts[k], pts[k + 1]
        p3 = pts[min(k + 2, len(pts) - 1)]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f
                          + (-p0 + 3 * p1 - 3 * p2 + p3) * f * f * f))
    return out


LEG_R = [(0.0, 0.084, 0.088), (0.12, 0.076, 0.078), (0.3, 0.066, 0.066), (0.46, 0.053, 0.053),
         (0.52, 0.048, 0.049), (0.58, 0.049, 0.051), (0.7, 0.054, 0.056), (0.84, 0.042, 0.042),
         (0.95, 0.032, 0.033), (1.0, 0.031, 0.032)]
ARM_R = [(0.0, 0.047, 0.047), (0.18, 0.042, 0.041), (0.46, 0.032, 0.031), (0.52, 0.031, 0.030),
         (0.62, 0.034, 0.031), (0.85, 0.027, 0.023), (1.0, 0.024, 0.019)]


def build_leg(side, mat):
    s = 1 if side == "L" else -1
    top = J["hip" + side] + Vector((-s * 0.004, 0.0, 0.07))
    path = limb_path([top, J["knee" + side], J["ankle" + side]], 34)

    def rfn(t, i):
        rx, ry = catmull(LEG_R, t)
        return rx, ry

    # joelho levemente para frente
    def prof(t, th, cx, cy):
        return cx, cy
    return tube("Corpo - perna " + side, path, rfn, 20, mat, cap_a=True, cap_b=True)


def build_arm(side, mat):
    path = limb_path([J["shoulder" + side] + (J["shoulder" + side] - J["elbow" + side]).normalized() * 0.03,
                      J["elbow" + side], J["wrist" + side]], 30)

    def rfn(t, i):
        rx, ry = catmull(ARM_R, t)
        return rx, ry
    return tube("Corpo - braço " + side, path, rfn, 16, mat)


def build_hand(side, skin, glove):
    """Mão relaxada: palma (luva sem dedos) + dedos de pele, levemente curvados."""
    s = 1 if side == "L" else -1
    wr = J["wrist" + side]
    end = J["hand_end" + side]
    fwd = (end - wr).normalized()
    # a palma fica virada para o corpo
    side_axis = Vector((0, -1, 0))
    side_axis = (side_axis - fwd * side_axis.dot(fwd)).normalized()   # direção polegar (frente)
    normal = fwd.cross(side_axis).normalized() * s                    # para fora do corpo
    objs = []
    palm_len = 0.085
    palm = [wr + fwd * (palm_len * i / 7) for i in range(8)]

    def pr(t, i):
        w = 0.024 + 0.012 * sstep(0.0, 0.5, t)
        return (w, 0.012 + 0.002 * math.sin(t * math.pi))
    P = tube_points(palm, pr, 12)
    # orientar o achatamento: a largura deve ficar no eixo side_axis
    # (tube_points usa N/B do transporte; reorientamos rodando os anéis)
    _, T, N, B = frames_along(palm)
    for r in range(P.shape[0]):
        cen = Vector(palm[r])
        for k in range(P.shape[1]):
            d = Vector(P[r, k]) - cen
            a = d.dot(N[r])
            b = d.dot(B[r])
            ang = math.atan2(side_axis.dot(B[r]), side_axis.dot(N[r]))
            ca, sa = math.cos(ang), math.sin(ang)
            P[r, k] = tuple(cen + N[r] * (a * ca - b * sa) + B[r] * (a * sa + b * ca))
    objs.append(grid_object("Luva - palma " + side, P, glove, wrap=True, cap_top=True, cap_bot=True))
    # dedos
    base = wr + fwd * palm_len
    for i in range(4):
        off = (i - 1.5) * 0.0118
        root = base + side_axis * off - fwd * 0.004
        L = [0.050, 0.056, 0.053, 0.044][i]
        curl = 0.55 + 0.12 * i
        pts = []
        p = root.copy()
        d = fwd.copy()
        for k in range(10):
            pts.append(p.copy())
            ang = curl * (k / 9) * 0.5
            q = Quaternion(side_axis, -ang * s)
            d = (q @ fwd).normalized()
            p = p + d * (L / 9)
        rad = 0.0072 - 0.0005 * i
        objs.append(tube("Mão - dedo %s %d" % (side, i), pts,
                         lambda t, j, rad=rad: (rad * (1 - 0.25 * t), rad * 0.92 * (1 - 0.25 * t)), 8, skin))
        # anel da luva cobrindo a base do dedo
        objs.append(tube("Luva - dedo %s %d" % (side, i), pts[:4],
                         lambda t, j, rad=rad: (rad * 1.18, rad * 1.12), 8, glove))
    # polegar
    troot = wr + fwd * 0.022 + side_axis * 0.02
    tdir = (fwd * 0.6 + side_axis * 0.55 - normal * 0.25).normalized()
    pts = [troot + tdir * (0.05 * k / 8) + (fwd * 0.012) * (k / 8) ** 2 for k in range(9)]
    objs.append(tube("Mão - polegar " + side, pts, lambda t, j: (0.0085 * (1 - 0.2 * t), 0.008 * (1 - 0.2 * t)), 8, skin))
    objs.append(tube("Luva - polegar " + side, pts[:5], lambda t, j: (0.0102, 0.0096), 8, glove))
    return objs


# --------------------------------------------------------------------------------------
# Cabeça anime
# --------------------------------------------------------------------------------------
HEAD_TOP = 0.118
HEAD_BOT = -0.108
# Contorno do rosto medido em metros a partir do centro da cabeça (altura -> valor).
# Rosto oval anime: largura cheia até as maçãs do rosto, maxilar que só começa a curvar
# abaixo da boca e queixo pequeno e arredondado (nada de "V").
FACE_HALF_W = [  # meia-largura vista de frente
    (0.118, 0.0), (0.112, 0.036), (0.10, 0.061), (0.08, 0.083), (0.055, 0.0945), (0.03, 0.099),
    (0.0, 0.0985), (-0.02, 0.0962), (-0.04, 0.0905), (-0.055, 0.083), (-0.068, 0.0735),
    (-0.08, 0.0605), (-0.09, 0.045), (-0.097, 0.033), (-0.102, 0.0235), (-0.105, 0.0155),
    (-0.107, 0.0085), (-0.108, 0.0),
]
BACK_HALF_W = [  # meia-largura atrás das orelhas (desce para o pescoço)
    (0.118, 0.0), (0.112, 0.038), (0.10, 0.064), (0.08, 0.086), (0.055, 0.099), (0.03, 0.102),
    (0.0, 0.1), (-0.03, 0.093), (-0.06, 0.075), (-0.08, 0.058), (-0.095, 0.045), (-0.108, 0.03),
]
FRONT_DEPTH = [  # quanto o rosto avança (valor positivo = para frente, -Y)
    (0.118, 0.0), (0.112, 0.04), (0.10, 0.066), (0.08, 0.087), (0.05, 0.098), (0.02, 0.1),
    (0.0, 0.099), (-0.03, 0.098), (-0.055, 0.095), (-0.07, 0.092), (-0.085, 0.087),
    (-0.096, 0.08), (-0.103, 0.07), (-0.107, 0.058), (-0.108, 0.045),
]
BACK_DEPTH = [  # nuca
    (0.118, 0.0), (0.112, 0.05), (0.10, 0.082), (0.08, 0.102), (0.05, 0.114), (0.02, 0.118),
    (0.0, 0.117), (-0.03, 0.108), (-0.055, 0.088), (-0.075, 0.062), (-0.09, 0.035),
    (-0.1, 0.01), (-0.108, -0.02),
]


for _t in (FACE_HALF_W, BACK_HALF_W, FRONT_DEPTH, BACK_DEPTH):
    _t.sort(key=lambda r: r[0])


def head_deform(x, y, z):
    """Esfera unitária -> cabeça anime (metros, relativo ao centro da cabeça)."""
    Z = z * (HEAD_TOP if z > 0 else -HEAD_BOT)
    r = math.sqrt(max(1e-9, 1.0 - z * z))
    xn, yn = x / r, y / r            # direção no anel (cos/sen da longitude)
    wf = catmull(FACE_HALF_W, Z)[0]
    wb = catmull(BACK_HALF_W, Z)[0]
    W = wf if yn <= 0 else lerp(wf, wb, yn * yn)
    if yn <= 0:
        D = -catmull(FRONT_DEPTH, Z)[0]
        # bochechas cheias: seção em superelipse só na altura das bochechas
        n = 2.0 + 0.3 * sstep(0.05, 0.0, Z) * sstep(-0.1, -0.06, Z)
        e = 2.0 / n
        X = math.copysign(abs(xn) ** e, xn) * W
        Y = math.copysign(abs(yn) ** e, yn) * -D
    else:
        D = catmull(BACK_DEPTH, Z)[0]
        X = xn * W
        Y = yn * D
    X *= r if z > 0.985 or z < -0.985 else 1.0
    # nariz pequeno e lábios levemente projetados
    if yn < -0.6:
        gx = math.exp(-(X / 0.0065) ** 2)
        Y -= 0.0055 * gx * math.exp(-((Z + 0.03) / 0.014) ** 2)
        Y -= 0.0022 * math.exp(-(X / 0.016) ** 2) * math.exp(-((Z + 0.063) / 0.008) ** 2)
        # leve apoio do queixo
        Y -= 0.002 * math.exp(-(X / 0.02) ** 2) * math.exp(-((Z + 0.098) / 0.006) ** 2)
    return X, Y, Z


def build_head(skin_face_mat):
    cols, rows = 56, 40
    P = np.zeros((rows, cols, 3))
    c0 = J["head_c"]
    for r in range(rows):
        lat = math.pi / 2 - math.pi * (r + 1) / (rows + 1)
        for c in range(cols):
            lon = 2 * math.pi * c / cols
            x = math.cos(lat) * math.cos(lon)
            y = math.cos(lat) * math.sin(lon)
            z = math.sin(lat)
            X, Y, Z = head_deform(x, y, z)
            P[r, c] = (c0.x + X, c0.y + Y, c0.z + Z)

    def face_uv(P_, faces, uvs):
        verts = list(P_.reshape(-1, 3))
        verts.append(P_[0].mean(axis=0))
        verts.append(P_[-1].mean(axis=0))
        out = []
        for f in faces:
            q = []
            for vi in f:
                vi = min(vi, len(verts) - 1)
                vx, vy, vz = verts[vi]
                lx, ly, lz = vx - c0.x, vy - c0.y, vz - c0.z
                u = 0.5 + lx / FACE_W
                v = (lz - FACE_Z0) / FACE_H
                if ly > 0.035:
                    u = 0.5 + math.copysign(0.495, lx)   # borda lateral: só pele
                u = min(max(u, 0.003), 0.997)
                v = min(max(v, 0.003), 0.997)
                q.append((u * 0.5, 0.5 + v * 0.5))   # quadro 0 do atlas (cima-esquerda)
            out.append(q)
        return out
    return grid_object("Cabeça", P, skin_face_mat, wrap=True, cap_top=True, cap_bot=True, uv_override=face_uv)


# --------------------------------------------------------------------------------------
# Cabelo — cachos 3A em espiral (geometria), volume até a cintura
# --------------------------------------------------------------------------------------
CAP_R = (0.106, 0.113, 0.128, 0.104)  # rx, ry (trás), rz (topo), ry (frente) — superfície do couro cabeludo + cabelo
AXIS_Y = 0.02                         # eixo vertical do volume de cabelo (um pouco para trás)

ENV_BACK = [(0.06, 0.15), (0.0, 0.165), (-0.10, 0.19), (-0.20, 0.215), (-0.32, 0.222),
            (-0.44, 0.212), (-0.56, 0.19), (-0.66, 0.16)]
ENV_SIDE = [(0.06, 0.15), (0.0, 0.16), (-0.10, 0.185), (-0.20, 0.218), (-0.32, 0.218),
            (-0.44, 0.2), (-0.56, 0.18)]
ENV_FRONT = [(0.06, 0.14), (0.0, 0.15), (-0.10, 0.165), (-0.20, 0.188), (-0.30, 0.19),
             (-0.40, 0.17)]


def env_radius(zr, phi):
    a = abs(phi)
    b = catmull(ENV_BACK, -zr if False else zr) if False else None
    def tab(t):
        return catmull(sorted(t, key=lambda r: r[0]), zr)[0]
    rb, rs, rf = tab(ENV_BACK), tab(ENV_SIDE), tab(ENV_FRONT)
    if a <= math.pi / 2:
        return lerp(rb, rs, sstep(0.0, math.pi / 2, a))
    return lerp(rs, rf, sstep(math.pi / 2, math.pi * 0.8, a))


def cap_point(phi, el, lift=0.0):
    """Ponto na superfície do cabelo sobre o crânio. phi: 0=trás, ±pi/2 lados, ±pi frente."""
    rx, ryb, rz, ryf = CAP_R
    ry = ryb if math.cos(phi) > 0 else ryf
    dx, dy = math.sin(phi), math.cos(phi)
    rh = 1.0 / math.sqrt((dx / rx) ** 2 + (dy / ry) ** 2)
    ce, se = math.cos(el), math.sin(el)
    # normal aproximada
    n = Vector((dx * ce / rh, dy * ce / rh, se / rz)).normalized()
    p = Vector((dx * rh * ce, dy * rh * ce + AXIS_Y * 0.3, rz * se))
    return p + n * lift


def resample(pts, ds):
    pts = [Vector(p) for p in pts]
    out = [pts[0].copy()]
    acc = 0.0
    i = 0
    cur = pts[0].copy()
    while i < len(pts) - 1:
        seg = pts[i + 1] - cur
        L = seg.length
        if acc + L >= ds:
            t = (ds - acc) / L
            cur = cur + seg * t
            out.append(cur.copy())
            acc = 0.0
        else:
            acc += L
            cur = pts[i + 1].copy()
            i += 1
    if (out[-1] - pts[-1]).length > ds * 0.3:
        out.append(pts[-1].copy())
    return out


def smooth_path(pts, it=3):
    pts = [Vector(p) for p in pts]
    for _ in range(it):
        pts = [pts[0]] + [(pts[i - 1] + pts[i] * 2 + pts[i + 1]) / 4 for i in range(1, len(pts) - 1)] + [pts[-1]]
    return pts


def lock_path(phi0, el0, z_end, layer=1.0, lift=0.012, drift=0.0, rng=None):
    """Caminho do eixo de uma mecha: desce pelo crânio e cai seguindo o envelope de volume."""
    pts = []
    el = el0
    rx, ryb, rz, ryf = CAP_R
    # trecho sobre o crânio
    steps = max(2, int((el0 + 0.55) / 0.05))
    for k in range(steps + 1):
        e = el0 - (el0 + 0.55) * k / steps
        t = k / steps
        lf = lift + (layer * 0.03) * sstep(0.0, 1.0, t)
        p = cap_point(phi0, e, lf)
        z = p.z
        if z < 0.0:
            # começa a se afastar para o envelope
            R = math.hypot(p.x, p.y - AXIS_Y)
            Re = env_radius(z, phi0) * layer
            if Re > R:
                d = Vector((p.x, p.y - AXIS_Y, 0)).normalized()
                p = Vector((d.x * Re, AXIS_Y + d.y * Re, z))
        pts.append(p)
    # queda livre seguindo o envelope
    z = pts[-1].z
    phi = phi0
    while z > z_end:
        z -= 0.012
        depth = -z
        ph = phi0 + drift * sstep(0.05, 0.35, depth)
        R = env_radius(z, ph) * layer
        d = Vector((math.sin(ph), math.cos(ph), 0))
        pts.append(Vector((d.x * R, AXIS_Y + d.y * R, z)))
    return [face_clear(q, 0.03) for q in smooth_path(pts, 4)]


def face_clear(p, margin=0.0):
    """Afasta o cabelo da área do rosto de forma suave (coordenadas relativas ao centro da cabeça).
    A zona livre é só olhos, nariz e boca: as laterais do rosto ficam cobertas pelas mechas."""
    if p.y > 0.02:
        return p
    z = p.z
    if z > 0.01:
        lim = 0.083                                  # olhos (a asinha vai até ~0.08)
    elif z > -0.04:
        lim = lerp(0.083, 0.07, sstep(0.01, -0.04, z))
    else:
        lim = lerp(0.07, 0.05, sstep(-0.04, -0.11, z))
    w = sstep(0.07, 0.045, z) * sstep(-0.16, -0.11, z) * sstep(0.02, -0.03, p.y)
    if w <= 0.0:
        return p
    lim = (lim + margin) * w
    soft = 0.008
    ax = abs(p.x)
    k = (ax - lim) / soft
    nx = lim + soft * (math.log1p(math.exp(k)) if k < 30 else k)
    return Vector((math.copysign(nx, p.x if p.x != 0 else 1.0), p.y, p.z))


def coil_lock(name, path, mat, rt=0.012, rc=0.016, pitch=0.05, sides=None, spt=None, phase=0.0,
              root_relax=0.07, tip_curl=True, flat_root=False):
    """Mecha cacheada: tubo que espirala em volta do eixo (cachinho de verdade)."""
    sides = sides or HAIR_SIDES
    spt = spt or HAIR_SPT
    path = resample(path, pitch / spt)
    if len(path) < 4:
        return None
    pts, T, N, B = frames_along(path)
    n = len(pts)
    total = (n - 1) * pitch / spt
    center = []
    for i in range(n):
        s = i * pitch / spt
        k = sstep(0.0, root_relax, s)
        tip = s / max(total, 1e-6)
        r = rc * (0.25 + 0.75 * k) * (1.0 - 0.35 * sstep(0.85, 1.0, tip))
        a = 2 * math.pi * s / pitch + phase
        center.append(face_clear(pts[i] + N[i] * (math.cos(a) * r) + B[i] * (math.sin(a) * r), rt * 0.8))

    def rfn(t, i):
        root = 0.75 + 0.25 * sstep(0.0, 0.08, t)
        tipf = 1.0 - 0.72 * sstep(0.72, 1.0, t)
        r = rt * root * tipf
        return (r, r * 0.86)
    return tube(name, center, rfn, sides, mat, cap_a=True, cap_b=True)


HAIR_SIDES = 6
HAIR_SPT = 8


def build_hair(mats, quality=1.0):
    """mats: lista [escuro, base, claro] — variação por mecha dá profundidade."""
    rng = random.Random(SEED)
    c0 = J["head_c"]
    objs = []

    def place(ob):
        if ob is None:
            return
        ob.location = c0
        objs.append(ob)

    # couro cabeludo / base: casca sobre o crânio (fora do rosto)
    cols, rows = 48, 26
    P = np.zeros((rows, cols, 3))
    for r in range(rows):
        el = math.pi / 2 - (math.pi / 2 + 0.75) * (r + 0.5) / rows
        for c in range(cols):
            phi = 2 * math.pi * c / cols
            # anti-horário visto de cima: x=sin(phi) y=cos(phi) gira horário -> invertemos phi
            p = cap_point(-phi + math.pi / 2, el, -0.006)
            P[r, c] = tuple(p)
    cap = grid_object("Cabelo - base", P, mats[0], wrap=True, cap_top=True)
    # remove a parte do rosto da base
    bm = bmesh.new()
    bm.from_mesh(cap.data)
    kill = []
    for f in bm.faces:
        cen = f.calc_center_median()
        phi = math.atan2(cen.x, cen.y - AXIS_Y * 0.3)
        a = abs(phi)
        if a > math.radians(80):
            hl = lerp(-0.09, 0.035, sstep(math.radians(80), math.radians(108), a))
            hl = lerp(hl, 0.072, sstep(math.radians(120), math.radians(170), a))
            if cen.z < hl:
                kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context='FACES')
    bm.to_mesh(cap.data)
    bm.free()
    cap.data.materials.append(mats[0]) if not cap.data.materials else None
    place(cap)

    def pick_mat():
        r = rng.random()
        return mats[1] if r < 0.55 else (mats[2] if r < 0.8 else mats[0])

    count = 0

    def lock(phi, el, z_end, layer, **kw):
        nonlocal count
        drift = kw.pop("drift", 0.0)
        lift = kw.pop("lift", 0.012)
        path = lock_path(phi, el, z_end, layer=layer, lift=lift, drift=drift)
        ob = coil_lock("Cabelo - cacho %03d" % count, path, kw.pop("mat", pick_mat()),
                       phase=rng.uniform(0, 6.28), **kw)
        count += 1
        place(ob)

    # volume interno: casca escura atrás (evita buracos entre os cachos)
    rows_i, cols_i = 22, 30
    P = np.zeros((rows_i, cols_i, 3))
    for r in range(rows_i):
        z = lerp(0.02, -0.56, r / (rows_i - 1))
        for c in range(cols_i):
            phi = lerp(1.6, -1.6, c / (cols_i - 1))
            R = env_radius(z, phi) * 0.8
            if z > -0.06:
                R = max(R, math.hypot(*cap_point(phi, math.asin(max(-1, min(1, z / CAP_R[2]))), -0.004).xy) - 0.0)
            P[r, c] = (math.sin(phi) * R, AXIS_Y + math.cos(phi) * R, z)
    shell = grid_object("Cabelo - volume interno", P, mats[0], wrap=False)
    add_solidify(shell, 0.03, 0.0)
    place(shell)
    n_in = int(12 * quality)
    for i in range(n_in):
        phi = lerp(-1.7, 1.7, (i + rng.random() * 0.6) / n_in)
        z_end = -0.5 - 0.08 * math.cos(phi) + rng.uniform(-0.03, 0.03)
        lock(phi, rng.uniform(0.2, 0.9), z_end, 0.9, rt=0.02, rc=0.018, pitch=0.07,
             spt=max(5, HAIR_SPT - 1), mat=mats[0], drift=-0.25 * phi)
    # camada externa — costas e laterais (menos mechas = mechas mais grossas)
    thick = min(1.4, max(1.0, (1.0 / max(quality, 0.3)) ** 0.5))
    n_out = int(64 * quality)
    for i in range(n_out):
        phi = lerp(-1.9, 1.9, (i + rng.random()) / n_out)
        a = abs(phi)
        el = rng.uniform(0.1, 0.7)
        z_end = lerp(-0.62, -0.42, sstep(0.3, 2.0, a)) + rng.uniform(-0.05, 0.04)
        layer = rng.uniform(0.94, 1.06)
        lock(phi, el, z_end, layer, rt=rng.uniform(0.011, 0.015) * thick, rc=rng.uniform(0.014, 0.02) * thick,
             pitch=rng.uniform(0.045, 0.06), drift=-0.18 * phi * sstep(1.2, 1.9, a))
    # mechas da frente (caem na frente dos ombros, até o peito)
    for side in (-1, 1):
        for j in range(5):
            phi = side * (1.78 + 0.04 * j + rng.uniform(-0.03, 0.03))
            z_end = -0.27 - 0.04 * j + rng.uniform(-0.03, 0.03)
            lock(phi, rng.uniform(0.95, 1.2), z_end, rng.uniform(0.98, 1.05),
                 rt=rng.uniform(0.010, 0.013), rc=0.015, pitch=0.048, drift=side * (0.35 + 0.06 * j))
    # topo: cachinhos curtos que quebram a silhueta da cabeça
    n_top = int(22 * quality)
    for i in range(n_top):
        phi = rng.uniform(-math.pi, math.pi)
        el = rng.uniform(0.75, 1.35) if abs(phi) < 2.0 else rng.uniform(1.05, 1.4)
        p0 = cap_point(phi, el, 0.006)
        p1 = cap_point(phi, el - 0.5, 0.018)
        path = smooth_path(bezier(p0, p0 + (p1 - p0) * 0.3 + Vector((0, 0, 0.02)), p1, p1 + Vector((0, 0, -0.02)), 12), 1)
        ob = coil_lock("Cabelo - topo %03d" % i, path, pick_mat(), rt=0.011, rc=0.014, pitch=0.042,
                       phase=rng.uniform(0, 6.28), root_relax=0.03)
        place(ob)
    # franja: cachos que caem sobre a testa e emolduram o rosto
    bangs = [
        # (phi raiz, el raiz, ponto final (x, y, z) relativo ao centro da cabeça)
        (math.pi - 0.12, 1.15, (-0.05, -0.106, 0.085)),
        (-math.pi + 0.3, 1.1, (0.02, -0.112, 0.09)),
        (math.pi - 0.5, 1.0, (-0.085, -0.088, 0.065)),
        (-math.pi + 0.6, 1.0, (0.085, -0.086, 0.06)),
        (math.pi - 0.85, 0.85, (-0.128, -0.035, -0.03)),
        (-math.pi + 0.9, 0.85, (0.13, -0.033, -0.025)),
        (math.pi - 1.25, 0.7, (-0.15, 0.0, -0.14)),
        (-math.pi + 1.3, 0.7, (0.152, 0.0, -0.15)),
        (math.pi - 1.4, 0.6, (-0.162, 0.02, -0.22)),
        (-math.pi + 1.45, 0.6, (0.165, 0.02, -0.23)),
    ]
    for k in range(7):
        x_end = lerp(-0.07, 0.07, k / 6) + rng.uniform(-0.008, 0.008)
        z_end = 0.072 + rng.uniform(0.0, 0.016) + 0.012 * (abs(x_end) / 0.07)
        phi = math.pi - lerp(-0.55, 0.55, k / 6) * 0.9
        phi = (phi + math.pi) % (2 * math.pi) - math.pi
        bangs.append((phi, 1.25 + rng.uniform(-0.08, 0.08), (x_end, -0.108 + 0.25 * x_end * x_end, z_end)))
    # mechas laterais rentes ao rosto (cobrem têmporas e a lateral das bochechas)
    for side in (-1, 1):
        for j, (dy, z_end, dx) in enumerate(((-0.058, -0.19, 0.0), (-0.036, -0.24, 0.012), (-0.012, -0.28, 0.024))):
            root = cap_point(side * (math.pi - 0.95 - 0.12 * j), 0.62 + 0.05 * j, 0.008)
            top = Vector((side * (0.091 + dx * 0.5), dy, 0.03))
            mid = Vector((side * (0.093 + dx), dy + 0.004, -0.08))
            end = Vector((side * (0.1 + dx), dy + 0.01, z_end))
            path = [face_clear(q, 0.012) for q in bezier(root, top, mid, end, 28)]
            ob = coil_lock("Cabelo - lateral %d %d" % (side, j), path, mats[1 if j != 1 else 2],
                           rt=0.0105, rc=0.011, pitch=0.04, phase=rng.uniform(0, 6.28), root_relax=0.05)
            place(ob)
    for i, (phi, el, end) in enumerate(bangs):
        p0 = cap_point(phi, el, 0.01)
        end = Vector(end)
        mid = cap_point(phi, el - 0.45, 0.035)
        ctrl1 = p0 + (mid - p0) * 0.8 + Vector((0, -0.02, 0.012))
        ctrl2 = end + Vector((end.x * 0.3, -0.015, 0.05))
        path = [face_clear(q, 0.024) for q in bezier(p0, ctrl1, ctrl2, end, 24)]
        ob = coil_lock("Cabelo - franja %02d" % i, path, mats[1 if i % 3 else 2],
                       rt=0.011 if i < 10 else 0.0095, rc=0.011 if (i < 4 or i >= 10) else 0.013,
                       pitch=0.04 if i < 10 else 0.034, phase=rng.uniform(0, 6.28),
                       root_relax=0.04)
        place(ob)
    return objs


# --------------------------------------------------------------------------------------
# Roupa
# --------------------------------------------------------------------------------------
def ang_front(th):
    """Ângulo em relação à frente (-Y) em [-pi, pi]; th é o ângulo da grade (x=cos, y=sin)."""
    a = th + math.pi / 2
    return (a + math.pi) % (2 * math.pi) - math.pi


def merge_close(ob, dist=1e-5):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=dist)
    bm.to_mesh(ob.data)
    bm.free()


def delete_faces(ob, pred):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    kill = [f for f in bm.faces if pred(f.calc_center_median())]
    bmesh.ops.delete(bm, geom=kill, context='FACES')
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


def neck_open(z):
    """Meia-abertura do decote em V (rad) em função da altura."""
    return 0.62 * sstep(1.232, 1.345, z) ** 0.8


def build_bodice(mat, trim):
    """Vestido (parte de cima): segue o tronco, decote em V limpo."""
    rows, cols = 34, 40
    zs = np.linspace(1.345, 0.95, rows)
    P = np.zeros((rows, cols + 1, 3))
    for r, z in enumerate(zs):
        op = neck_open(z)
        for c in range(cols + 1):
            af = lerp(op, 2 * math.pi - op, c / cols)
            x, y = torso_shape(z, af - math.pi / 2, 0.0075)
            P[r, c] = (x, y, z)
    ob = grid_object("Vestido - corpo", P, mat, wrap=False, metric=True)
    merge_close(ob)
    objs = [ob]
    for sgn in (1, -1):
        E = np.zeros((10, 3, 3))
        for r, z in enumerate(np.linspace(1.345, 1.236, 10)):
            op = neck_open(z)
            for k, da in enumerate((0.0, 0.06, 0.12)):
                x, y = torso_shape(z, sgn * (op + da) - math.pi / 2, 0.0105)
                E[r, k] = (x, y, z)
        if sgn < 0:
            E = E[:, ::-1]
        objs.append(grid_object("Bordado - decote %d" % sgn, E, trim, wrap=False))
    return objs


def arm_point(side, t):
    path = limb_path([J["shoulder" + side], J["elbow" + side], J["wrist" + side]], 60)
    i = min(int(t * 59), 59)
    return path[i]


def build_sleeve(side, cloth, trim):
    sh = J["shoulder" + side]
    el = J["elbow" + side]
    start = sh + (sh - el).normalized() * 0.035 + Vector((-0.03 if side == "L" else 0.03, 0, 0.01))
    path = limb_path([start, sh, el, J["wrist" + side]], 40)[:25]

    def rfn(t, i):
        tt = t * 0.5
        rx, ry = catmull(ARM_R, max(0.0, tt))
        puff = 0.012 + 0.01 * math.sin(min(t, 1.0) * math.pi) - 0.004 * t
        return rx + puff, ry + puff
    ob = tube("Vestido - manga " + side, path, rfn, 18, cloth, cap_a=False, cap_b=False, metric=True)
    add_solidify(ob, 0.004)
    # barra bordada
    end = path[-3:]
    band = limb_path([path[-4], path[-1]], 4)

    def rb(t, i):
        rx, ry = catmull(ARM_R, 0.5)
        return rx + 0.017, ry + 0.017
    b = tube("Bordado - manga " + side, band, rb, 18, trim, cap_a=False, cap_b=False)
    set_band_uv(b, 0.36)
    return [ob, b]


def set_band_uv(ob, length_m):
    """UV de faixa: u ao redor (repete a cada 0.1 m), v atravessa a faixa."""
    me = ob.data
    uvl = me.uv_layers.active or me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        for li in poly.loop_indices:
            u, v = uvl.data[li].uv
            uvl.data[li].uv = (u * length_m / 0.8, v)


def build_bracer(side, leather, dark, bronze):
    path = limb_path([J["shoulder" + side], J["elbow" + side], J["wrist" + side]], 60)
    seg = path[36:60]
    seg.append(seg[-1] + (seg[-1] - seg[-2]).normalized() * 0.012)

    def rfn(t, i):
        tt = 0.6 + 0.4 * t
        rx, ry = catmull(ARM_R, min(tt, 1.0))
        flare = 0.007 + 0.006 * (1 - t)
        return rx + flare, ry + flare
    ob = tube("Braçadeira " + side, seg, rfn, 16, leather, cap_a=False, cap_b=False, metric=True)
    add_solidify(ob, 0.003)
    objs = [ob]
    for k, tt in enumerate((0.3, 0.75)):
        i = int(tt * (len(seg) - 1))
        band = [seg[max(i - 1, 0)], seg[i], seg[min(i + 1, len(seg) - 1)]]

        def rb(t, j, tt=tt):
            rx, ry = catmull(ARM_R, 0.6 + 0.4 * tt)
            return rx + 0.0125, ry + 0.0125
        objs.append(tube("Braçadeira - tira %s %d" % (side, k), band, rb, 16, dark, cap_a=False, cap_b=False))
        # fivela
        _, T, N, B = frames_along(band)
        s = 1 if side == "L" else -1
        out = Vector((s, -0.4, 0)).normalized()
        out = (out - T[1] * out.dot(T[1])).normalized()
        rx, ry = catmull(ARM_R, 0.6 + 0.4 * tt)
        objs.append(box("Braçadeira - fivela %s %d" % (side, k), band[1] + out * (rx + 0.014), T[1], out,
                        (0.014, 0.018, 0.004), bronze))
    return objs


def box(name, center, up, out, size, mat, bevel=0.0015):
    """Caixa orientada: up (altura), out (frente/normal), size=(largura, altura, profundidade)."""
    up = Vector(up).normalized()
    out = (Vector(out) - up * Vector(out).dot(up)).normalized()
    right = up.cross(out).normalized()
    w, h, d = [x / 2 for x in size]
    verts, faces = [], []
    for sz in (-1, 1):
        for sy in (-1, 1):
            for sx in (-1, 1):
                verts.append(Vector(center) + right * (sx * w) + up * (sy * h) + out * (sz * d))
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    ob = mesh_object(name, verts, faces, None, mat, smooth=False)
    # normais para fora
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, affect='EDGES')
    bm.to_mesh(ob.data)
    bm.free()
    uvl = ob.data.uv_layers.new(name="UVMap")
    for poly in ob.data.polygons:
        for k, li in enumerate(poly.loop_indices):
            uvl.data[li].uv = ((k in (1, 2)) * 1.0, (k in (2, 3)) * 1.0)
    return ob


# ---- saia -------------------------------------------------------------------------------
SKIRT_TOP = 1.0


def skirt_hem(af, front=0.565, side=0.47, back=0.365):
    k = (1 - math.cos(af)) / 2          # 0 frente, 1 trás
    if k < 0.5:
        return lerp(front, side, sstep(0.0, 0.5, k) ** 0.9)
    return lerp(side, back, sstep(0.5, 1.0, k))


def skirt_point(t, af, hem_fn, inflate=0.0, folds=1.0, flare=1.0):
    """t: 0 cintura -> 1 barra; af: ângulo a partir da frente."""
    th = af - math.pi / 2
    zh = hem_fn(af)
    z = lerp(SKIRT_TOP, zh, t)
    # raio do cone da saia
    drop = SKIRT_TOP - z
    cx = (0.150 + 0.30 * drop ** 1.05 * flare) if drop > 0 else 0.15
    cy = (0.112 + 0.22 * drop ** 1.05 * flare) if drop > 0 else 0.11
    # pregas
    amp = 0.016 * folds * sstep(0.08, 0.5, drop)
    r_mod = 1.0 + amp / 0.2 * (math.sin(9 * th + 0.6 * math.sin(3 * th)) * 0.8 + 0.2 * math.sin(17 * th))
    x, y = math.cos(th) * cx * r_mod, math.sin(th) * cy * r_mod
    # nunca dentro do quadril
    if z > 0.775:
        tx, ty = torso_shape(z, th, 0.016 + inflate)
        tr = math.hypot(tx, ty)
        cr = math.hypot(x, y)
        if cr < tr:
            x, y = tx, ty
    rr = math.hypot(x, y)
    if rr > 1e-6:
        x += x / rr * inflate
        y += y / rr * inflate
    return (x, y + 0.008 * sstep(0.0, 0.5, drop), z)


def split_angle(t):
    return 0.34 * sstep(0.18, 1.0, t) ** 0.85


def build_skirt(cloth, under, trim):
    objs = []
    rows, cols = 26, 60
    hem = skirt_hem
    P = np.zeros((rows, cols + 1, 3))
    for r in range(rows):
        t = r / (rows - 1)
        sp = split_angle(t)
        for c in range(cols + 1):
            af = lerp(sp, 2 * math.pi - sp, c / cols)
            af = (af + math.pi) % (2 * math.pi) - math.pi
            P[r, c] = skirt_point(t, af, hem)
    sk = grid_object("Saia - externa", P, cloth, wrap=False, metric=True)
    add_solidify(sk, 0.005)
    objs.append(sk)
    # bordado da barra e das bordas da abertura
    hp = np.zeros((3, cols + 1, 3))
    for r, t in enumerate((0.955, 0.978, 1.0)):
        sp = split_angle(t)
        for c in range(cols + 1):
            af = lerp(sp, 2 * math.pi - sp, c / cols)
            af = (af + math.pi) % (2 * math.pi) - math.pi
            hp[r, c] = skirt_point(t, af, hem, inflate=0.0035)
    b = grid_object("Bordado - barra da saia", hp, trim, wrap=False)
    set_band_uv(b, 1.9)
    objs.append(b)
    for sgn in (1, -1):
        ep = np.zeros((rows - 4, 3, 3))
        for r in range(4, rows):
            t = r / (rows - 1)
            sp = split_angle(t)
            for k, da in enumerate((0.0, 0.05, 0.1)):
                af = sgn * (sp + da)
                ep[r - 4, k] = skirt_point(t, af, hem, inflate=0.0035)
        if sgn < 0:
            ep = ep[:, ::-1]
        b = grid_object("Bordado - abertura %d" % sgn, ep, trim, wrap=False)
        objs.append(b)
    # segunda faixa bordada, mais fina, acima da barra
    hp2 = np.zeros((2, cols + 1, 3))
    for r, t in enumerate((0.875, 0.892)):
        sp = split_angle(t)
        for c in range(cols + 1):
            af = lerp(sp + 0.1, 2 * math.pi - sp - 0.1, c / cols)
            af = (af + math.pi) % (2 * math.pi) - math.pi
            hp2[r, c] = skirt_point(t, af, hem, inflate=0.0035)
    b2 = grid_object("Bordado - faixa da saia", hp2, trim, wrap=False)
    set_band_uv(b2, 1.9)
    objs.append(b2)
    # anágua / saia de baixo
    rows2, cols2 = 16, 48
    P2 = np.zeros((rows2, cols2, 3))

    def hem2(af):
        return skirt_hem(af, 0.70, 0.56, 0.47)
    for r in range(rows2):
        t = r / (rows2 - 1)
        for c in range(cols2):
            af = 2 * math.pi * c / cols2 - math.pi / 2
            th = 2 * math.pi * c / cols2
            P2[r, c] = skirt_point(t, ang_front(th), hem2, inflate=-0.006, folds=0.5, flare=0.85)
    us = grid_object("Saia - interna", P2, under, wrap=True, metric=True)
    add_solidify(us, 0.004)
    objs.append(us)
    return objs


def build_corset(leather, dark, bronze):
    objs = []
    rows, cols = 16, 44
    P = np.zeros((rows, cols, 3))
    for r in range(rows):
        t = r / (rows - 1)
        for c in range(cols):
            th = 2 * math.pi * c / cols
            af = abs(ang_front(th))
            ztop = lerp(1.135, 1.168, sstep(0.0, 1.2, af))
            zbot = lerp(0.965, 0.995, sstep(0.0, 0.8, af))
            z = lerp(ztop, zbot, t)
            x, y = torso_shape(z, th, 0.019)
            P[r, c] = (x, y, z)
    ob = grid_object("Corpete", P, leather, wrap=True, metric=True)
    add_solidify(ob, 0.004)
    objs.append(ob)
    # duas tiras com fivelas na frente
    for k, zc in enumerate((1.115, 1.03)):
        rows2 = 3
        Q = np.zeros((rows2, cols, 3))
        for r in range(rows2):
            z = zc + 0.013 - 0.026 * r / (rows2 - 1)
            for c in range(cols):
                th = 2 * math.pi * c / cols
                x, y = torso_shape(z, th, 0.026)
                Q[r, c] = (x, y, z)
        objs.append(grid_object("Corpete - tira %d" % k, Q, dark, wrap=True))
        fx, fy = torso_shape(zc, -math.pi / 2 + 0.25, 0.03)
        objs.append(box("Corpete - fivela %d" % k, (fx, fy, zc), (0, 0, 1), (0.25, -1, 0), (0.03, 0.034, 0.006), bronze))
        objs.append(box("Corpete - passador %d" % k, (fx - 0.004, fy - 0.004, zc), (0, 0, 1), (0.25, -1, 0), (0.016, 0.02, 0.008), dark))
    # amarração cruzada na frente do corpete (ilhoses de bronze + cordão)
    lace = []
    zs = np.linspace(1.105, 1.0, 7)
    for k, z in enumerate(zs):
        for sgn in ((-1, 1) if k % 2 == 0 else (1, -1)):
            th = -math.pi / 2 + sgn * 0.085
            x, y = torso_shape(z, th, 0.0245)
            lace.append(Vector((x, y, z)))
            objs.append(box("Corpete - ilhós", (x, y, z), (0, 0, 1), (x * 0.3, -1, 0), (0.007, 0.007, 0.004), bronze, 0.0012))
    objs.append(tube("Corpete - cordão", smooth_path(lace, 1), lambda t, i: (0.0024, 0.0024), 6, dark))
    # rebites nas tiras
    for zc in (1.115, 1.03):
        for th in np.linspace(-math.pi / 2 - 1.1, -math.pi / 2 + 1.1, 9):
            if abs(th + math.pi / 2 - 0.25) < 0.12:
                continue
            x, y = torso_shape(zc, th, 0.028)
            objs.append(box("Corpete - rebite", (x, y, zc), (0, 0, 1), (x, y, 0), (0.006, 0.006, 0.004), bronze, 0.0015))
    # cinto baixo, inclinado sobre o quadril (por cima da saia)
    cols3 = 56
    Q = np.zeros((3, cols3, 3))
    for r in range(3):
        for c in range(cols3):
            th = 2 * math.pi * c / cols3
            zc = 0.915 + 0.03 * math.cos(th)          # mais alto do lado esquerdo
            z = zc + 0.016 - 0.032 * r / 2
            x, y = torso_shape(z, th, 0.034)
            Q[r, c] = (x, y, z)
    objs.append(grid_object("Cinto do quadril", Q, leather, wrap=True, metric=True))
    th = -math.pi / 2 + 0.15
    zc = 0.915 + 0.03 * math.cos(th)
    fx, fy = torso_shape(zc, th, 0.038)
    objs.append(box("Cinto - fivela", (fx, fy, zc), (0, 0, 1), (0.12, -1, 0), (0.042, 0.042, 0.007), bronze))
    objs.append(box("Cinto - fivela centro", (fx, fy - 0.004, zc), (0, 0, 1), (0.12, -1, 0), (0.026, 0.026, 0.008), dark))
    # bolsas: grande no lado direito (−x), pequena atrás à esquerda
    for name, th, size, drop in (("Bolsa grande", math.pi + 0.62, (0.092, 0.105, 0.05), 0.065),
                                 ("Bolsa pequena", 0.35, (0.06, 0.07, 0.04), 0.045)):
        zc = 0.915 + 0.03 * math.cos(th) - drop
        x, y = torso_shape(zc, th, 0.06 + size[2] / 2)
        n = Vector((x, y, 0)).normalized()
        objs.append(box(name, (x, y, zc), (0, 0, 1), n, size, leather, bevel=0.008))
        objs.append(box(name + " - tampa", Vector((x, y, zc)) + n * (size[2] / 2 + 0.002) + Vector((0, 0, size[1] * 0.22)),
                        (0, 0, 1), n, (size[0] * 1.04, size[1] * 0.5, 0.008), dark, bevel=0.003))
        objs.append(box(name + " - fecho", Vector((x, y, zc)) + n * (size[2] / 2 + 0.008) + Vector((0, 0, size[1] * 0.02)),
                        (0, 0, 1), n, (0.014, 0.02, 0.005), bronze))
    return objs


# ---- capa curta com capuz -------------------------------------------------------------
def cape_point(t, th, inflate=0.0):
    """Capa: t=0 gola -> t=1 barra. Domo sobre os ombros."""
    af = ang_front(th)
    k = (1 - math.cos(af)) / 2              # 0 frente, 1 trás
    z0 = 1.372 - 0.008 * (1 - k)
    zh = lerp(1.165, 1.13, k) - 0.03 * math.exp(-(af / 0.35) ** 2)   # ponta na frente
    side = abs(math.cos(th))                 # 1 nos lados
    zh += 0.02 * side
    z = lerp(z0, zh, t ** 1.25)
    # raio: gola justa -> ombros -> barra aberta
    r_neck = (0.068, 0.064)
    r_sh = (0.205, 0.128)
    r_hem = (0.255, 0.17)
    s1 = math.sin(min(t, 1.0) * math.pi / 2) ** 0.7
    if t < 0.55:
        u = t / 0.55
        rx = lerp(r_neck[0], r_sh[0], u ** 0.7)
        ry = lerp(r_neck[1], r_sh[1], u ** 0.7)
    else:
        u = (t - 0.55) / 0.45
        rx = lerp(r_sh[0], r_hem[0], u)
        ry = lerp(r_sh[1], r_hem[1], u)
    # dobras suaves
    amp = 0.007 * sstep(0.4, 1.0, t)
    m = 1.0 + amp / 0.2 * math.sin(7 * th + 1.3)
    x = math.cos(th) * (rx + inflate) * m
    y = math.sin(th) * (ry + inflate) * m + 0.012
    # nunca dentro do corpo
    if z > 1.0:
        tx, ty = torso_shape(z, th, 0.035 + inflate)
        if math.hypot(x, y - 0.012) < math.hypot(tx, ty):
            x, y = tx, ty
    return (x, y, z)


def cape_open(t):
    """Meia-abertura da frente da capa (rad): decote em V que abre até as axilas."""
    return 0.22 + 0.95 * t ** 1.15


def build_capelet(cloth, trim, bronze):
    objs = []
    rows, cols = 18, 56
    P = np.zeros((rows, cols + 1, 3))
    for r in range(rows):
        t = r / (rows - 1)
        op = cape_open(t)
        for c in range(cols + 1):
            af = lerp(op, 2 * math.pi - op, c / cols)
            P[r, c] = cape_point(t, af - math.pi / 2)
    ob = grid_object("Capa", P, cloth, wrap=False, metric=True)
    add_solidify(ob, 0.006)
    objs.append(ob)
    # bordado: barra + bordas da frente
    Q = np.zeros((3, cols + 1, 3))
    for r, t in enumerate((0.9, 0.95, 1.0)):
        op = cape_open(t)
        for c in range(cols + 1):
            af = lerp(op, 2 * math.pi - op, c / cols)
            Q[r, c] = cape_point(t, af - math.pi / 2, inflate=0.004)
    b = grid_object("Bordado - capa", Q, trim, wrap=False)
    set_band_uv(b, 1.4)
    objs.append(b)
    for sgn in (1, -1):
        E = np.zeros((rows - 2, 3, 3))
        for r in range(1, rows - 1):
            t = r / (rows - 1)
            op = cape_open(t)
            for k, da in enumerate((0.0, 0.07, 0.14)):
                E[r - 1, k] = cape_point(t, sgn * (op + da) - math.pi / 2, inflate=0.004)
        if sgn < 0:
            E = E[:, ::-1]
        objs.append(grid_object("Bordado - capa frente %d" % sgn, E, trim, wrap=False))
    # capuz caído: rolo grosso em volta da nuca + bolsa do capuz nas costas
    pts = []
    for i in range(29):
        a = lerp(-0.95, 0.95, i / 28) * math.pi * 0.62     # ao redor por trás
        th = math.pi / 2 + a
        r_x, r_y = 0.085, 0.075
        z = 1.39 - 0.03 * (abs(a) / (math.pi * 0.6)) ** 2
        pts.append(Vector((math.cos(th) * r_x, math.sin(th) * r_y + 0.02, z)))

    def rr(t, i):
        mid = math.sin(t * math.pi)
        return (0.018 + 0.028 * mid, 0.014 + 0.016 * mid)
    hood = tube("Capuz - dobra", pts, rr, 14, cloth, metric=True)
    objs.append(hood)
    # bolsa do capuz (pendurada nas costas)
    rows3, cols3 = 12, 20
    H = np.zeros((rows3, cols3, 3))
    for r in range(rows3):
        t = r / (rows3 - 1)
        for c in range(cols3):
            th = 2 * math.pi * c / cols3
            w = 0.11 * math.sin(math.pi * (0.15 + 0.85 * t)) ** 0.6 + 0.02
            d = 0.03 + 0.02 * math.sin(math.pi * t)
            z = lerp(1.385, 1.2, t)
            y = 0.125 + 0.03 * math.sin(math.pi * t) + 0.02 * t
            H[r, c] = (math.cos(th) * w, y + math.sin(th) * d, z)
    objs.append(grid_object("Capuz - costas", H, cloth, wrap=True, cap_bot=True, metric=True))
    # broche de folha na gola
    leaf = []
    for i in range(9):
        t = i / 8
        leaf.append(Vector((0.0, -0.066 - 0.004 * math.sin(t * math.pi), 1.36 - 0.035 * t)))
    objs.append(tube("Broche de folha", leaf, lambda t, i: (0.011 * math.sin(math.pi * min(0.98, 0.1 + t)) + 0.002, 0.004), 8, bronze))
    return objs


# ---- botas ------------------------------------------------------------------------------
def build_boot(side, leather, dark, sole_m, lace_m, bronze):
    objs = []
    s = 1 if side == "L" else -1
    leg = limb_path([J["hip" + side] + Vector((-s * 0.004, 0.0, 0.07)), J["knee" + side], J["ankle" + side]], 34)
    shaft = leg[19:]          # abaixo do joelho até o tornozelo

    def rfn(t, i):
        tt = 19 / 33 + t * (14 / 33)
        rx, ry = catmull(LEG_R, tt)
        top = 0.012 * (1 - sstep(0.0, 0.15, t))
        return rx + 0.011 + top, ry + 0.012 + top
    ob = tube("Bota - cano " + side, shaft, rfn, 20, leather, cap_a=False, cap_b=False, metric=True)
    objs.append(ob)
    # punho dobrado no topo + tira com fivela
    cuff = shaft[:4]

    def rc(t, i):
        rx, ry = catmull(LEG_R, 19 / 33)
        return rx + 0.02, ry + 0.021
    objs.append(tube("Bota - punho " + side, cuff, rc, 20, dark, cap_a=False, cap_b=False))
    i = 9
    band = shaft[i - 1:i + 2]

    def rb(t, j):
        rx, ry = catmull(LEG_R, (19 + i) / 33)
        return rx + 0.017, ry + 0.018
    objs.append(tube("Bota - tira " + side, band, rb, 20, dark, cap_a=False, cap_b=False))
    rx, ry = catmull(LEG_R, (19 + i) / 33)
    objs.append(box("Bota - fivela " + side, Vector(band[1]) + Vector((s * (rx + 0.016) * 0.7, -(ry + 0.017) * 0.7, 0)),
                    (0, 0, 1), (s * 0.7, -0.7, 0), (0.016, 0.02, 0.005), bronze))
    # pé: do calcanhar à ponta
    an = J["ankle" + side]
    toe = J["toe_end" + side]
    heel = Vector((an.x, an.y + 0.05, 0.05))
    foot = [heel + (Vector((toe.x, toe.y, 0.045)) - heel) * (k / 15) for k in range(16)]

    def fr(t, i):
        w = 0.031 + 0.01 * math.sin(min(1.0, t * 1.25) * math.pi * 0.5) - 0.02 * sstep(0.75, 1.0, t)
        h = 0.044 * (1 - t) ** 0.6 + 0.019
        return (h, w)          # (vertical, largura): N do transporte aponta para cima

    def prof(t, th, cx, cy):
        # base achatada (sola) e topo arredondado subindo para o tornozelo
        if cx < 0:
            cx *= 0.45
        else:
            cx += 0.035 * (1 - sstep(0.0, 0.45, t))
        return cx, cy
    P = tube_points(foot, fr, 20, profile=prof)
    # garantir orientação: N do transporte aponta para cima?
    objs.append(grid_object("Bota - pé " + side, P, leather, wrap=True, cap_top=True, cap_bot=True, metric=True))
    # sola
    sole = [heel + Vector((0, 0.005, -0.03)) + (Vector((toe.x, toe.y - 0.006, 0.02)) - heel - Vector((0, 0.005, -0.03))) * (k / 15) for k in range(16)]
    sole = [Vector((p.x, p.y, 0.012)) for p in sole]

    def sr(t, i):
        w = 0.035 + 0.01 * math.sin(min(1.0, t * 1.25) * math.pi * 0.5) - 0.02 * sstep(0.78, 1.0, t)
        return (0.009, w)
    objs.append(tube("Bota - sola " + side, sole, sr, 14, sole_m))
    # salto
    objs.append(box("Bota - salto " + side, (heel.x, heel.y + 0.005, 0.022), (0, 0, 1), (0, -1, 0), (0.05, 0.042, 0.05), sole_m, 0.004))
    # cadarço: zigue-zague na frente do cano
    lace = []
    for k in range(12):
        t = k / 11
        idx = int(lerp(3, len(shaft) - 3, t))
        p = Vector(shaft[idx])
        rx, ry = catmull(LEG_R, (19 + idx) / 33)
        off = (0.012 if k % 2 == 0 else -0.012)
        lace.append(p + Vector((off, -(ry + 0.0135), 0)))
    objs.append(tube("Bota - cadarço " + side, lace, lambda t, i: (0.0028, 0.0028), 6, lace_m))
    return objs


# --------------------------------------------------------------------------------------
# Montagem
# --------------------------------------------------------------------------------------
def make_materials(face_size=2048):
    M = {}
    M["face"] = material("face", PAL["skin"], 0.75, image=new_image("asterion_face", face_atlas(face_size)))
    M["skin"] = material("skin", PAL["skin"], 0.75)
    M["hair_dark"] = material("hair_dark", "#170c09", 0.6, double=True)
    M["hair"] = material("hair", PAL["hair"], 0.55)
    M["hair_light"] = material("hair_light", "#3a2117", 0.5)
    M["cloth_green"] = material("cloth_green", PAL["green"], 0.9, double=True)
    M["cloth_dark"] = material("cloth_dark", PAL["green_dark"], 0.9, double=True)
    M["trim"] = material("trim", PAL["trim"], 0.6, image=new_image("asterion_trim", fabric_trim_texture()), double=True)
    M["leather"] = material("leather", PAL["leather"], 0.7, double=True)
    M["leather_dark"] = material("leather_dark", PAL["leather_dark"], 0.7)
    M["bronze"] = material("bronze", PAL["bronze"], 0.35, 0.8)
    M["sole"] = material("sole", PAL["sole"], 0.9)
    M["lace"] = material("lace", PAL["lace"], 0.9)
    return M


def build_model(hair_quality=1.0):
    define_joints()
    M = make_materials()
    parts = {}

    def add(key, obs):
        if obs is None:
            return
        if not isinstance(obs, (list, tuple)):
            obs = [obs]
        parts.setdefault(key, []).extend([o for o in obs if o is not None])

    add("torso", build_torso(M["skin"], z_bot=1.2, rows=20, cols=36))
    add("head", build_head(M["face"]))
    for sd in ("L", "R"):
        add("leg" + sd, build_leg(sd, M["skin"]))
        add("arm" + sd, build_arm(sd, M["skin"]))
        add("hand" + sd, build_hand(sd, M["skin"], M["leather_dark"]))
        add("arm" + sd, build_sleeve(sd, M["cloth_dark"], M["trim"]))
        add("arm" + sd, build_bracer(sd, M["leather"], M["leather_dark"], M["bronze"]))
        add("boot" + sd, build_boot(sd, M["leather"], M["leather_dark"], M["sole"], M["lace"], M["bronze"]))
    add("torso", build_bodice(M["cloth_dark"], M["trim"]))
    add("torso", build_corset(M["leather"], M["leather_dark"], M["bronze"]))
    add("skirt", build_skirt(M["cloth_green"], M["cloth_dark"], M["trim"]))
    add("cape", build_capelet(M["cloth_green"], M["trim"], M["bronze"]))
    add("hair", build_hair([M["hair_dark"], M["hair"], M["hair_light"]], hair_quality))
    return parts, M


# --------------------------------------------------------------------------------------
# Esqueleto
# --------------------------------------------------------------------------------------
# Nomes seguem o perfil humanoide do Godot (SkeletonProfileHumanoid) — dá para
# redirecionar animações do Mixamo no Godot sem renomear nada.
HAIR_CHAINS = {
    # nome: (phi inicial, phi final, raio do envelope, z inicial e final relativos à cabeça, nº de ossos)
    "HairBackC": (0.0, 0.0, 0.95, -0.02, -0.56, 4),
    "HairBackL": (0.48, 0.5, 0.95, -0.02, -0.55, 4),
    "HairBackR": (-0.48, -0.5, 0.95, -0.02, -0.55, 4),
    "HairBackLL": (0.95, 0.9, 0.95, -0.03, -0.52, 4),
    "HairBackRR": (-0.95, -0.9, 0.95, -0.03, -0.52, 4),
    "HairSideL": (1.4, 1.22, 0.97, -0.04, -0.46, 4),
    "HairSideR": (-1.4, -1.22, 0.97, -0.04, -0.46, 4),
    "HairFrontL": (1.85, 2.3, 1.0, -0.08, -0.32, 3),
    "HairFrontR": (-1.85, -2.3, 1.0, -0.08, -0.32, 3),
    "HairCheekL": None,
    "HairCheekR": None,
}
SKIRT_CHAINS = {
    "SkirtFL": 0.45, "SkirtFR": -0.45, "SkirtSL": 1.55, "SkirtSR": -1.55, "SkirtBL": 2.55, "SkirtBR": -2.55,
}
CAPE_CHAINS = {"CapeL": 1.45, "CapeR": -1.45, "CapeB": 3.14159}


def hair_chain_points():
    """Pontos (relativos ao centro da cabeça) de cada corrente de ossos do cabelo."""
    out = {}
    for name, spec in HAIR_CHAINS.items():
        if spec is None:
            side = 1 if name.endswith("L") else -1
            out[name] = [Vector((side * 0.095, -0.04, 0.0)), Vector((side * 0.098, -0.035, -0.08)),
                         Vector((side * 0.104, -0.03, -0.16)), Vector((side * 0.11, -0.025, -0.25))]
            continue
        phi0, phi1, lay, z0, z1, n = spec
        pts = []
        for k in range(n + 1):
            t = k / n
            z = lerp(z0, z1, t)
            phi = lerp(phi0, phi1, sstep(0.0, 1.0, t))
            R = env_radius(z, phi) * lay * (0.92 if k == 0 else 1.0)
            pts.append(Vector((math.sin(phi) * R, AXIS_Y + math.cos(phi) * R, z)))
        out[name] = pts
    return out


def bone_specs():
    """Lista (nome, cabeça, cauda, pai)."""
    B = []
    up = Vector((0, 0, 1))
    B.append(("Hips", J["hips"], J["spine"], None))
    B.append(("Spine", J["spine"], J["chest"], "Hips"))
    B.append(("Chest", J["chest"], J["upper_chest"], "Spine"))
    B.append(("UpperChest", J["upper_chest"], J["neck"], "Chest"))
    B.append(("Neck", J["neck"], J["head"], "UpperChest"))
    B.append(("Head", J["head"], J["head_top"], "Neck"))
    for side, nm in (("L", "Left"), ("R", "Right")):
        B.append((nm + "Shoulder", J["clav" + side], J["shoulder" + side], "UpperChest"))
        B.append((nm + "UpperArm", J["shoulder" + side], J["elbow" + side], nm + "Shoulder"))
        B.append((nm + "LowerArm", J["elbow" + side], J["wrist" + side], nm + "UpperArm"))
        B.append((nm + "Hand", J["wrist" + side], J["hand_end" + side], nm + "LowerArm"))
        B.append((nm + "UpperLeg", J["hip" + side], J["knee" + side], "Hips"))
        B.append((nm + "LowerLeg", J["knee" + side], J["ankle" + side], nm + "UpperLeg"))
        B.append((nm + "Foot", J["ankle" + side], J["toe" + side], nm + "LowerLeg"))
        B.append((nm + "Toes", J["toe" + side], J["toe_end" + side], nm + "Foot"))
    c0 = J["head_c"]
    for name, pts in hair_chain_points().items():
        parent = "Head"
        for k in range(len(pts) - 1):
            bn = "%s%d" % (name, k + 1)
            B.append((bn, c0 + pts[k], c0 + pts[k + 1], parent))
            parent = bn
    for name, af in SKIRT_CHAINS.items():
        pts = [Vector(skirt_point(t, af, skirt_hem, inflate=-0.01)) for t in (0.12, 0.55, 1.0)]
        B.append((name + "1", pts[0], pts[1], "Hips"))
        B.append((name + "2", pts[1], pts[2], name + "1"))
    for name, af in CAPE_CHAINS.items():
        th = af - math.pi / 2
        p0 = Vector(cape_point(0.45, th))
        p1 = Vector(cape_point(1.0, th))
        B.append((name, p0, p1, "UpperChest"))
    return B


def build_armature():
    arm = bpy.data.armatures.new("AsterionRig")
    ob = bpy.data.objects.new("Asterion", arm)
    collection("Asterion").objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm.edit_bones
    for name, h, t, parent in bone_specs():
        b = eb.new(name)
        b.head = h
        b.tail = t
        # rolagem consistente: eixo Z do osso aponta para frente (-Y) quando possível
        b.align_roll(Vector((0, -1, 0)) if abs((t - h).normalized().y) < 0.9 else Vector((0, 0, 1)))
        if parent:
            b.parent = eb[parent]
            b.use_connect = (eb[parent].tail - b.head).length < 1e-4
        b.use_deform = True
    bpy.ops.object.mode_set(mode='OBJECT')
    arm.display_type = 'STICK'
    ob.show_in_front = True
    return ob


# --------------------------------------------------------------------------------------
# Pesos de pele por região
# --------------------------------------------------------------------------------------
def seg_dist(P, a, b):
    """Distância de pontos P (N,3) ao segmento ab; também devolve t ao longo do segmento."""
    a = np.array(a)
    b = np.array(b)
    ab = b - a
    L2 = max(float(ab @ ab), 1e-12)
    t = np.clip(((P - a) @ ab) / L2, 0.0, 1.0)
    proj = a + t[:, None] * ab
    return np.linalg.norm(P - proj, axis=1), t


SKIN_RULES = {
    # região: {osso: multiplicador de influência}
    "torso": {"Hips": 1.0, "Spine": 1.0, "Chest": 1.0, "UpperChest": 1.0, "Neck": 0.8,
              "LeftShoulder": 0.55, "RightShoulder": 0.55, "LeftUpperLeg": 0.35, "RightUpperLeg": 0.35},
    "head": {"Head": 1.0},
    "neck": {"Neck": 1.0, "Head": 0.7, "UpperChest": 0.8},
    "armL": {"LeftShoulder": 0.6, "LeftUpperArm": 1.0, "LeftLowerArm": 1.0, "LeftHand": 0.8, "UpperChest": 0.25},
    "armR": {"RightShoulder": 0.6, "RightUpperArm": 1.0, "RightLowerArm": 1.0, "RightHand": 0.8, "UpperChest": 0.25},
    "handL": {"LeftHand": 1.0, "LeftLowerArm": 0.35},
    "handR": {"RightHand": 1.0, "RightLowerArm": 0.35},
    "legL": {"LeftUpperLeg": 1.0, "LeftLowerLeg": 1.0, "LeftFoot": 0.8, "Hips": 0.4},
    "legR": {"RightUpperLeg": 1.0, "RightLowerLeg": 1.0, "RightFoot": 0.8, "Hips": 0.4},
    "bootL": {"LeftLowerLeg": 1.0, "LeftFoot": 1.0, "LeftToes": 0.9},
    "bootR": {"RightLowerLeg": 1.0, "RightFoot": 1.0, "RightToes": 0.9},
    "skirt": dict({"Hips": 0.9}, **{n + k: 1.0 for n in SKIRT_CHAINS for k in "12"}),
    "cape": dict({"UpperChest": 1.0, "Neck": 0.5, "LeftShoulder": 0.8, "RightShoulder": 0.8,
                  "LeftUpperArm": 0.3, "RightUpperArm": 0.3}, **{n: 0.9 for n in CAPE_CHAINS}),
    "hair": {"Head": 1.2},     # mechas: ver assign_hair_weights
}


def assign_weights(ob, rule, bones, rigid=False, power=4.0, top=3):
    """Pesos por distância aos ossos candidatos (com multiplicadores)."""
    me = ob.data
    n = len(me.vertices)
    if n == 0:
        return
    co = np.zeros(n * 3, np.float32)
    me.vertices.foreach_get("co", co)
    P = co.reshape(-1, 3).astype(np.float64)
    mw = np.array(ob.matrix_world)
    P = P @ mw[:3, :3].T + mw[:3, 3]
    if rigid:
        P = np.repeat(P.mean(axis=0, keepdims=True), n, axis=0)
    names = list(rule.keys())
    W = np.zeros((n, len(names)))
    for j, bn in enumerate(names):
        h, t = bones[bn]
        d, _ = seg_dist(P, h, t)
        W[:, j] = rule[bn] / np.maximum(d, 0.004) ** power
    # manter só os maiores
    if len(names) > top:
        idx = np.argsort(-W, axis=1)[:, top:]
        np.put_along_axis(W, idx, 0.0, axis=1)
    W /= np.maximum(W.sum(axis=1, keepdims=True), 1e-12)
    for j, bn in enumerate(names):
        vg = ob.vertex_groups.get(bn) or ob.vertex_groups.new(name=bn)
        col = W[:, j]
        nz = np.nonzero(col > 0.002)[0]
        for i in nz:
            vg.add([int(i)], float(col[i]), 'REPLACE')


def assign_hair_weights(ob, bones):
    """Cada mecha segue a cabeça na raiz e as 2 correntes de ossos mais próximas no resto."""
    name = ob.name
    chains = {n: [b for b in bones if b.startswith(n) and b[len(n):].isdigit()] for n in HAIR_CHAINS}
    rigid_head = "topo" in name or "base" in name
    if "franja" in name:
        idx = int(name.split()[-1])
        rigid_head = idx < 4 or idx >= 10
    if rigid_head:
        assign_weights(ob, {"Head": 1.0}, bones)
        return
    me = ob.data
    co = np.zeros(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", co)
    mw = np.array(ob.matrix_world)
    P = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
    if "volume" in name:
        rule = {"Head": 1.0}
        for n in ("HairBackC", "HairBackL", "HairBackR", "HairBackLL", "HairBackRR", "HairSideL", "HairSideR"):
            for b in chains[n]:
                rule[b] = 1.0
        assign_weights(ob, rule, bones, power=3.0, top=3)
        return
    tip = P[np.argmin(P[:, 2])]
    mid = P.mean(axis=0)

    def chain_dist(n):
        best = 1e9
        for b in chains[n]:
            h, t = bones[b]
            d1, _ = seg_dist(tip[None, :], h, t)
            d2, _ = seg_dist(mid[None, :], h, t)
            best = min(best, float(d1[0]) + 0.5 * float(d2[0]))
        return best
    order = sorted(HAIR_CHAINS, key=chain_dist)
    rule = {"Head": 1.3}
    for b in chains[order[0]]:
        rule[b] = 1.0
    for b in chains[order[1]]:
        rule[b] = 0.45
    assign_weights(ob, rule, bones, power=3.0, top=3)


def apply_modifiers(ob):
    bpy.context.view_layer.objects.active = ob
    for m in list(ob.modifiers):
        if m.type in ('SOLIDIFY', 'SUBSURF', 'BEVEL', 'WEIGHTED_NORMAL'):
            try:
                bpy.ops.object.modifier_apply(modifier=m.name)
            except Exception as e:
                print("modifier", ob.name, m.name, e)


def skin_and_join(parts, arm_ob):
    bones = {}
    for b in arm_ob.data.bones:
        bones[b.name] = (tuple(b.head_local), tuple(b.tail_local))
    bpy.context.view_layer.update()
    rigid_words = ("fivela", "passador", "Bolsa", "Broche", "salto", "ilhós", "rebite")
    for key, obs in parts.items():
        for ob in obs:
            apply_modifiers(ob)
            rule_key = key
            if key in ("handL", "handR"):
                rule_key = key
            rule = SKIN_RULES[rule_key]
            rigid = any(w in ob.name for w in rigid_words)
            if key == "torso" and ob.name.startswith("Corpo - tronco"):
                # pescoço: vértices acima de 1.33 usam regra do pescoço
                assign_weights(ob, rule, bones)
                fix_neck(ob, bones)
            elif key == "hair":
                assign_hair_weights(ob, bones)
            elif key == "skirt" and "Bordado" not in ob.name and "interna" not in ob.name:
                assign_weights(ob, rule, bones, power=3.0)
            else:
                assign_weights(ob, rule, bones, rigid=rigid)
    # juntar tudo num único objeto (menos chamadas de desenho no celular)
    meshes = [o for obs in parts.values() for o in obs]
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:
        o.select_set(True)
    body = parts["torso"][0]
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body.name = "AsterionBody"
    body.data.name = "AsterionBody"
    # limpar pesos minúsculos e normalizar
    bpy.ops.object.vertex_group_clean(group_select_mode='ALL', limit=0.01)
    bpy.ops.object.vertex_group_limit_total(group_select_mode='ALL', limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode='ALL', lock_active=False)
    bake_vertex_ao(body)
    body.parent = arm_ob
    mod = body.modifiers.new("Armature", 'ARMATURE')
    mod.object = arm_ob
    return body


def fix_neck(ob, bones):
    """Pescoço da malha do tronco: mistura Neck/Head/UpperChest pela altura."""
    names = ("UpperChest", "Neck", "Head")
    groups = {n: (ob.vertex_groups.get(n) or ob.vertex_groups.new(name=n)) for n in names}
    for v in ob.data.vertices:
        z = v.co.z
        if z < 1.30:
            continue
        a = sstep(1.30, 1.36, z)       # 0 peito -> 1 pescoço
        b = sstep(1.40, 1.46, z)       # pescoço -> cabeça
        w_up = 1 - a
        w_neck = a * (1 - b)
        w_head = a * b
        for g in ob.vertex_groups:
            if g.name not in names:
                try:
                    g.remove([v.index])
                except Exception:
                    pass
        for n, w in zip(names, (w_up, w_neck, w_head)):
            if w > 0.001:
                groups[n].add([v.index], w, 'REPLACE')
            else:
                try:
                    groups[n].remove([v.index])
                except Exception:
                    pass


# --------------------------------------------------------------------------------------
# Animação procedural: FK/IK + física de mola (cabelo, saia, capa) "assada" nos quadros
# --------------------------------------------------------------------------------------
FPS = 30


def qaxis(axis, deg):
    return Quaternion(Vector(axis), math.radians(deg))


def qx(d):
    return qaxis((1, 0, 0), d)


def qy(d):
    return qaxis((0, 1, 0), d)


def qz(d):
    return qaxis((0, 0, 1), d)


def qmul(*qs):
    out = Quaternion()
    for q in qs:
        out = out @ q
    return out


class Rig:
    def __init__(self, arm_ob):
        self.ob = arm_ob
        self.bones = arm_ob.data.bones
        self.order = []
        self.parent = {}
        self.rest_h = {}
        self.rest_t = {}
        self.R = {}
        for b in arm_ob.data.bones:
            pass

        def walk(b):
            self.order.append(b.name)
            for c in b.children:
                walk(c)
        for b in arm_ob.data.bones:
            if b.parent is None:
                walk(b)
        for b in arm_ob.data.bones:
            self.parent[b.name] = b.parent.name if b.parent else None
            self.rest_h[b.name] = b.head_local.copy()
            self.rest_t[b.name] = b.tail_local.copy()
            self.R[b.name] = b.matrix_local.to_quaternion()
        self.chains = {}
        for name in list(HAIR_CHAINS) + list(SKIRT_CHAINS) + list(CAPE_CHAINS):
            ch = [n for n in self.order if n == name or (n.startswith(name) and n[len(name):].isdigit())]
            self.chains[name] = ch

    def length(self, b):
        return (self.rest_t[b] - self.rest_h[b]).length

    def fk(self, spec, hips_off):
        """spec: {osso: ('rel'|'abs', Quaternion)} -> Q absoluto (armadura) e posições."""
        Q, H, T = {}, {}, {}
        for b in self.order:
            p = self.parent[b]
            Qp = Q[p] if p else Quaternion()
            kind, q = spec.get(b, ("rel", Quaternion()))
            Qb = (Qp @ q) if kind == "rel" else q
            Q[b] = Qb
            if p is None:
                H[b] = self.rest_h[b] + hips_off
            else:
                H[b] = H[p] + Qp @ (self.rest_h[b] - self.rest_h[p])
            T[b] = H[b] + Qb @ (self.rest_t[b] - self.rest_h[b])
        return Q, H, T

    def key(self, Q, hips_off, frame):
        pbs = self.ob.pose.bones
        for b in self.order:
            p = self.parent[b]
            Qp = Q[p] if p else Quaternion()
            Rb = self.R[b]
            local = Rb.inverted() @ (Qp.inverted() @ Q[b]) @ Rb
            local.normalize()
            pb = pbs[b]
            pb.rotation_mode = 'QUATERNION'
            pb.rotation_quaternion = local
            pb.keyframe_insert("rotation_quaternion", frame=frame)
        hip = pbs["Hips"]
        hip.location = self.R["Hips"].inverted() @ hips_off
        hip.keyframe_insert("location", frame=frame)


def leg_ik(rig, Q, H, side, ankle, pitch_deg, toe_deg, yaw_deg=0.0):
    nm = "Left" if side == "L" else "Right"
    up, lo, ft, to = nm + "UpperLeg", nm + "LowerLeg", nm + "Foot", nm + "Toes"
    hp = H[up]
    L1, L2 = rig.length(up), rig.length(lo)
    d = ankle - hp
    dist = min(d.length, (L1 + L2) * 0.9995)
    u = d.normalized()
    a1 = math.acos(max(-1.0, min(1.0, (L1 * L1 + dist * dist - L2 * L2) / (2 * L1 * dist))))
    pole = qz(yaw_deg) @ Vector((0, -1, 0.0))
    pole = (pole - u * pole.dot(u)).normalized()
    knee = hp + u * (L1 * math.cos(a1)) + pole * (L1 * math.sin(a1))
    ank = knee + (hp + u * dist - knee).normalized() * L2
    Qh = Q["Hips"]
    rest_up = (rig.rest_t[up] - rig.rest_h[up]).normalized()
    rest_lo = (rig.rest_t[lo] - rig.rest_h[lo]).normalized()
    Qu = (Qh @ rest_up).rotation_difference((knee - hp).normalized()) @ Qh
    Ql = (Qu @ rest_lo).rotation_difference((ank - knee).normalized()) @ Qu
    Qf = qz(yaw_deg) @ qx(pitch_deg)
    Qt = Qf @ qx(toe_deg)
    return {up: ("abs", Qu), lo: ("abs", Ql), ft: ("abs", Qf), to: ("abs", Qt)}


class Springs:
    """Correntes de partículas (Verlet) que seguem os ossos-pai e colidem com o corpo."""

    def __init__(self, rig, stiffness, damping, gravity=9.8, drag=0.0):
        self.rig = rig
        self.k = stiffness
        self.damp = damping
        self.g = gravity
        self.drag = drag
        self.state = {}

    def targets(self, chain, Q, H):
        rig = self.rig
        root = chain[0]
        p = rig.parent[root]
        Qp = Q[p]
        pts = [H[root]]
        for b in chain:
            pts.append(H[p] + Qp @ (rig.rest_t[b] - rig.rest_h[p]))
        return pts, Qp

    def step(self, name, Q, H, dt, wind, colliders, stiff=None):
        chain = self.rig.chains[name]
        tgt, Qp = self.targets(chain, Q, H)
        st = self.state.get(name)
        if st is None:
            st = {"x": [t.copy() for t in tgt], "xp": [t.copy() for t in tgt]}
            self.state[name] = st
        x, xp = st["x"], st["xp"]
        k = self.k if stiff is None else stiff
        x[0] = tgt[0].copy()
        xp[0] = tgt[0].copy()
        for i in range(1, len(x)):
            v = (x[i] - xp[i]) * self.damp
            acc = Vector((0, 0, -self.g)) * 0.25 + wind + (tgt[i] - x[i]) * k
            nx = x[i] + v + acc * dt * dt
            xp[i] = x[i]
            x[i] = nx
        # comprimento dos segmentos + colisões
        for _ in range(3):
            for i in range(1, len(x)):
                L = (tgt[i] - tgt[i - 1]).length
                d = x[i] - x[i - 1]
                if d.length > 1e-9:
                    x[i] = x[i - 1] + d.normalized() * L
                for (a, b, r) in colliders:
                    ab = b - a
                    t = max(0.0, min(1.0, (x[i] - a).dot(ab) / max(ab.length_squared, 1e-9)))
                    c = a + ab * t
                    off = x[i] - c
                    if off.length < r:
                        x[i] = c + (off.normalized() if off.length > 1e-9 else Vector((0, 1, 0))) * r
        return x

    def rotations(self, name, Q, H, x):
        rig = self.rig
        chain = rig.chains[name]
        out = {}
        Qparent = Q[rig.parent[chain[0]]]
        for i, b in enumerate(chain):
            rest_dir = (rig.rest_t[b] - rig.rest_h[b]).normalized()
            cur = Qparent @ rest_dir
            new = (x[i + 1] - x[i]).normalized()
            Qb = cur.rotation_difference(new) @ Qparent
            out[b] = ("abs", Qb)
            Qparent = Qb
        return out


def body_colliders(H, T, part):
    c = []
    if part == "hair":
        c.append((H["Head"] + Vector((0, 0.0, 0.08)), H["Head"] + Vector((0, 0.0, 0.08)), 0.15))
        c.append((H["Spine"] + Vector((0, 0.02, 0)), H["Neck"] + Vector((0, 0.03, -0.04)), 0.2))
        c.append((H["LeftUpperArm"], H["LeftUpperArm"], 0.11))
        c.append((H["RightUpperArm"], H["RightUpperArm"], 0.11))
    elif part == "skirt":
        c.append((H["Hips"] + Vector((0, 0, -0.04)), H["Hips"] + Vector((0, 0, 0.05)), 0.18))
        for nm in ("Left", "Right"):
            c.append((H[nm + "UpperLeg"], H[nm + "LowerLeg"], 0.1))
            c.append((H[nm + "LowerLeg"], H[nm + "Foot"], 0.085))
    elif part == "cape":
        c.append((H["Chest"], H["UpperChest"], 0.17))
        for nm in ("Left", "Right"):
            c.append((H[nm + "UpperArm"], H[nm + "LowerArm"], 0.075))
    return c


SPRING_SETS = {
    "hair": (list(HAIR_CHAINS), 70.0, 0.965, 1.0),
    "skirt": (list(SKIRT_CHAINS), 260.0, 0.95, 0.6),
    "cape": (list(CAPE_CHAINS), 380.0, 0.94, 0.5),
}


def bake_action(rig, name, frames, pose_fn, loop=True, speed=0.0, warm_cycles=2, wind=None):
    """pose_fn(t_seg) -> (spec, hips_off). t em segundos. Assa primário + molas."""
    ob = rig.ob
    if ob.animation_data is None:
        ob.animation_data_create()
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    ob.animation_data.action = act
    springs = {k: Springs(rig, v[1], v[2]) for k, v in SPRING_SETS.items()}
    dur = frames / FPS
    sub = 4
    dt = 1.0 / (FPS * sub)
    warm_static = 0 if loop else FPS      # 1 s parado na pose inicial para o cabelo assentar
    total_frames = frames * (warm_cycles + 1) if loop else frames + 1 + warm_static
    wind = Vector((0, speed * 2.2, 0)) + (wind or Vector())
    f_out = 0
    for f in range(total_frames * sub):
        t = f * dt
        tt = (t % dur) if loop else min(max(t - warm_static / FPS, 0.0), dur)
        spec, hips_off = pose_fn(tt)
        Q, H, T = rig.fk(spec, hips_off)
        sec = {}
        for part, (chains, k, damp, wscale) in SPRING_SETS.items():
            cols = body_colliders(H, T, part)
            for ch in chains:
                x = springs[part].step(ch, Q, H, dt, wind * wscale, cols)
                sec.update(springs[part].rotations(ch, Q, H, x))
        record_from = frames * warm_cycles if loop else warm_static
        frame_idx = f // sub
        if f % sub == 0 and frame_idx >= record_from:
            full = dict(spec)
            full.update(sec)
            Q2, H2, T2 = rig.fk(full, hips_off)
            rig.key(Q2, hips_off, frame_idx - record_from + 1)
    # fechar o loop com o primeiro quadro
    act_end = frames + 1 if loop else frames + 1
    if loop:
        for fc in fcurves_of(act):
            if len(fc.keyframe_points) > 1:
                first = fc.keyframe_points[0].co[1]
                fc.keyframe_points.insert(act_end, first)
                for kp in fc.keyframe_points:
                    kp.interpolation = 'LINEAR'
    else:
        for fc in fcurves_of(act):
            for kp in fc.keyframe_points:
                kp.interpolation = 'LINEAR'
    track = ob.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 1, act)
    strip.name = name
    track.mute = True
    ob.animation_data.action = None
    return act


def fcurves_of(act):
    """Compatível com ações em camadas (Blender 4.4+) e antigas."""
    try:
        return list(act.fcurves)
    except Exception:
        pass
    out = []
    try:
        for layer in act.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    out.extend(bag.fcurves)
    except Exception:
        pass
    return out


# ---- poses ------------------------------------------------------------------------------
def arm_pose(side, swing, elbow, abduct=6.0, twist=0.0, hand=0.0):
    """swing: + para frente (graus); elbow: flexão; abduct: afastar do corpo."""
    s = 1 if side == "L" else -1
    nm = "Left" if side == "L" else "Right"
    return {
        nm + "UpperArm": ("rel", qmul(qx(-swing), qy(s * (17.0 - abduct)), qz(s * twist))),
        nm + "LowerArm": ("rel", qx(-elbow)),
        nm + "Hand": ("rel", qx(hand)),
    }


def spine_pose(spec, pitch=0.0, yaw=0.0, roll=0.0, chest_yaw=0.0, chest_pitch=0.0, head_pitch=0.0,
               head_yaw=0.0, head_roll=0.0, shoulders=0.0):
    spec["Hips"] = ("rel", qmul(qz(yaw), qy(roll), qx(pitch)))
    spec["Spine"] = ("rel", qmul(qz(chest_yaw * 0.4), qy(-roll * 0.5), qx(chest_pitch * 0.4)))
    spec["Chest"] = ("rel", qmul(qz(chest_yaw * 0.35), qy(-roll * 0.3), qx(chest_pitch * 0.35)))
    spec["UpperChest"] = ("rel", qmul(qz(chest_yaw * 0.25), qx(chest_pitch * 0.25)))
    spec["Neck"] = ("rel", qmul(qz(head_yaw * 0.4), qx(head_pitch * 0.4)))
    spec["Head"] = ("rel", qmul(qz(head_yaw * 0.6), qy(head_roll), qx(head_pitch * 0.6)))
    spec["LeftShoulder"] = ("rel", qy(-shoulders))
    spec["RightShoulder"] = ("rel", qy(shoulders))


def locomotion(rig, cycle, stance, front, back, lift, hip_drop, bob, lean, swing, elbow0, elbow1,
               pelvis_yaw, chest_yaw, roll, sway, toe_off_lift=0.05, heel_pitch=14.0, toe_pitch=-28.0,
               lift_peak=0.4, head_pitch=0.0, arm_abduct=8.0, run=False):
    """Gera pose_fn para andar/correr no lugar (o jogo move o personagem)."""
    J0 = {s: rig.rest_h[("Left" if s == "L" else "Right") + "Foot"] for s in "LR"}

    def foot_state(ph):
        """ph em [0,1): 0 = toque do calcanhar à frente."""
        if ph < stance:
            u = ph / stance
            y = lerp(-front, back, u)
            z = 0.0
            pitch = lerp(heel_pitch, 0.0, sstep(0.0, 0.18, u))
            pitch = lerp(pitch, toe_pitch * 0.55, sstep(0.72, 1.0, u))
            z += toe_off_lift * 0.6 * sstep(0.7, 1.0, u)
            toe = -pitch * 0.9 * sstep(0.7, 1.0, u)
            return y, z, pitch, toe
        u = (ph - stance) / (1 - stance)
        y = lerp(back, -front, sstep(0.0, 1.0, u) if not run else sstep(0.05, 0.95, u) ** 0.95)
        peak = math.sin(math.pi * min(1.0, u / (2 * lift_peak))) if u < lift_peak else \
            math.cos(math.pi / 2 * (u - lift_peak) / (1 - lift_peak))
        z = lift * max(0.0, peak) + toe_off_lift * 0.6 * (1 - sstep(0.0, 0.25, u))
        pitch = lerp(toe_pitch, heel_pitch, sstep(0.25, 0.95, u))
        toe = lerp(-toe_pitch * 0.5, 0.0, sstep(0.0, 0.3, u))
        return y, z, pitch, toe

    def fn(t):
        ph = (t / cycle) % 1.0
        phases = {"L": ph, "R": (ph + 0.5) % 1.0}
        spec = {}
        # quadril: desce no apoio duplo, sobe no meio do apoio
        a = math.cos(4 * math.pi * ph)
        hz = -hip_drop + bob * (-a if not run else a)
        hx = sway * math.sin(2 * math.pi * ph)
        hips_off = Vector((hx, 0.0, hz))
        sL = math.sin(2 * math.pi * ph)
        spine_pose(spec, pitch=lean, yaw=pelvis_yaw * sL, roll=roll * math.sin(2 * math.pi * ph + math.pi / 2),
                   chest_yaw=-chest_yaw * sL, chest_pitch=0.0, head_pitch=head_pitch - lean * 0.6,
                   head_yaw=pelvis_yaw * 0.3 * sL)
        Q, H, T = rig.fk(spec, hips_off)
        for s in "LR":
            y, z, pitch, toe = foot_state(phases[s])
            base = J0[s]
            ank = Vector((base.x * 0.92, base.y + y, base.z + z))
            spec.update(leg_ik(rig, Q, H, s, ank, pitch, toe, yaw_deg=pelvis_yaw * 0.4 * sL))
        # braços opostos às pernas
        for s, sg in (("L", -1), ("R", 1)):
            sw = swing * sg * sL
            el = lerp(elbow0, elbow1, max(0.0, sw / max(swing, 1e-6)))
            spec.update(arm_pose(s, sw, el, abduct=arm_abduct))
        return spec, hips_off
    return fn


def idle_fn(rig, dur=4.0):
    J0 = {s: rig.rest_h[("Left" if s == "L" else "Right") + "Foot"] for s in "LR"}

    def fn(t):
        b = math.sin(2 * math.pi * t / dur)          # respiração
        w = math.sin(2 * math.pi * t / dur + 0.8)
        spec = {}
        hips_off = Vector((0.018 + 0.004 * w, 0.0, -0.012 + 0.003 * b))
        spine_pose(spec, pitch=1.0, yaw=3.0, roll=-2.5 - 0.6 * w, chest_yaw=-3.0, chest_pitch=1.2 * b - 1.0,
                   head_pitch=-2.0 - 1.0 * b, head_yaw=2.0 * math.sin(2 * math.pi * t / dur * 0.5), head_roll=2.5,
                   shoulders=1.2 * b)
        Q, H, T = rig.fk(spec, hips_off)
        spec.update(leg_ik(rig, Q, H, "L", Vector((J0["L"].x * 0.95, J0["L"].y - 0.02, J0["L"].z)), 0.0, 0.0, 6.0))
        spec.update(leg_ik(rig, Q, H, "R", Vector((J0["R"].x * 1.05, J0["R"].y + 0.05, J0["R"].z + 0.012)), -6.0, 6.0, -8.0))
        spec.update(arm_pose("L", 4.0 + 1.0 * b, 14.0 + 2 * b, abduct=4.0, hand=6.0))
        spec.update(arm_pose("R", 2.0 + 1.0 * b, 10.0 + 2 * b, abduct=4.0, hand=4.0))
        return spec, hips_off
    return fn


def stand(rig, spec, hips_off, feet=None):
    """Completa a pose com as pernas por IK mantendo os pés no chão.
    feet: {"L": (dx, dy, dz, pitch, toe, yaw), ...} deslocamentos a partir do repouso."""
    feet = feet or {}
    Q, H, T = rig.fk(spec, hips_off)
    for s in "LR":
        nm = "Left" if s == "L" else "Right"
        base = rig.rest_h[nm + "Foot"]
        dx, dy, dz, pitch, toe, yaw = feet.get(s, (0, 0, 0, 0, 0, 0))
        spec.update(leg_ik(rig, Q, H, s, base + Vector((dx, dy, dz)), pitch, toe, yaw))
    return spec


def ease(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


def blend_keys(keys, t):
    """keys: [(tempo, valor)] -> valor interpolado com suavização."""
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t <= t1:
            u = ease((t - t0) / max(t1 - t0, 1e-6))
            if isinstance(v0, (tuple, list)):
                return tuple(lerp(a, b, u) for a, b in zip(v0, v1))
            return lerp(v0, v1, u)
    return keys[-1][1]


IDLE_BASE = dict(hx=0.018, hz=-0.012, pitch=1.0, yaw=3.0, roll=-2.5, chest_yaw=-3.0, head_roll=2.5)


def base_idle(rig, t=0.0, **over):
    """Pose de descanso (mesma do início do idle) — ponto de partida das outras ações."""
    p = dict(IDLE_BASE)
    p.update(over)
    spec = {}
    hips_off = Vector((p["hx"], 0.0, p["hz"]))
    spine_pose(spec, pitch=p["pitch"], yaw=p["yaw"], roll=p["roll"], chest_yaw=p["chest_yaw"],
               chest_pitch=p.get("chest_pitch", -1.0), head_pitch=p.get("head_pitch", -2.0),
               head_yaw=p.get("head_yaw", 0.0), head_roll=p["head_roll"], shoulders=p.get("shoulders", 0.0))
    return spec, hips_off


def idle_feet():
    return {"L": (-0.0044, -0.02, 0.0, 0.0, 0.0, 6.0), "R": (-0.0044, 0.05, 0.012, -6.0, 6.0, -8.0)}


def cast_fn(rig):
    def fn(t):
        k = [(0.0, 0.0), (0.08, -0.35), (0.19, 1.0), (0.42, 1.0), (0.7, 0.0)]
        a = blend_keys(k, t)                 # -0.35 preparação, 1 = braço estendido
        spec, ho = base_idle(rig, pitch=1.0 + 6 * max(a, 0), chest_yaw=-3 - 14 * a, yaw=3 + 6 * a,
                             head_pitch=-4.0 * max(a, 0), head_yaw=6 * a)
        ho = ho + Vector((0, -0.02 * max(a, 0), -0.01 * max(a, 0)))
        spec.update(arm_pose("R", lerp(2, 84, max(a, 0)) + 18 * min(a, 0), lerp(10, 8, max(a, 0)) - 40 * min(a, 0),
                             abduct=lerp(4, 10, max(a, 0)), hand=lerp(4, -38, max(a, 0)), twist=-30 * max(a, 0)))
        spec.update(arm_pose("L", lerp(4, -14, max(a, 0)), lerp(14, 30, max(a, 0)), abduct=lerp(4, 14, max(a, 0)), hand=6))
        f = idle_feet()
        f["L"] = (0.0, lerp(-0.02, -0.09, max(a, 0)), 0.0, 0.0, 0.0, 6.0)
        return stand(rig, spec, ho, f), ho
    return fn


def jump_fn(rig):
    """Impulso: agacha e estica; pés saem do chão (o jogo sobe o corpo)."""
    def fn(t):
        c = blend_keys([(0.0, 0.0), (0.1, 1.0), (0.22, -0.4), (0.4, 0.6)], t)   # 1 agachado, -0.4 esticado, 0.6 encolhido no ar
        spec, ho = base_idle(rig, pitch=2 + 10 * max(c, 0) - 4 * min(c, 0), roll=0.0, yaw=0.0, chest_yaw=0.0,
                             head_pitch=-6 * min(c, 0) - 3)
        air = sstep(0.18, 0.3, t)
        ho = Vector((0.0, 0.0, -0.13 * max(c, 0) * (1 - air) + 0.03 * (1 - air) * max(-c, 0)))
        tuck = 0.16 * air * max(c, 0.2)
        f = {"L": (0.0, -0.05 * air, lerp(0.0, tuck + 0.06, air), lerp(0, 10, air), 0.0, 4.0),
             "R": (0.0, 0.06 * air, lerp(0.0, tuck * 1.6 + 0.04, air), lerp(0, -20, air), 10 * air, -4.0)}
        arm = lerp(-20 * max(c, 0), 35, sstep(0.12, 0.3, t))
        spec.update(arm_pose("L", arm, 30 + 20 * air, abduct=10 + 14 * air, hand=-8))
        spec.update(arm_pose("R", arm * 0.8, 35 + 20 * air, abduct=10 + 16 * air, hand=-8))
        # no ar os pés seguem o quadril (não ficam presos ao chão)
        if air > 0:
            f = {s: (v[0], v[1], v[2] + ho.z * air, v[3], v[4], v[5]) for s, v in f.items()}
        return stand(rig, spec, ho, f), ho
    return fn


def fall_fn(rig, dur=0.6):
    def fn(t):
        w = math.sin(2 * math.pi * t / dur)
        spec, ho = base_idle(rig, pitch=4.0, roll=1.5 * w, yaw=0.0, chest_yaw=2 * w, head_pitch=4.0)
        ho = Vector((0.0, 0.0, 0.0))
        f = {"L": (0.0, -0.06, 0.1 + 0.01 * w, 12, 0, 4), "R": (0.0, 0.05, 0.16 - 0.01 * w, -18, 12, -4)}
        spec.update(arm_pose("L", 20 + 4 * w, 35, abduct=30 + 4 * w, hand=-10))
        spec.update(arm_pose("R", 14 - 4 * w, 40, abduct=32 - 4 * w, hand=-10))
        return stand(rig, spec, ho, f), ho
    return fn


def kneel_fn(rig):
    """Ajoelha sobre o joelho direito e estende a mão direita ao chão; segura no fim."""
    def fn(t):
        k = blend_keys([(0.0, 0.0), (0.75, 1.0), (1.2, 1.0)], t)
        spec, ho = base_idle(rig, pitch=1 + 24 * k, roll=-2.5 * (1 - k), yaw=3 * (1 - k) - 6 * k,
                             chest_yaw=-3 - 8 * k, chest_pitch=-1 + 12 * k, head_pitch=-2 + 14 * k,
                             head_roll=2.5 * (1 - k))
        ho = Vector((0.018 * (1 - k), -0.06 * k, -0.012 - 0.40 * k))
        f = {"L": (0.0, lerp(-0.02, -0.22, k), 0.0, 0.0, 0.0, 6.0),
             "R": (lerp(-0.004, -0.01, k), lerp(0.05, 0.30, k), lerp(0.012, 0.075, k), lerp(-6, -62, k),
                   lerp(6, 55, k), -8.0)}
        spec.update(arm_pose("R", lerp(2, 30, k), lerp(10, 8, k), abduct=lerp(4, 8, k), hand=lerp(4, -35, k)))
        spec.update(arm_pose("L", lerp(4, 24, k), lerp(14, 70, k), abduct=lerp(4, 16, k), hand=6))
        return stand(rig, spec, ho, f), ho
    return fn


def sigh_fn(rig):
    def fn(t):
        b = blend_keys([(0.0, 0.0), (0.7, 1.0), (1.0, 1.0), (1.8, -0.4), (2.4, 0.0)], t)
        spec, ho = base_idle(rig, chest_pitch=-1.0 - 4 * b, head_pitch=-2 - 9 * b, shoulders=5 * b,
                             head_roll=2.5 + 3 * max(-b, 0))
        ho = ho + Vector((0, 0, 0.006 * b))
        spec.update(arm_pose("L", 4 - 2 * b, 14 + 4 * max(-b, 0), abduct=4 + 2 * b, hand=6))
        spec.update(arm_pose("R", 2 - 2 * b, 10 + 4 * max(-b, 0), abduct=4 + 2 * b, hand=4))
        return stand(rig, spec, ho, idle_feet()), ho
    return fn


def look_fn(rig):
    """Olha em volta (o vento passa pelo cabelo)."""
    def fn(t):
        yaw = blend_keys([(0.0, 0.0), (0.6, 38.0), (1.4, 38.0), (2.1, -30.0), (2.8, -30.0), (3.4, 0.0)], t)
        pit = blend_keys([(0.0, 0.0), (0.6, -6.0), (1.4, -4.0), (2.1, -2.0), (2.8, -5.0), (3.4, 0.0)], t)
        spec, ho = base_idle(rig, chest_yaw=-3 + yaw * 0.35, head_yaw=yaw, head_pitch=-2 + pit)
        spec.update(arm_pose("L", 4, 14, abduct=4, hand=6))
        spec.update(arm_pose("R", 2 + abs(yaw) * 0.05, 12, abduct=5, hand=4))
        return stand(rig, spec, ho, idle_feet()), ho
    return fn


def shift_fn(rig):
    """Troca o peso de perna e ajeita a braçadeira."""
    def fn(t):
        w = blend_keys([(0.0, 0.0), (0.7, 1.0), (2.0, 1.0), (2.7, 0.0)], t)
        g = blend_keys([(0.0, 0.0), (0.6, 0.0), (1.0, 1.0), (1.7, 1.0), (2.2, 0.0)], t)
        spec, ho = base_idle(rig, hx=lerp(0.018, -0.02, w), roll=lerp(-2.5, 2.5, w), yaw=lerp(3, -3, w),
                             head_roll=lerp(2.5, -1.5, w), head_pitch=-2 + 14 * g, head_yaw=-10 * g)
        f = {"L": (0.004 * w, lerp(-0.02, 0.04, w), 0.012 * w, -6 * w, 6 * w, 6.0),
             "R": (-0.004, lerp(0.05, -0.01, w), 0.012 * (1 - w), -6 * (1 - w), 6 * (1 - w), -8.0)}
        spec.update(arm_pose("L", lerp(4, 38, g), lerp(14, 105, g), abduct=lerp(4, 8, g), twist=-30 * g, hand=6))
        spec.update(arm_pose("R", lerp(2, 30, g), lerp(10, 80, g), abduct=lerp(4, 2, g), twist=20 * g, hand=-10 * g))
        return stand(rig, spec, ho, f), ho
    return fn


def hurt_fn(rig):
    def fn(t):
        h = blend_keys([(0.0, 0.0), (0.08, 1.0), (0.45, 0.0)], t)
        spec, ho = base_idle(rig, pitch=1 - 10 * h, chest_pitch=-1 - 8 * h, head_pitch=-2 - 12 * h, roll=-2.5 + 4 * h)
        ho = ho + Vector((0, 0.05 * h, -0.02 * h))
        spec.update(arm_pose("L", 4 + 20 * h, 14 + 30 * h, abduct=4 + 20 * h, hand=6))
        spec.update(arm_pose("R", 2 + 25 * h, 10 + 35 * h, abduct=4 + 18 * h, hand=4))
        return stand(rig, spec, ho, idle_feet()), ho
    return fn


CLIP_INFO = {"idle": {"loop": True}, "fall": {"loop": True}}


def clips(rig):
    """Define e assa todas as animações (no lugar; o jogo move o personagem)."""
    out = {}
    out["idle"] = bake_action(rig, "idle", 120, idle_fn(rig, 4.0), loop=True)
    # andar: passo 0.68 m em 58% de 0.72 s -> ~1.63 m/s (o jogo ajusta a velocidade de reprodução)
    walk = dict(cycle=0.72, stance=0.58, front=0.34, back=0.34)
    out["walk"] = bake_action(rig, "walk", round(walk["cycle"] * FPS), locomotion(
        rig, walk["cycle"], stance=walk["stance"], front=walk["front"], back=walk["back"], lift=0.09,
        hip_drop=0.04, bob=0.013, lean=3.5, swing=19.0, elbow0=10.0, elbow1=28.0, pelvis_yaw=7.0,
        chest_yaw=8.0, roll=3.0, sway=0.012, toe_off_lift=0.055, lift_peak=0.38, arm_abduct=7.0),
        loop=True, speed=1.6)
    run = dict(cycle=0.58, stance=0.32, front=0.32, back=0.56)
    out["run"] = bake_action(rig, "run", round(run["cycle"] * FPS), locomotion(
        rig, run["cycle"], stance=run["stance"], front=run["front"], back=run["back"], lift=0.27,
        hip_drop=0.08, bob=0.026, lean=12.0, swing=42.0, elbow0=72.0, elbow1=96.0, pelvis_yaw=10.0,
        chest_yaw=13.0, roll=2.0, sway=0.01, toe_off_lift=0.09, heel_pitch=6.0, toe_pitch=-40.0,
        lift_peak=0.32, head_pitch=4.0, arm_abduct=12.0, run=True), loop=True, speed=4.7)
    CLIP_INFO["walk"] = {"loop": True, "speed": (walk["front"] + walk["back"]) / (walk["stance"] * walk["cycle"])}
    CLIP_INFO["run"] = {"loop": True, "speed": (run["front"] + run["back"]) / (run["stance"] * run["cycle"])}
    out["cast"] = bake_action(rig, "cast", 21, cast_fn(rig), loop=False)
    out["jump"] = bake_action(rig, "jump", 12, jump_fn(rig), loop=False)
    out["fall"] = bake_action(rig, "fall", 18, fall_fn(rig, 0.6), loop=True, wind=Vector((0, 0, 7.0)))
    out["kneel"] = bake_action(rig, "kneel", 30, kneel_fn(rig), loop=False)
    out["sigh"] = bake_action(rig, "sigh", 72, sigh_fn(rig), loop=False)
    out["look"] = bake_action(rig, "look", 102, look_fn(rig), loop=False, wind=Vector((2.5, 0.8, 0)))
    out["shift"] = bake_action(rig, "shift", 81, shift_fn(rig), loop=False)
    out["hurt"] = bake_action(rig, "hurt", 14, hurt_fn(rig), loop=False)
    return out


# --------------------------------------------------------------------------------------
# Exportação
# --------------------------------------------------------------------------------------
def export(arm_ob, body, path_glb, path_blend=None):
    bpy.ops.object.select_all(action='DESELECT')
    arm_ob.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = arm_ob
    kw = dict(filepath=path_glb, export_format='GLB', use_selection=True, export_apply=True,
              export_animations=True, export_skins=True, export_yup=True,
              export_texcoords=True, export_normals=True, export_materials='EXPORT',
              export_image_format='AUTO')
    for k, v in (("export_animation_mode", 'NLA_TRACKS'), ("export_force_sampling", True),
                 ("export_def_bones", True), ("export_optimize_animation_size", True),
                 ("export_anim_slide_to_zero", True), ("export_bake_animation", False),
                 ("export_tangents", False), ("export_vertex_color", 'ACTIVE'),
                 ("export_all_vertex_colors", False), ("export_colors", True),
                 ("export_active_vertex_color_when_no_material", True)):
        kw[k] = v
    # remove opções que a versão instalada do exportador não conhece
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    kw = {k: v for k, v in kw.items() if k in props}
    bpy.ops.export_scene.gltf(**kw)
    if path_blend:
        try:
            bpy.ops.wm.save_as_mainfile(filepath=path_blend)
        except Exception as e:
            print("salvar .blend:", e)


def setup_viewport_scene():
    """Câmera e luzes bonitas para ver no Blender (não vão para o .glb)."""
    sc = bpy.context.scene
    sc.render.fps = FPS
    for eng in ('BLENDER_EEVEE_NEXT', 'BLENDER_EEVEE'):
        try:
            sc.render.engine = eng
            break
        except Exception:
            continue
    if sc.world is None:
        sc.world = bpy.data.worlds.new("Mundo")
    sc.world.color = (0.05, 0.06, 0.06)
    coll = collection("Cena")
    for name, loc, energy, size in (("Luz principal", (-2.5, -3.5, 3.6), 500, 3.0),
                                    ("Luz de recorte", (2.2, 2.8, 3.0), 650, 2.0),
                                    ("Preenchimento", (3, -2, 1.2), 120, 3.0)):
        ld = bpy.data.lights.new(name, 'AREA')
        ld.energy = energy
        ld.size = size
        lo = bpy.data.objects.new(name, ld)
        coll.objects.link(lo)
        lo.location = loc
        lo.rotation_euler = (Vector((0, 0, 1.0)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    cd = bpy.data.cameras.new("Câmera")
    cd.lens = 70
    co = bpy.data.objects.new("Câmera", cd)
    coll.objects.link(co)
    co.location = (2.6, -4.6, 1.45)
    co.rotation_euler = (Vector((0, 0, 0.95)) - co.location).to_track_quat('-Z', 'Y').to_euler()
    sc.camera = co


def main(out_dir=None, hair_quality=1.0, hair_sides=6, hair_spt=8, animate=True):
    global HAIR_SIDES, HAIR_SPT
    HAIR_SIDES, HAIR_SPT = hair_sides, hair_spt
    random.seed(SEED)
    reset_scene()
    parts, M = build_model(hair_quality)
    arm = build_armature()
    body = skin_and_join(parts, arm)
    rig = Rig(arm)
    if animate:
        clips(rig)
        # deixa a animação de idle tocando ao abrir o arquivo
        tr = arm.animation_data.nla_tracks.get("idle")
        if tr:
            tr.mute = False
    setup_viewport_scene()
    if out_dir is None:
        out_dir = os.environ.get("ASTERION_OUT") or (
            os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else bpy.path.abspath("//"))
        if not out_dir or not os.path.isdir(out_dir):
            out_dir = os.path.expanduser("~")
    glb = os.path.join(out_dir, "asterion.glb")
    blend = os.path.join(out_dir, "asterion.blend")
    export(arm, body, glb, blend)
    for k, arr in detail_textures().items():
        save_png(arr, os.path.join(out_dir, "detail_%s.png" % k))
    try:
        import json
        with open(os.path.join(out_dir, "asterion_clips.json"), "w") as f:
            json.dump(CLIP_INFO, f, indent=1)
    except Exception as e:
        print("clips json:", e)
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print("ASTERION: pronto — %d triângulos, %d ossos. Arquivos: %s" % (tris, len(arm.data.bones), out_dir))
    return arm, body


QUALITY_PRESETS = {
    # nome: (qualidade do cabelo, lados de cada cacho, amostras por volta)
    "alta": (1.0, 6, 8),     # para ver/renderizar no Blender (~120 mil triângulos)
    "jogo": (0.6, 6, 6),     # o que vai para o celular (~95 mil triângulos)
}


if __name__ == "__main__":
    q = QUALITY_PRESETS.get(os.environ.get("ASTERION_QUALITY", "alta"), QUALITY_PRESETS["alta"])
    main(hair_quality=q[0], hair_sides=q[1], hair_spt=q[2])
