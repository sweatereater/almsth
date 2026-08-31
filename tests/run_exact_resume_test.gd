extends SceneTree

const Suite := preload("res://tests/exact_resume_test.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = await Suite.new().run(self)
	for failure in failures:
		push_error(failure)
	print("EXACT RESUME TEST PASSED" if failures.is_empty() else "EXACT RESUME TEST FAILED: %d failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)
