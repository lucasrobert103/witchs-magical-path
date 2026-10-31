#!/usr/bin/env python3
"""Synthesize Asterion's original quiet forest loop, using only Python stdlib.

No sampled instruments, recordings, external assets or borrowed melodies.
The circular score and delay tails make the 28-second PCM file loop cleanly.
"""

from array import array
import math
from pathlib import Path
import random
import struct
import wave

RATE = 22050
DURATION = 28.0
FRAMES = int(RATE * DURATION)
TAU = math.tau
RNG = random.Random(731098)


def frequency(midi):
    return 440.0 * 2.0 ** ((midi - 69.0) / 12.0)


def add_note(left, right, start, duration, midi, gain, pan=0.0, kind="flute"):
    """Write envelopes into a circular buffer, including tails crossing its end."""
    freq = frequency(midi)
    phase = RNG.random() * TAU
    left_gain = math.sqrt((1.0 - pan) * 0.5) * gain
    right_gain = math.sqrt((1.0 + pan) * 0.5) * gain
    offset = int(start * RATE)
    for frame in range(int(duration * RATE)):
        t = frame / RATE
        progress = t / duration
        if kind == "flute":
            # Slow breath-in and a rounded tail prevent the sound of a pure beep.
            attack = min(t / 0.28, 1.0)
            release = min((duration - t) / 0.72, 1.0)
            envelope = math.sin(attack * math.pi * 0.5) ** 2 * release ** 1.5
            vibrato = 0.0038 * math.sin(TAU * 4.7 * t) * min(t, 1.0)
            angle = TAU * freq * t + phase + vibrato * math.sin(TAU * 1.7 * t)
            sample = (math.sin(angle) + 0.075 * math.sin(angle * 2.0 + 0.2)
                      + 0.025 * math.sin(angle * 3.0)) * envelope
        else:
            attack = min(t / 0.018, 1.0)
            envelope = attack * math.exp(-3.8 * progress) * (1.0 - progress) ** 1.8
            angle = TAU * freq * t + phase
            sample = (math.sin(angle) + math.sin(angle * 2.002) * 0.28
                      + math.sin(angle * 3.003) * 0.09) * envelope
        index = (offset + frame) % FRAMES
        left[index] += sample * left_gain
        right[index] += sample * right_gain


