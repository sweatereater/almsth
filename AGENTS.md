# Almsth agent workflow

These instructions apply to the whole repository.

## Project baseline

- This is a Godot 4 project written in GDScript. Read `README.md` before changing behavior.
- Preserve all existing uncommitted and untracked work. Never reset, discard, or overwrite
  unrelated changes.
- Do not create commits, publish builds, or use remote services unless the user explicitly asks.
- Keep Russian and English localization in sync for every player-facing change.
- Maintain save compatibility or add an explicit migration and regression coverage.
- Treat `docs/art-direction.md` as the source of truth for approved asset dimensions,
  creature anchors, visual footprints, zoom-review sizes, and world/UI rendering boundaries.
- Do not introduce a balance-specialist workflow until the user asks for one after the playable
  prototype is established.

## Multi-agent workflow

Use subagents when a task crosses multiple systems, has ambiguous impact, or benefits from an
independent review. Handle small, obvious, single-file changes directly.

For a substantial feature or defect:

1. If useful, run `almsth_architect` and `almsth_qa` in parallel before implementation.
   Both gather evidence; neither may edit project sources. When the task changes sprites,
   textures, animation, effects, camera scale, or a substantial UI composition, also run
   `almsth_visual_designer` to produce an art brief against `docs/art-direction.md`.
2. Wait for both results. The primary agent owns requirements and resolves contradictions into
   one implementation specification with explicit acceptance criteria.
3. Delegate implementation to one `almsth_developer`. Do not let the primary agent or another
   worker edit overlapping files concurrently.
4. After implementation stops, run `almsth_qa` again for independent verification. For a
   visually significant change, let `almsth_visual_designer` independently inspect the final
   assets and preview matrix as a read-only visual review.
5. Send confirmed defects back to the same developer, then rerun the relevant checks.
6. The primary agent integrates the evidence and gives the user the final outcome.

Never use multiple write-capable agents on the same feature at the same time. The visual
designer is advisory and read-only; the primary agent owns product decisions and the single
developer remains the only source-changing agent. Parallelize exploration and review;
serialize source-code changes.

## Verification

- Start with the narrowest relevant checks.
- Run `godot --headless --path . --script res://tests/smoke_test.gd` for normal changes.
- Run `godot --headless --path . --script res://tests/soak_test.gd` when generation,
  progression, randomness, survival, or long sequences are affected.
- If `godot` is not on `PATH`, locate the existing compatible Godot executable and report the
  exact command used.
- A task is not complete while relevant tests fail or a confirmed regression remains.

## Agent handoffs

Subagent reports should be concise and evidence-based. Include repository-relative file paths,
symbols, commands, results, and remaining uncertainty. The primary agent—not a subagent—owns
product decisions and the final response to the user.
