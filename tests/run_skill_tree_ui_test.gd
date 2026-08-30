extends SceneTree

const SkillTreeUiSuite := preload("res://tests/skill_tree_ui_test.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = await SkillTreeUiSuite.new().run(self)
	if failures.is_empty():
		print("SKILL TREE UI TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("SKILL TREE UI TEST FAILED: %d failure(s)" % failures.size())
	quit(1)
