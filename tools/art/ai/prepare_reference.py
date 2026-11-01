#!/usr/bin/env python3
"""Prepares tools/art/ai/source/*.png from the author's character sheet.

1. Crops each view from the sheet (512x279 reference).
2. Upscales 4x with Real-ESRGAN x4plus_anime_6B (numpy implementation, no PyTorch).
3. Removes the background with ISNet-anime (onnxruntime) + colour refinement and de-haloing.

Models (download once into a folder passed as --models):
  https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.2.4/RealESRGAN_x4plus_anime_6B.pth
  https://github.com/danielgatis/rembg/releases/download/v0.0.0/isnet-anime.onnx

    pip install numpy pillow onnxruntime
    python3 tools/art/ai/prepare_reference.py sheet.jpg --models ~/ai
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from esrgan_numpy import load_pth, upscale  # noqa: E402

CROPS = {'front': (6, 18, 116, 264), 'side': (124, 18, 196, 264), 'back': (198, 18, 310, 264),
         'bust': (306, 14, 404, 112), 'face': (416, 14, 496, 94)}


def isnet_mask(sess, img):
    w, h = img.size
    im = np.asarray(img.resize((1024, 1024), Image.LANCZOS), dtype=np.float32) / 255.0
    im = (im - np.array([0.485, 0.456, 0.406])) / np.array([1.0, 1.0, 1.0])
    out = sess.run(None, {sess.get_inputs()[0].name: im.transpose(2, 0, 1)[None].astype(np.float32)})[0][0, 0]
    out = (out - out.min()) / (out.max() - out.min())
    return np.asarray(Image.fromarray((out * 255).astype(np.uint8)).resize((w, h), Image.LANCZOS), dtype=np.float32) / 255.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sheet')
    ap.add_argument('--models', required=True)
    args = ap.parse_args()
    import onnxruntime as ort
    P = load_pth(os.path.join(args.models, 'RealESRGAN_x4plus_anime_6B.pth'))
    sess = ort.InferenceSession(os.path.join(args.models, 'isnet-anime.onnx'), providers=['CPUExecutionProvider'])
    sheet = Image.open(args.sheet).convert('RGB')
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'source')
    os.makedirs(out_dir, exist_ok=True)
    for name, box in CROPS.items():
        pad = 6
        im = np.pad(np.asarray(sheet.crop(box), dtype=np.float32) / 255, ((pad, pad), (pad, pad), (0, 0)), mode='edge')
        up = upscale(im, P)[pad * 4:-pad * 4, pad * 4:-pad * 4]
        img = Image.fromarray((up * 255 + 0.5).astype(np.uint8))
        m = isnet_mask(sess, img)
        a = np.asarray(img, dtype=np.float32)
        border = np.concatenate([a[:8].reshape(-1, 3), a[-8:].reshape(-1, 3), a[:, :8].reshape(-1, 3), a[:, -8:].reshape(-1, 3)])
        bg = np.median(border, axis=0)
        color_alpha = np.clip((np.linalg.norm(a - bg, axis=2) - 18) / 40, 0, 1)
        alpha = np.clip((m - 0.25) / 0.5, 0, 1)
        alpha = np.where(m > 0.85, 1.0, alpha * np.maximum(color_alpha, (m > 0.6)))
        al = alpha[..., None]
        rgb = np.clip(np.where(al > 0.02, (a - bg * (1 - al)) / np.maximum(al, 0.02), a), 0, 255)
        Image.fromarray(np.dstack([rgb, alpha * 255]).astype(np.uint8), 'RGBA').save(os.path.join(out_dir, name + '.png'))
        print(name)


if __name__ == '__main__':
    main()
