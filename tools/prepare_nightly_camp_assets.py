"""Build the approved 2026-09-01 camp base and independent runtime layers.

The empty v2 concept supplies the base.  A reviewed built-in ImageGen background-extraction
edit of the furnished v2 concept supplies isolated prop pixels; its baked light checker is
removed by an edge-connected neutral-light matte.  No furnished-minus-empty subtraction is
used.  Each module is placed into the approved v2 composition and cropped to its own tight
RGBA bounds.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import tempfile
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
CONCEPT = ROOT / "art" / "concepts" / "camp" / "2026-09-01"
ASSET_ROOT = ROOT / "assets" / "art" / "camp-2026-09-01"
REVIEW_ROOT = CONCEPT / "runtime-review"
ISOLATION_CANDIDATE = CONCEPT / "candidates" / "camp-isolation-attempt-03.png"
ISOLATION_ATTEMPTS = [
    {
        "attempt": 1,
        "candidate": "camp-isolation-attempt-01.png",
        "response_item_ordinal": 2890,
        "custom_tool_call_id": "ctc_0e02eb5ad014acac016a961b77ca8087d29efe793644c03d9d",
        "imagegen_call_id": "call_sxbfVvHwouR3lz9HpNdqIpPq",
        "tool_result_id": "exec-5e8511df-a4dd-489e-9ec0-e2590759a2fb",
        "verdict": "rejected: furnishings were rearranged and overlapped",
    },
    {
        "attempt": 2,
        "candidate": "camp-isolation-attempt-02.png",
        "response_item_ordinal": 3131,
        "custom_tool_call_id": "ctc_0e02eb5ad014acac016a961e274a1887d2a83a8ab5ee6b676f",
        "imagegen_call_id": "call_DD6ejrGvudSjzn34L7o6QYdn",
        "tool_result_id": "exec-1eada5ca-e429-4c65-acd0-94134846771e",
        "verdict": "rejected: exact-position retry still rearranged furnishings",
    },
    {
        "attempt": 3,
        "candidate": "camp-isolation-attempt-03.png",
        "response_item_ordinal": 3289,
        "custom_tool_call_id": "ctc_0e02eb5ad014acac016a961f9ee19487d28fd8246174b12093",
        "imagegen_call_id": "call_vdYZLrxbzmCAKF25gzZLAjKd",
        "tool_result_id": "exec-f434ce79-a3d2-4053-b468-b957a7025523",
        "verdict": "accepted: clean independent 4-by-3 atlas",
    },
]
DRAW_ORDER = [
    "mural", "bunk", "textile_area", "workbench", "writing_set", "ritual_table",
    "crusher", "whetstone", "campfire", "kettle", "rocking_chair", "record_player",
]

# Attempt 03 supplies reviewed isolated RGB; a deterministic neutral-light matte supplies
# alpha. Source/target rectangles place each disjoint atlas cell into the approved v2
# composition; furnished-minus-empty subtraction is never used.
MASK_COMPONENTS = {
    "mural": [((0, 0, 362, 362), (468, 90, 573, 177))],
    "bunk": [((362, 0, 724, 362), (610, 116, 793, 269))],
    "textile_area": [((724, 0, 1086, 362), (209, 102, 397, 261))],
    "workbench": [((1086, 0, 1448, 362), (40, 140, 214, 285))],
    "writing_set": [((0, 362, 362, 724), (70, 112, 210, 206))],
    "ritual_table": [((362, 362, 724, 704), (415, 143, 577, 272))],
    "crusher": [((724, 362, 1086, 724), (32, 242, 222, 459))],
    "whetstone": [((1086, 362, 1448, 724), (216, 273, 349, 414))],
    "campfire": [((0, 724, 362, 1086), (336, 293, 522, 431))],
    "kettle": [((400, 704, 660, 1010), (365, 235, 500, 368))],
    "rocking_chair": [((724, 724, 1086, 1086), (516, 239, 693, 445))],
    "record_player": [((1086, 724, 1448, 1086), (655, 227, 815, 469))],
}

HITBOXES = {
    "crusher": [54, 304, 142, 105],
    "whetstone": [237, 298, 93, 91],
    "ritual_table": [430, 181, 132, 77],
    "kettle": [397, 268, 72, 66],
}

# The two standalone workshop machines are each one contiguous owned silhouette.
# Attempt 03 also contains detached, unrelated alpha islands in these atlas cells:
# a bright orange arc below the whetstone and tiny debris below/beside the crusher.
# Keep only the primary 8-connected alpha cluster for these layers.  Multi-part
# modules such as the kettle and writing set intentionally remain exempt.
PRIMARY_CLUSTER_LAYERS = {"crusher", "whetstone"}


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def _normalize(source: Path) -> Image.Image:
    image = Image.open(source).convert("RGB")
    if image.size != (1639, 959):
        raise ValueError(f"unexpected approved concept size: {source} {image.size}")
    # Crop three horizontal edge pixels total (one left, two right), then duplicate
    # the last architectural edge row to reach the shared 1636x960 review space.
    cropped = image.crop((1, 0, 1637, 959))
    normalized = Image.new("RGB", (1636, 960))
    normalized.paste(cropped, (0, 0))
    normalized.paste(cropped.crop((0, 958, 1636, 959)), (0, 959))
    return normalized


def _base_half(image: Image.Image) -> Image.Image:
    return image.resize((818, 480), Image.Resampling.LANCZOS).convert("RGB")


def _connected_light_background_alpha(image: Image.Image) -> Image.Image:
    """Extract the candidate's neutral checker without using the empty concept."""

    rgb = image.convert("RGB")
    eligible = Image.new("L", rgb.size, 255)
    source = rgb.load()
    pixels = eligible.load()
    for y in range(rgb.height):
        for x in range(rgb.width):
            red, green, blue = source[x, y]
            brightness = (red + green + blue) / 3.0
            saturation = max(red, green, blue) - min(red, green, blue)
            pixels[x, y] = 0 if brightness >= 180.0 and saturation <= 45 else 255
    # Remove every neutral-light checker pixel, including pockets enclosed between
    # table legs or chair slats; retaining only edge-connected cells left white holes.
    return eligible.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.55))


