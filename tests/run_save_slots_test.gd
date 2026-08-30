extends SceneTree

const SaveSlotsSuite := preload("res://tests/save_slots_test.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = await SaveSlotsSuite.new().run(self)
	if failures.is_empty():
		print("SAVE SLOTS TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("SAVE SLOTS TEST FAILED: %d failure(s)" % failures.size())
	quit(1)
