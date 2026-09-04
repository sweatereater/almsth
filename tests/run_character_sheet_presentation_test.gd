extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	preload("res://scripts/system/input_bindings.gd").ensure_defaults()
	var failures: Array[String] = await preload("res://tests/character_sheet_presentation_test.gd").new().run(self)
	for failure in failures:
		push_error(failure)
	print("CHARACTER SHEET PRESENTATION %s: %d failures" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
