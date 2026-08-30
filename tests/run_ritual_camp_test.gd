extends SceneTree

const RitualCampSuite := preload("res://tests/ritual_camp_test.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = await RitualCampSuite.new().run(self)
	if failures.is_empty():
		print("RITUAL CAMP TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("RITUAL CAMP TEST FAILED: %d failure(s)" % failures.size())
	quit(1)
