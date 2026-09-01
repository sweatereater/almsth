# ImageGen provenance — 2026-09-01 map runtime and Old Claymore

This is the workspace copy of the exact prompts sent to the built-in ImageGen tool.
Runtime code and assets do not refer to the original generation directory. A rejected
six-reference female-skeleton invocation failed before generation (`referenced_image_paths`
supports at most five paths), so it is recorded separately and is not counted as an art
attempt. Every generated set stayed below the approved maximum of three attempts.

## Candidates and decisions

| Set | Attempts | Candidate 1 / origin | Candidate 2 / origin | Integrated |
|---|---:|---|---|---|
| female/skeleton | 2 | `candidates/female-skeleton-attempt-01.png` / `exec-35a446dd-5ab4-4d0c-ab0e-7efc18d15468` | `candidates/female-skeleton-attempt-02.png` / `exec-e40d2111-4fea-4a13-a880-dbd829f1caad` | attempt 2 |
| female/zombie | 2 | `candidates/female-zombie-attempt-01.png` / `exec-707c026b-e3b0-42ac-99f7-4f72d0bea6d7` | `candidates/female-zombie-attempt-02.png` / `exec-e03da3df-ec89-4634-9e76-43c16418a81a` | attempt 2 |
| female/revenant | 2 | `candidates/female-revenant-attempt-01.png` / `exec-6cbfcc00-fe45-4938-9242-d7485c850ba0` | `candidates/female-revenant-attempt-02.png` / `exec-b78a42a8-41bd-4fef-a11f-86d5ad109c2f` | attempt 1 |
| female/almost_human | 1 | `candidates/female-almost-human-attempt-01.png` / `exec-432f62f5-437c-45ed-b1f8-c301ccee9407` | — | attempt 1 |
| male/skeleton | 2 | `candidates/male-skeleton-attempt-01.png` / `exec-2e37e652-d048-4c53-a7ca-4956f6026347` | `candidates/male-skeleton-attempt-02.png` / `exec-74b2afcf-41f4-48ac-b88c-0c79b20ace07` | attempt 1 |
| male/zombie | 2 | `candidates/male-zombie-attempt-01.png` / `exec-621b2112-e914-4963-854a-4256a834cc1d` | `candidates/male-zombie-attempt-02.png` / `exec-ed365485-f8f5-47f6-b2fc-bf4587ec4687` | attempt 1 |
| male/ghoul | 2 | `candidates/male-ghoul-attempt-01.png` / `exec-de80b8d8-1ea7-4d9d-9bfc-0f8a60b50d46` | `candidates/male-ghoul-attempt-02.png` / `exec-c7ae95e1-9815-4f24-b099-c2e3e33867dc` | attempt 1 |
| male/revenant | 2 | `candidates/male-revenant-attempt-01.png` / `exec-27a3ef2e-5ecd-472d-abaf-403a0c752802` | `candidates/male-revenant-attempt-02.png` / `exec-5830791d-6333-4ea5-ac0d-a87954f48635` | attempt 1 |
| male/almost_human | 2 | `candidates/male-almost-human-attempt-01.png` / `exec-244294f6-0dff-43cb-929f-632de6835b5c` | `candidates/male-almost-human-attempt-02.png` / `exec-3f0300a4-5041-4f2c-a0b7-32b865fb38c7` | attempt 1 |
| old_claymore | 1 | `candidates/old-claymore-attempt-01.png` / `exec-5247ce1e-3c1d-49b3-9e58-980163149686` | — | attempt 1 |

Attempt 2 for female/revenant and the five male sets was retained as a review candidate
but not integrated; the more faithful attempt 1 was selected. The deterministic runtime
recipe and final hashes are in `runtime-manifest.json` and
`tools/prepare_nightly_character_assets.py`.

## Exact prompts

### female/skeleton — attempt 1

