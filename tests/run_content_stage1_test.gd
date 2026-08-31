extends SceneTree

const Suite := preload("res://tests/content_stage1_test.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = await Suite.new().run(self)
	for failure in failures:
		push_error(failure)
	print("CONTENT STAGE1 TEST PASSED" if failures.is_empty() else "CONTENT STAGE1 TEST FAILED: %d" % failures.size())
	quit(0 if failures.is_empty() else 1)