def synthesize():
    left = array("d", [0.0]) * FRAMES
    right = array("d", [0.0]) * FRAMES
    # Four spacious voicings. Raised ninths keep the harmony open and unhurried.
    chords = ((50, 57, 64, 65), (48, 55, 62, 64),
              (53, 60, 67, 69), (45, 52, 59, 62))
    wind_left = wind_right = 0.0
    for frame in range(FRAMES):
        t = frame / RATE
        # Low-pass correlated noise is a breeze, rather than white-noise hiss.
        wind_left = 0.997 * wind_left + 0.003 * RNG.uniform(-1.0, 1.0)
        wind_right = 0.997 * wind_right + 0.003 * RNG.uniform(-1.0, 1.0)
        breeze = 0.65 + 0.35 * math.sin(TAU * t / DURATION * 2.0 + 0.7)
        left[frame] = wind_left * 0.23 * breeze
        right[frame] = wind_right * 0.23 * breeze
        for chord_index, chord in enumerate(chords):
            centre = chord_index * 7.0 + 3.5
            distance = min(abs(t - centre), DURATION - abs(t - centre))
            weight = max(0.0, math.cos(min(distance / 7.0, 1.0) * math.pi * 0.5)) ** 2
            if weight < 0.0001:
                continue
            for voice, midi in enumerate(chord):
                # Exact integer loop cycles keep the sustained bed phase-continuous.
                freq = round(frequency(midi) * DURATION) / DURATION
                phase = voice * 1.13 + chord_index * 0.41
                fundamental = math.sin(TAU * freq * t + phase)
                overtone = math.sin(TAU * freq * 2.0 * t + phase) * 0.06
                tone = (fundamental + overtone) * weight * 0.009
                pan = (-0.45, 0.35, -0.18, 0.50)[voice]
                left[frame] += tone * (1.0 - pan)
                right[frame] += tone * (1.0 + pan)

    # An original, sparse eight-note flute line; rests carry much of the piece.
    for start, duration, note, gain, pan in (
        (1.8, 2.4, 74, 0.073, -0.16), (5.7, 1.8, 69, 0.060, 0.10),
        (9.2, 2.8, 72, 0.071, 0.18), (13.0, 1.9, 76, 0.058, -0.12),
        (17.0, 2.7, 67, 0.067, -0.20), (20.8, 3.1, 69, 0.062, 0.16),
        (24.5, 2.1, 65, 0.058, -0.12), (26.4, 1.8, 64, 0.048, 0.12),
    ):
        add_note(left, right, start, duration, note, gain, pan)

    # Quiet harp responses, separated from the flute and each other.
    for chord_index, chord in enumerate(chords):
        for step, voice in enumerate((0, 2, 1)):
            add_note(left, right, chord_index * 7.0 + step * 0.74,
                     3.2, chord[voice] + 12, 0.037 - step * 0.004,
                     -0.44 + step * 0.40, "harp")

    # Three distant, soft two-part calls. These are synthesized, not recordings.
    for start, pitch, pan in ((4.4, 1640.0, 0.65), (15.2, 1860.0, -0.60), (23.2, 1530.0, 0.60)):
        for frame in range(int(0.45 * RATE)):
            t = frame / RATE
            envelope = math.sin(math.pi * t / 0.45) ** 4
            angle = TAU * (pitch * t + 180.0 * t * t) + math.sin(TAU * 17 * t) * 0.15
            sample = math.sin(angle) * envelope * 0.008
            index = (int(start * RATE) + frame) % FRAMES
            left[index] += sample * (1.0 - pan)
            right[index] += sample * (1.0 + pan)

    # Circular cross-channel early reflections. Never cuts off a note at the seam.
    dry_left, dry_right = left[:], right[:]
    for delay, amount in ((0.183, 0.15), (0.427, 0.12), (0.793, 0.085), (1.213, 0.055)):
        offset = int(delay * RATE)
        for frame in range(FRAMES):
            previous = (frame - offset) % FRAMES
            left[frame] += dry_right[previous] * amount
            right[frame] += dry_left[previous] * amount

    # Only the low noise component lacks a periodic oscillator. A very short
    # equal-power seam blend removes its subaudible discontinuity as well.
    seam = int(0.06 * RATE)
    for channel in (left, right):
        seam_value = (channel[-1] + channel[0]) * 0.5
        for frame in range(seam):
            weight = 0.5 - 0.5 * math.cos(math.pi * frame / seam)
            channel[frame] = seam_value * (1.0 - weight) + channel[frame] * weight
            end = FRAMES - 1 - frame
            channel[end] = seam_value * (1.0 - weight) + channel[end] * weight

    peak = max(max(abs(x) for x in left), max(abs(x) for x in right))
    gain = 0.42 / max(peak, 0.0001)
    pcm = bytearray(FRAMES * 4)
    squared = 0.0
    for frame in range(FRAMES):
        lvalue = left[frame] * gain
        rvalue = right[frame] * gain
        squared += lvalue * lvalue + rvalue * rvalue
        struct.pack_into("<hh", pcm, frame * 4, round(lvalue * 32767), round(rvalue * 32767))
    path = Path(__file__).resolve().parents[1] / "assets/audio/forest_theme.wav"
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm)
    rms = math.sqrt(squared / (FRAMES * 2))
    print(f"Wrote {path}: {FRAMES} stereo frames @ {RATE} Hz, {DURATION:.1f}s")
    print(f"Peak: {peak * gain:.4f}; RMS: {rms:.4f}; bytes: {path.stat().st_size}")
    print("Godot WAV loop: LOOP_FORWARD, loop_begin=0, loop_end=617400")


if __name__ == "__main__":
    synthesize()