```text
Use case: stylized-concept
Asset type: Almsth top-down dungeon character walking sprite source sheet
Primary request: Create exactly four genuinely distinct alternating walking poses for the approved FEMALE SKELETON character from the references, arranged as a clean 2×2 sheet, for later deterministic extraction into four square game frames.
Input images: Image 1 is the exact identity, proportions, clothing and palette reference; Image 2 is the approved female progression master; Image 3 is the exact camera-scale, 3/4-left viewpoint, grounded gait rhythm and silhouette-readability reference only.
Subject: the same female skeleton, same long distressed dark leather coat, purple cloth, exposed ivory bones, skull proportions and accessories; no weapon.
Style/medium: preserve the approved painterly inked dark-fantasy game-art style, muted brown-gray palette, strong readable silhouette.
Composition/framing: four equal isolated full-body figures in a 2×2 grid, all facing 3/4 left, same anatomical scale and foot baseline; contact A, transition, contact B, transition. Arms, legs, coat tails and feet must actually change pose. Keep the body centered in each quadrant and never clip coat, hands or feet.
Constraints: genuinely transparent background; exactly four figures and no extras; no grid lines, labels, text, watermark, frame, shadows crossing quadrants or checkerboard; no whole-body canvas bob; consistent head height and hip registration; generous transparent space around each figure; do not redesign identity, outfit, damage, proportions or palette.
```

### female/skeleton — attempt 2

```text
Use case: precise-object-edit
Asset type: Almsth top-down dungeon character walking sprite source sheet
Primary request: Correct only the character identity in Image 1 while preserving its exact 2×2 layout and four genuinely distinct walking poses.
Input images: Image 1 is the edit target; Images 2 and 3 are the exact approved FEMALE SKELETON identity/outfit references; Image 4 is gait/viewpoint reference only.
Required correction: remove all hair, flesh, boots and cloth trousers. The figure must be a bald bare ivory skull and exposed skeletal legs/feet like Images 2–3. Preserve the approved long distressed leather coat, purple waist cloth, bone torso/arms, belt and pouches. No weapon.
Invariants: keep exactly four isolated figures; keep the current contact A, transition, contact B, transition pose differences; same 3/4-left view, scale, baseline, transparent background, quadrant placement and painterly inked style.
Constraints: genuinely transparent background; no grid, labels, text, watermark, frame, checkerboard or extra figure; no clipping; no redesign beyond the stated identity correction.
```

### female/zombie — attempt 1

```text
Use case: stylized-concept
Asset type: Almsth top-down dungeon character walking sprite source sheet
Primary request: Create exactly four genuinely distinct alternating walking poses for the approved FEMALE ZOMBIE character from the references, arranged as a clean 2×2 sheet, for deterministic extraction into four square game frames.
Input images: Image 1 is the exact identity, proportions, clothing and palette reference; Image 2 is the approved master; Image 3 is the exact camera-scale, 3/4-left viewpoint, grounded gait rhythm and silhouette-readability reference only.
Subject: same gaunt decayed woman with messy dark hair, damaged grey flesh, torn pale tunic and trousers, long distressed dark leather coat, wraps and boots; no weapon.
Style/medium: preserve the approved painterly inked dark-fantasy game-art style and muted brown-gray palette with a strong readable silhouette.
Composition/framing: four equal isolated full-body figures in a 2×2 grid, all facing 3/4 left, same anatomical scale and foot baseline; contact A, transition, contact B, transition. Arms, legs, coat and feet must visibly change pose. Center each figure in its quadrant; never clip hair, coat, hands or feet.
Constraints: genuinely transparent background; exactly four figures and no extras; no grid lines, labels, text, watermark, frame, checkerboard or cross-quadrant shadow; no whole-body canvas bob; consistent head height and hip registration; generous transparent space; do not redesign identity, outfit, damage, proportions or palette.
```

### female/zombie — attempt 2

```text
Use case: precise-object-edit
Asset type: Almsth four-pose walking sprite source sheet
Primary request: Correct Image 1 into the approved FEMALE ZOMBIE stage and remove its backdrop to genuine transparency, while preserving the exact 2×2 layout and the four distinct walking poses.
Input images: Image 1 is edit target; Images 2–3 are exact identity/outfit references.
Required identity: gaunt decayed grey-brown female corpse, messy dark shoulder hair, deeply damaged face and exposed decay; torn dirty pale-grey shirt/tunic and ragged dark trousers beneath the same long distressed coat, wraps and worn boots. Remove the developed purple shirt, clean tan trousers, arm tattoo and healthy revenant look. No weapon.
Invariants: exactly four figures; same 3/4-left view, scale, baseline, pose differences and painterly inked style; change only stage identity/outfit and background.
Constraints: genuinely transparent background, not checkerboard or painted black; no glow/shadow plate; no text/grid/frame/watermark; no clipping or extra figure.
```

