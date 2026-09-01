extends SceneTree

const BodySkillSuite := preload("res://tests/body_skill_test.gd")


func _init() -> void:
	var failures: Array[String] = BodySkillSuite.new().run()
	if failures.is_empty():
		print("BODY SKILL TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("BODY SKILL TEST FAILED: %d failure(s)" % failures.size())
	quit(1)
