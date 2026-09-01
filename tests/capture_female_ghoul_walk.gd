extends SceneTree

const Demo := preload("res://scripts/demo/female_ghoul_walk.gd")
const Motion := preload("res://scripts/demo/female_ghoul_motion.gd")
const OUT := "res://builds/previews/female-ghoul/"
var demo: Control
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	demo = Demo.new()
	root.add_child(demo)
	demo.manual_control_enabled = false
	await process_frame
	for pixels in [44, 66, 88]:
		demo.reset_demo()
		demo.set_zoom(pixels)
		await _save("%dx%d-%d-idle" % [root.size.x, root.size.y, pixels])
		demo.motion.begin_step(demo.floor_data, Vector2i.RIGHT)
		demo.motion.advance(Motion.STEP_SECONDS * 0.55)
		demo.refresh_presentation()
		await _save("%dx%d-%d-walk" % [root.size.x, root.size.y, pixels])
	# Draw the exact same sprite at the same cell with and without mirroring.
	demo.reset_demo()
	demo.set_zoom(88)
	demo.motion.facing_right = true
	demo.refresh_presentation()
	await _save("%dx%d-88-idle-mirrored" % [root.size.x, root.size.y])
	demo.toggle_locale()
	await _save("%dx%d-88-en" % [root.size.x, root.size.y])
	for entry in [["edge", Vector2i(1, 5)], ["door", Vector2i(7, 3)], ["chest", Vector2i(8, 2)]]:
		demo.reset_demo()
		demo.motion.cell = entry[1]
		demo.refresh_presentation()
		await _save("%dx%d-88-%s" % [root.size.x, root.size.y, entry[0]])
	if OS.get_cmdline_user_args().has("--animation"):
		demo.reset_demo()
		demo.auto_walk = true
		for index in range(144):
			demo.motion.advance(0.05)
			if not demo.motion.moving:
				demo.motion.begin_step(demo.floor_data, demo._auto_direction())
			demo.refresh_presentation()
			await _save("motion-%03d" % index)
	demo.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("FEMALE GHOUL CAPTURE PASSED" if failures.is_empty() else "FEMALE GHOUL CAPTURE FAILED")
	quit(0 if failures.is_empty() else 1)


func _save(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		failures.append("Empty renderer capture: " + name)
		return
	if image.save_png(OUT + name + ".png") != OK:
		failures.append("Cannot save capture: " + name)
