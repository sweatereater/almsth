extends RefCounted

## Optional for existing direct runners; mandatory for nightly entry points.
static func verify(required := false) -> bool:
	var run_root := OS.get_environment("ALMSTH_NIGHTLY_ROOT").replace("\\", "/").trim_suffix("/")
	if run_root.is_empty():
		return not required
	var executable := OS.get_executable_path().replace("\\", "/")
	var user_dir := OS.get_user_data_dir().replace("\\", "/")
	var workspace_tmp := ProjectSettings.globalize_path("res://.tmp/nightly/").replace("\\", "/")
	var valid := (run_root.begins_with(workspace_tmp)
		and executable.begins_with(run_root + "/runtime/")
		and user_dir.begins_with(run_root + "/environment/appdata/"))
	print("NIGHTLY EXECUTABLE=", executable)
	print("NIGHTLY USER DATA=", user_dir)
	print("NIGHTLY ISOLATION GUARD=", valid)
	if not valid:
		push_error("Nightly environment must isolate both executable and user data before tests")
	return valid
