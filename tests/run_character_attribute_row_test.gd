extends SceneTree

const CharacterAttributeRowSuite := preload("res://tests/character_attribute_row_test.gd")
const InputProfile := preload("res://scripts/system/input_bindings.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	InputProfile.ensure_defaults()
	var failures: Array[String] = await CharacterAttributeRowSuite.new().run(self)
	if failures.is_empty():
		print("CHARACTER ATTRIBUTE ROW TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("CHARACTER ATTRIBUTE ROW TEST FAILED: %d failure(s)" % failures.size())
	quit(1)
