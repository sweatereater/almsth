extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = await preload("res://tests/room_door_test.gd").new().run(self)
	for failure in failures:
		push_error(failure)
	print("ROOM DOOR TEST PASSED" if failures.is_empty() else "ROOM DOOR TEST FAILED: %d" % failures.size())
	quit(0 if failures.is_empty() else 1)
