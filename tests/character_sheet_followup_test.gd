extends SceneTree

const SoulLevelSuite := preload("res://tests/soul_level_test.gd")
const InventoryUiSuite := preload("res://tests/inventory_ui_test.gd")
const VisualOverhaulSuite := preload("res://tests/visual_overhaul_test.gd")
const StatusCooldownSuite := preload("res://tests/status_cooldown_test.gd")
const SkillTreeUiSuite := preload("res://tests/skill_tree_ui_test.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	for suite in [SoulLevelSuite.new(), InventoryUiSuite.new(), VisualOverhaulSuite.new(), StatusCooldownSuite.new(), SkillTreeUiSuite.new()]:
		for failure in await suite.run(self):
			if not failures.has(String(failure)):
				failures.append(String(failure))
	if failures.is_empty():
		print("CHARACTER SHEET FOLLOW-UP TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("CHARACTER SHEET FOLLOW-UP TEST FAILED: %d failure(s)" % failures.size())
	quit(1)
