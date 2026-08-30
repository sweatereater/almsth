extends SceneTree

const StatusCooldownSuite := preload("res://tests/status_cooldown_test.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = await StatusCooldownSuite.new().run(self)
	if failures.is_empty():
		print("STATUS COOLDOWN TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("STATUS COOLDOWN TEST FAILED: %d failure(s)" % failures.size())
	quit(1)
