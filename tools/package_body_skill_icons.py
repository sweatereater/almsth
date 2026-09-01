#!/usr/bin/env python3
"""Build the deterministic Almsth body-skill icon set.

Image generation supplies the anatomical accent masks.  This packager owns the
runtime contract: every icon receives the same canonical silhouette/alpha,
pose, center, footprint and baseline, and every visible pixel uses one of the
two approved RGB colors.  It also writes an auditable manifest and the visual
review contact sheets.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SET_DIR = ROOT / "art" / "skills" / "body-icons" / "2026-09-01"
CANDIDATE_DIR = SET_DIR / "candidates"
MASTER_DIR = SET_DIR / "masters"
PREVIEW_DIR = SET_DIR / "previews"
RUNTIME_DIR = ROOT / "assets" / "ui" / "skill-icons" / "body"

IDS = (
    "strong_bones",
    "flexible_joints",
    "strong_spine",
    "sharp_vision",
    "muscle_fibers",
    "stomach",
    "flesh_regeneration",
    "ears",
    "nervous_system",
    "choose_appearance",
    "fundamentals",
)

IMAGEGEN_RESULT_FILES = {
    "strong_bones": "exec-278da2d9-6187-4c48-8cc2-177b16ecefb3.png",
    "flexible_joints": "exec-2ded0f3a-43b1-4ae0-90ab-82816392997f.png",
    "strong_spine": "exec-3feb93ee-e587-4ddb-b536-f9174c29e093.png",
    "sharp_vision": "exec-d5c2bef1-c23e-4291-9fa5-85227f55955f.png",
    "muscle_fibers": "exec-7ee2dcfc-86b4-44aa-9cc4-3e84b99b1ac1.png",
    "stomach": "exec-421f750a-08cf-44ca-9146-e1c660de166a.png",
    "flesh_regeneration": "exec-4a4954c6-800a-4a17-b1be-e2956cfc9d9c.png",
    "ears": "exec-6e09f4f7-4768-4c89-89e1-557534ff7112.png",
    "nervous_system": "exec-2f075508-3d86-488b-a57d-a7a449008fbe.png",
    "choose_appearance": "exec-54ab04ab-57f7-41c0-8e82-d53c76e94040.png",
    "fundamentals": "exec-8c65bc86-1e8d-42a2-bd29-5ecdf397c1f3.png",
}

GRAPHITE = (0x59, 0x67, 0x7A)
ANATOMY_RED = (0xE3, 0x5D, 0x63)
MASTER_SIZE = 512
RUNTIME_SIZE = 128
MASTER_SAFE = (64, 64, 448, 448)
RUNTIME_SAFE = (16, 16, 112, 112)
MASTER_BASELINE = 448
RUNTIME_BASELINE = 112

# Expansion is performed after aligning each generated red mask to the
# canonical silhouette.  It keeps important anatomy legible at the 40 px
# minimum review size without introducing additional colors or alpha.
ACCENT_EXPANSION = {
    "strong_bones": 3,
    "flexible_joints": 5,
    "strong_spine": 13,
    "sharp_vision": 11,
    "muscle_fibers": 1,
    "stomach": 5,
    "flesh_regeneration": 1,
    "ears": 15,
    "nervous_system": 1,
    "choose_appearance": 5,
    "fundamentals": 5,
}


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def image_bytes(image: Image.Image) -> bytes:
    return image.tobytes()


def foreground_mask(image: Image.Image) -> Image.Image:
    """Return a mask suitable for locating the generated mannequin.

    The canonical generation has real transparency.  Some edit results have
    an opaque baked checker despite the prompt, so those are located by their
    dark/non-neutral figure pixels instead.  The checker cells are much lighter
    than the approved graphite/red artwork.
    """

    rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8)
    alpha = rgba[:, :, 3]
    if int(alpha.min()) < 255:
        mask = alpha > 12
    else:
        rgb = rgba[:, :, :3].astype(np.int16)
        channel_min = rgb.min(axis=2)
        channel_max = rgb.max(axis=2)
        red = (
            (rgb[:, :, 0] >= 125)
            & ((rgb[:, :, 0] - rgb[:, :, 1]) >= 18)
            & ((rgb[:, :, 0] - rgb[:, :, 2]) >= 10)
        )
        dark_figure = channel_min < 205
        colored_figure = (channel_max - channel_min) > 24
        mask = dark_figure | colored_figure | red
    return Image.fromarray((mask.astype(np.uint8) * 255), mode="L")


def accent_mask(image: Image.Image) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.int16)
    r = rgba[:, :, 0]
    g = rgba[:, :, 1]
    b = rgba[:, :, 2]
    a = rgba[:, :, 3]
    red = (
        (r >= 125)
        & ((r - g) >= 22)
        & ((r - b) >= 10)
        & ((r * 100) >= (g * 118))
        & (a > 12)
    )
    return Image.fromarray((red.astype(np.uint8) * 255), mode="L")


def fit_inside(width: int, height: int, max_width: int, max_height: int) -> tuple[int, int]:
    scale = min(max_width / float(width), max_height / float(height))
    return max(1, round(width * scale)), max(1, round(height * scale))


def target_box(source_box: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    width = source_box[2] - source_box[0]
    height = source_box[3] - source_box[1]
    target_width, target_height = fit_inside(width, height, 384, 384)
    left = (MASTER_SIZE - target_width) // 2
    top = MASTER_BASELINE - target_height
    return left, top, left + target_width, top + target_height


def align_mask(
    mask: Image.Image,
    source_box: tuple[int, int, int, int],
    destination_box: tuple[int, int, int, int],
) -> Image.Image:
    width = destination_box[2] - destination_box[0]
    height = destination_box[3] - destination_box[1]
    crop = mask.crop(source_box).resize((width, height), Image.Resampling.LANCZOS)
    result = Image.new("L", (MASTER_SIZE, MASTER_SIZE), 0)
    result.paste(crop, destination_box[:2])
    return result


def clip_to_safe(mask: Image.Image, safe: tuple[int, int, int, int]) -> Image.Image:
    pixels = np.asarray(mask, dtype=np.uint8).copy()
    left, top, right, bottom = safe
    pixels[:top, :] = 0
    pixels[bottom:, :] = 0
    pixels[:, :left] = 0
    pixels[:, right:] = 0
    return Image.fromarray(pixels, mode="L")


def runtime_box(left: float, top: float, right: float, bottom: float) -> tuple[int, int, int, int]:
    """Convert authored 128-space anatomy coordinates to the 512 master."""

    return tuple(round(value * (MASTER_SIZE / RUNTIME_SIZE)) for value in (left, top, right, bottom))


def normalize_head_alpha(alpha: Image.Image) -> Image.Image:
    """Give the shared mannequin a stable readable face and external ears.

    ImageGen produced an unusually narrow head whose eye/ear edits collapsed to
    the same one-pixel mark after downsampling.  This small common silhouette
    normalization applies to every icon, so the alpha/pose contract remains
    byte-identical while the two paired organs have enough room at runtime.
    """

    result = alpha.copy()
    draw = ImageDraw.Draw(result)
    draw.ellipse(runtime_box(54, 16, 74, 34), fill=255)
    draw.ellipse(runtime_box(52, 20, 60, 33), fill=255)
    draw.ellipse(runtime_box(68, 20, 76, 33), fill=255)
    return clip_to_safe(result, MASTER_SAFE)


def authored_accent_mask(skill_id: str) -> Image.Image | None:
    """Return exact large-form anatomy for the three high-risk small icons."""

    if skill_id not in {"strong_bones", "sharp_vision", "ears"}:
        return None
    mask = Image.new("L", (MASTER_SIZE, MASTER_SIZE), 0)
    draw = ImageDraw.Draw(mask)
    if skill_id == "sharp_vision":
        # Two horizontal eyes, each ~9x7 runtime pixels with a clear center gap.
        draw.ellipse(runtime_box(52, 22, 61, 29), fill=255)
        draw.ellipse(runtime_box(67, 22, 76, 29), fill=255)
        return mask
    if skill_id == "ears":
        # Two tall external ears.  Their aspect and separation deliberately
        # differ from the eye mask at every reviewed downsample size.
        draw.ellipse(runtime_box(52, 20, 61, 33), fill=255)
        draw.ellipse(runtime_box(67, 20, 76, 33), fill=255)
        return mask

    # Simplified front-facing skeleton.  These are deliberately separated
    # strokes/loops inside the graphite body, never a recolored mannequin.
    skull = runtime_box(56, 17, 72, 32)
    draw.ellipse(skull, outline=255, width=12)
    draw.line([runtime_box(58, 29, 58, 29)[:2], runtime_box(70, 29, 70, 29)[:2]], fill=255, width=8)
    # Central spine and paired clavicles.
    draw.line([runtime_box(64, 31, 64, 31)[:2], runtime_box(64, 72, 64, 72)[:2]], fill=255, width=11)
    draw.line([runtime_box(64, 36, 64, 36)[:2], runtime_box(52, 40, 52, 40)[:2]], fill=255, width=10)
    draw.line([runtime_box(64, 36, 64, 36)[:2], runtime_box(76, 40, 76, 40)[:2]], fill=255, width=10)
    # Four closed, graphite-separated ribs around the spine.
    for rib_box in [
        (52, 38, 76, 47),
        (53, 43, 75, 52),
        (54, 48, 74, 57),
        (56, 53, 72, 61),
    ]:
        draw.ellipse(runtime_box(*rib_box), outline=255, width=8)
    # Pelvic ring and sacral V.
    draw.ellipse(runtime_box(54, 61, 74, 74), outline=255, width=11)
    draw.line(
        [runtime_box(56, 65, 56, 65)[:2], runtime_box(64, 73, 64, 73)[:2], runtime_box(72, 65, 72, 65)[:2]],
        fill=255,
        width=9,
        joint="curve",
    )
    # Major arm and leg bones stop before hands and feet, leaving graphite
    # margins around every stroke so the silhouette never reads as solid red.
    for points in [
        [(51, 40), (45, 54), (39, 67)],
        [(77, 40), (83, 54), (89, 67)],
        [(58, 72), (56, 90), (55, 107)],
        [(70, 72), (72, 90), (73, 107)],
    ]:
        draw.line(
            [runtime_box(x, y, x, y)[:2] for x, y in points],
            fill=255,
            width=11,
            joint="curve",
        )
    return mask


def build_rgba(alpha: Image.Image, accent: Image.Image) -> Image.Image:
    alpha_array = np.asarray(alpha, dtype=np.uint8)
    accent_array = np.asarray(accent, dtype=np.uint8) >= 96
    visible = alpha_array > 0
    accent_array &= visible
    rgba = np.zeros((alpha.height, alpha.width, 4), dtype=np.uint8)
    rgba[:, :, :3] = GRAPHITE
    rgba[accent_array, :3] = ANATOMY_RED
    rgba[:, :, 3] = alpha_array
    rgba[~visible, :3] = 0
    return Image.fromarray(rgba, mode="RGBA")


def runtime_from_master(master_alpha: Image.Image, master_accent: Image.Image) -> Image.Image:
    alpha = master_alpha.resize((RUNTIME_SIZE, RUNTIME_SIZE), Image.Resampling.LANCZOS)
    alpha = clip_to_safe(alpha, RUNTIME_SAFE)
    accent = master_accent.resize((RUNTIME_SIZE, RUNTIME_SIZE), Image.Resampling.LANCZOS)
    return build_rgba(alpha, accent)


def bbox_as_list(mask: Image.Image) -> list[int]:
    box = mask.getbbox()
    if box is None:
        return []
    return [int(value) for value in box]


def red_components(image: Image.Image, minimum_pixels: int = 4) -> list[dict[str, int]]:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8)
    red = np.all(rgba[:, :, :3] == np.asarray(ANATOMY_RED), axis=2) & (rgba[:, :, 3] > 0)
    visited = np.zeros(red.shape, dtype=bool)
    components: list[dict[str, int]] = []
    height, width = red.shape
    for start_y, start_x in zip(*np.where(red & ~visited)):
        if visited[start_y, start_x]:
            continue
        stack = [(int(start_x), int(start_y))]
        visited[start_y, start_x] = True
        xs: list[int] = []
        ys: list[int] = []
        while stack:
            x, y = stack.pop()
            xs.append(x)
            ys.append(y)
            for offset_y in (-1, 0, 1):
                for offset_x in (-1, 0, 1):
                    if offset_x == 0 and offset_y == 0:
                        continue
                    neighbor_x = x + offset_x
                    neighbor_y = y + offset_y
                    if (
                        0 <= neighbor_x < width
                        and 0 <= neighbor_y < height
                        and red[neighbor_y, neighbor_x]
                        and not visited[neighbor_y, neighbor_x]
                    ):
                        visited[neighbor_y, neighbor_x] = True
                        stack.append((neighbor_x, neighbor_y))
        if len(xs) >= minimum_pixels:
            components.append({
                "left": min(xs), "top": min(ys),
                "right": max(xs) + 1, "bottom": max(ys) + 1,
                "pixels": len(xs),
            })
    return sorted(components, key=lambda component: component["left"])


def dominant_red_components(image: Image.Image) -> list[dict[str, int]]:
    """Find red organs after UI-sized LANCZOS resampling."""

    rgba = np.asarray(image.convert("RGBA"), dtype=np.int16)
    dominant = (
        ((rgba[:, :, 0] - rgba[:, :, 1]) > 45)
        & ((rgba[:, :, 0] - rgba[:, :, 2]) > 30)
        & (rgba[:, :, 3] > 32)
    )
    normalized = np.zeros(rgba.shape, dtype=np.uint8)
    normalized[dominant, :3] = ANATOMY_RED
    normalized[dominant, 3] = 255
    return red_components(Image.fromarray(normalized, mode="RGBA"), minimum_pixels=1)


def write_contact_sheet(paths: dict[str, Path], name: str, background: str) -> None:
    sizes = (128, 64, 54, 48, 41, 40)
    column_width = 144
    row_height = 152
    left_margin = 52
    top_margin = 38
    width = left_margin + column_width * len(IDS)
    height = top_margin + row_height * len(sizes)
    if background == "dark":
        sheet = Image.new("RGBA", (width, height), (0x11, 0x17, 0x20, 255))
    elif background == "light":
        sheet = Image.new("RGBA", (width, height), (0xF0, 0xF2, 0xF4, 255))
    else:
        sheet = Image.new("RGBA", (width, height), (0xE8, 0xE8, 0xE8, 255))
        draw = ImageDraw.Draw(sheet)
        checker = 12
        for y in range(0, height, checker):
            for x in range(0, width, checker):
                if ((x // checker) + (y // checker)) % 2:
                    draw.rectangle((x, y, x + checker - 1, y + checker - 1), fill=(0xC8, 0xCC, 0xD0, 255))

    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    text_color = (235, 238, 242, 255) if background == "dark" else (32, 38, 46, 255)
    for index, skill_id in enumerate(IDS):
        x = left_margin + index * column_width
        label = skill_id.replace("_", "\n")
        draw.multiline_text((x + column_width // 2, 4), label, font=font, fill=text_color, anchor="ma", align="center", spacing=0)
    for row, size in enumerate(sizes):
        y = top_margin + row * row_height
        draw.text((6, y + row_height // 2), str(size), font=font, fill=text_color, anchor="lm")
        for column, skill_id in enumerate(IDS):
            icon = Image.open(paths[skill_id]).convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
            x = left_margin + column * column_width + (column_width - size) // 2
            icon_y = y + (row_height - size) // 2
            sheet.alpha_composite(icon, (x, icon_y))
    sheet.save(PREVIEW_DIR / name, optimize=False, compress_level=9)


def validate_runtime(images: dict[str, Image.Image]) -> None:
    alpha_hashes: set[str] = set()
    for skill_id, image in images.items():
        if image.size != (RUNTIME_SIZE, RUNTIME_SIZE) or image.mode != "RGBA":
            raise ValueError(f"{skill_id}: expected 128x128 RGBA")
        rgba = np.asarray(image, dtype=np.uint8)
        alpha = rgba[:, :, 3]
        alpha_hashes.add(sha256_bytes(alpha.tobytes()))
        if np.any(alpha[: RUNTIME_SAFE[1], :]) or np.any(alpha[RUNTIME_SAFE[3] :, :]):
            raise ValueError(f"{skill_id}: alpha escapes the vertical safe rect")
        if np.any(alpha[:, : RUNTIME_SAFE[0]]) or np.any(alpha[:, RUNTIME_SAFE[2] :]):
            raise ValueError(f"{skill_id}: alpha escapes the horizontal safe rect")
        visible_colors = {tuple(color) for color in rgba[alpha > 0, :3]}
        if not visible_colors.issubset({GRAPHITE, ANATOMY_RED}):
            raise ValueError(f"{skill_id}: non-contract RGB colors {visible_colors}")
        if ANATOMY_RED not in visible_colors:
            raise ValueError(f"{skill_id}: no anatomical red remains after packaging")
    if len(alpha_hashes) != 1:
        raise ValueError("runtime alpha masks differ")

    strong = np.asarray(images["strong_bones"], dtype=np.uint8)
    strong_visible = strong[:, :, 3] > 0
    strong_red = np.all(strong[:, :, :3] == np.asarray(ANATOMY_RED), axis=2) & strong_visible
    strong_ratio = float(np.count_nonzero(strong_red)) / float(np.count_nonzero(strong_visible))
    if not 0.12 <= strong_ratio <= 0.52:
        raise ValueError(f"strong_bones: skeleton red coverage {strong_ratio:.3f} reads as empty or solid body")

    paired: dict[str, list[dict[str, int]]] = {
        skill_id: red_components(images[skill_id]) for skill_id in ("sharp_vision", "ears")
    }
    for skill_id, components in paired.items():
        if len(components) != 2:
            raise ValueError(f"{skill_id}: expected exactly two separated red organs, got {components}")
        if components[1]["left"] - components[0]["right"] < 1:
            raise ValueError(f"{skill_id}: paired organs have no center gap")
    for eye in paired["sharp_vision"]:
        if eye["right"] - eye["left"] < 7 or eye["bottom"] - eye["top"] < 5:
            raise ValueError(f"sharp_vision: eye component is too small: {eye}")
    for ear in paired["ears"]:
        if ear["right"] - ear["left"] < 7 or ear["bottom"] - ear["top"] < 10:
            raise ValueError(f"ears: external-ear component is too small: {ear}")
    if any(
        (ear["bottom"] - ear["top"]) <= (eye["bottom"] - eye["top"])
        for ear, eye in zip(paired["ears"], paired["sharp_vision"])
    ):
        raise ValueError("sharp_vision and ears must retain distinct paired silhouettes")
    for review_size in (64, 54, 48, 41, 40):
        reviewed = {
            skill_id: dominant_red_components(
                images[skill_id].resize((review_size, review_size), Image.Resampling.LANCZOS)
            )
            for skill_id in ("sharp_vision", "ears")
        }
        for skill_id, components in reviewed.items():
            if len(components) != 2:
                raise ValueError(
                    f"{skill_id}: {review_size}px review must retain two red organs, got {components}"
                )
        if reviewed["sharp_vision"] == reviewed["ears"] or any(
            (ear["bottom"] - ear["top"]) <= (eye["bottom"] - eye["top"])
            for ear, eye in zip(reviewed["ears"], reviewed["sharp_vision"])
        ):
            raise ValueError(
                f"sharp_vision and ears become visually indistinguishable at {review_size}px"
            )


def validate_manifest_paths(expected_icons: dict[str, object]) -> None:
    manifest_path = SET_DIR / "manifest.json"
    if not manifest_path.is_file():
        raise FileNotFoundError("body-skill manifest is missing")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    icons = manifest.get("icons", {})
    if set(icons) != set(IDS):
        raise ValueError("manifest icon IDs differ from the canonical 11 body skills")
    for skill_id in IDS:
        entry = icons[skill_id]
        expected = expected_icons[skill_id]
        expected_runtime = os.path.relpath(RUNTIME_DIR / f"{skill_id}.png", SET_DIR).replace("\\", "/")
        runtime_reference = str(entry.get("runtime", ""))
        resolved_runtime = (SET_DIR / runtime_reference).resolve()
        if runtime_reference != expected_runtime or resolved_runtime != (RUNTIME_DIR / f"{skill_id}.png").resolve():
            raise ValueError(f"{skill_id}: manifest runtime path does not resolve to the packaged asset")
        if not resolved_runtime.is_file():
            raise FileNotFoundError(f"{skill_id}: manifest runtime target is missing")
        for field in ("mapping", "candidate", "master", "runtime_sha256", "runtime_alpha_sha256"):
            if entry.get(field) != expected.get(field):
                raise ValueError(f"{skill_id}: manifest {field} is stale")


def build(check: bool) -> None:
    missing = [str(CANDIDATE_DIR / f"{skill_id}.png") for skill_id in IDS if not (CANDIDATE_DIR / f"{skill_id}.png").is_file()]
    if missing:
        raise FileNotFoundError("missing ImageGen candidates:\n" + "\n".join(missing))

    MASTER_DIR.mkdir(parents=True, exist_ok=True)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)

    canonical = Image.open(CANDIDATE_DIR / "strong_bones.png").convert("RGBA")
    canonical_foreground = foreground_mask(canonical)
    canonical_source_box = canonical_foreground.getbbox()
    if canonical_source_box is None:
        raise ValueError("canonical figure has no foreground")
    destination_box = target_box(canonical_source_box)
    canonical_alpha = align_mask(canonical.getchannel("A"), canonical_source_box, destination_box)
    canonical_alpha = normalize_head_alpha(clip_to_safe(canonical_alpha, MASTER_SAFE))

    manifest_icons: dict[str, object] = {}
    runtime_images: dict[str, Image.Image] = {}
    runtime_paths: dict[str, Path] = {}
    master_alpha_hash = sha256_bytes(np.asarray(canonical_alpha, dtype=np.uint8).tobytes())

    for skill_id in IDS:
        candidate_path = CANDIDATE_DIR / f"{skill_id}.png"
        candidate = Image.open(candidate_path).convert("RGBA")
        source_foreground = foreground_mask(candidate)
        source_box = source_foreground.getbbox()
        if source_box is None:
            raise ValueError(f"{skill_id}: generated candidate has no foreground")
        authored_accent = authored_accent_mask(skill_id)
        accent = (
            authored_accent
            if authored_accent is not None
            else align_mask(accent_mask(candidate), source_box, destination_box)
        )

        if authored_accent is None and skill_id in ("flesh_regeneration", "nervous_system"):
            # Remove the generated capillary/fine-nerve noise while keeping the
            # large heart/brain, central trunk and strongest limb branches.
            accent = accent.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(5))

        if authored_accent is None and skill_id == "strong_spine":
            # The edit occasionally retains a red skull.  Preserve only the
            # central spinal column from the skull base through the sacrum.
            accent_pixels = np.asarray(accent, dtype=np.uint8).copy()
            accent_pixels[:104, :] = 0
            accent_pixels[:, :226] = 0
            accent_pixels[:, 286:] = 0
            accent_pixels[374:, :] = 0
            accent = Image.fromarray(accent_pixels, mode="L")

        if authored_accent is None:
            expansion = ACCENT_EXPANSION[skill_id]
            if expansion > 1:
                accent = accent.filter(ImageFilter.MaxFilter(expansion))
        accent = Image.composite(accent, Image.new("L", accent.size, 0), canonical_alpha)

        master = build_rgba(canonical_alpha, accent)
        runtime = runtime_from_master(canonical_alpha, accent)
        runtime_images[skill_id] = runtime

        master_path = MASTER_DIR / f"{skill_id}.png"
        runtime_path = RUNTIME_DIR / f"{skill_id}.png"
        runtime_paths[skill_id] = runtime_path
        if check:
            if not master_path.is_file() or not runtime_path.is_file():
                raise FileNotFoundError(f"{skill_id}: packaged output is missing")
            if Image.open(master_path).convert("RGBA").tobytes() != master.tobytes():
                raise ValueError(f"{skill_id}: master differs from deterministic build")
            if Image.open(runtime_path).convert("RGBA").tobytes() != runtime.tobytes():
                raise ValueError(f"{skill_id}: runtime differs from deterministic build")
        else:
            master.save(master_path, optimize=False, compress_level=9)
            runtime.save(runtime_path, optimize=False, compress_level=9)

        runtime_alpha = runtime.getchannel("A")
        runtime_accent = Image.fromarray(
            (np.all(np.asarray(runtime)[:, :, :3] == np.asarray(ANATOMY_RED), axis=2).astype(np.uint8) * 255),
            mode="L",
        )
        manifest_icons[skill_id] = {
            "mapping": f"res://assets/ui/skill-icons/body/{skill_id}.png",
            "imagegen_result_file": IMAGEGEN_RESULT_FILES[skill_id],
            "candidate": f"candidates/{skill_id}.png",
            "candidate_sha256": sha256_file(candidate_path),
            "candidate_size": list(candidate.size),
            "candidate_foreground_bbox": list(source_box),
            "master": f"masters/{skill_id}.png",
            "master_sha256": sha256_file(master_path) if master_path.is_file() else "",
            "master_alpha_sha256": master_alpha_hash,
            "runtime": os.path.relpath(runtime_path, SET_DIR).replace("\\", "/"),
            "runtime_sha256": sha256_file(runtime_path) if runtime_path.is_file() else "",
            "runtime_alpha_sha256": sha256_bytes(np.asarray(runtime_alpha, dtype=np.uint8).tobytes()),
            "runtime_used_rect": bbox_as_list(runtime_alpha),
            "runtime_accent_rect": bbox_as_list(runtime_accent),
            "runtime_red_pixels": int(np.count_nonzero(np.asarray(runtime_accent))),
        }

    validate_runtime(runtime_images)
    if check:
        validate_manifest_paths(manifest_icons)
        print("Body skill icon package check: PASS (11 deterministic runtime icons)")
        return

    write_contact_sheet(runtime_paths, "contact-dark.png", "dark")
    write_contact_sheet(runtime_paths, "contact-light.png", "light")
    write_contact_sheet(runtime_paths, "contact-checker.png", "checker")

    manifest = {
        "schema_version": 1,
        "set": "body-skill-icons-2026-09-01",
        "generation_workflow": "one canonical generation plus ten precise edits from that canonical",
        "canonical_skill_id": "strong_bones",
        "canonical_source_bbox": list(canonical_source_box),
        "master_destination_bbox": list(destination_box),
        "master_size": [MASTER_SIZE, MASTER_SIZE],
        "runtime_size": [RUNTIME_SIZE, RUNTIME_SIZE],
        "master_safe_rect": list(MASTER_SAFE),
        "runtime_safe_rect": list(RUNTIME_SAFE),
        "master_baseline": MASTER_BASELINE,
        "runtime_baseline": RUNTIME_BASELINE,
        "palette": {"silhouette": "#59677A", "anatomy": "#E35D63"},
        "alpha_contract": "identical byte-for-byte across all 11 masters and all 11 runtime icons",
        "downsample": "Pillow LANCZOS alpha/accent masks; RGB requantized to exact palette",
        "import": {
            "compress/mode": 0,
            "mipmaps/generate": False,
            "process/fix_alpha_border": True,
            "process/premult_alpha": False,
            "process/size_limit": 0,
        },
        "icons": manifest_icons,
        "contact_sheets": [
            "previews/contact-dark.png",
            "previews/contact-light.png",
            "previews/contact-checker.png",
        ],
    }
    (SET_DIR / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Body skill icon package: wrote 11 masters, 11 runtime icons, manifest and contact sheets")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="verify checked-in PNG pixels against a fresh deterministic build")
    args = parser.parse_args()
    build(args.check)


if __name__ == "__main__":
    main()
