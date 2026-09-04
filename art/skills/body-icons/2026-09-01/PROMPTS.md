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

## Stage 1E replacement set — 2026-09-02

The prior mannequin material remains historical provenance only. Stage 1E used
eleven independent built-in ImageGen cutouts; no accepted candidate is an edit,
derivative, or shared-silhouette variant. Each call used `previews/contact-dark.png`
and, when available, `.tmp/stage1c-previews/ru-1280x720-skill-all-icons.png` as
references. The packager only crops, fits, preserves alpha, re-quantizes, and
downsamples; it never draws or changes anatomical content.

Exact common prompt template (with the table substitutions):

> Create one original Almsth anatomical body-skill emblem on a transparent 512×512 canvas. Subject: `{subject}`. Composition: `{composition}`. Fit every meaningful pixel inside x/y 64–447. Use flat slate `#59677A` with restrained coral `#E35D63`, strong irregular anatomical shapes, broad negative space, and a unique alpha silhouette readable at 54 px. Minimum structural stroke 24 master px and primary gap 20 master px. No full-body mannequin unless explicitly required, background, checkerboard, cast shadow, glow, frame, UI state, lock, cost, text, letters, numerals, runes, logos, badge, gore, stock imagery, or copied anatomy.

| ID | Subject / composition | Accepted result |
|---|---|---|
| `strong_bones` | pelvis + outward load-bearing femurs; broad A; coral marrow | `exec-72913d58-637f-4da3-89bf-42640eb558b8.png` |
| `flexible_joints` | bent knee/elbow S hinge; rounded patella; diagonal chevron | `exec-36ad35c0-8f6c-45f1-9ae0-b9d6cfdd4b3d.png` |
| `strong_spine` | curved vertebral column to sacrum/pelvis; tall segmented vertical | `exec-2947deac-6d79-4c21-a8c4-99ebb8668990.png` |
| `sharp_vision` | almond eye, sharp lid, iris/pupil, ≤3 rays; wide horizontal | `exec-44650f4c-b1c9-4b4c-8b2d-5b20235824e6.png` |
| `muscle_fibers` | flexed biceps cutaway, three broad fiber bundles; diagonal arm | `exec-b74fc6e8-7214-40f6-8570-d5f1bcc7a7f4.png` |
| `stomach` | J stomach + esophagus/duodenum, coral fold; pear/J | `exec-4c4432b1-2597-481c-9068-c0792cc284a6.png` |
| `flesh_regeneration` | heart with two circulation-loop arteries; compact loop | `exec-cd12bf96-5d6e-4679-9228-8381bab33bcc.png` |
| `ears` | side ear with helix/concha and echo arc; C silhouette | `exec-7e4635b9-6c5e-4cb8-9e75-60b38e537f25.png` |
| `nervous_system` | brain crown, spinal cord, paired roots; vertical tree | `exec-afb56b5c-a82b-4c42-82ce-2e9aacb99255.png` |
| `choose_appearance` | offset revenant/human profiles; split identity | `exec-4cedddef-9b29-493f-8fc9-e6e1ca6f8ebd.png` |
| `fundamentals` | open five-finger palm with wrist/tendons; broad hand | `exec-8ffa8005-903d-4977-8533-951a02454e86.png` |

### Rejected independent calls

All calls below remain provenance only and were never packaged or referenced by
runtime assets. They failed the explicit coral-coverage review gate after the
same transparent-alpha validation: `stomach` `exec-19bca7dd-df1b-4500-93a5-1bfe29d28d67.png` (42.4%), `flesh_regeneration` `exec-8e0304d5-a4c1-4a8f-bf4c-2e095a633f93.png` (38.2%), `ears` `exec-70d26e1c-c301-4f05-83fd-06e59cc1f527.png` (30.9%), `choose_appearance` `exec-69c1dbcd-2cc2-4cfe-8d29-f1b64fbf099a.png` (30.1%), `fundamentals` `exec-542d4c31-0f3c-4293-ab18-d1745d0a1b6a.png` (35.3%), and two later `stomach` attempts: `exec-b59543f9-a19f-4b90-a61d-851fd58d7c77.png` (33.2%) and `exec-550a7195-e6ef-4b12-b472-45e1f38f9b6f.png` (5.0%).
