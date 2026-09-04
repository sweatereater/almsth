# Camp concept prompts — 2026-09-01

Mode: built-in image_gen. No CLI fallback.

Final delivered pair: camp-furnished-v2.png and camp-empty-v2.png, both 1639×959 RGB.
The v1 pair is retained as iteration history. Every output is copied unmodified from the built-in tool.

## Storage chest — independent thirteenth runtime layer

Output master: `storage-chest-master.png`, 1536×1024 RGBA.

Method/provenance: fresh original generated with the built-in `image_gen` tool using only
project-owned camp images as visual references; no CLI, API fallback, old 4×3 atlas crop,
external source, background removal or repaint. The available final tool/result ID is
`exec-f4220fc7-adab-4c44-9243-6cd76a83e082`; the tool exposed no separate call ID or custom
tool-call ID. Source SHA-256:
`9FC7C1D961E2A9B0D13EA967866C3C6B4E91422E044D1EB7E894770238C3D1A3`.

```text
Use case: stylized-concept
Asset type: original game environment prop master for the Almsth underground camp
Primary request: create one low, broad, CLOSED storage chest as a standalone transparent-background cutout.
Visual reference context: match the project's own underground camp assets already inspected: realistic painterly dark-fantasy materials, elevated three-quarter camp camera, compact readable silhouette, subdued detail and grounded lighting. Do not copy or include any existing prop.
Scene/backdrop: none; genuine transparent background across the entire canvas outside the prop.
Subject: a sturdy low broad storage chest, weathered dark wood, restrained aged-iron bands and corner guards, one small dull iron latch, clearly readable closed lid seam.
Composition/framing: single chest centered, elevated 3/4 view consistent with looking slightly down into the camp; broad horizontal silhouette; tight but complete cutout with modest transparent padding; bottom-center grounding reference; no cropping.
Lighting/mood: cool ambient stone-room light with only a subtle warm hearth edge light; quiet utilitarian camp storage, not treasure.
Materials/textures: worn dark timber grain, matte oxidized iron, subtle age and scuffs; one tight local contact shadow directly under the chest contained within the cutout.
Constraints: brand-new original project-owned design suitable for future commercial sale without royalties; actual alpha transparency; closed lid; readable at small game scale; no text; no logo; no watermark.
Avoid: open lid, visible loot, coins, gems, runes, glow, magic, text, labels, UI symbols, arrows, rugs, sacks, loose containers, broad floor patches, room/background pixels, neighboring props, halo, outline, bloom, dramatic treasure-light, ornate fantasy excess.
```

## Final correction: furnished v2

Edit target: camp-furnished-v1.png. Output: camp-furnished-v2.png.

```text
Use case: precise-object-edit.
Input image: edit target, the furnished Almsth camp concept.
Make exactly ONE targeted correction to the stone-and-iron SALVAGE CRUSHER in the lower left corner: its leftmost body and foundation are clipped by the left edge. Reposition and slightly reduce ONLY this crusher and its little base/scrap cluster so the ENTIRE machine body, feet/foundation, vertical screw, long handle and its associated small debris are inside the picture, with a clearly visible strip of about 40 image pixels of existing floor between the machine silhouette and the left frame edge. Preserve its exact design, material, orientation, convincing human scale and contact shadows. It should occupy approximately x=50..370 and y=510..875 on this roughly 1641x959 canvas; these are approximate composition guides, not printed coordinates. Leave some visible floor before the whetstone so both machines are separately readable.
Reconstruct just the tiny areas of floor uncovered by the repositioned machine, following the existing stone joints. Do not move the whetstone or workbench.
CRITICAL LOCK: preserve every other pixel/feature as closely as possible, exact canvas size/aspect ratio and crop, camera, framing, all architecture, ceiling hatch, masonry, floor outside this small lower-left edit, the workbench and padded stool, textile mannequin and both mirrors, coat sketches, ritual table and mural, bed and ledge, cauldron/campfire, rocker/fur rug, record player, all lighting and all other small props.
No redesign, no extra objects, no other edits, no text or watermark. Return the corrected COMPLETE furnished scene.
```

## Final empty v2

