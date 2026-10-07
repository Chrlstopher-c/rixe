"""Synthétise les bruitages du jeu en local (numpy/scipy) → assets/sfx/*.wav (mono 44,1 kHz, 16 bits)."""
from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "sfx"
RNG = np.random.default_rng(42)


def t(sec: float) -> np.ndarray:
    return np.arange(int(SR * sec)) / SR


def noise(sec: float) -> np.ndarray:
    return RNG.uniform(-1, 1, int(SR * sec))


def env(x: np.ndarray, attack: float, decay: float) -> np.ndarray:
    tt = np.arange(len(x)) / SR
    return x * np.minimum(tt / max(attack, 1e-4), 1.0) * np.exp(-tt / decay)


def lp(x: np.ndarray, hz: float, order: int = 2) -> np.ndarray:
    b, a = butter(order, hz / (SR / 2), "low")
    return lfilter(b, a, x)


def hp(x: np.ndarray, hz: float, order: int = 2) -> np.ndarray:
    b, a = butter(order, hz / (SR / 2), "high")
    return lfilter(b, a, x)


def bp(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    b, a = butter(2, [lo / (SR / 2), hi / (SR / 2)], "band")
    return lfilter(b, a, x)


def sweep(sec: float, f0: float, f1: float, curve: float = 1.0) -> np.ndarray:
    tt = t(sec)
    f = f0 + (f1 - f0) * (tt / sec) ** curve
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def mix(*parts: np.ndarray) -> np.ndarray:
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def drive(x: np.ndarray, amount: float) -> np.ndarray:
    return np.tanh(x * amount) / np.tanh(amount)


def tail(x: np.ndarray, sec: float = 0.35, wet: float = 0.25) -> np.ndarray:
    """Petite réverb : échos filtrés décroissants."""
    out = np.concatenate([x, np.zeros(int(SR * sec))])
    for i, d in enumerate([0.029, 0.047, 0.071, 0.113, 0.167]):
        k = int(SR * d)
        out[k: k + len(x)] += lp(x, 3000) * wet * (0.7 ** i)
    return out


def rifle() -> np.ndarray:
    crack = env(hp(noise(0.12), 1200), 0.0005, 0.018)
    body = env(lp(noise(0.25), 1800), 0.001, 0.05)
    thump = env(sweep(0.2, 160, 60), 0.001, 0.04)
    return tail(lp(drive(mix(crack * 0.6, body * 1.0, thump * 1.2), 2.5), 5500), 0.3, 0.2)


def shotgun() -> np.ndarray:
    crack = env(hp(noise(0.15), 900), 0.0005, 0.03)
    body = env(lp(noise(0.6), 900), 0.002, 0.14)
    thump = env(sweep(0.4, 110, 38), 0.001, 0.1)
    return tail(lp(drive(mix(crack * 0.6, body * 1.4, thump * 1.5), 3.0), 4500), 0.5, 0.3)


def railgun() -> np.ndarray:
    zap = env(sweep(0.7, 2400, 90, 0.4), 0.002, 0.22)
    fm = env(np.sin(2 * np.pi * 70 * t(0.7) + 6 * np.sin(2 * np.pi * 1300 * t(0.7))), 0.001, 0.15)
    crack = env(hp(noise(0.2), 2500), 0.0003, 0.03)
    return tail(lp(drive(mix(zap * 0.9, fm * 0.6, crack * 0.6), 1.8), 8000), 0.6, 0.35)


def impact() -> np.ndarray:
    click = env(hp(noise(0.05), 3000), 0.0002, 0.006)
    ric = env(sweep(0.18, 3200, 1800), 0.001, 0.05) * (RNG.random() * 0.4 + 0.2)
    dust = env(bp(noise(0.12), 400, 2500), 0.001, 0.03)
    return lp(mix(click * 0.6, ric * 0.4, dust * 0.8), 6000)


def flesh() -> np.ndarray:
    thud = env(lp(noise(0.14), 700), 0.001, 0.035)
    wet = env(bp(noise(0.14), 300, 1400) * (1 + 0.6 * np.sin(2 * np.pi * 38 * t(0.14))), 0.002, 0.04)
    return drive(mix(thud * 1.4, wet * 0.8, env(sweep(0.1, 140, 70), 0.001, 0.03)), 2.0)


def gore() -> np.ndarray:
    splat = env(lp(noise(0.5), 1100) * (1 + 0.8 * np.sin(2 * np.pi * 23 * t(0.5))), 0.002, 0.12)
    crunch = env(bp(noise(0.2), 900, 4000), 0.001, 0.03)
    bone = env(sweep(0.08, 900, 300), 0.0005, 0.02)
    return tail(drive(mix(splat * 1.3, crunch * 0.8, bone * 0.6), 2.2), 0.3, 0.2)


def jump() -> np.ndarray:
    return env(bp(noise(0.16), 600, 2400) * np.linspace(0.3, 1, int(SR * 0.16)), 0.01, 0.06) * 0.6


def air_jump() -> np.ndarray:
    return mix(jump(), env(sweep(0.2, 500, 1100), 0.005, 0.07) * 0.35)


def land() -> np.ndarray:
    return mix(env(lp(noise(0.12), 400), 0.001, 0.03) * 1.2, env(bp(noise(0.1), 800, 3000), 0.001, 0.015) * 0.3)


def dash() -> np.ndarray:
    n = int(SR * 0.3)
    whoosh = bp(noise(0.3), 300, 3500) * np.sin(np.linspace(0, np.pi, n)) ** 2
    return whoosh * 0.8 + env(sweep(0.3, 300, 120), 0.01, 0.1) * 0.2


def shell() -> np.ndarray:
    tt = t(0.12)
    ting = sum(np.sin(2 * np.pi * f * tt) * a for f, a in [(3100, 1), (4700, 0.6), (6900, 0.3)])
    return env(ting, 0.0005, 0.025) * 0.35


def swing() -> np.ndarray:
    n = int(SR * 0.22)
    return bp(noise(0.22), 500, 4000) * np.sin(np.linspace(0, np.pi, n)) ** 3 * 0.9


def punch() -> np.ndarray:
    return drive(mix(env(lp(noise(0.15), 500), 0.001, 0.04) * 1.5, env(sweep(0.12, 180, 60), 0.001, 0.05)), 2.5)


def slowmo() -> np.ndarray:
    boom = env(sweep(1.2, 90, 28), 0.002, 0.45)
    air = env(lp(noise(1.2), 600), 0.05, 0.4) * 0.3
    return tail(mix(boom, air), 0.6, 0.3) * 0.9


def pickup() -> np.ndarray:
    return mix(env(sweep(0.08, 900, 1400), 0.001, 0.03), env(np.sin(2 * np.pi * 1800 * t(0.15)), 0.001, 0.05) * 0.5)


def ricochet() -> np.ndarray:
    whine = env(sweep(0.35, 3400, 1500, 0.6), 0.001, 0.12) * (1 + 0.3 * np.sin(2 * np.pi * 45 * t(0.35)))
    click = env(hp(noise(0.03), 4000), 0.0002, 0.004)
    return lp(mix(click * 0.6, whine * 0.5), 7000)


def reload_out() -> np.ndarray:
    clack = env(bp(noise(0.08), 1500, 6000), 0.0005, 0.012)
    slide = env(bp(noise(0.12), 800, 3000), 0.01, 0.04) * 0.5
    return mix(clack, np.concatenate([np.zeros(int(SR * 0.05)), slide]))


def reload_in() -> np.ndarray:
    seat = env(lp(noise(0.06), 1800), 0.0005, 0.01) * 1.2
    cock = env(bp(noise(0.1), 2000, 7000), 0.0005, 0.015)
    return mix(seat, np.concatenate([np.zeros(int(SR * 0.11)), cock]), env(sweep(0.05, 300, 120), 0.001, 0.02))


def dry() -> np.ndarray:
    return env(bp(noise(0.05), 2500, 8000), 0.0002, 0.006) * 0.8


def round_start() -> np.ndarray:
    tt = t(0.9)
    chord = sum(np.sin(2 * np.pi * f * tt) for f in [110, 165, 220, 330])
    return tail(env(drive(chord * 0.4, 1.5), 0.01, 0.35), 0.6, 0.3) * 0.6


SOUNDS = {
    "rifle": rifle, "shotgun": shotgun, "railgun": railgun, "impact": impact, "flesh": flesh, "gore": gore,
    "jump": jump, "air_jump": air_jump, "land": land, "dash": dash, "shell": shell, "swing": swing,
    "punch": punch, "slowmo": slowmo, "pickup": pickup, "round": round_start, "ricochet": ricochet,
    "reload_out": reload_out, "reload_in": reload_in, "dry": dry,
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in SOUNDS.items():
        x = fn()
        x = x / max(np.abs(x).max(), 1e-9) * 0.89
        fade = min(len(x), int(SR * 0.01))
        x[-fade:] *= np.linspace(1, 0, fade)
        wavfile.write(OUT / f"{name}.wav", SR, (x * 32767).astype(np.int16))
    print(f"{len(SOUNDS)} sons -> {OUT}")


if __name__ == "__main__":
    main()
