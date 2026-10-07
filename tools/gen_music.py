"""Synthétise la musique en trois couches synchrones, en boucle parfaite (numpy/scipy) → assets/music/*.wav.

calme (nappe, basse tenue, shaker), combat (batterie, basse, arpège), tension (dernier debout : pulsation,
roulements, stabs). Les couches partagent tempo et longueur ; le jeu les mélange selon l'action.
"""
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


def bass_hold(track: np.ndarray) -> None:
    t_bar = np.arange(int(SR * 4 * BEAT)) / SR
    for bar in range(BARS):
        root, _ = CHORDS[bar % 4]
        env = np.minimum(t_bar / 0.08, 1) * np.minimum((t_bar[-1] - t_bar) / 0.2, 1)
        tone = np.sin(2 * np.pi * root * t_bar) + 0.3 * np.sin(2 * np.pi * root * 2 * t_bar)
        place(track, lp(tone * env, 400) * 0.22, bar * 4 * BEAT)


def shaker(track: np.ndarray) -> None:
    for bar in range(BARS):
        for step in range(8):
            place(track, hat() * (0.35 if step % 2 else 0.18), bar * 4 * BEAT + step * BEAT * 0.5)


def pulse(track: np.ndarray) -> None:
    """Dernier debout : doubles croches graves, roulements de caisse, stabs aigus dissonants à contretemps."""
    for bar in range(BARS):
        root, intervals = CHORDS[bar % 4]
        b0 = bar * 4 * BEAT
        for step in range(16):
            acc = 1.0 if step % 4 == 0 else 0.55
            place(track, saw(root * 2, BEAT * 0.2, 900 + 300 * (step % 4)) * 0.22 * acc, b0 + step * BEAT * 0.25)
        for beat in (1.5, 3.5):
            f = root * 8 * 2 ** (intervals[1] / 12)
            stab = saw(f, BEAT * 0.3, 4200) + saw(f * 2 ** (1 / 12), BEAT * 0.3, 4200) * 0.6
            place(track, stab * 0.1, b0 + beat * BEAT)
        if bar % 2 == 1:
            for k in range(8):
                place(track, snare() * (0.12 + 0.05 * k), b0 + (2 + k * 0.25) * BEAT)


def pad(track: np.ndarray) -> None:
    t_bar = np.arange(int(SR * 4 * BEAT)) / SR
    for bar in range(BARS):
        root, intervals = CHORDS[bar % 4]
        chord = sum(np.sin(2 * np.pi * root * 4 * 2 ** (i / 12) * t_bar + 0.3 * np.sin(2 * np.pi * 0.5 * t_bar))
                    for i in intervals)
        env = np.minimum(t_bar / 0.4, 1) * np.minimum((t_bar[-1] - t_bar) / 0.3, 1)
        place(track, lp(chord * env, 1800) * 0.07, bar * 4 * BEAT)


LAYERS = {
    "calme": [pad, bass_hold, shaker],
    "combat": [drums, bass_and_arp],
    "tension": [pulse],
}


def render(parts: list) -> np.ndarray:
    total = BARS * 4 * BEAT
    track = np.zeros(int(SR * total) + SR)
    for fn in parts:
        fn(track)
    n = int(SR * total)
    tail = track[n:]
    track = track[:n]
    track[: len(tail)] += tail
    return track


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    layers = {name: render(parts) for name, parts in LAYERS.items()}
    gain = 0.85 / np.abs(np.tanh(sum(layers.values()) * 1.2)).max()
    for name, x in layers.items():
        y = np.tanh(x * 1.2) * gain
        wavfile.write(OUT / f"{name}.wav", SR, (np.clip(y, -1, 1) * 32767).astype(np.int16))
    print(f"musique {BARS * 4 * BEAT:.1f}s, couches {list(layers)} -> {OUT}")


if __name__ == "__main__":
    main()
