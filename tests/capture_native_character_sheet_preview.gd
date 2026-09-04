extends SceneTree

const Loc := preload("res://scripts/localization/localization.gd")
const Artwork := preload("res://scripts/ui/character_artwork.gd")
const ROOT := "res://.tmp/character-sheet-previews"
var records: Array = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	for window in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = window
		for locale in ["ru", "en"]:
			Loc.set_locale(locale)
			var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
			main.persistence_enabled = false
			main.audio_playback_enabled = false
			root.add_child(main)
			await process_frame
			main.set_process(false)
			main.state.configure_character("Ньюб" if locale == "ru" else "Newbie", GameRules.default_attributes())
			main._show_base("", "none")
			main._show_character()
			main._select_character_panel("inventory")
			for sex in Artwork.SEXES:
				main.state.character_sex = sex
				for form in Artwork.FORMS:
					main.state.current_form_id = form
					main.state.highest_unlocked_form_index = 4
					main.state.display_form_id = ""
					main.state.hp = main.state.get_derived_stats().max_hp
					main._refresh_character_sheet()
					await process_frame
					await process_frame
					await RenderingServer.frame_post_draw
					var path := ROOT.path_join("%s-%dx%d-%s-%s.png" % [locale, window.x, window.y, sex, form])
					var picture := root.get_texture().get_image()
					assert(picture.get_size() == window)
					assert(picture.save_png(path) == OK)
					records.append({"path":path, "sha256":FileAccess.get_sha256(path), "locale":locale, "sex":sex, "form":form, "window":[window.x,window.y]})
			main.queue_free()
			await process_frame
	var manifest := FileAccess.open(ROOT.path_join("manifest.json"), FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"count":records.size(), "captures":records}, "\t"))
	print("CHARACTER SHEET PREVIEW PASS: %d real-renderer captures" % records.size())
	quit(0)