def _isolated_component(
    catalog: Image.Image,
    catalog_alpha: Image.Image,
    source_box: tuple[int, int, int, int],
    target_box: tuple[int, int, int, int],
) -> Image.Image:
    component_alpha = catalog_alpha.crop(source_box)
    visible = component_alpha.point(lambda value: 255 if value > 8 else 0).getbbox()
    if visible is None:
        raise ValueError(f"empty isolation component: {source_box}")
    component = catalog.crop(source_box).convert("RGBA").crop(visible)
    component.putalpha(component_alpha.crop(visible))
    left, top, right, bottom = target_box
    component = component.resize((right - left, bottom - top), Image.Resampling.LANCZOS)
    placed = Image.new("RGBA", (818, 480), (0, 0, 0, 0))
    placed.alpha_composite(component, (left, top))
    return placed


def _alpha_components(
    alpha: Image.Image,
    threshold: int = 0,
) -> list[dict[str, object]]:
    """Return deterministic 8-connected alpha components, largest first."""

    pixels = alpha.load()
    width, height = alpha.size
    visited: set[tuple[int, int]] = set()
    components: list[dict[str, object]] = []
    for y in range(height):
        for x in range(width):
            if (x, y) in visited or pixels[x, y] <= threshold:
                continue
            pending = [(x, y)]
            visited.add((x, y))
            points: list[tuple[int, int]] = []
            while pending:
                current_x, current_y = pending.pop()
                points.append((current_x, current_y))
                for neighbor_y in range(current_y - 1, current_y + 2):
                    for neighbor_x in range(current_x - 1, current_x + 2):
                        if neighbor_x == current_x and neighbor_y == current_y:
                            continue
                        neighbor = (neighbor_x, neighbor_y)
                        if (
                            0 <= neighbor_x < width
                            and 0 <= neighbor_y < height
                            and neighbor not in visited
                            and pixels[neighbor_x, neighbor_y] > threshold
                        ):
                            visited.add(neighbor)
                            pending.append(neighbor)
            xs = [point[0] for point in points]
            ys = [point[1] for point in points]
            components.append(
                {
                    "points": points,
                    "pixel_count": len(points),
                    "bounds_xyxy": [min(xs), min(ys), max(xs) + 1, max(ys) + 1],
                }
            )
    components.sort(
        key=lambda component: (
            -int(component["pixel_count"]),
            list(component["bounds_xyxy"]),
        )
    )
    return components


