extends SceneTree

const Suite := preload("res://tests/wiki_contract_test.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = Suite.new().run(self)
	if failures.is_empty():
		print("WIKI CONTRACT TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("WIKI CONTRACT TEST FAILED: %d failure(s)" % failures.size())
	quit(1)