### female/revenant — attempt 1

```text
Use case: stylized-concept
Asset type: Almsth top-down dungeon character walking sprite source sheet
Primary request: Create exactly four genuinely distinct alternating walking poses for the approved FEMALE REVENANT character from the references, arranged as a clean 2×2 sheet, for deterministic extraction into four square game frames.
Input images: Image 1 is the exact identity, proportions, clothing and palette reference; Image 2 is the approved master; Image 3 is the exact camera-scale, 3/4-left viewpoint, grounded gait rhythm and silhouette-readability reference only.
Subject: same pale revenant woman with dark braided undercut hair, facial scars, black fitted vest, long distressed dark leather coat, wide tan trousers, belts, pouches and heavy boots; no weapon.
Style/medium: preserve the approved painterly inked dark-fantasy game-art style and muted brown-gray palette with a strong readable silhouette.
Composition/framing: four equal isolated full-body figures in a 2×2 grid, all facing 3/4 left, same anatomical scale and foot baseline; contact A, transition, contact B, transition. Arms, legs, coat and feet must visibly change pose. Center each figure in its quadrant; never clip hair, coat, hands or feet.
Constraints: genuinely transparent background; exactly four figures and no extras; no grid lines, labels, text, watermark, frame, checkerboard or cross-quadrant shadow; no whole-body canvas bob; consistent head height and hip registration; generous transparent space; do not redesign identity, outfit, damage, proportions or palette.
```

### female/revenant — attempt 2

```text
Use case: background-extraction
Asset type: Almsth four-pose walking sprite source sheet
Primary request: Remove only the dark gradient background from Image 1 and return a clean genuinely transparent RGBA cutout sheet.
Input images: Image 1 is the edit target; Image 2 confirms the exact approved female revenant identity.
Invariants: preserve every pixel-level artistic feature, identity, face, hair, outfit, proportions, scale, 2×2 placement, and all four existing distinct walking poses. Do not redraw, restyle, reposition or change limbs.
Constraints: actual transparency, clean fine hair/coat edges, no halos, no checkerboard, no shadow plate, no text/grid/frame/watermark, no clipping.
```

### female/almost_human — attempt 1

```text
Use case: stylized-concept
Asset type: Almsth top-down dungeon character walking sprite source sheet
Primary request: Create exactly four genuinely distinct alternating walking poses for the approved FEMALE ALMOST HUMAN character from the references, arranged as a clean 2×2 sheet, for deterministic extraction into four square game frames.
Input images: Image 1 is the exact identity, proportions, clothing and palette reference; Image 2 is the approved master; Image 3 is the exact camera-scale, 3/4-left viewpoint, grounded gait rhythm and silhouette-readability reference only.
Subject: same living brown-skinned woman with purple braided undercut hair, earrings, purple shirt, arm tattoo, long distressed dark leather coat, wide tan trousers, belts, pouches and heavy boots; no weapon.
Style/medium: preserve the approved painterly inked dark-fantasy game-art style and muted brown-gray palette with a strong readable silhouette.
Composition/framing: four equal isolated full-body figures in a 2×2 grid, all facing 3/4 left, same anatomical scale and foot baseline; contact A, transition, contact B, transition. Arms, legs, coat and feet must visibly change pose. Center each figure in its quadrant; never clip hair, coat, hands or feet.
Constraints: genuinely transparent background; exactly four figures and no extras; no grid lines, labels, text, watermark, frame, checkerboard or cross-quadrant shadow; no whole-body canvas bob; consistent head height and hip registration; generous transparent space; do not redesign identity, outfit, damage, proportions or palette.
```

### male/skeleton — attempt 1