def _retain_primary_alpha_cluster(
    layer_id: str,
    mask: Image.Image,
) -> tuple[Image.Image, dict[str, object]]:
    """Remove detached atlas leaks from a documented single-cluster module."""

    components = _alpha_components(mask)
    if not components:
        raise ValueError(f"empty alpha component set: {layer_id}")
    primary = components[0]
    cleaned = Image.new("L", mask.size, 0)
    cleaned_pixels = cleaned.load()
    source_pixels = mask.load()
    for x, y in primary["points"]:
        cleaned_pixels[x, y] = source_pixels[x, y]
    removed = components[1:]
    removed_mask = ImageChops.subtract(mask, cleaned)
    removed_above_16 = _alpha_components(removed_mask, threshold=16)
    return cleaned, {
        "policy": "retain_largest_8_connected_alpha_cluster",
        "alpha_threshold": 0,
        "source_component_count": len(components),
        "removed_component_count": len(removed),
        "removed_alpha_pixel_count": sum(int(component["pixel_count"]) for component in removed),
        "removed_components_xyxy": [component["bounds_xyxy"] for component in removed],
        "removed_components_above_16": [
            {
                "pixel_count": int(component["pixel_count"]),
                "bounds_xyxy": component["bounds_xyxy"],
            }
            for component in removed_above_16
        ],
    }


def _layer(
    catalog: Image.Image,
    catalog_alpha: Image.Image,
    layer_id: str,
) -> tuple[Image.Image, tuple[int, int, int, int], float, dict[str, object] | None]:
    rgba = Image.new("RGBA", (818, 480), (0, 0, 0, 0))
    for source_box, target_box in MASK_COMPONENTS[layer_id]:
        rgba = Image.alpha_composite(
            rgba,
            _isolated_component(catalog, catalog_alpha, source_box, target_box),
        )
    mask = rgba.getchannel("A")
    # ImageGen's RGB atlas contains a faint neutral fringe/contact plate against
    # its light review background. Remove only neutral pixels near the silhouette
    # edge; keep interior metal highlights and every coloured material pixel.
    binary = mask.point(lambda value: 255 if value > 8 else 0)
    interior = binary.filter(ImageFilter.MinFilter(11))
    edge = ImageChops.subtract(binary, interior)
    neutral = Image.new("L", rgba.size, 0)
    rgb_pixels = rgba.convert("RGB").load()
    neutral_pixels = neutral.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue = rgb_pixels[x, y]
            brightness = (red + green + blue) / 3.0
            saturation = max(red, green, blue) - min(red, green, blue)
            if brightness >= 82.0 and saturation <= 30:
                neutral_pixels[x, y] = 255
    mask = ImageChops.subtract(mask, ImageChops.multiply(edge, neutral))
    if layer_id == "ritual_table":
        # The atlas rendered a pale review plate in the open space below the table.
        # It is neither a prop nor a contact shadow, so key it out locally while
        # retaining the saturated wood/iron feet around it.
        mask_pixels = mask.load()
        for y in range(242, 272):
            for x in range(438, 555):
                red, green, blue = rgb_pixels[x, y]
                brightness = (red + green + blue) / 3.0
                saturation = max(red, green, blue) - min(red, green, blue)
                if brightness >= 48.0 and saturation <= 26:
                    mask_pixels[x, y] = 0
    # Erode one pixel before the final feather to remove the light checker fringe
    # that ImageGen baked into boundary antialiasing.
    mask = mask.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.55))
    component_cleanup = None
    if layer_id in PRIMARY_CLUSTER_LAYERS:
        mask, component_cleanup = _retain_primary_alpha_cluster(layer_id, mask)
    bounds = mask.point(lambda value: 255 if value > 2 else 0).getbbox()
    if bounds is None:
        raise ValueError(f"empty layer mask: {layer_id}")
    rgba.putalpha(mask)
    cropped = rgba.crop(bounds)
    alpha = cropped.getchannel("A")
    occupied = sum(count for count, value in alpha.getcolors(alpha.width * alpha.height) if value > 8)
    coverage = occupied / float(alpha.width * alpha.height)
    return cropped, bounds, coverage, component_cleanup


