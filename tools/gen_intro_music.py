"""Musique de l'intro (7,5 s, 150 BPM), calée sur la chorégraphie de hud/intro_choreo.gd → assets/music/intro.wav.

Montée (bruit filtré, roulement), combat (batterie, basse distordue en croches, stabs sur les coups), ralenti (tout
coupe : grave qui tombe, battements de cœur, souffle qui monte), coup final, impacts des lettres du titre, traîne.
"""
from pathlib import Path

import numpy as np
from scipy.io import wavfile

from gen_music import SR, hp, kick, lp, place, saw, snare, hat

OUT = Path(__file__).resolve().parent.parent / "assets" / "music" / "intro.wav"
BEAT = 0.4
LENGTH = 7.5
HITS = [0.8, 1.2, 1.72, 2.12]
SLOW = (3.3, 3.9)
TITLE = [4.6, 4.72, 4.84, 4.96]
RNG = np.random.default_rng(3)
A = 55.0


def noise(sec: float) -> np.ndarray:
    return RNG.uniform(-1, 1, int(SR * sec))


def riser(track: np.ndarray, start: float, sec: float, gain: float) -> None:
    n = noise(sec)
    t = np.arange(len(n)) / len(n)
    out = np.zeros_like(n)
    for i in range(8):
        seg = slice(i * len(n) // 8, (i + 1) * len(n) // 8)
        out[seg] = hp(n, 300 + 5000 * (i / 8) ** 2)[seg]
    place(track, out * t ** 2 * gain, start)


def boom(sec: float = 1.6) -> np.ndarray:
    t = np.arange(int(SR * sec)) / SR
    f = 30 + 90 * np.exp(-t * 6)
    return np.tanh(np.sin(2 * np.pi * np.cumsum(f) / SR) * 2.5) * np.exp(-t * 2.2)


def crash(sec: float = 2.0) -> np.ndarray:
    t = np.arange(int(SR * sec)) / SR
    return hp(noise(sec), 4000) * np.exp(-t * 2.5) * 0.5


def chord(root: float, sec: float, cutoff: float) -> np.ndarray:
    return sum(saw(root * 2 ** (i / 12), sec, cutoff) for i in (0, 7, 12, 15))


def fight(track: np.ndarray) -> None:
    riff = [0, 0, 12, 0, 3, 0, 7, 5]
    for b in range(6):
        t0 = 0.8 + b * BEAT
        place(track, kick(), t0)
        if b % 2 == 1:
            place(track, snare() * 0.7, t0)
        for s in range(2):
            place(track, hat(s == 1) * 0.8, t0 + s * BEAT / 2)
            semi = riff[(b * 2 + s) % len(riff)]
            place(track, np.tanh(saw(A * 2 ** (semi / 12), BEAT * 0.45, 900) * 3) * 0.3, t0 + s * BEAT / 2)
    for k in range(8):
        place(track, snare() * (0.15 + 0.07 * k), 0.8 + 6 * BEAT - 0.8 + k * 0.1)
    for h in HITS:
        place(track, chord(A * 4, 0.25, 3000) * 0.12, h)
        place(track, crash(0.5) * 0.5, h)


def slow(track: np.ndarray) -> None:
    place(track, lp(boom(2.0), 200) * 0.45, SLOW[0])
    for beat in (3.45, 3.62):
        place(track, lp(kick(), 300) * 0.8, beat)
    riser(track, SLOW[0], SLOW[1] - SLOW[0], 0.35)


def finale(track: np.ndarray) -> None:
    hit = SLOW[1]
    place(track, kick() * 1.2, hit)
    place(track, snare() * 1.0, hit)
    place(track, boom(1.5) * 0.8, hit)
    place(track, crash(2.5), hit)
    place(track, np.tanh(chord(A * 2, 0.6, 2000) * 2) * 0.18, hit)
    for i, t in enumerate(TITLE):
        place(track, kick() * 0.9, t)
        place(track, lp(snare(), 2500) * 0.6, t)
        tone = saw(A * 2 * 2 ** ([0, 3, 7, 12][i] / 12), 0.3, 1500)
        place(track, np.tanh(tone * 2) * 0.15, t)
    last = TITLE[-1]
    place(track, crash(3.0) * 1.2, last)
    place(track, boom(2.5) * 0.7, last)
    t = np.arange(int(SR * (LENGTH - last))) / SR
    tones = sum(np.sin(2 * np.pi * A * k * 2 ** (i / 12) * t) for i in (0, 7, 15) for k in (1, 2))
    drone = lp(np.tanh(tones * 0.8), 700) * np.exp(-t * 0.5) * 0.28
    place(track, drone, last)


def main() -> None:
    track = np.zeros(int(SR * (LENGTH + 2)))
    riser(track, 0.0, 0.8, 0.3)
    for k in range(12):
        place(track, snare() * (0.05 + 0.03 * k), 0.2 + k * 0.05)
    fight(track)
    slow(track)
    finale(track)
    track = track[: int(SR * LENGTH)]
    t = np.arange(len(track)) / SR
    track *= np.minimum((LENGTH - t) / 0.4, 1)
    y = np.tanh(track * 1.3)
    y = y / np.abs(y).max() * 0.9
    OUT.parent.mkdir(parents=True, exist_ok=True)
    wavfile.write(OUT, SR, (np.stack([y, y], 1) * 32767).astype(np.int16))
    print("intro →", OUT)


if __name__ == "__main__":
    main()
