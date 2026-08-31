extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not preload("res://tests/nightly_environment.gd").verify(true):
		quit(2)
		return
	var phase := "settings"
	var seed_value := 812
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="):
			phase = argument.trim_prefix("--phase=")
		elif argument.begins_with("--seed="):
			seed_value = argument.trim_prefix("--seed=").to_int()
	if phase == "fail":
		push_error("NIGHTLY INJECTED FAILURE: exit zero must not mask engine errors")
		print("NIGHTLY PHASE PASSED")
		quit(0)
		return
	if phase == "timeout":
		print("NIGHTLY INJECTED TIMEOUT: awaiting parent process timeout")
		await create_timer(60.0).timeout
		quit(0)
		return
	var failures: Array[String] = await preload("res://tests/nightly_scenarios.gd").new().run(self, phase, seed_value)
	for failure in failures:
		push_error(failure)
	print("NIGHTLY PHASE PASSED: %s seed=%d" % [phase, seed_value] if failures.is_empty() else "NIGHTLY PHASE FAILED: %s seed=%d" % [phase, seed_value])
	quit(0 if failures.is_empty() else 1)
