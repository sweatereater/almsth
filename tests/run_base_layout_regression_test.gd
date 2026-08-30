extends SceneTree

const InventorySuite := preload("res://tests/inventory_ui_test.gd")
const DungeonViewportSuite := preload("res://tests/dungeon_viewport_test.gd")
const InputProfile := preload("res://scripts/system/input_bindings.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	InputProfile.ensure_defaults()
	var failures: Array[String] = []
	failures.append_array(await InventorySuite.new().run(self))
	failures.append_array(await DungeonViewportSuite.new().run(self))
	if failures.is_empty():
		print("BASE LAYOUT REGRESSION TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("BASE LAYOUT REGRESSION TEST FAILED: %d failure(s)" % failures.size())
	quit(1)
