extends SceneTree

const RegressionSuite := preload("res://tests/regression_test.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = await RegressionSuite.new().run(self)
	if failures.is_empty():
		print("REGRESSION TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("REGRESSION TEST FAILED: %d failure(s)" % failures.size())
	quit(1)
