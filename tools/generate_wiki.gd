extends SceneTree

const Reference := preload("res://tools/wiki_reference.gd")


func _init() -> void:
	var check_only := OS.get_cmdline_args().has("--check") or OS.get_cmdline_user_args().has("--check")
	var failures := Reference.check_generated_files() if check_only else Reference.write_generated_files()
	if failures.is_empty():
		print("WIKI GENERATED FILES ARE FRESH" if check_only else "WIKI GENERATED FILES UPDATED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("WIKI GENERATION FAILED: %d failure(s)" % failures.size())
	quit(1)
