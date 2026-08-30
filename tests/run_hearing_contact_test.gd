extends SceneTree

const HearingContactSuite := preload("res://tests/hearing_contact_test.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = await HearingContactSuite.new().run(self)
	if failures.is_empty():
		print("HEARING CONTACT TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("HEARING CONTACT TEST FAILED: %d failure(s)" % failures.size())
	quit(1)
