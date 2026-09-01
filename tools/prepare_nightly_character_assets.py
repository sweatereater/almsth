"""Deterministically prepare the 2026-09-01 map-character and item assets.

This script performs no generation.  It consumes the reviewed ImageGen candidates copied
into ``art/characters/map-runtime/2026-09-01/candidates`` and normalizes each 2x2 gait
sheet into four anchored 264x264 RGBA8 runtime frames.  The two approved RGB candidates
use a connected-background matte; all other sheets retain their authored alpha.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
CANDIDATES = ROOT / "art" / "characters" / "map-runtime" / "2026-09-01" / "candidates"
OUTPUT = ROOT / "assets" / "dungeon" / "player-forms"

SHEETS = {
    ("female", "skeleton"): ("female-skeleton-attempt-02.png", True),
    ("female", "zombie"): ("female-zombie-attempt-02.png", True),
    ("female", "revenant"): ("female-revenant-attempt-01.png", False),
    ("female", "almost_human"): ("female-almost-human-attempt-01.png", False),
    ("male", "skeleton"): ("male-skeleton-attempt-01.png", False),
    ("male", "zombie"): ("male-zombie-attempt-01.png", False),
    ("male", "ghoul"): ("male-ghoul-attempt-01.png", False),
    ("male", "revenant"): ("male-revenant-attempt-01.png", False),
    ("male", "almost_human"): ("male-almost-human-attempt-01.png", False),
}


def _connected_light_background_alpha(cell: Image.Image) -> Image.Image:
    """Return a matte for the reviewed light-checker candidates without pose synthesis."""

    rgb = cell.convert("RGB")
    eligible = Image.new("L", rgb.size, 255)
    source = rgb.load()
    pixels = eligible.load()
    for y in range(rgb.height):
        for x in range(rgb.width):
            red, green, blue = source[x, y]
            brightness = (red + green + blue) / 3.0
            saturation = max(red, green, blue) - min(red, green, blue)
            pixels[x, y] = 0 if brightness >= 224.0 and saturation <= 18 else 255

    # Only near-neutral light pixels connected to a cell edge are background.  This keeps
    # pale bone/skin highlights enclosed by the authored outline instead of punching holes.
    flood = eligible.copy()
    draw = ImageDraw.Draw(flood)
    for x in range(flood.width):
        if flood.getpixel((x, 0)) == 0:
            ImageDraw.floodfill(flood, (x, 0), 128, thresh=0)
        if flood.getpixel((x, flood.height - 1)) == 0:
            ImageDraw.floodfill(flood, (x, flood.height - 1), 128, thresh=0)
    for y in range(flood.height):
        if flood.getpixel((0, y)) == 0:
            ImageDraw.floodfill(flood, (0, y), 128, thresh=0)
        if flood.getpixel((flood.width - 1, y)) == 0:
            ImageDraw.floodfill(flood, (flood.width - 1, y), 128, thresh=0)

    alpha = flood.point(lambda value: 0 if value == 128 else 255)
    # Pull the matte half a pixel inward and soften only the cut edge to avoid a light halo.
    return alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.55))


def _cell(sheet: Image.Image, index: int) -> Image.Image:
    half_width = sheet.width // 2
    half_height = sheet.height // 2
    column = index % 2
    row = index // 2
    left = column * half_width
    top = row * half_height
    right = sheet.width if column == 1 else half_width
    bottom = sheet.height if row == 1 else half_height
    return sheet.crop((left, top, right, bottom))


def _extract_subject(cell: Image.Image, extract_light_background: bool) -> Image.Image:
    rgba = cell.convert("RGBA")
    if extract_light_background:
        rgba.putalpha(_connected_light_background_alpha(cell))
    alpha = rgba.getchannel("A")
    bounds = alpha.point(lambda value: 255 if value > 8 else 0).getbbox()
    if bounds is None:
        raise ValueError("candidate cell has no visible pixels")
    return rgba.crop(bounds)


def _normalize_frame(subject: Image.Image, scale: float) -> tuple[Image.Image, tuple[int, int]]:
    resized = subject.resize(
        (max(1, round(subject.width * scale)), max(1, round(subject.height * scale))),
        Image.Resampling.LANCZOS,
    )
    frame = Image.new("RGBA", (264, 264), (0, 0, 0, 0))
    # The authored contact baseline is fixed at y=259; logical anchor is immediately below
    # it at (132, 260).  Normalizing every frame to this line prevents canvas bob or drift.
    x = 132 - resized.width // 2
    y = 260 - resized.height
    frame.alpha_composite(resized, (x, y))
    return frame, resized.size


def _silhouette_sha256(frame: Image.Image) -> str:
    alpha = frame.getchannel("A").point(lambda value: 255 if value > 8 else 0)
    return hashlib.sha256(alpha.tobytes()).hexdigest().upper()


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def build(output_root: Path = OUTPUT) -> dict:
    manifest: dict[str, object] = {
        "schema_version": 2,
        "frame_size": [264, 264],
        "format": "RGBA8",
        "anchor": [132, 260],
        "minimum_alpha_padding": 4,
        "sets": {},
    }
    for (sex, form), (filename, extract_light_background) in SHEETS.items():
        source = CANDIDATES / filename
        if not source.is_file():
            raise FileNotFoundError(source)
        sheet = Image.open(source)
        subjects = [
            _extract_subject(_cell(sheet, index), extract_light_background)
            for index in range(4)
        ]
        # Anatomical scale is a property of the set, never of an individual pose.
        # The widest/tallest authored contact determines one scale applied verbatim
        # to all four subjects; shorter/narrower poses keep their natural variance.
        max_width = max(subject.width for subject in subjects)
        max_height = max(subject.height for subject in subjects)
        shared_scale = min(248.0 / max_width, 252.0 / max_height)
        destination = output_root / sex / form
        destination.mkdir(parents=True, exist_ok=True)
        frames: list[dict[str, object]] = []
        for index, subject in enumerate(subjects):
            frame, resized_size = _normalize_frame(subject, shared_scale)
            target = destination / f"walk-{index:02d}.png"
            frame.save(target, format="PNG", optimize=True)
            bounds = frame.getchannel("A").point(lambda value: 255 if value > 8 else 0).getbbox()
            if bounds is None:
                raise ValueError(f"empty runtime frame: {target}")
            left, top, right, bottom = bounds
            padding = [left, top, 264 - right, 264 - bottom]
            if min(padding) < 4:
                raise ValueError(f"alpha padding below 4 px for {target}: {padding}")
            frames.append(
                {
                    "path": (OUTPUT / sex / form / target.name).relative_to(ROOT).as_posix(),
                    "sha256": _sha256(target),
                    "silhouette_sha256": _silhouette_sha256(frame),
                    "source_subject_size": list(subject.size),
                    "resized_subject_size": list(resized_size),
                    "alpha_bounds": list(bounds),
                    "alpha_padding": padding,
                }
            )
        signatures = {entry["sha256"] for entry in frames}
        if len(signatures) != 4:
            raise ValueError(f"duplicate gait frames for {sex}/{form}")
        silhouette_signatures = {entry["silhouette_sha256"] for entry in frames}
        if len(silhouette_signatures) != 4:
            raise ValueError(f"translation-only or duplicate gait silhouettes for {sex}/{form}")
        manifest["sets"][f"{sex}/{form}"] = {
            "candidate": source.relative_to(ROOT).as_posix(),
            "deterministic_light_background_matte": extract_light_background,
            "shared_normalization_scale": round(shared_scale, 12),
            "frames": frames,
        }
    return manifest


def prepare_claymore(target: Path | None = None) -> dict[str, object]:
    source = CANDIDATES / "old-claymore-attempt-01.png"
    if not source.is_file():
        raise FileNotFoundError(source)
    rgba = Image.open(source).convert("RGBA")
    bounds = rgba.getchannel("A").point(lambda value: 255 if value > 8 else 0).getbbox()
    if bounds is None:
        raise ValueError("Old Claymore candidate has no visible pixels")
    subject = rgba.crop(bounds)
    scale = min(116.0 / subject.width, 116.0 / subject.height)
    resized = subject.resize(
        (max(1, round(subject.width * scale)), max(1, round(subject.height * scale))),
        Image.Resampling.LANCZOS,
    )
    icon = Image.new("RGBA", (132, 132), (0, 0, 0, 0))
    icon.alpha_composite(resized, ((132 - resized.width) // 2, (132 - resized.height) // 2))
    canonical_target = ROOT / "assets" / "items" / "item-old-claymore.png"
    if target is None:
        target = canonical_target
    target.parent.mkdir(parents=True, exist_ok=True)
    icon.save(target, format="PNG", optimize=True)
    icon_bounds = icon.getchannel("A").point(lambda value: 255 if value > 8 else 0).getbbox()
    if icon_bounds is None:
        raise ValueError("Old Claymore runtime icon is empty")
    left, top, right, bottom = icon_bounds
    padding = [left, top, 132 - right, 132 - bottom]
    if min(padding) < 4:
        raise ValueError(f"Old Claymore padding below 4 px: {padding}")
    return {
        "path": canonical_target.relative_to(ROOT).as_posix(),
        "sha256": _sha256(target),
        "alpha_bounds": list(icon_bounds),
        "alpha_padding": padding,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="verify deterministic output")
    args = parser.parse_args()
    manifest_path = ROOT / "art" / "characters" / "map-runtime" / "2026-09-01" / "runtime-manifest.json"
    if args.check:
        with tempfile.TemporaryDirectory(prefix="almsth-character-assets-check-") as temporary:
            temporary_root = Path(temporary)
            generated_root = temporary_root / "player-forms"
            generated_claymore = temporary_root / "item-old-claymore.png"
            manifest = build(generated_root)
            manifest["old_claymore"] = prepare_claymore(generated_claymore)
            encoded = json.dumps(manifest, indent=2, ensure_ascii=False) + "\n"
            stale: list[str] = []
            for sex, form in SHEETS:
                for index in range(4):
                    relative = Path(sex) / form / f"walk-{index:02d}.png"
                    generated = generated_root / relative
                    runtime = OUTPUT / relative
                    if not runtime.is_file() or runtime.read_bytes() != generated.read_bytes():
                        stale.append(runtime.relative_to(ROOT).as_posix())
            canonical_claymore = ROOT / "assets" / "items" / "item-old-claymore.png"
            if not canonical_claymore.is_file() or canonical_claymore.read_bytes() != generated_claymore.read_bytes():
                stale.append(canonical_claymore.relative_to(ROOT).as_posix())
            if not manifest_path.is_file() or manifest_path.read_text(encoding="utf-8") != encoded:
                stale.append(manifest_path.relative_to(ROOT).as_posix())
            if stale:
                raise SystemExit("stale runtime assets: " + ", ".join(stale))
    else:
        manifest = build()
        manifest["old_claymore"] = prepare_claymore()
        encoded = json.dumps(manifest, indent=2, ensure_ascii=False) + "\n"
        manifest_path.parent.mkdir(parents=True, exist_ok=True)
        manifest_path.write_text(encoded, encoding="utf-8", newline="\n")
    print(f"prepared {len(SHEETS)} gait sets and Old Claymore icon")


if __name__ == "__main__":
    main()
