"""Rebuild the approved female artwork pack using only its local source pixels.

Requires Pillow and numpy. No network, generation, recolouring or game integration.
The reviewed contours and facial landmarks live in the pack's recipe.json.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "art/characters/female"
ICONS = ROOT / "assets/portraits/female"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def record(path: Path) -> dict:
    with Image.open(path) as im:
        return {"path": relative(path), "sha256": sha(path),
                "size": list(im.size), "mode": im.mode}


def mask_for(source: Image.Image, stage: dict) -> Image.Image:
    """Antialias reviewed polygons; suppress paper only inside the contour.

    RGB is never changed in the native head. The skull uses its reviewed outer
    silhouette alone, so its light bone cannot be mistaken for parchment.
    """
    box = stage["head_crop_xyxy"]
    size = (box[2] - box[0], box[3] - box[1])
    coverage = Image.new("L", (size[0] * 4, size[1] * 4))
    draw = ImageDraw.Draw(coverage)
    for polygon in stage["include_polygons_source_xy"]:
        points = [((x - box[0]) * 4, (y - box[1]) * 4) for x, y in polygon]
        draw.polygon(points, fill=255)
    for polygon in stage.get("exclude_polygons_source_xy", []):
        points = [((x - box[0]) * 4, (y - box[1]) * 4) for x, y in polygon]
        draw.polygon(points, fill=0)
    # Area coverage has no ringing outside a polygon (unlike a sinc filter).
    coverage = coverage.resize(size, Image.Resampling.BOX)
    alpha = np.asarray(coverage, dtype=np.float32)
    if "paper_alpha_min_channel" in stage:
        # Paper is much lighter than the hair. Interior skin, eyes and earrings
        # stay protected by a second reviewed polygon where necessary.
        lower, upper = stage["paper_alpha_min_channel"]
        minimum = np.asarray(source.crop(box).convert("RGB")).min(axis=2)
        retention = np.clip((upper - minimum.astype(np.float32)) / (upper - lower), 0, 1)
        protected = Image.new("L", size)
        pd = ImageDraw.Draw(protected)
        for polygon in stage.get("preserve_paper_colours_source_xy", []):
            pd.polygon([(x - box[0], y - box[1]) for x, y in polygon], fill=255)
        retention[np.asarray(protected) > 0] = 1
        alpha *= retention
    if "exterior_paper_guard" in stage:
        lower, upper, radius = stage["exterior_paper_guard"]
        interior = np.asarray(coverage.filter(ImageFilter.MinFilter(2 * radius + 1)), dtype=np.float32)
        edge = np.clip((np.asarray(coverage, dtype=np.float32) - interior) / 255, 0, 1)
        minimum = np.asarray(source.crop(box).convert("RGB")).min(axis=2)
        retention = np.clip((upper - minimum.astype(np.float32)) / (upper - lower), 0, 1)
        alpha *= 1 - edge * (1 - retention)
    return Image.fromarray(np.rint(alpha).astype(np.uint8))


def icon_for(head: Image.Image, stage: dict, recipe: dict) -> tuple[Image.Image, dict]:
    box = stage["head_crop_xyxy"]
    eye = stage["eye_midpoint_source_xy"]
    target_eye = recipe["icon_eye_midpoint_xy"]
    scale = recipe["icon_eye_to_chin_px"] / (stage["chin_source_y"] - eye[1])
    # A single similarity transform preserves proportions. RGBa avoids pulling
    # invisible paper into resampled edges; native files retain exact source RGB.
    matrix = (1 / scale, 0, eye[0] - box[0] - target_eye[0] / scale,
              0, 1 / scale, eye[1] - box[1] - target_eye[1] / scale)
    icon = head.convert("RGBa").transform(
        (264, 264), Image.Transform.AFFINE, matrix,
        resample=Image.Resampling.BICUBIC).convert("RGBA")
    return icon, {"uniform_scale": scale, "target_eye_midpoint_xy": target_eye,
                  "target_eye_to_chin_px": recipe["icon_eye_to_chin_px"],
                  "resampling": "Pillow BICUBIC affine in premultiplied alpha"}


def backdrop(size: tuple[int, int], theme: str) -> Image.Image:
    colours = {"dark": (30, 32, 37, 255), "light": (244, 241, 232, 255),
               "checker": (181, 185, 190, 255)}
    im = Image.new("RGBA", size, colours[theme])
    if theme == "checker":
        draw = ImageDraw.Draw(im)
        for y in range(0, size[1], 12):
            for x in range(0, size[0], 12):
                if (x // 12 + y // 12) % 2:
                    draw.rectangle((x, y, x + 11, y + 11), fill=(217, 220, 224, 255))
    return im


def previews(recipe: dict) -> list[Path]:
    outputs = []
    icons = [Image.open(ICONS / f"form-{s['file_id']}.png").convert("RGBA")
             for s in recipe["stages"]]
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 18) if Path("C:/Windows/Fonts/arial.ttf").exists() else ImageFont.load_default()
    for theme in ("dark", "light", "checker"):
        for size in (264, 88, 66, 44):
            sheet = backdrop((5 * (size + 24) + 24, size + 70), theme)
            draw = ImageDraw.Draw(sheet)
            colour = (235, 231, 222) if theme == "dark" else (30, 32, 37)
            for i, (stage, icon) in enumerate(zip(recipe["stages"], icons)):
                thumb = icon.resize((size, size), Image.Resampling.LANCZOS)
                x = 24 + i * (size + 24)
                sheet.alpha_composite(thumb, (x, 12))
                draw.text((x, size + 27), f"0{i+1}", font=font, fill=colour)
            output = PACK / "previews" / f"heads-{size}-{theme}.png"
            sheet.convert("RGB").save(output)
            outputs.append(output)
        nice = backdrop((1464, 344), theme)
        nd = ImageDraw.Draw(nice)
        colour = (235, 231, 222) if theme == "dark" else (30, 32, 37)
        for i, (stage, icon) in enumerate(zip(recipe["stages"], icons)):
            x = 24 + i * 288
            nice.alpha_composite(icon, (x, 12))
            nd.text((x + 12, 287), stage["label_ru"], font=font, fill=colour)
            nd.text((x + 12, 312), stage["label_en"], font=font, fill=colour)
        output = PACK / "previews" / f"five-heads-{theme}.png"
        nice.convert("RGB").save(output)
        outputs.append(output)
    return outputs


def build(recipe: dict) -> None:
    ICONS.mkdir(parents=True, exist_ok=True)
    for folder in ("heads", "fullbody", "masks", "previews"):
        (PACK / folder).mkdir(exist_ok=True)
    sources = {}
    for item in recipe["sources"]:
        path = PACK / item["path"]
        assert sha(path) == item["sha256"], f"Approved master changed: {path}"
        sources[item["id"]] = Image.open(path).convert("RGB")
    manifest = {"schema": 1, "canonical_female_art_approved": "2026-08-31",
                "runtime_connected": False, "generated_this_delivery": False,
                "recipe": {"path": relative(PACK / "recipe.json"), "sha256": sha(PACK / "recipe.json")},
                "sources": [{"id": item["id"], "original_filename": item["original_filename"],
                             **record(PACK / item["path"])} for item in recipe["sources"]],
                "stages": [], "previews": []}
    for stage in recipe["stages"]:
        source = sources[stage["source_id"]]
        head = source.crop(stage["head_crop_xyxy"]).convert("RGBA")
        mask = mask_for(source, stage)
        head.putalpha(mask)
        stem = f"form-{stage['file_id']}.png"
        head_path, mask_path = PACK / "heads" / stem, PACK / "masks" / stem
        body_path, icon_path = PACK / "fullbody" / stem, ICONS / stem
        head.save(head_path)
        mask.save(mask_path)
        source.crop(stage["fullbody_crop_xyxy"]).save(body_path)
        icon, transform = icon_for(head, stage, recipe)
        icon.save(icon_path)
        manifest["stages"].append({
            "id": stage["id"], "label_ru": stage["label_ru"], "label_en": stage["label_en"],
            "source_id": stage["source_id"], "head_crop_xyxy": stage["head_crop_xyxy"],
            "fullbody_crop_xyxy": stage["fullbody_crop_xyxy"],
            "fullbody_transform": "Unscaled rectangular RGB source crop; reference only, not a runtime sprite",
            "native_head_transform": "Exact unscaled source RGB; reviewed antialiased alpha mask only",
            "native_head": record(head_path), "mask": record(mask_path),
            "fullbody_reference": record(body_path), "icon": record(icon_path),
            "icon_transform": transform, "icon_alpha_bbox": list(icon.getchannel("A").getbbox())})
    manifest["previews"] = [record(path) for path in previews(recipe)]
    (PACK / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    check(recipe)


def check(recipe: dict) -> None:
    manifest = json.loads((PACK / "manifest.json").read_text(encoding="utf-8"))
    assert len(recipe["stages"]) == len(manifest["stages"]) == 5
    assert sha(PACK / "recipe.json") == manifest["recipe"]["sha256"]
    sources = {}
    for item, output in zip(recipe["sources"], manifest["sources"]):
        path = PACK / item["path"]
        assert sha(path) == item["sha256"] == output["sha256"]
        sources[item["id"]] = Image.open(path).convert("RGB")
    for stage, result in zip(recipe["stages"], manifest["stages"]):
        source = sources[stage["source_id"]]
        for field in ("native_head", "mask", "fullbody_reference", "icon"):
            output = result[field]
            path = ROOT / output["path"]
            assert record(path) == output, f"Changed output: {path}"
        head = Image.open(ROOT / result["native_head"]["path"])
        assert head.mode == "RGBA"
        assert np.array_equal(np.asarray(head.convert("RGB")), np.asarray(source.crop(stage["head_crop_xyxy"]))), stage["id"]
        assert np.array_equal(np.asarray(head.getchannel("A")), np.asarray(mask_for(source, stage)))
        assert np.array_equal(np.asarray(Image.open(ROOT / result["fullbody_reference"]["path"])), np.asarray(source.crop(stage["fullbody_crop_xyxy"])))
        icon = Image.open(ROOT / result["icon"]["path"])
        assert icon.mode == "RGBA" and icon.size == (264, 264)
        alpha = np.asarray(icon.getchannel("A"))
        assert alpha.max() == 255 and alpha.min() == 0
        assert not np.any(alpha[:4]) and not np.any(alpha[-4:]) and not np.any(alpha[:, :4]) and not np.any(alpha[:, -4:]), stage["id"]
        expected, _ = icon_for(head, stage, recipe)
        assert np.array_equal(np.asarray(icon), np.asarray(expected))
        import_path = ROOT / (result["icon"]["path"] + ".import")
        if import_path.exists():
            settings = import_path.read_text(encoding="utf-8")
            for parameter in ("compress/mode=0", "mipmaps/generate=false", "process/fix_alpha_border=true"):
                assert parameter in settings
        print(f"PASS {stage['id']}: exact source RGB/crops, reproducible mask+icon, 264x264 RGBA8, >=4px alpha border")
    for output in manifest["previews"]:
        assert record(ROOT / output["path"]) == output
    print("PASS approved source SHA-256, manifest/output hashes, five stages, and 15 preview sheets")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate existing files without rewriting them")
    args = parser.parse_args()
    data = json.loads((PACK / "recipe.json").read_text(encoding="utf-8"))
    check(data) if args.check else build(data)
