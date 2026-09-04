# Stage 1E protected-art transition

Stage 1E is a one-way, hash-gated transition from the accepted 416-record
Stage 1C freeze to a 427-record Stage 1E freeze. It changes exactly 41 paths:
11 new ImageGen candidates, 11 masters, 11 runtime icons, three icon contact
sheets, prompt and icon manifests, record-player and workbench layers, and the
camp manifest. There are zero permanent exceptions, including no soul-icon
exception.

`tools/verify_stage1c_protected_assets.py --apply-stage1e-transition` derives
the pre-turn set from immutable pre-Stage1E archive hashes plus the canonical
accepted-baseline digest. It refuses missing, extra, or unallowlisted deltas,
records exact 416→427 evidence, and closes the transition. Normal verification
then byte-compares all 427 records with no filtered paths. Its self-test mutates
an existing disallowed protected record and proves rejection.

The camp recipe is hash-gated by `tools/patch_stage1e_camp_art.py`: record
player source `a75599c37967d5dd64d886d066c44afc29e47e8428a2e5b288c2f2f9cd554737`
becomes `067820e5123e52111e8af6dc819fd0212c37a01c497604d6263355d6f50f3873` via
exact `[4,4,3,4]` padding. Workbench source
`856baaec3bde125fd442c592ab61c6584b714fb8a2dba9a98ca54afa0278522d` becomes
`c48a78418b85b14ddc8cb4a59f0af520db48a6d191cd72848de046aa10345303`: first 47
exterior alpha-only clears (18 alpha-1, 29 alpha-2), then a region-gated
457-pixel pale attached-halo cleanup in `[64,107]–[135,130]`, preserving RGB
and 269 saturated brown/wood pixels. The manifest and nightly contract verify
dimensions, hashes, counts, and bounds.
