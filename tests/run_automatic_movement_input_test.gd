extends SceneTree

const Suite := preload("res://tests/automatic_movement_input_test.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = await Suite.new().run(self)
	if failures.is_empty():
		print("AUTOMATIC MOVEMENT INPUT TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("AUTOMATIC MOVEMENT INPUT TEST FAILED: %d failure(s)" % failures.size())
	quit(1)
