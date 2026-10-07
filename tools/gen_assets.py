"""Génère les textures du jeu avec Pigment (local) → assets/textures/<thème>/ (ciel, 4 montagnes, tuiles)."""
import os
import sys
from pathlib import Path

# Pigment : dépôt voisin par défaut (../pigment), ou chemin donné par PIGMENT_PATH.
sys.path.insert(0, os.environ.get("PIGMENT_PATH", str(Path(__file__).resolve().parents[2] / "pigment")))
from pigment import lowpoly, pixel_tiles, sky  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "assets" / "textures"
MOUNTAINS = [(21, 0.48, 0.30, 0.10, 0.30), (22, 0.36, 0.42, 0.12, 0.26), (23, 0.24, 0.52, 0.13, 0.22),
             (24, 0.12, 0.62, 0.10, 0.18)]
# thème : palette du décor lointain, ciel (t0, t1, soleil), palettes des tuiles (briques, métal, sol, herbe)
THEMES = {
    "crepuscule": {"pal": "dusk", "sky": (0.05, 0.85, (0.72, 0.42, 0.075)), "tiles": ("dusk", "steel", "rust", "moss")},
    "acier": {"pal": "steel", "sky": (0.02, 0.55, (0.25, 0.3, 0.05)), "tiles": ("steel", "steel", "ink", "steel")},
    "rouille": {"pal": "rust", "sky": (0.15, 0.95, (0.5, 0.5, 0.11)), "tiles": ("rust", "rust", "rust", "dusk")},
}


def theme(name: str, cfg: dict) -> None:
    out = OUT / name
    out.mkdir(parents=True, exist_ok=True)
    t0, t1, sun = cfg["sky"]
    sky.gradient(640, 360, palette=cfg["pal"], t0=t0, t1=t1, sun=sun).save(out / "sky.png")
    for i, (seed, tone, peak, spread, amp) in enumerate(MOUNTAINS):
        img = lowpoly.mountains(1800, 360, seed=seed + len(name), palette=cfg["pal"], tone=tone, peak=peak,
                                spread=spread, amp=amp, density=520, tileable=True)
        img.save(out / f"mtn{i}.png")
    bricks, metal, soil, top = cfg["tiles"]
    pixel_tiles.bricks(32, seed=3, palette=bricks).save(out / "bricks.png")
    pixel_tiles.metal_plate(32, seed=5, palette=metal).save(out / "metal.png")
    pixel_tiles.ground(64, 32, seed=7, soil=soil, top=top).save(out / "ground.png")
    pixel_tiles.concrete(32, seed=9, palette=metal).save(out / "concrete.png")
    pixel_tiles.glass(32, seed=11, palette=metal).save(out / "glass.png")
    pixel_tiles.grate(32, seed=13, palette=metal).save(out / "grate.png")


def main() -> None:
    for name, cfg in THEMES.items():
        theme(name, cfg)
    for old in OUT.glob("*.png"):
        old.unlink()
    print("thèmes ->", ", ".join(THEMES))


if __name__ == "__main__":
    main()
