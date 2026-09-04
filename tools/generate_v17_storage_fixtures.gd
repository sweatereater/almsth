extends SceneTree

## One-shot provenance helper for the frozen Stage 1B migration fixtures.
## This file intentionally targets the strict v17 implementation that existed
## before storage fields were added. Do not update it to emit newer versions.

const SaveSystem := preload("res://scripts/system/persistence.gd")
const Snapshot := preload("res://scripts/system/run_snapshot.gd")
const OUTPUT_DIR := "res://tests/fixtures/save-v17"
const WORK_DIR := "user://stage1b-v17-fixture-generation"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if SaveSystem.SAVE_VERSION != 17 or SaveSystem.STATE_ONLY_VERSION != 17:
		push_error("v17 fixtures must be captured before changing persistence versions")
		quit(1)
		return
	_cleanup(WORK_DIR)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var state := RunState.new()
	state.configure_character("Frozen v17", GameRules.default_attributes())
	state.character_sex = "female"
	state.resources = {"wood": 23, "stone": 11, "cloth": 7}
	state.inventory = {
		GameRules.make_item_key("bone_knife", 2): 3,
		GameRules.make_item_key("old_claymore", 3, true): 1,
	}
	state.inventory_marks = {
		GameRules.make_item_key("bone_knife", 2): "salvage",
		GameRules.make_item_key("old_claymore", 3, true): "keep",
	}
	state.total_turns = 17
	state.mana = 0
	state.mana_regeneration_progress = 0.375

	var state_result := SaveSystem.save_slot(
		state, "frozen-v17-state", "overwrite", WORK_DIR, 1700000017,
	)
	if not bool(state_result.get("ok", false)):
		push_error("failed to create strict v17 state-only fixture: %s" % state_result)
		quit(1)
		return

	var random := RandomNumberGenerator.new()
	random.seed = -7017001700170017
	random.state = 17001700170017
	# Keep publication_order deterministic while still going through save_slot().
	SaveSystem._publication_clock = 7000000000000000000
	var full_result := SaveSystem.save_slot(
		state,
		"frozen-v17-full",
		"history",
		WORK_DIR,
		1700000018,
		Callable(),
		{"fixture": "stage1b-v17-full-run"},
		Callable(),
		Snapshot.capture("base", {}, Vector2i.ZERO, random, {}),
	)
	if not bool(full_result.get("ok", false)):
		push_error("failed to create strict v17 full-run fixture: %s" % full_result)
		quit(1)
		return

	for pair in [
		["frozen-v17-state.json", "frozen-v17-state-only.json"],
		["frozen-v17-full.json", "frozen-v17-full-run.json"],
	]:
		var source := WORK_DIR.path_join(String(pair[0]))
		var destination := OUTPUT_DIR.path_join(String(pair[1]))
		var bytes := FileAccess.get_file_as_bytes(source)
		var output := FileAccess.open(destination, FileAccess.WRITE)
		if output == null:
			push_error("failed to open fixture output: %s" % destination)
			quit(1)
			return
		output.store_buffer(bytes)
		output.close()
	print("FROZEN V17 STORAGE FIXTURES CAPTURED")
	quit(0)


func _cleanup(path: String) -> void:
	assert(path == WORK_DIR or path.begins_with(WORK_DIR + "/"))
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file_name in directory.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(file_name)))
	for child in directory.get_directories():
		_cleanup(path.path_join(child))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