def _assert_independence(
    layer_id: str,
    layer: Image.Image,
    bounds: tuple[int, int, int, int],
    coverage: float,
) -> None:
    """Reject broad patches and detached leaks in single-cluster workshop props."""

    if coverage >= 0.90:
        raise ValueError(f"{layer_id} is not a tight cutout: alpha coverage {coverage:.4f}")
    alpha = layer.getchannel("A")
    if alpha.getextrema()[0] > 8:
        raise ValueError(f"{layer_id} has no transparent pixels")
    if layer_id in PRIMARY_CLUSTER_LAYERS:
        components = _alpha_components(alpha)
        if len(components) != 1:
            raise ValueError(
                f"{layer_id} must be one 8-connected alpha cluster, got {len(components)}"
            )


def _generate(asset_root: Path, review_root: Path) -> None:
    asset_root.mkdir(parents=True, exist_ok=True)
    review_root.mkdir(parents=True, exist_ok=True)
    empty_source = CONCEPT / "camp-empty-v2.png"
    furnished_source = CONCEPT / "camp-furnished-v2.png"
    empty_normalized = _normalize(empty_source)
    furnished_normalized = _normalize(furnished_source)
    empty_normalized.save(review_root / "camp-empty-normalized-1636x960.png", optimize=True)
    furnished_normalized.save(review_root / "camp-furnished-normalized-1636x960.png", optimize=True)
    base = _base_half(empty_normalized)
    furnished = _base_half(furnished_normalized)
    if not ISOLATION_CANDIDATE.is_file():
        raise FileNotFoundError(f"missing reviewed mask candidate: {ISOLATION_CANDIDATE}")
    isolation = Image.open(ISOLATION_CANDIDATE).convert("RGB")
    if isolation.size != (1448, 1086):
        raise ValueError(f"unexpected mask candidate size: {isolation.size}")
    catalog_alpha = _connected_light_background_alpha(isolation)
    isolation_review = isolation.convert("RGBA")
    isolation_review.putalpha(catalog_alpha)
    isolation_review.save(review_root / "camp-isolation-matte.png", optimize=True)
    base_path = asset_root / "camp-base.png"
    base.save(base_path, optimize=True)
    base.save(review_root / "empty-runtime.png", optimize=True)

    composite = base.convert("RGBA")
    layer_records = {}
    for layer_id in DRAW_ORDER:
        layer, bounds, coverage, component_cleanup = _layer(
            isolation, catalog_alpha, layer_id,
        )
        _assert_independence(layer_id, layer, bounds, coverage)
        asset_name = f"camp-{layer_id.replace('_', '-')}.png"
        target = asset_root / asset_name
        layer.save(target, optimize=True)
        composite.alpha_composite(layer, (bounds[0], bounds[1]))
        layer_records[layer_id] = {
            "path": (ASSET_ROOT / asset_name).relative_to(ROOT).as_posix(),
            "sha256": _sha256(target),
            "size": list(layer.size),
            "draw_rect_local": [bounds[0], bounds[1], layer.width, layer.height],
            "hitbox_local": HITBOXES.get(layer_id),
            "alpha_coverage": round(coverage, 6),
            "mask_components": [
                {"source_xyxy": list(source), "target_xyxy": list(target_box)}
                for source, target_box in MASK_COMPONENTS[layer_id]
            ],
            "component_gate": (
                {
                    **component_cleanup,
                    "output_component_count": len(_alpha_components(layer.getchannel("A"))),
                    "output_component_bounds_xyxy": [
                        component["bounds_xyxy"]
                        for component in _alpha_components(layer.getchannel("A"))
                    ],
                }
                if component_cleanup is not None
                else None
            ),
            "owns": "only this module's props, contact shadow and local light",
        }
    composite.save(review_root / "all-modules-runtime.png", optimize=True)
    manifest = {
        "schema_version": 2,
        "approved_v2_lineage_only": True,
        "empty_source": empty_source.relative_to(ROOT).as_posix(),
        "empty_source_sha256": _sha256(empty_source),
        "furnished_source": furnished_source.relative_to(ROOT).as_posix(),
        "furnished_source_sha256": _sha256(furnished_source),
        "mask_template": ISOLATION_CANDIDATE.relative_to(ROOT).as_posix(),
        "mask_template_sha256": _sha256(ISOLATION_CANDIDATE),
        "mask_template_usage": "reviewed ImageGen edit supplies isolated layer RGB; deterministic local matte supplies alpha before placement into the approved v2 composition",
        "isolation_attempts": [
            {
                **attempt,
                "path": (CONCEPT / "candidates" / attempt["candidate"]).relative_to(ROOT).as_posix(),
                "sha256": _sha256(CONCEPT / "candidates" / attempt["candidate"]),
                "size": list(Image.open(CONCEPT / "candidates" / attempt["candidate"]).size),
            }
            for attempt in ISOLATION_ATTEMPTS
        ],
        "exact_prompts": "art/concepts/camp/2026-09-01/PROMPTS.md#runtime-layer-isolation-attempts",
        "normalization": "crop x=1..1636 (one left/two right pixels removed), duplicate source row 958 as row 959, exact 0.5 resize",
        "subtraction_used": False,
        "base": {
            "path": (ASSET_ROOT / "camp-base.png").relative_to(ROOT).as_posix(),
            "sha256": _sha256(base_path),
            "size": [818, 480],
            "format": "RGB8",
        },
        "draw_order": DRAW_ORDER,
        "layers": layer_records,
        "interactive_hitboxes": HITBOXES,
    }
    (asset_root / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n",
    )


