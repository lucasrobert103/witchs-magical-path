"""Real-ESRGAN (x4plus_anime_6B) inference in pure numpy.

Loads the official .pth checkpoint without PyTorch (zip + pickle with a stub
unpickler) and runs the RRDBNet forward pass with im2col convolutions.
Weights: https://github.com/xinntao/Real-ESRGAN/releases (BSD-3-Clause).
"""
import pickle
import sys
import zipfile

import numpy as np


class _Storage:
    def __init__(self, key, dtype):
        self.key = key
        self.dtype = dtype


def load_pth(path):
    z = zipfile.ZipFile(path)
    prefix = z.namelist()[0].split('/')[0]
    dtypes = {'FloatStorage': np.float32, 'HalfStorage': np.float16}

    class U(pickle.Unpickler):
        def find_class(self, mod, name):
            if name == '_rebuild_tensor_v2':
                def rebuild(storage, offset, size, stride, *a):
                    raw = np.frombuffer(z.read(f'{prefix}/data/{storage.key}'), dtype=storage.dtype)
                    n = int(np.prod(size)) if len(size) else 1
                    arr = np.lib.stride_tricks.as_strided(raw[offset:], shape=size, strides=[s * raw.itemsize for s in stride]) if n else raw[:0]
                    return np.array(arr, dtype=np.float32)
                return rebuild
            if name.endswith('Storage'):
                return name
            if name == 'OrderedDict':
                import collections
                return collections.OrderedDict
            return super().find_class(mod, name)

        def persistent_load(self, pid):
            _, storage_type, key, _loc, _n = pid
            st = storage_type if isinstance(storage_type, str) else str(storage_type)
            return _Storage(key, dtypes.get(st, np.float32))

    data = U(z.open(f'{prefix}/data.pkl')).load()
    if 'params_ema' in data:
        data = data['params_ema']
    elif 'params' in data:
        data = data['params']
    return data


def conv(x, w, b):
    # x: C,H,W ; w: O,C,3,3
    c, h, wd = x.shape
    xp = np.pad(x, ((0, 0), (1, 1), (1, 1)))
    cols = np.empty((c, 9, h, wd), dtype=np.float32)
    k = 0
    for dy in range(3):
        for dx in range(3):
            cols[:, k] = xp[:, dy:dy + h, dx:dx + wd]
            k += 1
    out = w.reshape(w.shape[0], -1) @ cols.reshape(c * 9, h * wd)
    return (out + b[:, None]).reshape(w.shape[0], h, wd)


def lrelu(x):
    return np.where(x > 0, x, x * 0.2)


def rdb(x, P, pre):
    x1 = lrelu(conv(x, P[pre + 'conv1.weight'], P[pre + 'conv1.bias']))
    x2 = lrelu(conv(np.concatenate([x, x1]), P[pre + 'conv2.weight'], P[pre + 'conv2.bias']))
    x3 = lrelu(conv(np.concatenate([x, x1, x2]), P[pre + 'conv3.weight'], P[pre + 'conv3.bias']))
    x4 = lrelu(conv(np.concatenate([x, x1, x2, x3]), P[pre + 'conv4.weight'], P[pre + 'conv4.bias']))
    x5 = conv(np.concatenate([x, x1, x2, x3, x4]), P[pre + 'conv5.weight'], P[pre + 'conv5.bias'])
    return x5 * 0.2 + x


def upscale(img, P, blocks=6):
    """img: H,W,3 float 0..1 -> 4H,4W,3"""
    x = img.transpose(2, 0, 1).astype(np.float32)
    feat = conv(x, P['conv_first.weight'], P['conv_first.bias'])
    body = feat
    for i in range(blocks):
        y = body
        for j in (1, 2, 3):
            y = rdb(y, P, f'body.{i}.rdb{j}.')
        body = y * 0.2 + body
    feat = feat + conv(body, P['conv_body.weight'], P['conv_body.bias'])
    for name in ('conv_up1', 'conv_up2'):
        feat = feat.repeat(2, axis=1).repeat(2, axis=2)
        feat = lrelu(conv(feat, P[name + '.weight'], P[name + '.bias']))
    out = conv(lrelu(conv(feat, P['conv_hr.weight'], P['conv_hr.bias'])), P['conv_last.weight'], P['conv_last.bias'])
    return np.clip(out.transpose(1, 2, 0), 0, 1)


if __name__ == '__main__':
    from PIL import Image
    P = load_pth(sys.argv[1])
    im = np.asarray(Image.open(sys.argv[2]).convert('RGB'), dtype=np.float32) / 255.0
    out = upscale(im, P)
    Image.fromarray((out * 255 + 0.5).astype(np.uint8)).save(sys.argv[3])