```text
Use case: stylized-concept
Asset type: Almsth top-down dungeon character walking sprite source sheet
Primary request: Create exactly four genuinely distinct alternating walking poses for the approved MALE SKELETON character from the references, arranged as a clean 2×2 sheet, for deterministic extraction into four square game frames.
Input images: Image 1 is the exact identity, proportions, clothing and palette reference; Image 2 is the approved male progression master; Image 3 is camera-scale, 3/4-left viewpoint, grounded gait rhythm and silhouette-readability reference only.
Subject: same bald ivory male skeleton, exposed skull/ribs/long leg bones, fitted black ragged tailcoat, brown waist cloth and belts; no flesh, hair, boots or trousers; no weapon.
Style/medium: preserve the approved painterly inked dark-fantasy game-art style, muted brown-gray palette and strong readable silhouette.
Composition/framing: four equal isolated full-body figures in a 2×2 grid, all facing 3/4 left, same anatomical scale and foot baseline; contact A, transition, contact B, transition. Arms, legs, coat and feet visibly change pose. Center each figure; never clip hair, coat, hands or feet.
Constraints: genuinely transparent background; exactly four figures and no extras; no grid lines, labels, text, watermark, frame, checkerboard or cross-quadrant shadow; no whole-body canvas bob; consistent head height and hip registration; generous transparent space; do not redesign identity, outfit, damage, proportions or palette.
```

### male/skeleton — attempt 2

```text
Use case: background-extraction
Asset type: Almsth four-pose walking sprite source sheet
Primary request: Remove only the dark gradient background from Image 1 and return a clean genuinely transparent RGBA cutout sheet.
Input images: Image 1 is the edit target; Image 2 confirms the exact approved male skeleton identity.
Invariants: preserve every artistic feature, identity, face, hair/bone anatomy, outfit, damage, proportions, anatomical scale, 2×2 placement, and all four existing genuinely distinct walking poses. Do not redraw, restyle, reposition or change limbs.
Constraints: actual transparency with clean fine hair/bone/coat edges; no halos, checkerboard, shadow plate, text, grid, frame, watermark or clipping; exactly four figures.
```

### male/zombie — attempt 1

```text
Use case: stylized-concept
Asset type: Almsth top-down dungeon character walking sprite source sheet
Primary request: Create exactly four genuinely distinct alternating walking poses for the approved MALE ZOMBIE character from the references, arranged as a clean 2×2 sheet, for deterministic extraction into four square game frames.
Input images: Image 1 is the exact identity, proportions, clothing and palette reference; Image 2 is the approved male progression master; Image 3 is camera-scale, 3/4-left viewpoint, grounded gait rhythm and silhouette-readability reference only.
Subject: same decayed male zombie with white messy hair, broken exposed face and grey flesh, torn white shirt, ragged dark tailcoat and trousers, wraps and worn boots; no weapon.
Style/medium: preserve the approved painterly inked dark-fantasy game-art style, muted brown-gray palette and strong readable silhouette.
Composition/framing: four equal isolated full-body figures in a 2×2 grid, all facing 3/4 left, same anatomical scale and foot baseline; contact A, transition, contact B, transition. Arms, legs, coat and feet visibly change pose. Center each figure; never clip hair, coat, hands or feet.
Constraints: genuinely transparent background; exactly four figures and no extras; no grid lines, labels, text, watermark, frame, checkerboard or cross-quadrant shadow; no whole-body canvas bob; consistent head height and hip registration; generous transparent space; do not redesign identity, outfit, damage, proportions or palette.
```

### male/zombie — attempt 2

```text
Use case: background-extraction
Asset type: Almsth four-pose walking sprite source sheet
Primary request: Remove only the dark gradient background from Image 1 and return a clean genuinely transparent RGBA cutout sheet.
Input images: Image 1 is the edit target; Image 2 confirms the exact approved male zombie identity.
Invariants: preserve every artistic feature, identity, face, hair/bone anatomy, outfit, damage, proportions, anatomical scale, 2×2 placement, and all four existing genuinely distinct walking poses. Do not redraw, restyle, reposition or change limbs.
Constraints: actual transparency with clean fine hair/bone/coat edges; no halos, checkerboard, shadow plate, text, grid, frame, watermark or clipping; exactly four figures.
```

### male/ghoul — attempt 1

