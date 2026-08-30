extends SceneTree

const AudioSuite := preload("res://tests/audio_test.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = await AudioSuite.new().run(self)
	if failures.is_empty():
		print("AUDIO TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("AUDIO TEST FAILED: %d failure(s)" % failures.size())
	quit(1)
