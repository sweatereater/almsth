#!/usr/bin/env python3
"""Create deterministic Character-sheet runtime cutouts from approved ImageGen edits.

The script performs technical alpha cleanup, crop, resize and anchoring only. It does
not repaint the five approved reference-guided results or modify their lineup source.
"""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
LINEUP = ROOT / "art/concepts/character_fullbody/final/character_fullbody_set_01.png"
LINEUP_SHA256 = "953e27c097d4805026f7236ed025dc5fbd48786f35fb2748b85163be1f65732f"
TARGET_DIR = ROOT / "assets/ui/character-fullbody"

SOURCES = {
    "form-skeleton.png": "exec-2caecd14-17f5-49d2-a211-849e3fa72d4f.png",
    "form-zombie.png": "exec-09f23b75-7134-4a95-a264-e9babcb145e9.png",
    "form-ghoul.png": "exec-d79a3a3b-e356-4e84-aed5-ab5f933ccae6.png",
    "form-revenant.png": "exec-cc5afca5-a40f-485d-897f-eacbe0acb885.png",
    "form-almost-human.png": "exec-b27b1692-b573-4289-bcf7-07389d2aa0ad.png",
}

CANVAS_SIZE = (264, 704)
CONTENT_HEIGHT = 684
ANCHOR = (132, 696)
ALPHA_CUTOFF = 8


def _source_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _normalized(source_path: Path) -> Image.Image:
    source = Image.open(source_path).convert("RGBA")
    red, green, blue, alpha = source.split()
    alpha = alpha.point(lambda value: 0 if value < ALPHA_CUTOFF else value)
    source = Image.merge("RGBA", (red, green, blue, alpha))
    bounds = alpha.getbbox()
    if bounds is None:
        raise RuntimeError(f"No visible figure in {source_path}")
    source = source.crop(bounds)
    width = round(source.width * CONTENT_HEIGHT / source.height)
    if not 224 <= width <= 248:
        raise RuntimeError(f"Unexpected figure aspect ratio in {source_path}: {width}x{CONTENT_HEIGHT}")
    source = source.resize((width, CONTENT_HEIGHT), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    x = ANCHOR[0] - width // 2
    y = ANCHOR[1] - CONTENT_HEIGHT
    canvas.alpha_composite(source, (x, y))
    return canvas


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

    actual_hash = _source_hash(LINEUP)
    if actual_hash != LINEUP_SHA256:
        raise RuntimeError(f"Approved lineup changed: {actual_hash}")
    TARGET_DIR.mkdir(parents=True, exist_ok=True)
    for target_name, source_name in SOURCES.items():
        source_path = generated / source_name
        if not source_path.is_file():
            raise FileNotFoundError(source_path)
        output = _normalized(source_path)
        target = TARGET_DIR / target_name
        output.save(target, optimize=True)
        print(f"{target.relative_to(ROOT)} <- {source_name} ({output.width}x{output.height} RGBA)")


if __name__ == "__main__":
    main()
