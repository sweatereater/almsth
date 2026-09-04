"""Freeze/check the accepted Stage 1C art baseline during Stage 1D."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "docs/stage1c-protected-assets.json"
TRANSITION_EVIDENCE = ROOT / "docs/stage1e-protected-transition.json"
# Canonical accepted 427-record Stage1E manifest bytes.  This anchors the
# reconstructed 416-record source so an in-place change to any unaffected
# record cannot be smuggled through a later transition invocation.
ACCEPTED_STAGE1E_MANIFEST_SHA256 = "18e8dfdf30c9ffb74630f557f2f123cfde34b06e956a466a83ce69e7b00e95a6"
AUTHORIZED: set[str] = set()
# Stage 1E is a guarded transition, not a blanket unfreeze. These are the only
# baseline entries allowed to differ; every other protected record remains an
# exact Stage 1C byte comparison. The prior Stage 1D soul icon is retained as
# its already-accepted runtime exception.
STAGE1E_BODY_IDS = ["strong_bones", "flexible_joints", "strong_spine", "sharp_vision", "muscle_fibers", "stomach", "flesh_regeneration", "ears", "nervous_system", "choose_appearance", "fundamentals"]
STAGE1E_ALLOWED = {
    "art/skills/body-icons/2026-09-01/PROMPTS.md",
    "art/skills/body-icons/2026-09-01/manifest.json",
    "art/skills/body-icons/2026-09-01/previews/contact-checker.png",
    "art/skills/body-icons/2026-09-01/previews/contact-dark.png",
    "art/skills/body-icons/2026-09-01/previews/contact-light.png",
    "assets/art/camp-2026-09-01/camp-record-player.png",
    "assets/art/camp-2026-09-01/camp-workbench.png",
    "assets/art/camp-2026-09-01/manifest.json",
}
for _id in STAGE1E_BODY_IDS:
    STAGE1E_ALLOWED.add(f"art/skills/body-icons/2026-09-01/candidates/{_id}-stage1e.png")
    STAGE1E_ALLOWED.add(f"art/skills/body-icons/2026-09-01/masters/{_id}.png")
    STAGE1E_ALLOWED.add(f"assets/ui/skill-icons/body/{_id}.png")
ROOTS = [
    ROOT / "art",
    ROOT / "assets/art",
    ROOT / "assets/dungeon",
    ROOT / "assets/items",
    ROOT / "assets/ui/character-fullbody",
    ROOT / "assets/ui/skill-icons",
    ROOT / "assets/portraits",
]
EXACT_FILES = [
    # Runtime HUD input outside the protected art subtrees. Keep this narrow:
    # generated/unrelated assets/ui files are not part of the Stage 1D freeze.
    ROOT / "assets/ui/soul-icon.png",
]

# This is the accepted pre-Stage1E snapshot, recovered from the complete
# pre-change workspace archive (not from the mutable checkout or Git HEAD).
# It is deliberately only the thirty replaced records: the other 386 records
# are already byte-frozen by the accepted Stage1E baseline and the eleven
# candidate files did not exist before the transition.
PRE_STAGE1E_REPLACED: dict[str, tuple[str, int]] = {
    "art/skills/body-icons/2026-09-01/PROMPTS.md": ("4e52d3fb4692e434b17ad8e79d3dbd9c66a05a5aa888ce9bd08e56f8a5792101", 3995),
    "art/skills/body-icons/2026-09-01/manifest.json": ("5bbe7dea44dd893bedbd504fdf41c15d8e89cb9c17737f02dedc6002d9093a66", 14673),
    "art/skills/body-icons/2026-09-01/previews/contact-checker.png": ("f14f63d0df7b85473cd912bfe8eb80a7a86deef1b2f4d16357c299b34273768e", 89851),
    "art/skills/body-icons/2026-09-01/previews/contact-dark.png": ("2635332b2d1342f01a179aae5256a469120a98a17d5b9958246fc2dd324cb4ca", 81994),
    "art/skills/body-icons/2026-09-01/previews/contact-light.png": ("0de2e304f71c94c3b316a5706aaadb281b3d482a613f7347242ca6eb778c1abe", 84486),
    "assets/art/camp-2026-09-01/camp-record-player.png": ("a75599c37967d5dd64d886d066c44afc29e47e8428a2e5b288c2f2f9cd554737", 70900),
    "assets/art/camp-2026-09-01/camp-workbench.png": ("856baaec3bde125fd442c592ab61c6584b714fb8a2dba9a98ca54afa0278522d", 46366),
    "assets/art/camp-2026-09-01/manifest.json": ("c66bfe66ac9d5d92befd3af7c53f7d17e8c371f1e0da3c67987e8414376751dc", 19155),
}
_PRE_MASTERS = {
    "choose_appearance": ("99b0f2ecf36bf97ecd76288b493f49329fdcafcc1ef23e2e8bea3d6f16d1808e",19008), "ears": ("c04343dcdf1be5b731199047b1474b115b31620ce71a0223843859b2f25bd87a",17334), "flesh_regeneration": ("e7dc0a082af2dbd0eee49961fbfc6d25b51d6f9c7cfc63ec7b2f8a342f2d711c",17935), "flexible_joints": ("c6ad488dc6f803cb90dca473c60d0ad34cb8eb669996cb81535dc45166ff0873",17665), "fundamentals": ("6753fd4f7500894fdc7c5c27eeb801c4026c4ce920dee13b604091c56ed0ff02",17447), "muscle_fibers": ("5e77c4b8ac8b40379b5e5ce8f2aaeb5c569bb9e87f355cced31b5e179d529d65",18610), "nervous_system": ("23cfe8f4b5ea9db3a8394acbb23b2fc2a2c8d3dc4e6dd442f3b9223f7ab462ec",18077), "sharp_vision": ("75409986d757f9e3b03d3ef7b3f00141133e5ef0e214af6681582a0b5704c065",17308), "stomach": ("c27bc84dc5b8230a25c08e0365a13dd327f26b393ff3722216393eb65a82c33e",17285), "strong_bones": ("9238fd217811ed1775912e1862873835b2ee2a9ec3c02f88a4c7ff88eb70ce82",19523), "strong_spine": ("e767560f70e68846ffa3dd451907c40ec157c4b5deb202bf28a26062ed443990",17333),
}
_PRE_RUNTIME = {
    "choose_appearance": ("e654eb443bf33b6abff25f52a7e27de0ed7da2734852d44521e73812dcc4209c",3828), "ears": ("b4d70f463732a235de186316bfe1a7d572ed9b2c4afa0f48ef6f17d4a9608825",3496), "flesh_regeneration": ("653940b9e57007d3959854afa7a4249aa7fdf14255c039f5b68bb6bc18bda630",3614), "flexible_joints": ("c04ac8782e2e3e4f632d230244d2eca3bf6abbf079d508d830110417cdcedf7a",3602), "fundamentals": ("8f9b1c32a4ccc076cbae0680b8946c128b49386d9863ff568eaddcb35d569e26",3542), "muscle_fibers": ("7279fcad24aa099b23ec03b291da8a82bca6b69d5783a1cfbc33f988223b6a80",3665), "nervous_system": ("2a498faa16e5c4d3ecd38e2d86aea2ba501b61790dee78b4da67c22e12b33090",3645), "sharp_vision": ("c2e9503b2060223ae102d7dc1bcb06cac2389fbf6e4a7dce104156d14f52480e",3499), "stomach": ("2185623a5423f0a9cd116d6c57f8b2b2fd3700c4282614305bd77bf852ebcc08",3490), "strong_bones": ("ad4cd29e07fdd9cc0adac3131f3740015c7c57a27a632ec48e0d12138eebdf95",3868), "strong_spine": ("21955d39044fb095d76052e473a55cdae49e516e0a4b1e3ab81bd4ccd3962322",3501),
}
for _icon_id, _record in _PRE_MASTERS.items():
    PRE_STAGE1E_REPLACED[f"art/skills/body-icons/2026-09-01/masters/{_icon_id}.png"] = _record
for _icon_id, _record in _PRE_RUNTIME.items():
    PRE_STAGE1E_REPLACED[f"assets/ui/skill-icons/body/{_icon_id}.png"] = _record


def records() -> list[dict]:
    result = []
    paths: list[Path] = []
    for root in ROOTS:
        paths.extend(sorted(item for item in root.rglob("*") if item.is_file()))
    # Preserve the accepted manifest's existing ordering and append only the
    # narrowly added exact UI texture instead of churning unrelated records.
    paths.extend(EXACT_FILES)
    seen: set[Path] = set()
    for path in paths:
        if path in seen:
            continue
        seen.add(path)
        relative = path.relative_to(ROOT).as_posix()
        if relative in AUTHORIZED or relative.endswith(".import") or relative.endswith(".gdignore"):
            continue
        result.append({
            "path": relative,
            "bytes": path.stat().st_size,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        })
    return result


def changed_paths(before: dict, after: dict) -> list[str]:
	old = {entry["path"]: entry for entry in before["files"]}
	new = {entry["path"]: entry for entry in after["files"]}
	return sorted((set(old) ^ set(new)) | {path for path in set(old) & set(new) if old[path] != new[path]})


def validate_closed_stage1e_transition(candidate: dict, accepted: dict) -> None:
    """Reject every replay attempt after the accepted 427-record baseline.

    The original 416-to-427 transition was consumed when this repository's
    accepted manifest and evidence were written. This shared guard is used by
    both the command-line replay path and its mutation probes, so an otherwise
    allowlisted path cannot be rebaselined after acceptance.
    """
    if candidate != accepted:
        raise AssertionError(
            "Stage1E transition is permanently closed; live protected bytes must equal accepted 427 baseline"
        )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply-stage1e-transition", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    current = {
        "schema": 1,
        "baseline": "accepted Stage 1E protected art baseline",
        "authorized_runtime_exceptions": sorted(AUTHORIZED),
        "files": records(),
    }
    manifest_bytes = MANIFEST.read_bytes()
    if hashlib.sha256(manifest_bytes).hexdigest() != ACCEPTED_STAGE1E_MANIFEST_SHA256:
        raise AssertionError("Accepted Stage1E baseline digest changed; guarded transition is permanently closed")
    expected = json.loads(manifest_bytes)
    def immutable_stage1c() -> dict:
        # The original accepted source is reconstructed from the immutable,
        # hash-gated pre-Stage1E archive. It must never depend on Git HEAD.
        old = {entry["path"]: dict(entry) for entry in expected["files"]}
        for path in STAGE1E_ALLOWED:
            if "/candidates/" in path:
                old.pop(path, None)
                continue
            if path not in PRE_STAGE1E_REPLACED:
                raise AssertionError(f"Immutable Stage1C source missing archived hash for {path}")
            digest, size = PRE_STAGE1E_REPLACED[path]
            old[path] = {"path": path, "bytes": size, "sha256": digest}
        result = {"schema": 1, "baseline": "accepted Stage 1C protected art baseline", "authorized_runtime_exceptions": [], "files": [old[path] for path in sorted(old)]}
        assert len(result["files"]) == 416, "Immutable Stage1C source must contain exactly 416 frozen records"
        return result
    if args.self_test:
        before_hashes = {
            "manifest": hashlib.sha256(MANIFEST.read_bytes()).hexdigest(),
            "evidence": hashlib.sha256(TRANSITION_EVIDENCE.read_bytes()).hexdigest(),
        }
        before_mtimes = {
            "manifest": MANIFEST.stat().st_mtime_ns,
            "evidence": TRANSITION_EVIDENCE.stat().st_mtime_ns,
        }

        def assert_rejected(candidate: dict, label: str) -> None:
            try:
                validate_closed_stage1e_transition(candidate, expected)
            except AssertionError:
                return
            raise AssertionError("Stage1E closed transition accepted " + label + " mutation")

        probe_files = [dict(record) for record in current["files"]]
        for record in probe_files:
            if record["path"] == "assets/art/camp-2026-09-01/camp-base.png":
                record["sha256"] = "0" * 64
                break
        else:
            raise AssertionError("Self-test protected record missing")
        probe = {**current, "files": probe_files}
        assert_rejected(probe, "disallowed")
        # A transition is closed after the accepted 427 records are written: an
        # allowlisted path may not be silently rebaselined on a later invocation.
        allowed_probe_files = [dict(record) for record in current["files"]]
        for record in allowed_probe_files:
            if record["path"] == "assets/ui/skill-icons/body/ears.png":
                record["sha256"] = "f" * 64
                break
        else:
            raise AssertionError("Self-test allowlisted record missing")
        assert_rejected({**current, "files": allowed_probe_files}, "allowlisted")
        # The valid closed state is a verification-only replay: it must not
        # refresh timestamps or rewrite either frozen file.
        validate_closed_stage1e_transition(current, expected)
        after_hashes = {
            "manifest": hashlib.sha256(MANIFEST.read_bytes()).hexdigest(),
            "evidence": hashlib.sha256(TRANSITION_EVIDENCE.read_bytes()).hexdigest(),
        }
        after_mtimes = {
            "manifest": MANIFEST.stat().st_mtime_ns,
            "evidence": TRANSITION_EVIDENCE.stat().st_mtime_ns,
        }
        assert before_hashes == after_hashes and before_mtimes == after_mtimes, "Closed transition self-test must not rewrite baseline or evidence"
        print("STAGE 1E TRANSITION REJECTION SELF-TEST PASSED: disallowed and allowlisted mutations rejected; closed replay is read-only")
        return
    if args.apply_stage1e_transition:
        validate_closed_stage1e_transition(current, expected)
        accepted = immutable_stage1c()
        delta = changed_paths(accepted, current)
        assert len(delta) == 41 and set(delta) == STAGE1E_ALLOWED, "Stage1E transition must be the exact approved 41-path set"
        unauthorized = sorted(set(delta) - STAGE1E_ALLOWED)
        assert not unauthorized, "Stage1E transition rejected unallowlisted paths: " + ", ".join(unauthorized)
        print(f"STAGE 1E GUARDED PROTECTED TRANSITION CLOSED: {len(delta)} accepted allowlisted deltas; {len(current['files'])} frozen files; no files written")
        return
    validate_closed_stage1e_transition(current, expected)
    print(f"STAGE 1E PROTECTED ASSET CHECK PASSED: {len(current['files'])} frozen files, zero permanent exceptions")


if __name__ == "__main__":
    main()
