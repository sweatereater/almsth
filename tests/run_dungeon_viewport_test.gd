extends SceneTree

const Suite := preload("res://tests/dungeon_viewport_test.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = await Suite.new().run(self)
	if failures.is_empty():
		print("DUNGEON VIEWPORT TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("DUNGEON VIEWPORT TEST FAILED: %d failure(s)" % failures.size())
	quit(1)
