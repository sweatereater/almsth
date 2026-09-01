extends SceneTree

const Suite := preload("res://tests/nightly_contract_test.gd")


func _init() -> void:
	var failures: Array[String] = Suite.new().run()
	if failures.is_empty():
		print("NIGHTLY CONTRACT TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("NIGHTLY CONTRACT TEST FAILED: %d failure(s)" % failures.size())
	quit(1)
