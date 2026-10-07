"""Synthétise la musique de combat en boucle parfaite (numpy/scipy) → assets/music/combat.wav (mono 44,1 kHz)."""
from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SR = 44100
BPM = 124
BEAT = 60 / BPM
BARS = 16
OUT = Path(__file__).resolve().parent.parent / "assets" / "music"
RNG = np.random.default_rng(7)
# La mineur sombre : Am, F, Dm, E (fondamentales en Hz, octave basse)
CHORDS = [(110.0, [0, 3, 7]), (87.31, [0, 4, 7]), (73.42, [0, 3, 7]), (82.41, [0, 4, 7])]


def lp(x: np.ndarray, hz: float) -> np.ndarray:
    b, a = butter(2, hz / (SR / 2), "low")
    return lfilter(b, a, x)


def hp(x: np.ndarray, hz: float) -> np.ndarray:
    b, a = butter(2, hz / (SR / 2), "high")
    return lfilter(b, a, x)


def place(track: np.ndarray, sound: np.ndarray, at: float) -> None:
    i = int(at * SR)
    n = min(len(sound), len(track) - i)
    track[i: i + n] += sound[:n]


def kick() -> np.ndarray:
    t = np.arange(int(SR * 0.35)) / SR
    f = 45 + 110 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)


def snare() -> np.ndarray:
    t = np.arange(int(SR * 0.25)) / SR
    body = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25)
    return (hp(RNG.uniform(-1, 1, len(t)), 1500) * np.exp(-t * 16) * 0.8 + body * 0.5)


def hat(open_: bool = False) -> np.ndarray:
    t = np.arange(int(SR * (0.18 if open_ else 0.05))) / SR
    return hp(RNG.uniform(-1, 1, len(t)), 7000) * np.exp(-t * (14 if open_ else 70)) * 0.35


def saw(freq: float, sec: float, cutoff: float) -> np.ndarray:
    t = np.arange(int(SR * sec)) / SR
    x = sum(np.sin(2 * np.pi * freq * k * t) / k for k in range(1, 12)) * 0.5
    x += sum(np.sin(2 * np.pi * freq * 1.006 * k * t) / k for k in range(1, 12)) * 0.5
    env = np.minimum(t / 0.005, 1) * np.exp(-t * 3)
    return lp(x * env, cutoff)


def drums(track: np.ndarray) -> None:
    for bar in range(BARS):
        b0 = bar * 4 * BEAT
        for beat in range(4):
            place(track, kick() * 0.9, b0 + beat * BEAT)
            if beat in (1, 3) and bar >= 2:
                place(track, snare() * 0.55, b0 + beat * BEAT)
            for s in range(2):
                place(track, hat(s == 1 and beat == 3), b0 + (beat + s * 0.5) * BEAT)
        if bar % 4 == 3:
            place(track, kick() * 0.6, b0 + 3.75 * BEAT)


def bass_and_arp(track: np.ndarray) -> None:
    for bar in range(BARS):
        root, intervals = CHORDS[bar % 4]
        b0 = bar * 4 * BEAT
        open_ = 400 + 1400 * (bar % 8) / 7
        for step in range(8):
            place(track, saw(root, BEAT * 0.45, open_) * 0.45, b0 + step * BEAT * 0.5)
        if bar >= 4:
            for step in range(16):
                semi = intervals[step % 3] + 12 * (1 + (step // 3) % 2)
                f = root * 2 ** (semi / 12) * 2
                place(track, saw(f, BEAT * 0.22, 2600) * 0.12, b0 + step * BEAT * 0.25)


def pad(track: np.ndarray) -> None:
    t_bar = np.arange(int(SR * 4 * BEAT)) / SR
    for bar in range(BARS):
        root, intervals = CHORDS[bar % 4]
        chord = sum(np.sin(2 * np.pi * root * 4 * 2 ** (i / 12) * t_bar + 0.3 * np.sin(2 * np.pi * 0.5 * t_bar))
                    for i in intervals)
        env = np.minimum(t_bar / 0.4, 1) * np.minimum((t_bar[-1] - t_bar) / 0.3, 1)
        place(track, lp(chord * env, 1800) * 0.07, bar * 4 * BEAT)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    total = BARS * 4 * BEAT
    track = np.zeros(int(SR * total) + SR)
    drums(track)
    bass_and_arp(track)
    pad(track)
    n = int(SR * total)
    tail = track[n:]
    track = track[:n]
    track[: len(tail)] += tail
    track = np.tanh(track * 1.2)
    track = track / np.abs(track).max() * 0.85
    wavfile.write(OUT / "combat.wav", SR, (track * 32767).astype(np.int16))
    print(f"musique {total:.1f}s -> {OUT / 'combat.wav'}")


if __name__ == "__main__":
    main()