```text
Use case: stylized-concept
Asset type: Almsth top-down dungeon character walking sprite source sheet
Primary request: Create exactly four genuinely distinct alternating walking poses for the approved MALE GHOUL character from the references, arranged as a clean 2×2 sheet, for deterministic extraction into four square game frames.
Input images: Image 1 is the exact identity, proportions, clothing and palette reference; Image 2 is the approved male progression master; Image 3 is camera-scale, 3/4-left viewpoint, grounded gait rhythm and silhouette-readability reference only.
Subject: same male ghoul with white messy hair, skeletal damaged grey face and torso, black shirt and distressed tailcoat, brown belt sash, dark trousers and boots; no weapon.
Style/medium: preserve the approved painterly inked dark-fantasy game-art style, muted brown-gray palette and strong readable silhouette.
Composition/framing: four equal isolated full-body figures in a 2×2 grid, all facing 3/4 left, same anatomical scale and foot baseline; contact A, transition, contact B, transition. Arms, legs, coat and feet visibly change pose. Center each figure; never clip hair, coat, hands or feet.
Constraints: genuinely transparent background; exactly four figures and no extras; no grid lines, labels, text, watermark, frame, checkerboard or cross-quadrant shadow; no whole-body canvas bob; consistent head height and hip registration; generous transparent space; do not redesign identity, outfit, damage, proportions or palette.
```

### male/ghoul — attempt 2

```text
Use case: background-extraction
Asset type: Almsth four-pose walking sprite source sheet
Primary request: Remove only the dark gradient background from Image 1 and return a clean genuinely transparent RGBA cutout sheet.
Input images: Image 1 is the edit target; Image 2 confirms the exact approved male ghoul identity.
Invariants: preserve every artistic feature, identity, face, hair/bone anatomy, outfit, damage, proportions, anatomical scale, 2×2 placement, and all four existing genuinely distinct walking poses. Do not redraw, restyle, reposition or change limbs.
Constraints: actual transparency with clean fine hair/bone/coat edges; no halos, checkerboard, shadow plate, text, grid, frame, watermark or clipping; exactly four figures.
```

### male/revenant — attempt 1

```text
Use case: stylized-concept
Asset type: Almsth top-down dungeon character walking sprite source sheet
Primary request: Create exactly four genuinely distinct alternating walking poses for the approved MALE REVENANT character from the references, arranged as a clean 2×2 sheet, for deterministic extraction into four square game frames.
Input images: Image 1 is the exact identity, proportions, clothing and palette reference; Image 2 is the approved male progression master; Image 3 is camera-scale, 3/4-left viewpoint, grounded gait rhythm and silhouette-readability reference only.
Subject: same pale male revenant with white messy hair, facial damage, white shirt, dark waistcoat and long tailored distressed coat, dark trousers, red neck cloth and boots; no weapon.
Style/medium: preserve the approved painterly inked dark-fantasy game-art style, muted brown-gray palette and strong readable silhouette.
Composition/framing: four equal isolated full-body figures in a 2×2 grid, all facing 3/4 left, same anatomical scale and foot baseline; contact A, transition, contact B, transition. Arms, legs, coat and feet visibly change pose. Center each figure; never clip hair, coat, hands or feet.
Constraints: genuinely transparent background; exactly four figures and no extras; no grid lines, labels, text, watermark, frame, checkerboard or cross-quadrant shadow; no whole-body canvas bob; consistent head height and hip registration; generous transparent space; do not redesign identity, outfit, damage, proportions or palette.
```

### male/revenant — attempt 2

```text
Use case: background-extraction
Asset type: Almsth four-pose walking sprite source sheet
Primary request: Remove only the dark gradient background from Image 1 and return a clean genuinely transparent RGBA cutout sheet.
Input images: Image 1 is the edit target; Image 2 confirms the exact approved male revenant identity.
Invariants: preserve every artistic feature, identity, face, hair/bone anatomy, outfit, damage, proportions, anatomical scale, 2×2 placement, and all four existing genuinely distinct walking poses. Do not redraw, restyle, reposition or change limbs.
Constraints: actual transparency with clean fine hair/bone/coat edges; no halos, checkerboard, shadow plate, text, grid, frame, watermark or clipping; exactly four figures.
```

### male/almost_human — attempt 1

