extends SceneTree

const Suite := preload("res://tests/camp_build_panel_test.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = await Suite.new().run(self)
	if failures.is_empty():
		print("CAMP BUILD PANEL TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("CAMP BUILD PANEL TEST FAILED: %d failure(s)" % failures.size())
	quit(1)
