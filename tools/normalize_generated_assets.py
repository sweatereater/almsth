#!/usr/bin/env python3
"""Normalize approved ImageGen cut-outs into Almsth runtime asset contracts.

This script performs technical export work only: background flood removal for the
few ImageGen results that contain a light neutral preview matte, alpha cleanup,
aspect-preserving resize and deterministic anchoring. It does not repaint assets.
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[1]


ASSETS = (
    # kind, ImageGen cache file, project-relative destination
    ("world", "exec-e584a138-ad3f-4487-9364-1a01acdec0ae.png", "assets/dungeon/player-skeleton.png"),
    ("world", "exec-e4531213-90ff-4555-b83c-a6134d274a2e.png", "assets/dungeon/player-zombie.png"),
    ("world", "exec-0e189f57-2e8c-4138-865b-f1997a594a39.png", "assets/dungeon/player-ghoul.png"),
    ("world", "exec-5e5fca22-0134-4086-b8cb-3bda0628082f.png", "assets/dungeon/player-revenant.png"),
    ("world", "exec-11a3287d-16cd-4925-b31c-b74e8db9cae1.png", "assets/dungeon/player-almost-human.png"),
    ("world", "exec-26885518-1c69-48c7-bd58-2c0d6a79f1fc.png", "assets/dungeon/enemy-grave-rat.png"),
    ("portrait", "exec-d9007c69-aed3-4973-8144-3dec4e289fdd.png", "assets/portraits/form-skeleton.png"),
    ("portrait", "exec-9cd27f45-a26f-4edc-9c3c-9c83c82d02ab.png", "assets/portraits/form-zombie.png"),
    ("portrait", "exec-16999719-9808-4cea-9e19-280f71a1ffa1.png", "assets/portraits/form-ghoul.png"),
    ("portrait", "exec-b907abdd-49d0-4f3f-8c67-589aef56a9e2.png", "assets/portraits/form-revenant.png"),
    ("portrait", "exec-a5405540-43ab-4678-8f41-7e29b91ef64d.png", "assets/portraits/form-almost-human.png"),
    ("icon", "exec-b8c09645-f15f-4181-b925-d174e97d6846.png", "assets/items/item-bone-knife.png"),
    ("icon", "exec-caa30135-65e5-415e-a3c0-807b774ae6b1.png", "assets/items/item-grave-mace.png"),
    ("icon", "exec-03677d53-72ac-4166-a035-1d85fea96725.png", "assets/items/item-bone-bow.png"),
    ("icon", "exec-a7355982-f5eb-4d17-8c93-66182963f9a9.png", "assets/items/item-soul-locket.png"),
    ("icon", "exec-e42f5896-311a-48d6-8070-27c8a4e5b527.png", "assets/items/item-rotting-mail.png"),
    ("icon", "exec-3f63a26c-c42b-4a28-bfa9-2a7d42858c35.png", "assets/items/item-leather-gloves.png"),
    ("icon", "exec-c41685ec-ab98-4f73-985f-2e87de53e079.png", "assets/items/item-hollow-lantern.png"),
    ("icon", "exec-cf8069b2-d584-4a2e-8faf-bc1ed9e36ff0.png", "assets/items/item-pilgrim-shield.png"),
)


def _remove_light_neutral_matte(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    pixels = rgba.load()
    seen = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def is_background(x: int, y: int) -> bool:
        red, green, blue, _alpha = pixels[x, y]
        return min(red, green, blue) >= 218 and max(red, green, blue) - min(red, green, blue) <= 24

    def offer(x: int, y: int) -> None:
        index = y * width + x
        if seen[index] or not is_background(x, y):
            return
        seen[index] = 1
        queue.append((x, y))

    for x in range(width):
        offer(x, 0)
        offer(x, height - 1)
    for y in range(height):
        offer(0, y)
        offer(width - 1, y)

    while queue:
        x, y = queue.popleft()
        if x:
            offer(x - 1, y)
        if x + 1 < width:
            offer(x + 1, y)
        if y:
            offer(x, y - 1)
        if y + 1 < height:
            offer(x, y + 1)

    alpha = Image.new("L", (width, height), 255)
    alpha_pixels = alpha.load()
    for y in range(height):
        row = y * width
        for x in range(width):
            if seen[row + x]:
                alpha_pixels[x, y] = 0
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.55))
    rgba.putalpha(alpha)
    return rgba


def _load_cutout(path: Path) -> Image.Image:
    source = Image.open(path)
    if source.mode != "RGBA" or source.getchannel("A").getextrema()[0] == 255:
        source = _remove_light_neutral_matte(source)
    else:
        source = source.convert("RGBA")
    alpha = source.getchannel("A")
    alpha = alpha.point(lambda value: 0 if value < 5 else value)
    source.putalpha(alpha)
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError(f"No opaque pixels after alpha cleanup: {path}")
    return source.crop(bbox)


def _export(kind: str, source_path: Path, destination: Path) -> None:
    source = _load_cutout(source_path)
    target_size = 132 if kind == "icon" else 264
    padding = 8 if kind == "icon" else 4
    content_size = target_size - padding * 2
    scale = min(content_size / source.width, content_size / source.height)
    resized = source.resize(
        (max(1, round(source.width * scale)), max(1, round(source.height * scale))),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
    x = (target_size - resized.width) // 2
    if kind == "world":
        # Lower-center world anchor, with four transparent rows below support.
        y = target_size - padding - resized.height
    else:
        y = (target_size - resized.height) // 2
    canvas.alpha_composite(resized, (x, y))
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination, optimize=True)
    print(f"{destination.relative_to(ROOT)} <- {source_path.name} ({target_size}x{target_size})")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source-dir",
        type=Path,
        required=True,
        help="Directory containing the approved ImageGen PNG files.",
    )
    args = parser.parse_args()
    generated = args.source_dir.expanduser().resolve()

    for kind, source_name, destination_name in ASSETS:
        source_path = generated / source_name
        if not source_path.is_file():
            raise FileNotFoundError(source_path)
        _export(kind, source_path, ROOT / destination_name)


if __name__ == "__main__":
    main()
