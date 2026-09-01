# Map character runtime — 2026-09-01

This package supplies nine generated sex/form gait sheets plus the generated Old Claymore
candidate. The protected tenth set, `female/ghoul`, stays at
`assets/dungeon/female-ghoul/frames/` and is never copied or rewritten by this recipe.

- [Exact ImageGen prompts, candidates and decisions](imagegen-prompts.md)
- [Final frame/icon hashes and alpha bounds](runtime-manifest.json)
- Deterministic preparation: `tools/prepare_nightly_character_assets.py`

Each selected 2×2 gait sheet is deterministically separated into four genuinely distinct
264×264 RGBA8 frames. One scale derived from the set's widest/tallest subject is applied
verbatim to all four authored poses, which are centered at the shared logical anchor
`(132,260)` and retain at least 4 px transparent padding. No pose is synthesized by shifting
another pose. Female skeleton and zombie use a connected-edge
light-background matte; the remaining selected candidates retain authored alpha. The Old
Claymore is cropped and scaled as one authored object to 132×132 RGBA8 with 8/9/8/10 px
padding. Runtime paths contain no reference to the Codex generation directory.

Running `tools/prepare_nightly_character_assets.py --check` builds all frames and the icon
under a system temporary directory, compares their bytes and manifest against runtime, then
removes that temporary directory. Check mode never rewrites the delivered PNGs or workspace.

The Character Sheet remains a separate 264×704 asset family under
`assets/ui/character-fullbody/{female,male}/`; this package never rewrites it.
