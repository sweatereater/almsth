# Almsth body-skill icon ImageGen record

Generated on 2026-09-01 with the built-in ImageGen tool. `strong_bones` was one
new generation. Every other candidate was a separate `precise-object-edit`
whose only reference was `candidates/strong_bones.png`; no variant was derived
from another variant.

The checked-in candidates are generation evidence, not runtime-ready assets.
`tools/package_body_skill_icons.py` deliberately replaces checkerboard leakage,
palette variation, silhouette drift and alpha drift with one deterministic
canonical mask before writing the masters and runtime PNGs.

## Canonical generation

Result: `exec-278da2d9-6187-4c48-8cc2-177b16ecefb3.png`

> STYLIZED CONCEPT — canonical Almsth body-skill icon: strong_bones. A single
> gender-neutral adult anatomical mannequin, neutral front-facing symmetric
> A-pose, centered on a square transparent canvas, full body and feet visible,
> stable baseline, generous padding for a 96×96 safe footprint. Flat restrained
> medical-fantasy pictogram. Render the neutral body in muted slate gray
> #59677A and emphasize only a simplified complete skeleton in coral red
> #E35D63: skull, clavicles, readable rib cage, spine, pelvis and major arm/leg
> bones. Only those two colors plus alpha. No text, UI, frame, badge, background,
> checkerboard, shadow, glow, gore, clothing, hair, identity, perspective,
> cropped limbs or fine decorative noise. Designed as a 512×512 master that
> remains immediately readable at 48 px.

## Precise-edit invariant

Each call used the canonical candidate as its sole reference and this invariant:

> PRECISE OBJECT EDIT — preserve the referenced single neutral front-facing
> adult figure exactly: identical pose, silhouette, proportions, camera, crop,
> center, baseline, scale and rendering style. Remove the previous red anatomy.
> Keep the whole figure #59677A and add #E35D63 only to the requested anatomical
> accent. Preserve transparent padding and the same 96×96 safe-footprint
> relationship. Only #59677A, #E35D63 and alpha. No words, labels, numerals,
> symbols, background, checkerboard, frame, badge, shadow, scenery or UI chrome.

| ID | Result file | Requested red accent |
|---|---|---|
| `flexible_joints` | `exec-2ded0f3a-43b1-4ae0-90ab-82816392997f.png` | Only eight symmetric filled joint zones: shoulders, elbows, hips and knees. |
| `strong_spine` | `exec-3feb93ee-e587-4ddb-b536-f9174c29e093.png` | One continuous segmented spine from skull base to sacrum. |
| `sharp_vision` | `exec-d5c2bef1-c23e-4291-9fa5-85227f55955f.png` | Only two enlarged, separated eyes. |
| `muscle_fibers` | `exec-7ee2dcfc-86b4-44aa-9cc4-3e84b99b1ac1.png` | Large paired deltoid/chest, arm, abdominal, thigh and calf muscle masses with gray separation. |
| `stomach` | `exec-421f750a-08cf-44ca-9146-e1c660de166a.png` | One large readable J-shaped stomach, on the viewer's right. |
| `flesh_regeneration` | `exec-4a4954c6-800a-4a17-b1be-e2956cfc9d9c.png` | One heart and major branching blood vessels through torso and limbs. |
| `ears` | `exec-6e09f4f7-4768-4c89-89e1-557534ff7112.png` | Only the two external ears, symmetrically exaggerated. |
| `nervous_system` | `exec-2f075508-3d86-488b-a57d-a7a449008fbe.png` | Brain, central spinal nerve trunk and restrained large symmetric branches to limbs. |
| `choose_appearance` | `exec-54ab04ab-57f7-41c0-8e82-d53c76e94040.png` | Front facial plane and a continuous outer body contour. |
| `fundamentals` | `exec-8c65bc86-1e8d-42a2-bd29-5ecdf397c1f3.png` | Exactly five separated zones: forehead, chest, lower abdomen, left palm and right palm. |

## Rebuild

From the repository root, with the bundled workspace Python/Pillow runtime:

```powershell
python tools/package_body_skill_icons.py
python tools/package_body_skill_icons.py --check
```

The project uses its bundled Python path in automation when `python` is not on
`PATH`. `manifest.json` records source/output hashes, geometry, palette, alpha
hashes and Godot import requirements.