Edit target: camp-furnished-v2.png. Output: camp-empty-v2.png.
The exact prompt is identical to the full text under "Empty scene" below.

## Furnished scene

Reference images: assets/art/camp-base-expanded.png, assets/art/camp-crusher.png, assets/art/camp-ritual-table.png.
Output: camp-furnished-v1.png (1641×959 RGB).

```text
Use case: stylized-concept / environmental interior concept.
Asset type: a single complete furnished camp background concept for the dark-fantasy game Almsth; NOT a UI screenshot, NOT a contact sheet, NOT an isometric dollhouse.
Input images: Image 1 is the existing empty camp, the architectural and material/style reference to redesign and furnish. Image 2 is a reference for the recognizable rugged stone-and-iron salvage crusher. Image 3 is a reference for the ritual binding table. Use their grounded material language, integrate their designs naturally at room scale.
Primary request: turn this underground refuge into a carefully composed, genuinely comfortable inhabited home-workshop, with ALL twelve buildable modules already present. Keep the vaulted medieval stone cellar, old arches, overhead ceiling hatch with a soft cool shaft of light, worn irregular stone paving. Add a low permanent stone ledge in the right rear alcove to support the sleeping area. The place is underground, no exterior landscape or modern windows.
Canvas/framing: one wide landscape image approximately 818:480 aspect (preferred 3272x1920 if available). Fixed slightly elevated three-quarter room view, enough view of horizontal surfaces to understand every station. Show the entire usable camp and its ceiling hatch. No cropped furniture. Carefully spaced clusters along the perimeter with breathing room and a clear path from the hatch toward the foreground. This will be the master from which a bare architectural version is edited, so make room geometry coherent and easy to preserve.
Composition and REQUIRED inventory:
1. CAMPFIRE, slightly right of center in the lower middle of the room: one low ring of stone with burning logs, the main amber focal point.
2. COOKING KETTLE: one large black iron cauldron visibly suspended DIRECTLY OVER that same fire on a simple iron support; a ladle and small cooking utensils belong to this station. No separate second cooking fire.
3. ROCKING CHAIR, comfortably beside the fire facing inward, clearly readable curved rocker rails, a modest cushion, with a softly worn animal-hide rug at its feet and a folded throw. Chair and rug are one organic cozy cluster; keep visibly safe space from flames.
4. MUSIC APPARATUS near the chair but not overlapping it: a charming medieval-meets-modern hand-cranked wooden RECORD PLAYER with a visible black round record, needle arm, modest aged-brass acoustic horn and forged-iron details. Recognizable as a vinyl-style turntable in a crafted wooden cabinet, not a lute, not a modern plastic stereo. A small rack with two record sleeves belongs to it.
5. BUNK on the comfortable raised STONE LEDGE of the rear right alcove: thick layered mattress, linen blanket and pillows, sheltered and restful, reached by two low stone steps that are part of the architecture.
6. WORKBENCH on the left/back wall: sturdy broad wooden worktable with hand tools and drawers, plus a comfortable padded carpenter's stool tucked at an accessible angle. Separate in shape and purpose from the ritual table.
7. WRITING AND PAPER/INK MAKING SET as a distinct upgrade ON THE WORKBENCH: visible quill and inkwell, pigment jars, mortar, paper stack, small shallow pulp tray and a wooden papermaking screen/deckle, a few drying sheets on a short rail immediately above the table. Keep this compact and localized, not spread across other stations.
8. TEXTILE/TAILORING AREA beside the workbench along a separate rear wall section: a human-size headless torso dressmaker mannequin on a narrow stand, TWO mismatched tall framed mirrors, spools of thread and folded fabric in a basket, sewing implements. Several confident chalk/charchoal sketches of a long COAT directly on the masonry above the textiles. The mirrors face mostly bare stone and dim ambient light, NOT other removable furniture. Mannequin must read as tailoring equipment, not a person. Wall coat sketches are part of this area.
9. SALVAGE CRUSHER in the foreground-left workshop corner: heavy compact stone-and-iron manual screw press with long lever, referencing image 2. A small sorted pile of wood, stone and scraps immediately at its base.
10. WHETSTONE next to the crusher, but with a separate clear silhouette: a circular vertical grindstone on a small wooden stand with a hand crank, a sharpening cloth and a tiny water vessel. Do not merge it into the crusher.
11. RITUAL BINDING TABLE in its own rear-middle alcove, clearly separate from the ordinary workbench: squat old stone-topped table reinforced with iron, restrained carved circular sigil, a few candles and bindings, inspired by image 3. Tiny muted violet/blue accents only, much weaker than the campfire. No glowing giant portal.
12. MURAL on a free section of rear stone wall near but distinct from the ritual area: a small hand-drawn victorious MINOTAUR motif, simple ochre/charcoal horned bull-head battle graffiti. Drawn directly on masonry, NO framed picture, NO pedestal, no text. It must be distinct from the coat-pattern drawings.
Style/materials: high-quality painterly realistic game environment, tactile ancient grey-brown stone, weathered wood, linen, wool and aged iron, believable human furniture proportions. Same grounded dark-fantasy material family as the supplied camp; soften its austerity through the inhabitant's craft and textiles, not through a bright cartoon redesign.
Lighting: quiet cool diffuse light through the ceiling hatch makes all stations legible; warm local amber hearth and modest candle accents make the room inviting. The chair/bed/textiles should feel tenderly cared for. Keep most fire bounce local to its cluster, avoid dramatic broad shadows from one removable station over another. Readable broad silhouettes and restrained microdetail for an eventual 818x480 game view.
Modularity constraints: clusters have their own small belongings, rugs, contact shadows, and adjacent wall dressing. Minimize overlaps across independent clusters. Keep the hatch and open route unobstructed. Bunk mattress is removable but rock ledge/steps are permanent architecture. Coat sketches and mural are removable decorations, not carved masonry.
Avoid: people or living creatures, text labels, arrows, UI, labels or diagrams, split-screen, borders, watermarks, unrelated decorative clutter, extra workstations, multiple fires, oversaturated magic, steam obscuring silhouettes, modern electronics.
```

