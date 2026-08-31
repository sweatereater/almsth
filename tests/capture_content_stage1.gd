extends SceneTree

## Deterministic visual review fixtures, never a playable save or a build.
## Run with a real rendering driver; --headless uses the dummy renderer.
const Loc := preload("res://scripts/localization/localization.gd")
const OUT := "res://.tmp/stage1-previews/"
const ITEM_IDS := [
	"rusty_sabre", "short_crossbow", "bone_buckler", "gravediggers_lamp",
	"watchmans_cap", "archivists_mask", "wanderers_gambeson", "lamellar_vest",
	"scouts_trousers", "heavy_leg_wraps", "pilgrims_boots", "aiming_ring",
	"thickblood_ring", "expedition_backpack",
]
var captured: Array[String] = []


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var main = load("res://scenes/main.tscn").instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	root.add_child(main)
	await process_frame
	main.main_menu_open = false
	main.save_menu_panel.close()
	main._hide_game_interface()
	main.name_prompt_label.visible = false
	main.name_input.visible = false
	main.name_confirm_button.visible = false
	main._set_controls_visible(main.creation_controls, false)
	var layout_only := OS.get_cmdline_user_args().has("--layout-only")
	for viewport_size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = viewport_size
		await process_frame
		for locale in ["ru", "en"]:
			Loc.set_locale(locale)
			main._apply_locale()
			main.state = _state()
			main.action_history.clear()
			main._show_base("", "none")
			await _save(main, "%s-camp-before-tail" % locale)
			main.state.record_enemy_defeat("minotaur")
			main.state.camp_upgrades.kettle = true
			main.state.camp_upgrades.bunk = true
			main.state.safe_return()
			main.state.select_kettle_preparation(true)
			await _save(main, "%s-camp-tail-offer" % locale)
			main.state.build_camp_upgrade("mural")
			await _save(main, "%s-camp-built" % locale)
			main._open_inventory_service("crusher")
			_select_inventory_item(main, "expedition_backpack@0")
			await _save(main, "%s-crusher-backpack" % locale)
			_select_inventory_item(main, "rusty_sabre@0")
			main._on_inventory_dismantle_pressed()
			await _save(main, "%s-crusher-keep-confirm" % locale)
			main._show_base("", "none")
			main._show_character()
			main._select_character_panel("inventory")
			for page in range(ceili(main.inventory_panel.entries.size() / float(main.inventory_panel.PAGE_SIZE))):
				main.inventory_panel.page = page
				main.inventory_panel.refresh()
				main.inventory_panel.select_visible_index(0)
				await _save(main, "%s-inventory-page-%d" % [locale, page + 1])
		if not layout_only:
			Loc.set_locale("ru")
			main._apply_locale()
			main.state = _state()
			main.action_history.clear()
			main._show_base("", "none")
			main._begin_expedition_at(85)
			main.player_pos = Vector2i(10, 8)
			main.floor_data = _floor()
			main.inspected_target = {"kind": "enemy", "uid": "preview-bone_crossbowman", "pos": Vector2i(14, 8)}
			for cell_size in [44, 66, 88]:
				main.set_dungeon_cell_size(cell_size)
				await _save(main, "world-%d-visible" % cell_size)
				main.floor_data.visible_cells.erase(Vector2i(14, 8))
				await _save(main, "world-%d-hidden-shooter" % cell_size)
				main.floor_data.visible_cells[Vector2i(14, 8)] = true
	var manifest := FileAccess.open(OUT + "manifest.json", FileAccess.WRITE)
	var source_hashes := {}
	for path in ["scripts/main.gd", "scripts/ui/game_renderer.gd", "scripts/localization/localization.gd", "scripts/ui/inventory_panel.gd", "tests/capture_content_stage1.gd", "docs/stage1-asset-manifest.json"]:
		source_hashes[path] = FileAccess.get_sha256("res://" + path)
	manifest.store_string(JSON.stringify({"layout_only": layout_only, "captures": captured, "source_hashes": source_hashes}, "\t"))
	main.queue_free()
	await process_frame
	print("STAGE1 PREVIEWS CAPTURED: %d" % captured.size())
	quit(0)