def _assert_fresh(staged_asset_root: Path, staged_review_root: Path) -> None:
    comparisons = [
        (staged_asset_root, ASSET_ROOT),
        (staged_review_root, REVIEW_ROOT),
    ]
    stale: list[str] = []
    for staged_root, canonical_root in comparisons:
        for staged_path in sorted(path for path in staged_root.rglob("*") if path.is_file()):
            relative = staged_path.relative_to(staged_root)
            canonical_path = canonical_root / relative
            if not canonical_path.is_file() or staged_path.read_bytes() != canonical_path.read_bytes():
                stale.append(canonical_path.relative_to(ROOT).as_posix())
    if stale:
        raise ValueError("stale generated camp assets: " + ", ".join(stale))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    arguments = parser.parse_args()
    if arguments.check:
        with tempfile.TemporaryDirectory(prefix="almsth-camp-assets-check-") as temp_dir:
            staging_root = Path(temp_dir)
            staged_assets = staging_root / "assets"
            staged_review = staging_root / "review"
            _generate(staged_assets, staged_review)
            _assert_fresh(staged_assets, staged_review)
        print("CAMP ASSET CHECK PASSED: deterministic base, layers, component gates and manifest")
        return
    _generate(ASSET_ROOT, REVIEW_ROOT)
    print("prepared camp base and 12 independently-gated tight layers without concept subtraction")


if __name__ == "__main__":
    main()
