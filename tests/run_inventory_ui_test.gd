extends SceneTree

const Suite := preload("res://tests/inventory_ui_test.gd")
const InputProfile := preload("res://scripts/system/input_bindings.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	InputProfile.ensure_defaults()
	var failures: Array[String] = await Suite.new().run(self)
	if failures.is_empty():
		print("INVENTORY UI TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("INVENTORY UI TEST FAILED: %d failure(s)" % failures.size())
	quit(1)