```text
Use case: stylized-concept
Asset type: Almsth top-down dungeon character walking sprite source sheet
Primary request: Create exactly four genuinely distinct alternating walking poses for the approved MALE ALMOST HUMAN character from the references, arranged as a clean 2×2 sheet, for deterministic extraction into four square game frames.
Input images: Image 1 is the exact identity, proportions, clothing and palette reference; Image 2 is the approved male progression master; Image 3 is camera-scale, 3/4-left viewpoint, grounded gait rhythm and silhouette-readability reference only.
Subject: same living fair-skinned man with white messy hair, white open-collar shirt, distressed black coat, red-brown shoulder cape/scarf, leather straps, dark trousers, gloves and boots; no weapon.
Style/medium: preserve the approved painterly inked dark-fantasy game-art style, muted brown-gray palette and strong readable silhouette.
Composition/framing: four equal isolated full-body figures in a 2×2 grid, all facing 3/4 left, same anatomical scale and foot baseline; contact A, transition, contact B, transition. Arms, legs, coat and feet visibly change pose. Center each figure; never clip hair, coat, hands or feet.
Constraints: genuinely transparent background; exactly four figures and no extras; no grid lines, labels, text, watermark, frame, checkerboard or cross-quadrant shadow; no whole-body canvas bob; consistent head height and hip registration; generous transparent space; do not redesign identity, outfit, damage, proportions or palette.
```

### male/almost_human — attempt 2

```text
Use case: background-extraction
Asset type: Almsth four-pose walking sprite source sheet
Primary request: Remove only the dark gradient background from Image 1 and return a clean genuinely transparent RGBA cutout sheet.
Input images: Image 1 is the edit target; Image 2 confirms the exact approved male almost-human identity.
Invariants: preserve every artistic feature, identity, face, hair/bone anatomy, outfit, damage, proportions, anatomical scale, 2×2 placement, and all four existing genuinely distinct walking poses. Do not redraw, restyle, reposition or change limbs.
Constraints: actual transparency with clean fine hair/bone/coat edges; no halos, checkerboard, shadow plate, text, grid, frame, watermark or clipping; exactly four figures.
```

### Old Claymore — attempt 1

```text
Use case: production game UI item icon. Create one worn Old Claymore that belongs to the same painterly dark-fantasy item-icon family as the five references. A straight, visibly long iron two-handed sword with a readable cruciform guard, a clearly extra-long leather-wrapped grip sized for both hands, and a modest round pommel. Age it with scratches, nicks, oxidation, and dulled steel, but keep the silhouette clean and immediately readable at 44 px. Show the complete weapon diagonally from lower left to upper right, centered, with generous even transparent padding (prefer 8 px, minimum 4 px after final 132x132 crop). One object only. Output a square RGBA image with genuine transparency outside the sword. No background, checkerboard, glow, cast shadow, border, frame, text, letters, symbols, hands, character, scabbard, extra props, cropped tip, or cropped pommel.
```

## Rejected preflight invocation (no generation, not an attempt)

The first female-skeleton call used six reference paths and was rejected by the built-in
tool before generation. Its exact prompt was:

```text
Use case: stylized-concept
Asset type: Almsth top-down dungeon character walking sprite source sheet
Primary request: Create exactly four genuinely distinct alternating walking poses for the approved FEMALE SKELETON character from the references, arranged as a clean 2×2 sheet, for later deterministic extraction into four square game frames.
Input images: Image 1 is the exact identity, proportions, clothing and palette reference; Image 2 is the approved female progression master; Images 3–6 are the exact camera-scale, 3/4-left viewpoint, grounded gait rhythm and silhouette readability references only.
Subject: the same female skeleton, same long distressed dark leather coat, purple cloth, exposed ivory bones, skull proportions and accessories; no weapon.
Style/medium: preserve the approved painterly inked dark-fantasy game-art style, muted brown-gray palette, strong readable silhouette.
Composition/framing: four equal isolated full-body figures in a 2×2 grid, all facing 3/4 left, same anatomical scale and foot baseline; contact A, transition, contact B, transition. Arms, legs, coat tails and feet must actually change pose. Keep the body centered in each quadrant and never clip hair, coat, hands or feet.
Constraints: genuinely transparent background; exactly four figures and no extras; no grid lines, labels, text, watermark, frame, shadows crossing quadrants or checkerboard; no whole-body canvas bob; consistent head height and hip registration; at least generous transparent space around each figure; do not redesign identity, outfit, damage, proportions or palette.
```