## Empty scene

Edit target: camp-furnished-v1.png.
Output: camp-empty-v1.png (1640×959 RGB).

```text
Use case: precise-object-edit.
Asset type: bare architectural background paired with the supplied furnished Almsth camp concept.
Input image 1 is the EDIT TARGET and the exact camera/geometry/painting reference. Create the SAME room with completely bare walls and floor after every buildable object and all of its associated belongings have been removed.
Critical invariants: preserve EXACTLY the target image's canvas size and aspect ratio, camera, perspective, framing, crop, ceiling hatch position and shape, stone vaults, arches, columns, all exposed wall block edges and floor joints, the irregular stone border at the sides, and the raised stone sleeping ledge and its steps on the right. No scene redesign, no shifted stones, no new architecture, no crop, no zoom. Do not use a different empty-camp reference. Work by removing only furnishings from this particular image and carefully reconstructing the occluded stone wall or paving locally.
Remove all twelve buildable modules and their belongings:
- Entire left workbench, stool, tools, drawers/small cabinets, quill/ink/paper set, loose sheets and drying line, shelves, hanging equipment and workshop lanterns.
- Entire textile area, torso mannequin, both framed mirrors, cloth basket, fabric, threads, shelves; erase ALL coat outline drawings from the stone wall.
- Entire crusher in front left, iron arm, stone mechanism, base associated only with the machine, and its loose scrap pile. Restore coherent stone floor locally. Keep the room's structural rock border.
- Entire circular whetstone, wooden stand, water pail and rug.
- Entire ritual table, tabletop sigil, bindings, all candles and its floor carpet.
- Entire minotaur mural/graffiti from rear stone wall, exposing bare matching stone.
- Entire sleeping mattress, all pillows, blankets and hanging cloth in the right alcove, shelf/books/candle; KEEP the pre-existing permanent raised stone ledge and stone steps completely empty.
- Entire campfire: stones specifically forming the fire ring, logs, flame, ash, ALL cauldron and supporting iron frame, hanging utensils.
- Entire rocking chair, fur hide and throw.
- Entire record player, cabinet, horn, records/sleeves and rug.
- Remove every added candle, lantern, hook, small shelf, hanging textile, rug or decorative object anywhere. There should be no furniture, no props, no drawings, no tiny forgotten lights.
Lighting: preserve the cool diffuse ambient light and visible soft shaft entering through the ceiling hatch. With fire, candles and lanterns removed, remove the local warm orange fire glow, hot reflections and cast shadows generated by the removed objects. Keep all architectural shadows in their original positions; slightly lift neutral reflected ambient light only as needed so bare stone in all alcoves stays legible. Do not turn this into a pitch black room. Leave neutral grey-brown rock, cool stone and the same quiet painterly finish.
Result: a clean EMPTY architectural plate of this EXACT furnished scene, with empty alcoves, exposed continuous floor and empty right-hand sleeping ledge; suitable as the conceptual base for later local masking and overlay work. No annotations, text, UI, panels, watermark, figures, added doorway or loose rubble filling former stations.
```

