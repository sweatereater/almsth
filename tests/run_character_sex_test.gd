extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = await preload("res://tests/character_sex_test.gd").new().run(self)
	for failure in failures:
		push_error(failure)
	print("CHARACTER SEX TEST PASSED" if failures.is_empty() else "CHARACTER SEX TEST FAILED")
	quit(0 if failures.is_empty() else 1)