func _select_inventory_item(main, key: String) -> void:
	for i in range(main.inventory_panel.entries.size()):
		if main.inventory_panel.entries[i].key == key:
			main.inventory_panel.page = i / main.inventory_panel.PAGE_SIZE
			main.inventory_panel.select_visible_index(i % main.inventory_panel.PAGE_SIZE)
			main.inventory_panel.row_buttons[i % main.inventory_panel.PAGE_SIZE].call_deferred("grab_focus")
			return


func _state() -> RunState:
	var state := RunState.new()
	state.configure_character("Путник / Wanderer", GameRules.default_attributes())
	state.current_form_id = "almost_human"
	state.highest_unlocked_form_index = 4
	state.soul_level = 8
	state.skill_levels.stomach = 1
	state.skill_levels.magic_awakening = 1
	state.resources = {"wood": 120, "stone": 120, "cloth": 120}
	state.banked_souls = 120
	state.food = 3
	for id in ["crusher", "whetstone", "ritual_table", "campfire"]:
		state.camp_upgrades[id] = true
	for id in ITEM_IDS:
		state.add_item(id)
	state.equip("expedition_backpack", "back")
	state.set_item_mark("rusty_sabre@0", "keep")
	state.set_item_mark("short_crossbow@0", "salvage")
	state.hp = state.get_max_hp()
	state.mana = state.get_max_mana()
	return state


func _floor() -> Dictionary:
	var data: Dictionary = FloorGenerator.new().generate(85, 12345, 0.0)
	data.width = 24
	data.height = 18
	data.tiles = {}
	data.visible_cells = {}
	data.observed_cells = {}
	data.explored_cells = {}
	for y in range(18):
		for x in range(24):
			var cell := Vector2i(x, y)
			data.tiles[cell] = "wall" if x == 0 or y == 0 or x == 23 or y == 17 else "floor"
			data.observed_cells[cell] = true
			data.explored_cells[cell] = true
			if x >= 4 and x <= 17 and y >= 3 and y <= 13:
				data.visible_cells[cell] = true
	data.start = Vector2i(10, 8)
	data.exit = Vector2i(20, 15)
	data.base_gate = Vector2i(3, 15)
	data.cradle = Vector2i(-1, -1)
	data.rooms = []
	data.enemies = []
	var ids := ["blind_scavenger", "arachnid", "bone_crossbowman", "slag_smith", "grave_rat"]
	var positions := [Vector2i(7, 6), Vector2i(12, 5), Vector2i(14, 8), Vector2i(10, 9), Vector2i(7, 9)]
	for i in range(ids.size()):
		var enemy: Dictionary = GameRules.ENEMIES[ids[i]].duplicate(true)
		enemy.id = ids[i]
		enemy.uid = "preview-" + ids[i]
		enemy.pos = positions[i]
		enemy.hp = enemy.max_hp
		if ids[i] in ["bone_crossbowman", "slag_smith"]:
			enemy.preparation = {"remaining": int(enemy.preparation_turns), "target": Vector2i(10, 8)}
		data.enemies.append(enemy)
	data.items = [{"pos": Vector2i(8, 5), "item_id": "bone_knife", "opened": false, "appearance": "crypt"}]
	data.decorations = {}
	for y in range(9, 12):
		for x in range(12, 16):
			data.decorations[Vector2i(x, y)] = {"kind": "mosaic", "variant": (x + y) % 3, "patch": 0}
	data.decorations[Vector2i(6, 8)] = {"kind": "cocoon", "variant": 0}
	data.decorations[Vector2i(12, 7)] = {"kind": "cocoon", "variant": 1}
	return data


func _save(main, kind: String) -> void:
	main._refresh_interface()
	main.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := OUT + "%dx%d-%s.png" % [root.size.x, root.size.y, kind]
	var image := root.get_texture().get_image()
	if image.is_empty() or image.save_png(path) != OK:
		push_error("Failed stage1 preview: " + path)
		quit(1)
		return
	captured.append(path)
	print(path)
