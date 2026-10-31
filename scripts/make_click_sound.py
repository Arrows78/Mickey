#!/usr/bin/env python3
"""Synthesizes the default click sound (App/Resources/click.wav) from scratch.

A ~45 ms mono click: a short filtered noise transient followed by a fast-decaying 2.2 kHz tone.
Deterministic (fixed seed) so the asset is reproducible.
"""
import math
import random
import struct
import sys
import wave

RATE = 44100
DURATION = 0.045


def samples():
    rng = random.Random(7)
    n = int(RATE * DURATION)
    prev = 0.0
    for i in range(n):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        prev = 0.6 * prev + 0.4 * noise  # gentle low-pass to soften the transient
        transient = prev * math.exp(-t / 0.002)
        tone = math.sin(2 * math.pi * 2200 * t) * math.exp(-t / 0.008)
        body = math.sin(2 * math.pi * 700 * t) * math.exp(-t / 0.012) * 0.4
        fade = min(1.0, (n - i) / (RATE * 0.005))
        yield (0.55 * transient + 0.35 * tone + 0.25 * body) * fade


def main(path):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples()))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "App/Resources/click.wav")
