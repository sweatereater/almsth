"""Pack existing PNGs and actual Godot captures for review; no artwork edits."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "builds/previews/female-ghoul"
FRAMES = ROOT / "assets/dungeon/female-ghoul/frames"


def contact_sheet():
    sheet = Image.new("RGB", (1194, 360), "#17202b")
    draw = ImageDraw.Draw(sheet)
    for column, (name, background) in enumerate([
        ("DARK", "#10151d"), ("LIGHT", "#ddd8ce"), ("CHECKER", "#a2a7ad")
    ]):
        left = column * 398
        draw.rectangle((left + 2, 2, left + 395, 357), fill=background)
        if name == "CHECKER":
            for y in range(0, 360, 12):
                for x in range(left + 2, left + 396, 12):
                    if ((x - left - 2) // 12 + y // 12) % 2:
                        draw.rectangle((x, y, min(x + 11, left + 395), y + 11), fill="#e4e5e6")
        ink = "#eee8dc" if name == "DARK" else "#17202b"
        draw.text((left + 12, 12), name + " / four registered frames", fill=ink)
        for row, (cell, size) in enumerate([(44, 40), (66, 62), (88, 84)]):
            top = 40 + row * 103
            draw.text((left + 12, top), f"cell {cell} / canvas {size}", fill=ink)
            for index in range(4):
                image = Image.open(FRAMES / f"walk-{index:02d}.png").convert("RGBA")
                image = image.resize((size, size), Image.Resampling.BILINEAR)
                x, y = left + 22 + index * 94, top + 16
                sheet.paste(image, (x, y), image)
    sheet.save(OUT / "contact-sheet.png")
    for name, background in [("dark", "#10151d"), ("light", "#ddd8ce"), ("checker", "#a2a7ad")]:
        full = Image.new("RGBA", (1056, 286), background)
        label = ImageDraw.Draw(full)
        if name == "checker":
            for y in range(0, 286, 16):
                for x in range(0, 1056, 16):
                    if (x // 16 + y // 16) % 2:
                        label.rectangle((x, y, x + 15, y + 15), fill="#e4e5e6")
        for index in range(4):
            label.text((index * 264 + 8, 6), f"{index + 1} / 264 RGBA", fill="#ffffff" if name == "dark" else "#111111")
            full.alpha_composite(Image.open(FRAMES / f"walk-{index:02d}.png").convert("RGBA"), (index * 264, 22))
        full.convert("RGB").save(OUT / f"frames-264-{name}.png")


def animation():
    paths = sorted(OUT.glob("motion-*.png"))
    if not paths:
        return
    frames = [Image.open(path).convert("RGB") for path in paths]
    # One shared palette avoids a new colour mapping on every frame.
    palette = frames[0].quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    indexed = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
    indexed[0].save(OUT / "walking-map.gif", save_all=True, append_images=indexed[1:], duration=50, loop=0, optimize=False)
    # A separate crop is a literal screen capture crop at native physical pixels.
    # The full recording remains above and is the scale source of truth.
    scale = frames[0].width / 1280
    bounds = tuple(round(value * scale) for value in (200, 280, 584, 480))
    crops = [frame.crop(bounds) for frame in frames]
    crop_palette = crops[0].quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    indexed = [frame.quantize(palette=crop_palette, dither=Image.Dither.NONE) for frame in crops]
    indexed[0].save(OUT / "walking-map-crop.gif", save_all=True, append_images=indexed[1:], duration=50, loop=0, optimize=False)
    print(f"Packed {len(frames)} actual {frames[0].width}x{frames[0].height} Godot frames, 50 ms each.")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    contact_sheet()
    animation()
    print(OUT)
