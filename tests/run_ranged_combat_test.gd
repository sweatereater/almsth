extends SceneTree

const Suite := preload("res://tests/ranged_combat_test.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = await Suite.new().run(self)
	if failures.is_empty():
		print("RANGED COMBAT TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("RANGED COMBAT TEST FAILED: %d failure(s)" % failures.size())
	quit(1)