## Runtime layer-isolation attempts

All three calls used the built-in ImageGen tool. The call inputs below are copied verbatim
from the local session transcript. Attempt 3 is the selected source for deterministic
matte extraction and placement; attempts 1 and 2 are retained only as rejected candidates.
The three-attempt limit was reached and no fourth generative attempt was made.

Post-acceptance visual QA found two unrelated detached alpha leaks inside attempt 3's
otherwise accepted cells. No fourth ImageGen call was made. The deterministic recipe now
retains only the primary 8-connected alpha cluster for the standalone crusher and
whetstone: it removes the crusher's eight detached fragments (including the 11-pixel
high-alpha orphan at runtime-canvas bounds `[138,456,143,459]`) and the whetstone's foreign
orange arc (541 pixels above alpha 16 at `[259,399,310,414]`). The retained props keep their
original world placement; only their tight crop rects and generated hashes change. Exact
cleanup counts, bounds, output component count and hashes are recorded in
`assets/art/camp-2026-09-01/manifest.json` under each layer's `component_gate`.

### Attempt 1 — rejected

- Response item ordinal: `2890`
- Custom tool call: `ctc_0e02eb5ad014acac016a961b77ca8087d29efe793644c03d9d`
- ImageGen call: `call_sxbfVvHwouR3lz9HpNdqIpPq`
- Tool result: `exec-5e8511df-a4dd-489e-9ec0-e2590759a2fb`
- Candidate: `candidates/camp-isolation-attempt-01.png`
- Canvas: 1640×959 RGB
- SHA256: `08E6A9D73044DEC90AFC727653816C57B5036F9C9FB21BFFAADDCAD85C7F9EEE`
- Verdict: rejected because furnishings were rearranged and overlapped.

```text
Use case: background-extraction
Asset type: Almsth camp runtime isolation master for deterministic extraction into twelve independent RGBA prop layers
Input images: Image 1 is the exact approved furnished v2 camp scene and the edit target.
Primary request: Remove only the permanent stone architecture, ceiling, walls, columns, stairs, bare floor, and global room background from Image 1. Keep every furnishing and module exactly as painted, at its exact original position, scale, viewpoint, perspective, silhouette, palette, and relative spacing, on a genuinely transparent background.
Subject to preserve: all twelve existing module groups only: the wall mural; bunk with its own shelf and hanging cloth; textile area with wardrobe, mannequin, mirrors and basket; wooden workbench; writing papers/tools/candles belonging on and above that workbench; ritual table and its rug; crusher and its rubble/contact shadow; whetstone and its bucket/rug/contact shadow; campfire stone ring, logs, flame, tripod and local fire glow; kettle/pot; rocking chair with its own draped cloth, fur rug/contact shadow; mechanical record player with cabinet, horn, records and contact shadow.
Style/medium: preserve the approved painterly dark-fantasy game-environment rendering exactly; this is an extraction edit, not a redesign.
Composition/framing: preserve the original full wide 1639×959 framing and all original object coordinates; transparent pixels everywhere except the named props, their direct contact shadows, and tightly local light.
Constraints: genuinely transparent background; preserve fine edges and small hanging parts; no stone architecture or bare floor pixels; no checkerboard; no text; no labels; no frames; no watermark; no new objects; no missing objects; no object relocation, rescaling, replacement, restyling, or redraw; do not merge neighboring props; do not invent scenery behind open chair rails, table legs, shelves, or tripod gaps.
```

