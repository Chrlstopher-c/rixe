"""Planches de sprites des décors animés → assets/sprites/ : ventilateur (usine), torche (mine), drapeau (toits)."""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites"


def fan(frames: int = 8, size: int = 32) -> Image.Image:
    sheet = Image.new("RGBA", (size * frames, size))
    c = size / 2
    for i in range(frames):
        img = Image.new("RGBA", (size, size))
        d = ImageDraw.Draw(img)
        d.rectangle([1, 1, size - 2, size - 2], fill=(52, 54, 62, 255), outline=(96, 100, 112, 255))
        d.ellipse([3, 3, size - 4, size - 4], fill=(18, 18, 24, 255))
        for b in range(4):
            a = math.radians(i * 90 / frames + b * 90)
            tip = [(c + math.cos(a + o) * r, c + math.sin(a + o) * r) for o, r in ((-0.35, 12), (0.25, 13), (0.0, 3))]
            d.polygon(tip, fill=(120, 124, 136, 255))
        d.ellipse([c - 3, c - 3, c + 3, c + 3], fill=(70, 72, 82, 255))
        for y in range(6, size - 4, 6):
            d.line([(4, y), (size - 5, y)], fill=(80, 84, 96, 60))
        sheet.paste(img, (i * size, 0))
    return sheet


def torch(frames: int = 6, w: int = 16, h: int = 32) -> Image.Image:
    sheet = Image.new("RGBA", (w * frames, h))
    rng = random.Random(4)
    for i in range(frames):
        img = Image.new("RGBA", (w, h))
        d = ImageDraw.Draw(img)
        d.rectangle([6, 18, 9, 31], fill=(92, 58, 30, 255))
        d.rectangle([4, 17, 11, 19], fill=(70, 70, 76, 255))
        sway = rng.uniform(-1.5, 1.5)
        top = rng.uniform(2.0, 5.0)
        for scale, col in ((1.0, (255, 120, 30, 230)), (0.66, (255, 190, 60, 245)), (0.36, (255, 245, 190, 255))):
            d.polygon([(8 - 5 * scale, 17), (8 + sway * scale, 17 - (17 - top) * scale), (8 + 5 * scale, 17),
                       (8, 18)], fill=col)
        sheet.paste(img, (i * w, 0))
    return sheet


def flag(frames: int = 8, size: int = 32) -> Image.Image:
    sheet = Image.new("RGBA", (size * frames, size))
    for i in range(frames):
        img = Image.new("RGBA", (size, size))
        d = ImageDraw.Draw(img)
        d.rectangle([2, 2, 3, size - 1], fill=(150, 150, 160, 255))
        for x in range(4, 26):
            k = (x - 4) / 22
            dy = math.sin(i / frames * math.tau - k * 5.0) * 2.2 * k
            shade = 0.75 + 0.25 * math.cos(i / frames * math.tau - k * 5.0)
            col = (int(200 * shade), int(40 * shade), int(50 * shade), 255)
            d.line([(x, 4 + dy), (x, 15 + dy)], fill=col)
            if 12 <= x <= 17:
                d.line([(x, 8 + dy), (x, 11 + dy)], fill=(int(235 * shade), int(225 * shade), int(210 * shade), 255))
        sheet.paste(img, (i * size, 0))
    return sheet


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    fan().save(OUT / "fan.png")
    torch().save(OUT / "torch.png")
    flag().save(OUT / "flag.png")
    print("sprites →", OUT)


if __name__ == "__main__":
    main()
