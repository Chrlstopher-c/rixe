"""Génère les textures du jeu avec Pigment (local) → assets/textures/."""
import sys
from pathlib import Path

sys.path.insert(0, "/mnt/projects/pigment")
from pigment import lowpoly, pixel_tiles, sky  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "assets" / "textures"
MOUNTAINS = [(21, 0.48, 0.30, 0.10, 0.30), (22, 0.36, 0.42, 0.12, 0.26), (23, 0.24, 0.52, 0.13, 0.22),
             (24, 0.12, 0.62, 0.10, 0.18)]


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sky.gradient(640, 360, sun=(0.72, 0.42, 0.075)).save(OUT / "sky.png")
    for i, (seed, tone, peak, spread, amp) in enumerate(MOUNTAINS):
        img = lowpoly.mountains(1800, 360, seed=seed, tone=tone, peak=peak, spread=spread, amp=amp, density=520)
        img.save(OUT / f"mtn{i}.png")
    pixel_tiles.bricks(32, seed=3).save(OUT / "bricks.png")
    pixel_tiles.metal_plate(32, seed=5).save(OUT / "metal.png")
    pixel_tiles.ground(64, 32, seed=7).save(OUT / "ground.png")
    print("textures ->", OUT)


if __name__ == "__main__":
    main()