### Attempt 2 — rejected

- Response item ordinal: `3131`
- Custom tool call: `ctc_0e02eb5ad014acac016a961e274a1887d2a83a8ab5ee6b676f`
- ImageGen call: `call_DD6ejrGvudSjzn34L7o6QYdn`
- Tool result: `exec-1eada5ca-e429-4c65-acd0-94134846771e`
- Candidate: `candidates/camp-isolation-attempt-02.png`
- Canvas: 1639×959 RGB
- SHA256: `978AD627CD80D60E5E81704B5B904366779563071D525EF3FA4917C0A45F9903`
- Verdict: rejected because the exact-position retry still rearranged furnishings.

```text
Targeted background-extraction retry for the supplied approved furnished camp image. Keep the exact original canvas, camera, perspective, scale, lighting, and pixel-space placement of every existing furnishing. Remove only the dungeon architecture, walls, arches, ceiling, stairs, and floor, replacing all removed background with genuine transparent alpha. Do not rearrange, pack, move, resize, rotate, redraw, restyle, invent, omit, or duplicate any furnishing. Preserve the exact silhouettes of the mural, bunk plus its own shelf and banner, textile area, workbench, hanging writing set, ritual table, crusher, whetstone, campfire, hanging kettle, rocking chair, and record player in their original positions. Retain only each furnishing's directly attached contact shadow and tightly feathered local light; do not retain broad rectangular floor or wall patches. The campfire and kettle must remain visually separable: preserve the fire ring, logs, flame and tripod, and preserve the hanging pot and chain distinctly. The workbench and hanging writing set must remain visually separable. Output the isolated furnishings on a fully transparent background at the original aspect ratio, with no checkerboard baked into RGB, no text, no labels, no border, and no new objects.
```

### Attempt 3 — accepted

- Response item ordinal: `3289`
- Custom tool call: `ctc_0e02eb5ad014acac016a961f9ee19487d28fd8246174b12093`
- ImageGen call: `call_vdYZLrxbzmCAKF25gzZLAjKd`
- Tool result: `exec-f434ce79-a3d2-4053-b468-b957a7025523`
- Candidate: `candidates/camp-isolation-attempt-03.png`
- Canvas: 1448×1086 RGB
- SHA256: `8541B849007EDB9C2D1B409040F365321DC79A64FAD2B3FD66634AE48B662F7C`
- Verdict: accepted as a clean independent 4×3 atlas. Deterministic local matte extraction supplies alpha; no furnished-minus-empty subtraction is used.

```text
Targeted final layer-isolation retry from the supplied approved Almsth camp v2 image. Create a clean 4-by-3 atlas of exactly twelve independent transparent-background cutouts, with wide empty transparent gutters so no silhouette, shadow, glow, rug, support, utensil, or accessory touches or overlaps another cell. Preserve the approved dark painterly realistic style, three-quarter perspective, proportions, materials, and recognizable designs. Row 1: mural only; bunk with its shelf and hanging banner only; textile/tailoring area only; bare sturdy workbench and carpenter stool only, with tools and drawers but absolutely no paper, quill, ink, pigment, pulp tray, deckle, drying sheets, or writing props. Row 2: writing and paper/ink-making set only, including quill, inkwell, pigments, paper stack, pulp tray, deckle and drying sheets but no workbench body; ritual binding table only; salvage crusher only; whetstone only. Row 3: campfire only, consisting solely of stone ring, logs, flame, ash and its tightly local glow, with no cauldron, chain, tripod/support, ladle, or utensils; cooking kettle only, including the black cauldron, full iron support/tripod, chain, ladle and utensils, with no fire ring, logs, flame, or broad floor glow; rocking chair with its hide rug and throw only; record player with cabinet, horn, record and sleeves only. Every cell must contain exactly its named module and its own contact shadow/local light only. No architecture, floor, wall, stairs, unrelated neighbors, extra props, labels, text, borders, or baked checker pattern. Output genuine transparent alpha and keep every cutout fully inside its cell with generous clear gutters.
```
