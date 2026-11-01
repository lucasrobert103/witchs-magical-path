#!/usr/bin/env python3
"""Original, deterministic soundtrack and sound effects for Asterion.

Everything is synthesized from scratch with numpy (no samples). Music loops are
rendered with their reverb tail folded back to the start so they loop cleanly.
Requires: numpy, ffmpeg (for Ogg Vorbis encoding).

    python3 tools/audio/generate_audio.py
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'audio'))
SR = 32000
RNG = np.random.default_rng(20261031)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def env_adsr(n, a, d, s, r, sr=SR):
    a, d, r = int(a * sr), int(d * sr), int(r * sr)
    sus = max(0, n - a - d - r)
    e = np.concatenate([
        np.linspace(0, 1, max(a, 1), endpoint=False),
        np.linspace(1, s, max(d, 1), endpoint=False),
        np.full(sus, s),
        np.linspace(s, 0, max(r, 1)),
    ])
    return e[:n] if len(e) >= n else np.pad(e, (0, n - len(e)))


def lowpass(x, cutoff, sr=SR):
    # One-pole low-pass, vectorized through FFT for speed on long buffers.
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / sr)
    H = 1 / np.sqrt(1 + (f / cutoff) ** 4)
    return np.fft.irfft(X * H, len(x))


def bandpass(x, lo, hi, sr=SR):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / sr)
    H = 1 / np.sqrt(1 + (f / hi) ** 4) * (1 - 1 / np.sqrt(1 + (f / max(lo, 1)) ** 4))
    return np.fft.irfft(X * H, len(x))


def fft_convolve(a, b):
    n = len(a) + len(b) - 1
    N = 1 << (n - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(a, N) * np.fft.rfft(b, N), N)[:n]


def reverb(stereo, seconds=3.2, decay=0.9, wet=0.35, sr=SR):
    n = int(seconds * sr)
    t = np.arange(n) / sr
    out = []
    for ch in range(2):
        ir = RNG.standard_normal(n) * np.exp(-t / decay)
        ir = lowpass(ir, 5200)
        ir[: int(0.012 * sr)] *= np.linspace(0, 1, int(0.012 * sr))
        ir /= np.sqrt(np.sum(ir ** 2))
        out.append(fft_convolve(stereo[:, ch], ir))
    wetsig = np.stack(out, axis=1)
    dry = np.zeros_like(wetsig)
    dry[: len(stereo)] = stereo
    return dry * (1 - wet) + wetsig * wet * 1.6


def fold_loop(buf, length):
    """Fold everything past `length` back onto the start for a seamless loop."""
    out = buf[:length].copy()
    tail = buf[length:]
    while len(tail):
        k = min(len(tail), length)
        out[:k] += tail[:k]
        tail = tail[k:]
    return out


def place(buf, sig, start, pan=0.0, gain=1.0):
    s = int(start * SR)
    if s >= len(buf):
        return
    e = min(len(buf), s + len(sig))
    l = np.cos((pan + 1) * np.pi / 4) * gain
    r = np.sin((pan + 1) * np.pi / 4) * gain
    buf[s:e, 0] += sig[: e - s] * l
    buf[s:e, 1] += sig[: e - s] * r


# ----------------------------------------------------------------- instruments
def pluck(freq, dur=3.0, bright=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for k in range(1, 12):
        f = freq * k * (1 + 0.0004 * k * k)
        if f > SR / 2.2:
            break
        amp = (1 / k ** 1.4) * (bright if k > 3 else 1)
        s += amp * np.sin(2 * np.pi * f * t + RNG.random() * 0.3) * np.exp(-t * (1.1 + k * 0.55))
    s *= np.minimum(1, t / 0.003)
    return s * 0.5


def pad(freqs, dur, attack=1.6, release=2.2, bright=0.5):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for f in freqs:
        for det in (-0.12, 0.0, 0.13):
            ff = f * 2 ** (det / 12)
            lfo = 1 + 0.002 * np.sin(2 * np.pi * (0.2 + RNG.random() * 0.2) * t)
            for k, a in ((1, 1.0), (2, 0.35 * bright), (3, 0.18 * bright), (4, 0.08 * bright)):
                s += a * np.sin(2 * np.pi * ff * k * t * lfo + RNG.random() * 6)
    s *= env_adsr(n, attack, 0.5, 0.85, release)
    return s / (len(freqs) * 3) * 0.6


def flute(freq, dur, vib=5.2):
    n = int(dur * SR)
    t = np.arange(n) / SR
    v = 1 + 0.006 * np.sin(2 * np.pi * vib * t) * np.minimum(1, t / 0.4)
    phase = 2 * np.pi * np.cumsum(freq * v) / SR
    s = np.sin(phase) + 0.18 * np.sin(2 * phase) + 0.06 * np.sin(3 * phase)
    breath = lowpass(RNG.standard_normal(n), 2500) * 0.05
    s = (s + breath) * env_adsr(n, 0.09, 0.2, 0.75, min(0.5, dur * 0.4))
    return s * 0.32


def bell(freq, dur=4.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for ratio, amp, dec in ((1, 1, 1.2), (2.76, 0.45, 2.2), (5.40, 0.25, 3.5), (8.93, 0.12, 5.0), (0.5, 0.3, 0.8)):
        s += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t * dec)
    return s * np.minimum(1, t / 0.002) * 0.25


def choir(freqs, dur, vowel='a'):
    n = int(dur * SR)
    t = np.arange(n) / SR
    src = np.zeros(n)
    for f in freqs:
        for det in (-0.08, 0.07):
            ff = f * 2 ** (det / 12) * (1 + 0.004 * np.sin(2 * np.pi * 4.8 * t + RNG.random() * 6))
            ph = 2 * np.pi * np.cumsum(ff) / SR
            # band-limited saw approximation
            for k in range(1, 18):
                if f * k > SR / 2.5:
                    break
                src += np.sin(k * ph) / k
    formants = {'a': (800, 1150, 2900), 'o': (450, 800, 2830), 'u': (325, 700, 2530)}[vowel]
    out = np.zeros(n)
    for i, fc in enumerate(formants):
        out += bandpass(src, fc * 0.8, fc * 1.2) * (1.0, 0.5, 0.25)[i]
    out *= env_adsr(n, 2.0, 0.5, 0.9, 2.5)
    return out / (len(freqs) * 6)


# ----------------------------------------------------------------- music
def forest_theme():
    bpm = 74
    beat = 60 / bpm
    bar = beat * 4
    # D dorian: i9 - VII - VI - VII / i - iv - VII - III
    prog = [
        ([50, 57, 60, 64, 69], [62, 65, 69, 72]),
        ([48, 55, 59, 64], [60, 64, 67, 71]),
        ([46, 53, 57, 62], [58, 62, 65, 69]),
        ([48, 55, 60, 64], [60, 64, 67, 72]),
        ([50, 57, 62, 65], [62, 65, 69, 74]),
        ([43, 50, 55, 58], [55, 58, 62, 67]),
        ([48, 55, 59, 64], [60, 64, 67, 71]),
        ([45, 52, 57, 61], [57, 61, 64, 69]),
    ]
    bars = len(prog) * 2
    length = bars * bar
    buf = np.zeros((int((length + 5) * SR), 2))
    melody = [
        # (bar, beat, midi, beats)
        (0, 0, 74, 1.5), (0, 1.5, 72, 0.5), (0, 2, 69, 2), (1, 0, 67, 1), (1, 1, 69, 1), (1, 2, 71, 2),
        (2, 0, 69, 3), (2, 3, 65, 1), (3, 0, 67, 4),
        (4, 0, 74, 1.5), (4, 1.5, 76, 0.5), (4, 2, 77, 2), (5, 0, 74, 2), (5, 2, 70, 2),
        (6, 0, 72, 1), (6, 1, 71, 1), (6, 2, 67, 2), (7, 0, 69, 4),
        (10, 0, 81, 2), (10, 2, 77, 2), (11, 0, 79, 1), (11, 1, 77, 1), (11, 2, 76, 2),
        (12, 0, 74, 3), (12, 3, 72, 1), (13, 0, 70, 2), (13, 2, 69, 2), (14, 0, 67, 2), (14, 2, 71, 2), (15, 0, 69, 4),
    ]
    for b in range(bars):
        low, arp = prog[b % len(prog)]
        t0 = b * bar
        place(buf, pad([midi(n) for n in low[1:]], bar + 2.4, attack=1.2, release=2.0, bright=0.4), t0, 0, 0.55)
        place(buf, pluck(midi(low[0] - 12), 4.0, 0.6) * 0.9, t0, -0.1, 0.8)
        # harp arpeggio in eighths with a gentle swing
        pattern = [0, 1, 2, 3, 2, 1, 2, 3] if b % 2 == 0 else [0, 2, 1, 3, 2, 3, 1, 2]
        for i, idx in enumerate(pattern):
            if b < 2 and i % 2:
                continue
            tt = t0 + i * beat / 2 + (0.03 if i % 2 else 0)
            note = arp[idx] + (12 if (b >= 8 and i == 7) else 0)
            place(buf, pluck(midi(note), 2.4, 0.8), tt, -0.4 + 0.8 * (idx / 3), 0.32)
    for (b, bt, n, dur) in melody:
        place(buf, flute(midi(n), dur * beat + 0.1), b * bar + bt * beat, 0.15, 0.55)
    for b in (3, 7, 11, 15):
        place(buf, bell(midi(86), 4.5), b * bar + 3 * beat, 0.5, 0.25)
    wet = reverb(buf, 3.6, 1.1, 0.38)
    return fold_loop(wet, int(length * SR))


def prologue_theme():
    # Slow, cosmic: drones, choir swells, bells. A minor / F lydian colors.
    length = 96.0
    buf = np.zeros((int((length + 6) * SR), 2))
    chords = [
        ([45, 52, 57, 64], 'o'), ([41, 48, 57, 60, 67], 'a'), ([43, 50, 55, 62, 71], 'a'), ([40, 47, 55, 59, 64], 'u'),
        ([45, 52, 60, 64, 71], 'o'), ([41, 48, 55, 64, 69], 'a'), ([38, 45, 53, 57, 64], 'o'), ([40, 47, 56, 59, 64], 'u'),
    ]
    step = length / len(chords)
    for i, (notes, v) in enumerate(chords):
        t0 = i * step
        place(buf, pad([midi(n) for n in notes[:2]], step + 4, 3.0, 3.5, 0.25), t0, 0, 0.7)
        place(buf, choir([midi(n) for n in notes[2:]], step + 3.5, v), t0 + 0.5, 0, 1.2)
        for k in range(3):
            n = notes[-1] + 12 + (0, 7, 12)[k]
            place(buf, bell(midi(n), 5), t0 + 2 + k * step / 3.2, (-0.5, 0.4, 0.0)[k], 0.16)
    # low drone
    t = np.arange(len(buf)) / SR
    drone = 0.05 * np.sin(2 * np.pi * midi(33) * t) * (0.8 + 0.2 * np.sin(2 * np.pi * 0.05 * t))
    buf[:, 0] += drone
    buf[:, 1] += drone
    wet = reverb(buf, 5.0, 1.8, 0.55)
    return fold_loop(wet, int(length * SR))


def ambience():
    length = 40.0
    n = int(length * SR)
    buf = np.zeros((n + int(4 * SR), 2))
    t = np.arange(len(buf)) / SR
    for ch in range(2):
        wind = lowpass(RNG.standard_normal(len(buf)), 420)
        gust = 0.55 + 0.45 * np.sin(2 * np.pi * (0.05 + ch * 0.013) * t + ch) ** 2
        leaves = bandpass(RNG.standard_normal(len(buf)), 2500, 7000) * (0.25 + 0.75 * np.clip(np.sin(2 * np.pi * 0.07 * t + ch * 2), 0, 1) ** 3)
        buf[:, ch] += wind * gust * 0.12 + leaves * 0.012
    # birds: short FM chirps
    for _ in range(26):
        start = RNG.random() * (length - 2)
        base = 2600 + RNG.random() * 1800
        notes = RNG.integers(2, 6)
        pan = RNG.random() * 1.6 - 0.8
        for k in range(notes):
            d = 0.07 + RNG.random() * 0.08
            m = int(d * SR)
            tt = np.arange(m) / SR
            sweep = base * (1 + (RNG.random() - 0.3) * 0.5 * tt / d)
            ph = 2 * np.pi * np.cumsum(sweep) / SR
            sig = np.sin(ph + 2.0 * np.sin(2 * np.pi * 70 * tt)) * np.sin(np.pi * tt / d) ** 2
            place(buf, sig * 0.05, start + k * (d + 0.03), pan)
    wet = reverb(buf, 2.5, 0.8, 0.3)
    return fold_loop(wet, n)


# ----------------------------------------------------------------- sfx
def sfx_cast():
    d = 0.9
    n = int(d * SR)
    t = np.arange(n) / SR
    whoosh = bandpass(RNG.standard_normal(n), 600, 3500) * np.sin(np.pi * np.minimum(1, t / 0.5)) ** 2 * np.exp(-t * 3)
    shimmer = sum(np.sin(2 * np.pi * midi(n0) * t) * np.exp(-t * (4 + i)) for i, n0 in enumerate((81, 88, 93, 100)))
    sweep = np.sin(2 * np.pi * np.cumsum(400 + 1400 * t / d) / SR) * np.exp(-t * 5) * 0.4
    return (whoosh * 0.6 + shimmer * 0.18 + sweep * 0.3)


def sfx_hit():
    d = 0.7
    n = int(d * SR)
    t = np.arange(n) / SR
    thump = np.sin(2 * np.pi * (180 * np.exp(-t * 8) + 60) * t) * np.exp(-t * 9)
    crack = bandpass(RNG.standard_normal(n), 1500, 8000) * np.exp(-t * 25)
    sparkle = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * 7) for f in (1760, 2637, 3520)) * 0.15
    return thump * 0.7 + crack * 0.5 + sparkle


def sfx_pickup():
    d = 1.4
    out = np.zeros(int(d * SR))
    for i, n0 in enumerate((76, 81, 84, 88, 93)):
        b = bell(midi(n0), d - i * 0.07)
        s = int(i * 0.07 * SR)
        out[s:s + len(b)] += b[: len(out) - s]
    return out * 1.4


def sfx_pool():
    d = 1.8
    n = int(d * SR)
    t = np.arange(n) / SR
    bloop = np.sin(2 * np.pi * np.cumsum(300 + 900 * np.exp(-t * 12)) / SR) * np.exp(-t * 6)
    shimmer = sum(np.sin(2 * np.pi * midi(n0) * t) * np.exp(-t * 2.2) * np.minimum(1, t / 0.3) for n0 in (74, 79, 86, 91)) * 0.12
    water = bandpass(RNG.standard_normal(n), 800, 4000) * np.exp(-t * 4) * 0.15
    return bloop * 0.5 + shimmer + water


def sfx_rune():
    d = 2.6
    n = int(d * SR)
    t = np.arange(n) / SR
    low = np.sin(2 * np.pi * 55 * t) * np.exp(-t * 1.2) * np.minimum(1, t / 0.05)
    swell = sum(np.sin(2 * np.pi * midi(n0) * t) for n0 in (62, 69, 74, 78)) * np.sin(np.pi * np.minimum(1, t / d)) * 0.12
    b = bell(midi(86), d) * 0.8
    return low * 0.6 + swell + b


def sfx_gate():
    d = 4.5
    n = int(d * SR)
    t = np.arange(n) / SR
    rumble = lowpass(RNG.standard_normal(n), 120) * np.sin(np.pi * np.minimum(1, t / 3.5)) * 1.6
    grind = bandpass(RNG.standard_normal(n), 200, 900) * np.sin(np.pi * np.minimum(1, t / 3.0)) * 0.25
    ch = choir([midi(n0) for n0 in (57, 64, 69, 73)], d, 'a') * 1.6
    return rumble * 0.6 + grind + ch


def sfx_step(seed):
    r = np.random.default_rng(seed)
    d = 0.16
    n = int(d * SR)
    t = np.arange(n) / SR
    s = bandpass(r.standard_normal(n), 200 + seed * 40, 2600) * np.exp(-t * 38)
    s += np.sin(2 * np.pi * (90 + seed * 5) * t) * np.exp(-t * 45) * 0.6
    return s * 0.6


def sfx_jump():
    d = 0.35
    n = int(d * SR)
    t = np.arange(n) / SR
    return bandpass(RNG.standard_normal(n), 400, 2400) * np.sin(np.pi * t / d) ** 2 * 0.35


def sfx_land():
    d = 0.3
    n = int(d * SR)
    t = np.arange(n) / SR
    return (bandpass(RNG.standard_normal(n), 120, 1500) * np.exp(-t * 18) + np.sin(2 * np.pi * 70 * t) * np.exp(-t * 20)) * 0.6


def sfx_hurt():
    d = 0.5
    n = int(d * SR)
    t = np.arange(n) / SR
    thud = np.sin(2 * np.pi * (220 * np.exp(-t * 6) + 80) * t) * np.exp(-t * 7)
    dark = bandpass(RNG.standard_normal(n), 100, 900) * np.exp(-t * 6) * 0.5
    return thud * 0.7 + dark


def sfx_shade_die():
    d = 1.2
    n = int(d * SR)
    t = np.arange(n) / SR
    puff = bandpass(RNG.standard_normal(n), 150, 1800) * np.exp(-t * 4)
    fall = np.sin(2 * np.pi * np.cumsum(500 * np.exp(-t * 3) + 60) / SR) * np.exp(-t * 3) * 0.4
    chime = sum(np.sin(2 * np.pi * midi(n0) * t) * np.exp(-t * 3) * np.minimum(1, t / 0.2) for n0 in (79, 86)) * 0.12
    return puff * 0.5 + fall + chime


def sfx_shade_alert():
    d = 0.9
    n = int(d * SR)
    t = np.arange(n) / SR
    s = np.sin(2 * np.pi * np.cumsum(140 + 60 * np.sin(2 * np.pi * 6 * t)) / SR) * np.sin(np.pi * t / d)
    s += bandpass(RNG.standard_normal(n), 300, 1200) * np.sin(np.pi * t / d) * 0.3
    return s * 0.4


def sfx_ui(kind):
    d = 0.25 if kind == 'click' else 0.6
    n = int(d * SR)
    t = np.arange(n) / SR
    if kind == 'click':
        return np.sin(2 * np.pi * 1320 * t) * np.exp(-t * 30) * 0.4 + np.sin(2 * np.pi * 1980 * t) * np.exp(-t * 40) * 0.2
    return sum(np.sin(2 * np.pi * midi(n0) * t) * np.exp(-t * 5) * np.minimum(1, t / 0.01) for n0 in (72, 79, 84)) * 0.2


def sfx_heal():
    d = 1.6
    n = int(d * SR)
    t = np.arange(n) / SR
    s = sum(np.sin(2 * np.pi * midi(n0) * t) * np.sin(np.pi * np.minimum(1, t / d)) for n0 in (69, 73, 76, 81)) * 0.12
    return s + bell(midi(93), d) * 0.4


def sfx_essence(base):
    d = 1.5
    n = int(d * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for i, n0 in enumerate((base, base + 7, base + 12, base + 19)):
        st = int(i * 0.09 * SR)
        tt = t[: n - st]
        s[st:] += np.sin(2 * np.pi * midi(n0) * tt) * np.exp(-tt * 2.5) * np.minimum(1, tt / 0.02)
    sweep = bandpass(RNG.standard_normal(n), 2000, 9000) * np.sin(np.pi * t / d) ** 3 * 0.2
    return s * 0.2 + sweep


def sfx_victory():
    d = 5.0
    out = np.zeros(int(d * SR))
    seq = (62, 66, 69, 74, 78, 81)
    for i, n0 in enumerate(seq):
        p = pluck(midi(n0), d - i * 0.12, 1.0)
        s = int(i * 0.12 * SR)
        out[s:s + len(p)] += p[: len(out) - s] * 0.8
    c = choir([midi(n0) for n0 in (62, 69, 74, 78)], d, 'a') * 2.0
    return out + c[: len(out)]


def sfx_wake():
    d = 3.5
    n = int(d * SR)
    t = np.arange(n) / SR
    s = sum(np.sin(2 * np.pi * midi(n0) * t) * np.sin(np.pi * np.minimum(1, t / d)) ** 2 for n0 in (57, 64, 69, 76)) * 0.1
    return s + bell(midi(88), d) * 0.3


# ----------------------------------------------------------------- output
def normalize(x, peak=0.89):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def write_wav(path, data, sr=SR):
    data = normalize(data)
    if data.ndim == 1:
        data = data[:, None]
    pcm = (np.clip(data, -1, 1) * 32767).astype('<i2')
    with wave.open(path, 'wb') as w:
        w.setnchannels(pcm.shape[1])
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


def write_ogg(path, data, quality=4):
    with tempfile.TemporaryDirectory() as tmp:
        tmpwav = os.path.join(tmp, 'x.wav')
        write_wav(tmpwav, data)
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmpwav, '-c:a', 'libvorbis', '-q:a', str(quality), path], check=True)


def main():
    os.makedirs(os.path.join(ROOT, 'sfx'), exist_ok=True)
    music = {
        'music_forest.ogg': forest_theme,
        'music_prologue.ogg': prologue_theme,
        'ambience_forest.ogg': ambience,
    }
    for name, fn in music.items():
        write_ogg(os.path.join(ROOT, name), fn())
        print(name)
    sfx = {
        'cast': sfx_cast(), 'hit': sfx_hit(), 'pickup': sfx_pickup(), 'pool': sfx_pool(), 'rune': sfx_rune(),
        'gate': sfx_gate(), 'jump': sfx_jump(), 'land': sfx_land(), 'hurt': sfx_hurt(), 'shade_die': sfx_shade_die(),
        'shade_alert': sfx_shade_alert(), 'click': sfx_ui('click'), 'open': sfx_ui('open'), 'heal': sfx_heal(),
        'essence_moon': sfx_essence(69), 'essence_flame': sfx_essence(64), 'victory': sfx_victory(), 'wake': sfx_wake(),
    }
    for i in range(4):
        sfx[f'step{i}'] = sfx_step(i + 1)
    for name, data in sfx.items():
        write_wav(os.path.join(ROOT, 'sfx', name + '.wav'), data, SR)
    print(len(sfx), 'sfx')


if __name__ == '__main__':
    main()
