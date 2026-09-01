"""Build secondary contact sheets from the immutable nightly raw Godot captures."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


VIEWPORTS = ("1280x720", "960x540")
LOCALES = ("ru", "en")
ZOOMS = (44, 66, 88)
TILE_SIZE = (384, 216)
LABEL_HEIGHT = 28
TITLE_HEIGHT = 42
GAP = 8
COLUMNS = 4


def _font(size: int) -> ImageFont.ImageFont:
    try:
        return ImageFont.truetype("arial.ttf", size)
    except OSError:
        return ImageFont.load_default()


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def _matches(raw_dir: Path, prefixes: tuple[str, ...], token: str = "") -> list[Path]:
    matches = []
    for path in sorted(raw_dir.glob("*.png")):
        if path.name.startswith(prefixes) and (not token or token in path.name):
            matches.append(path)
    return matches


def _write_sheet(title: str, paths: list[Path], output_path: Path) -> dict:
    if not paths:
        raise RuntimeError(f"No raw captures selected for {title}")
    rows = math.ceil(len(paths) / COLUMNS)
    width = GAP + COLUMNS * (TILE_SIZE[0] + GAP)
    height = TITLE_HEIGHT + GAP + rows * (TILE_SIZE[1] + LABEL_HEIGHT + GAP)
    sheet = Image.new("RGB", (width, height), "#0d1219")
    draw = ImageDraw.Draw(sheet)
    title_font = _font(22)
    label_font = _font(15)
    draw.text((GAP, 9), title, fill="#e7e2d8", font=title_font)
    records = []
    for index, path in enumerate(paths):
        column = index % COLUMNS
        row = index // COLUMNS
        left = GAP + column * (TILE_SIZE[0] + GAP)
        top = TITLE_HEIGHT + GAP + row * (TILE_SIZE[1] + LABEL_HEIGHT + GAP)
        with Image.open(path) as source:
            frame = source.convert("RGB").resize(TILE_SIZE, Image.Resampling.LANCZOS)
        sheet.paste(frame, (left, top))
        draw.rectangle(
            (left, top + TILE_SIZE[1], left + TILE_SIZE[0], top + TILE_SIZE[1] + LABEL_HEIGHT),
            fill="#192330",
        )
        label = path.stem
        while draw.textlength(label, font=label_font) > TILE_SIZE[0] - 12 and len(label) > 4:
            label = label[:-1]
        if label != path.stem:
            label = label[:-3] + "..."
        draw.text((left + 6, top + TILE_SIZE[1] + 5), label, fill="#d8dde3", font=label_font)
        records.append({"path": path.name, "sha256": _sha256(path)})
    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path)
    return {
        "path": output_path.name,
        "title": title,
        "source_count": len(records),
        "sources": records,
        "sha256": _sha256(output_path),
    }


def build(raw_dir: Path, output_dir: Path) -> list[dict]:
    groups: list[tuple[str, str, list[Path]]] = []
    for viewport in VIEWPORTS:
        for zoom in ZOOMS:
            groups.append((
                f"map-matrix-{viewport}-z{zoom}.png",
                f"Map matrix {viewport}, cell {zoom}: 10 identities, idle + mid-step",
                _matches(raw_dir, (f"map-{viewport}-",), f"-z{zoom}-"),
            ))
        groups.append((
            f"map-extras-{viewport}.png",
            f"Map directions, mirror, door, chest and edge checks at {viewport}",
            _matches(raw_dir, (f"map-extra-{viewport}-",)),
        ))
        for locale in LOCALES:
            character_paths = _matches(
                raw_dir,
                (
                    f"character-{viewport}-{locale}-",
                    f"character-zoom-{viewport}-{locale}-",
                    f"hands-{viewport}-{locale}-",
                ),
            )
            groups.append((
                f"character-hands-{viewport}-{locale}.png",
                f"Character Sheet and hands {viewport}, {locale.upper()}",
                character_paths,
            ))
            camp_paths = _matches(
                raw_dir,
                (
                    f"camp-{viewport}-{locale}-",
                    f"camp-module-{viewport}-{locale}-",
                    f"camp-pair-{viewport}-{locale}-",
                    f"camp-modal-{viewport}-{locale}-",
                    f"death-{viewport}-{locale}-",
                ),
            )
            groups.append((
                f"camp-{viewport}-{locale}.png",
                f"Camp layers, pairs, all, modal and death split {viewport}, {locale.upper()}",
                camp_paths,
            ))
    output_dir.mkdir(parents=True, exist_ok=True)
    records = [_write_sheet(title, paths, output_dir / name) for name, title, paths in groups]
    manifest = {
        "schema_version": 1,
        "raw_directory": str(raw_dir.resolve()),
        "raw_capture_count": len(list(raw_dir.glob("*.png"))),
        "sheets": records,
    }
    manifest_path = output_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return records


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True, help="Directory containing raw PNG captures")
    parser.add_argument("--output", type=Path, required=True, help="Contact-sheet output directory")
    args = parser.parse_args()
    records = build(args.input, args.output)
    print(f"Built {len(records)} contact sheets from {sum(r['source_count'] for r in records)} placements")
    print(args.output.resolve())


if __name__ == "__main__":
    main()
