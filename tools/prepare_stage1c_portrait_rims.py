"""Rebuild the two selector portraits and remove only an exterior alpha rim.

The approved art/ masters are read-only. The original runtime images are rebuilt
in memory through their established recipes, then only alpha on exterior-connected
partially transparent pixels within two source pixels is cleared. RGB is never
changed and no light/white/chroma threshold is used.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUTPUTS = {
    "female": ROOT / "assets/portraits/female/form-almost-human.png",
    "male": ROOT / "assets/portraits/male/form-almost-human.png",
}
MANIFEST = ROOT / "assets/portraits/stage1c-fringe-manifest.json"
PREVIEW_DIR = ROOT / ".tmp/stage1c-portrait-previews"
PROTECTED_RECTS = {
    "female": [(68, 70, 174, 182)],
    "male": [(62, 20, 184, 94), (66, 78, 174, 180)],
}


def sha_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sha_pixels(image: Image.Image) -> str:
    return hashlib.sha256(image.convert("RGBA").tobytes()).hexdigest()


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def rebuild_originals() -> tuple[dict[str, Image.Image], dict[str, dict[str, str]]]:
    female_tool = load_module("female_assets", ROOT / "tools/prepare_female_character_assets.py")
    female_recipe = json.loads((ROOT / "art/characters/female/recipe.json").read_text(encoding="utf-8"))
    female_stage = next(item for item in female_recipe["stages"] if item["file_id"] == "almost-human")
    female_source_path = ROOT / "art/characters/female" / next(
        item["path"] for item in female_recipe["sources"] if item["id"] == female_stage["source_id"]
    )
    female_source = Image.open(female_source_path).convert("RGB")
    female_head = female_source.crop(female_stage["head_crop_xyxy"]).convert("RGBA")
    female_head.putalpha(female_tool.mask_for(female_source, female_stage))
    female, _metadata = female_tool.icon_for(female_head, female_stage, female_recipe)

    sex_tool = load_module("sex_assets", ROOT / "tools/prepare_character_sex_assets.py")
    sex_recipe = json.loads((ROOT / "art/characters/sex-selection/recipe.json").read_text(encoding="utf-8"))
    male_entry = sex_recipe["male_head"]
    male_source_path = ROOT / sex_recipe["sources"][male_entry["source"]]["path"]
    male_source = Image.open(male_source_path)
    male_native, _mask = sex_tool.cutout(male_source, male_entry)
    male = sex_tool.head_canvas(male_native, male_entry)

    sources = {
        "female": {"path": female_source_path.relative_to(ROOT).as_posix(), "sha256": sha_file(female_source_path)},
        "male": {"path": male_source_path.relative_to(ROOT).as_posix(), "sha256": sha_file(male_source_path)},
    }
    return {"female": female, "male": male}, sources


def exterior_zero(alpha: np.ndarray) -> np.ndarray:
    height, width = alpha.shape
    exterior = np.zeros((height, width), dtype=bool)
    queue: deque[tuple[int, int]] = deque()
    for x in range(width):
        queue.append((x, 0)); queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y)); queue.append((width - 1, y))
    while queue:
        x, y = queue.popleft()
        if exterior[y, x] or alpha[y, x] != 0:
            continue
        exterior[y, x] = True
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < width and 0 <= ny < height and not exterior[ny, nx]:
                queue.append((nx, ny))
    return exterior


def dilate(mask: np.ndarray, iterations: int) -> np.ndarray:
    result = mask.copy()
    for _index in range(iterations):
        padded = np.pad(result, 1, constant_values=False)
        expanded = np.zeros_like(result)
        for dy in range(3):
            for dx in range(3):
                expanded |= padded[dy:dy + result.shape[0], dx:dx + result.shape[1]]
        result = expanded
    return result


def clean_rim(sex: str, original: Image.Image) -> tuple[Image.Image, int]:
    pixels = np.array(original.convert("RGBA"))
    alpha = pixels[:, :, 3]
    near_exterior = dilate(exterior_zero(alpha), 2)
    remove = (alpha > 0) & (alpha < 255) & near_exterior
    for left, top, right, bottom in PROTECTED_RECTS[sex]:
        remove[top:bottom, left:right] = False
    cleaned = pixels.copy()
    cleaned[:, :, 3][remove] = 0
    assert np.array_equal(cleaned[:, :, :3], pixels[:, :, :3]), "RGB changed"
    assert np.array_equal(cleaned[alpha == 255], pixels[alpha == 255]), "Opaque pixel changed"
    for left, top, right, bottom in PROTECTED_RECTS[sex]:
        assert np.array_equal(cleaned[top:bottom, left:right], pixels[top:bottom, left:right])
    return Image.fromarray(cleaned, "RGBA"), int(remove.sum())


def render_previews(images: dict[str, Image.Image]) -> list[dict]:
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    backgrounds = [
        ("warm", (16, 15, 13)), ("cold", (7, 12, 17)), ("black", (0, 0, 0)),
        ("light", (242, 232, 212)), ("checker", None),
    ]
    records = []
    font_path = ROOT / "assets/fonts/noto-sans/NotoSans-Medium.ttf"
    font = ImageFont.truetype(str(font_path), 14)
    for size in (112, 84):
        cell_w, cell_h = size + 28, size + 46
        sheet = Image.new("RGB", (cell_w * len(backgrounds), cell_h * 2), (16, 15, 13))
        draw = ImageDraw.Draw(sheet)
        for column, (name, color) in enumerate(backgrounds):
            for row, sex in enumerate(("female", "male")):
                x, y = column * cell_w, row * cell_h
                if color is None:
                    for yy in range(y, y + cell_h, 10):
                        for xx in range(x, x + cell_w, 10):
                            tone = (190, 190, 190) if ((xx - x) // 10 + (yy - y) // 10) % 2 else (232, 232, 232)
                            draw.rectangle((xx, yy, xx + 9, yy + 9), fill=tone)
                else:
                    draw.rectangle((x, y, x + cell_w - 1, y + cell_h - 1), fill=color)
                portrait = images[sex].resize((size, size), Image.Resampling.LANCZOS)
                if sex == "male":
                    portrait = portrait.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                sheet.paste(portrait, (x + 14, y + 8), portrait)
                text_color = (242, 232, 212) if name not in ("light", "checker") else (35, 31, 27)
                draw.text((x + 8, y + size + 14), f"{sex} · {name}", fill=text_color, font=font)
        output = PREVIEW_DIR / f"portraits-{size}.png"
        sheet.save(output, optimize=True)
        records.append({"path": output.relative_to(ROOT).as_posix(), "size": list(sheet.size), "sha256": sha_file(output)})
    return records


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    originals, sources = rebuild_originals()
    cleaned = {}
    records = []
    for sex, original in originals.items():
        image, removed = clean_rim(sex, original)
        cleaned[sex] = image
        bounds = image.getchannel("A").getbbox()
        assert image.size == (264, 264)
        assert bounds is not None and bounds[0] >= 4 and bounds[1] >= 4 and bounds[2] <= 260 and bounds[3] <= 260
        output = OUTPUTS[sex]
        if args.check:
            with Image.open(output) as actual:
                assert np.array_equal(np.array(actual.convert("RGBA")), np.array(image)), f"Out of date: {output}"
        else:
            image.save(output, optimize=True)
        records.append({
            "sex": sex, "output": output.relative_to(ROOT).as_posix(), "size": [264, 264],
            "eye": [115, 105], "eye_to_chin": 56, "alpha_bounds": list(bounds),
            "protected_rects": [list(rect) for rect in PROTECTED_RECTS[sex]],
            "removed_partial_alpha_pixels": removed, "source_pixel_sha256": sha_pixels(original),
            "output_pixel_sha256": sha_pixels(image), "output_sha256": sha_file(output) if output.exists() else "",
        })
    previews = render_previews(cleaned) if not args.check else json.loads(MANIFEST.read_text(encoding="utf-8"))["previews"]
    manifest = {
        "schema": 1, "method": "exterior-connected alpha-only Chebyshev rim <= 2 source pixels",
        "rgb_threshold": None, "alpha_radius_source_px": 2, "sources": sources,
        "outputs": records, "previews": previews,
    }
    if args.check:
        expected = json.loads(MANIFEST.read_text(encoding="utf-8"))
        assert manifest == expected, "Portrait rim manifest is out of date"
        print("STAGE 1C PORTRAIT RIM CHECK PASSED")
    else:
        MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("Prepared two alpha-only Stage 1C selector portraits and 112/84 review sheets")


if __name__ == "__main__":
    main()
