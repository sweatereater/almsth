class_name VisualOverhaulTestSuite
extends RefCounted

const Rules := preload("res://scripts/game/game_rules.gd")
const Loc := preload("res://scripts/localization/localization.gd")
const Renderer := preload("res://scripts/ui/game_renderer.gd")
const CharacterSheetLayout := preload("res://scripts/ui/character_sheet_layout.gd")

const WORLD_ASSETS := [
	"res://assets/dungeon/enemy-blind-scavenger.png",
	"res://assets/dungeon/enemy-arachnid.png",
	"res://assets/dungeon/enemy-bone-crossbowman.png",
	"res://assets/dungeon/enemy-slag-smith.png",
	"res://assets/dungeon/player-skeleton.png",
	"res://assets/dungeon/player-zombie.png",
	"res://assets/dungeon/player-ghoul.png",
	"res://assets/dungeon/player-revenant.png",
	"res://assets/dungeon/player-almost-human.png",
	"res://assets/dungeon/enemy-grave-rat.png",
]
const PORTRAIT_ASSETS := [
	"res://assets/portraits/form-skeleton.png",
	"res://assets/portraits/form-zombie.png",
	"res://assets/portraits/form-ghoul.png",
	"res://assets/portraits/form-revenant.png",
	"res://assets/portraits/form-almost-human.png",
]
const ICON_ASSETS := [
	"res://assets/items/item-rusty-sabre.png",
	"res://assets/items/item-short-crossbow.png",
	"res://assets/items/item-bone-buckler.png",
	"res://assets/items/item-gravediggers-lamp.png",
	"res://assets/items/item-watchmans-cap.png",
	"res://assets/items/item-archivists-mask.png",
	"res://assets/items/item-wanderers-gambeson.png",
	"res://assets/items/item-lamellar-vest.png",
	"res://assets/items/item-scouts-trousers.png",
	"res://assets/items/item-heavy-leg-wraps.png",
	"res://assets/items/item-pilgrims-boots.png",
	"res://assets/items/item-aiming-ring.png",
	"res://assets/items/item-thickblood-ring.png",
	"res://assets/items/item-expedition-backpack.png",
	"res://assets/items/item-bone-knife.png",
	"res://assets/items/item-grave-mace.png",
	"res://assets/items/item-bone-bow.png",
	"res://assets/items/item-old-claymore.png",
	"res://assets/items/item-soul-locket.png",
	"res://assets/items/item-rotting-mail.png",
	"res://assets/items/item-leather-gloves.png",
	"res://assets/items/item-hollow-lantern.png",
	"res://assets/items/item-pilgrim-shield.png",
	"res://assets/items/item-unexpectedly-comfortable-jacket.png",
]
const CHARACTER_FULLBODY_ASSETS := [
	"res://assets/ui/character-fullbody/form-skeleton.png",
	"res://assets/ui/character-fullbody/form-zombie.png",
	"res://assets/ui/character-fullbody/form-ghoul.png",
	"res://assets/ui/character-fullbody/form-revenant.png",
	"res://assets/ui/character-fullbody/form-almost-human.png",
]
const CHARACTER_FULLBODY_HASHES := {
	"res://assets/ui/character-fullbody/form-skeleton.png": "b1e8f3622eacc7b2fbce6b8a4410728005e964a6c0bd83968f217c0834e72fbb",
	"res://assets/ui/character-fullbody/form-zombie.png": "b528022b22cdcd1fe2c09ff491aedb08d0f6184f6521fa9e84902ff62520580f",
	"res://assets/ui/character-fullbody/form-ghoul.png": "1fb4c3e2015b125192ae8df29ffc09003825cb8f0a723205098d5e2160585e6f",
	"res://assets/ui/character-fullbody/form-revenant.png": "f73e0b91a4a48381b43097979e72aa52baf7e4f368d359beecc2d76e9128cf14",
	"res://assets/ui/character-fullbody/form-almost-human.png": "c41ec12f65f464baa990c1dd6b2fb80885bc5b2c2ab29d0b266963acbea155d4",
}
const CHARACTER_LINEUP_PATH := "res://art/concepts/character_fullbody/final/character_fullbody_set_01.png"
const CHARACTER_LINEUP_SHA256 := "953e27c097d4805026f7236ed025dc5fbd48786f35fb2748b85163be1f65732f"
const APPROVED_REFERENCE_HASHES := {
	"res://art/concepts/character_faces/final/01_skeleton.png": "e3c59dd920f436fe5f8f661ee5647acadd41fdd3a9409ca4f506f5edeae0b94c",
	"res://art/concepts/character_faces/final/02_zombie.png": "67910cc29db1b0aea6c9cbfa2484218c78c91751ae8130b39357ab490c6033bd",
	"res://art/concepts/character_faces/final/03_ghoul.png": "5eefddbcddf366fd8251ccba88bab2f9d242ecf6170df217d28ad22787ced45b",
	"res://art/concepts/character_faces/final/04_revenant.png": "fe44e5deff607c32fe846c1ebfddbc9e85e30ed337cdd902cee988246515ceea",
	"res://art/concepts/character_faces/final/05_almost_human.png": "707d7711c3ecfcaa10ad7b9112617dad6f5731c17b2d6625d2134f4c81977e70",
	"res://art/concepts/character_fullbody/final/character_progression_lineup_v2_ghoul_eye.png": "953e27c097d4805026f7236ed025dc5fbd48786f35fb2748b85163be1f65732f",
	"res://art/concepts/character_fullbody/body_lineup_approved_clothing.png": "240944dfd6b6d5ff10f15e6d6513c3df5c212668625234dcbff8ff36961fafd2",
}

var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	failures.clear()
	_test_slot_registry()
	_test_character_layout_contract()
	_test_legacy_migration()
	_test_asset_contracts()
	_test_renderer_contracts()
	await _test_hit_feedback_and_character_slots(tree)
	return failures


func _test_slot_registry() -> void:
	var expected_slots: Array[String] = [
		"head", "body", "hands", "legs", "feet", "ring_1",
		"jacket", "talisman", "back", "right_hand", "left_hand", "ring_2",
	]
	_expect(Rules.EQUIPMENT_SLOT_ORDER == expected_slots, "Equipment registry must expose the exact ordered 12 physical slots")
	var expected_by_form := {
		"skeleton": ["jacket", "right_hand", "left_hand", "talisman"],
		"zombie": ["jacket", "right_hand", "left_hand", "feet", "head", "talisman"],
		"ghoul": ["jacket", "right_hand", "left_hand", "feet", "body", "legs", "hands", "head", "talisman"],
		"revenant": ["jacket", "right_hand", "left_hand", "feet", "body", "legs", "hands", "head", "talisman", "back"],
		"almost_human": expected_slots,
	}
	for form_id in Rules.FORM_ORDER:
		var unlocked: Array[String] = []
		for slot_id in expected_slots:
			if Rules.is_slot_unlocked(form_id, slot_id):
				unlocked.append(slot_id)
		var expected: Array = expected_by_form[form_id]
		expected.sort_custom(func(a, b): return expected_slots.find(a) < expected_slots.find(b))
		_expect(unlocked == expected, "%s must unlock its exact equipment-slot set" % form_id)
	for slot_id in expected_slots:
		var rules: Dictionary = Rules.EQUIPMENT_SLOTS.get(slot_id, {})
		_expect(
			not rules.is_empty()
			and not String(rules.get("name", "")).is_empty()
			and not String(rules.get("category", "")).is_empty()
			and rules.get("allowed_tags", []).size() > 0
			and rules.get("portrait_position", null) is Vector2,
			"Physical slot %s must centralize localization, category, tags and portrait position" % slot_id,
		)
	var portrait_rect := CharacterSheetLayout.FIGURE_RECT
	var slot_rects: Array[Rect2] = []
	for slot_id in expected_slots:
		var rect := CharacterSheetLayout.slot_rect(slot_id)
		_expect(not rect.intersects(portrait_rect), "Character slot %s must not overlap the portrait" % slot_id)
		for other in slot_rects:
			_expect(not rect.intersects(other), "Character equipment slots must not overlap each other")
		slot_rects.append(rect)
	_expect(Rules.compatible_slots("bone_bow") == ["right_hand"], "Weapon category and physical right-hand slot must remain separate")
	_expect(Rules.compatible_slots("pilgrim_shield") == ["left_hand"], "Offhand category must resolve to the physical left hand")
	var ring_slots: Array[String] = ["ring_1", "ring_2"]
	_expect(
		Rules.resolve_physical_slot(ring_slots, "almost_human", {}).get("slot", "") == "ring_1",
		"A dual-slot ring must choose the first empty physical ring slot",
	)


func _test_character_layout_contract() -> void:
	_expect(CharacterSheetLayout.NAME_FORM_RECT == Rect2(20, 14, 365, 34), "Character name/form rect must match the approved canvas")
	_expect(CharacterSheetLayout.SOULS_RECT == Rect2(20, 49, 365, 24), "Character souls rect must match the approved canvas")
	_expect(CharacterSheetLayout.STATS_CARD_RECT == Rect2(16, 76, 276, 570), "Character stats card rect must match the approved canvas")
	_expect(CharacterSheetLayout.FIGURE_CARD_RECT == Rect2(307, 76, 368, 570), "Character figure card rect must match the approved canvas")
	_expect(CharacterSheetLayout.INVENTORY_CARD_RECT == Rect2(691, 76, 573, 570), "Character inventory card rect must match the approved canvas")
	_expect(CharacterSheetLayout.SKILLS_CARD_RECT == Rect2(16, 76, 1248, 570), "Character Skills card must use the full content width")
	_expect(CharacterSheetLayout.FIGURE_SOURCE_RECT == Rect2(7, 8, 250, 692), "All forms must share the approved safe source crop")
	_expect(CharacterSheetLayout.FIGURE_RECT == Rect2(402, 122, 178, 493), "Character full-body figure rect must use the approved +12% presentation")
	_expect(CharacterSheetLayout.FIGURE_RECT.get_center().x == 491.0 and CharacterSheetLayout.FIGURE_BASELINE_Y == 612.0, "Character crop must preserve the centered shared foot anchor")
	var old_scale := 448.0 / 704.0
	var new_scale_y := CharacterSheetLayout.FIGURE_RECT.size.y / CharacterSheetLayout.FIGURE_SOURCE_RECT.size.y
	var new_scale_x := CharacterSheetLayout.FIGURE_RECT.size.x / CharacterSheetLayout.FIGURE_SOURCE_RECT.size.x
	_expect(absf(new_scale_x - new_scale_y) < 0.001 and absf(new_scale_y / old_scale - 1.1195) < 0.0001, "Shared source crop must enlarge every form by approximately 12% at one scale")
	var expected_rects := {
		"head": Rect2(323, 96, 64, 64), "body": Rect2(323, 190, 64, 64),
		"hands": Rect2(323, 284, 64, 64), "legs": Rect2(323, 378, 64, 64),
		"feet": Rect2(323, 472, 64, 64), "ring_1": Rect2(323, 566, 64, 64),
		"jacket": Rect2(595, 96, 64, 64), "talisman": Rect2(595, 190, 64, 64),
		"back": Rect2(595, 284, 64, 64), "right_hand": Rect2(595, 378, 64, 64),
		"left_hand": Rect2(595, 472, 64, 64), "ring_2": Rect2(595, 566, 64, 64),
	}
	var slots: Array[Rect2] = []
	for slot_id in Rules.EQUIPMENT_SLOT_ORDER:
		var slot_rect := CharacterSheetLayout.slot_rect(slot_id)
		_expect(slot_rect == expected_rects[slot_id], "Character slot %s must use its exact two-column rect" % slot_id)
		_expect(Rules.EQUIPMENT_SLOTS[slot_id]["portrait_position"] == slot_rect.position, "Registry portrait position must match layout for %s" % slot_id)
		_expect(slot_rect.size == Vector2(64, 64), "Character slot %s must remain exactly 64x64" % slot_id)
		_expect(CharacterSheetLayout.FIGURE_CARD_RECT.encloses(slot_rect), "Character slot %s must stay inside the central card" % slot_id)
		_expect(not slot_rect.intersects(CharacterSheetLayout.FIGURE_RECT), "Character slot %s must not cover the full-body figure" % slot_id)
		var scaled_slot := Rect2(slot_rect.position * 0.75, slot_rect.size * 0.75)
		var scaled_figure := Rect2(CharacterSheetLayout.FIGURE_RECT.position * 0.75, CharacterSheetLayout.FIGURE_RECT.size * 0.75)
		_expect(not scaled_slot.intersects(scaled_figure), "Scaled 960x540 slot %s must not cover the figure" % slot_id)
		for other in slots:
			_expect(not slot_rect.intersects(other), "Character slot rects must remain unique and non-overlapping")
		slots.append(slot_rect)
	_expect(slots.size() == 12, "Character Inventory must expose exactly 12 physical slot rects")
	var left_column := ["head", "body", "hands", "legs", "feet", "ring_1"]
	var right_column := ["jacket", "talisman", "back", "right_hand", "left_hand", "ring_2"]
	for row in range(6):
		var left_rect: Rect2 = CharacterSheetLayout.slot_rect(left_column[row])
		var right_rect: Rect2 = CharacterSheetLayout.slot_rect(right_column[row])
		_expect(left_rect.position == Vector2(323, 96 + row * 94) and right_rect.position == Vector2(595, 96 + row * 94), "Equipment row %d must use exact paired positions" % row)
		if row < 5:
			_expect(CharacterSheetLayout.slot_rect(left_column[row + 1]).position.y - left_rect.end.y == 30.0, "Left slot rows must retain a 30 px gap")
			_expect(CharacterSheetLayout.slot_rect(right_column[row + 1]).position.y - right_rect.end.y == 30.0, "Right slot rows must retain a 30 px gap")
	var ring_1 := CharacterSheetLayout.slot_rect("ring_1")
	var ring_2 := CharacterSheetLayout.slot_rect("ring_2")
	_expect(ring_1.get_center().y == ring_2.get_center().y and is_equal_approx((ring_1.get_center().x + ring_2.get_center().x) * 0.5, 491.0), "Ring slots must be symmetric around x=491 at the same y")
	for stats_rect in [CharacterSheetLayout.SOUL_FORM_RECT, CharacterSheetLayout.PRIMARY_ATTRIBUTES_RECT, CharacterSheetLayout.FREE_STATS_RECT, CharacterSheetLayout.STATUS_STRIP_RECT, CharacterSheetLayout.DERIVED_STATS_RECT, CharacterSheetLayout.CHEAT_BUTTON_RECT]:
		_expect(CharacterSheetLayout.STATS_CARD_RECT.encloses(stats_rect), "Every stats/status/cheat rect must fit inside the left card")
	var ring_slots: Array[String] = ["ring_1", "ring_2"]
	_expect(
		Rules.resolve_physical_slot(ring_slots, "almost_human", {"ring_1": "occupied"}).get("slot", "") == "ring_2",
		"A dual-slot ring must choose the second empty physical ring slot",
	)
	_expect(
		Rules.resolve_physical_slot(
			ring_slots, "almost_human", {"ring_1": "occupied", "ring_2": "occupied"}, "ring_2",
		).get("slot", "") == "ring_2",
		"An explicit dual-slot destination must replace exactly the selected ring",
	)
	_expect(
		Rules.resolve_physical_slot(
			ring_slots, "almost_human", {"ring_1": "occupied", "ring_2": "occupied"},
		).get("reason", "") == "slot_choice_required",
		"Two occupied compatible slots must require an explicit destination",
	)


func _test_legacy_migration() -> void:
	var legacy := RunState.new()
	_expect(legacy.restore_save_data({
		"character_name": "Legacy slots",
		"absorbed_souls": 80,
		"loadout": {
			"weapon": "bone_bow@2", "offhand": "pilgrim_shield@0",
			"charm": "soul_locket@0", "armor": "rotting_mail@0",
			"mutation": "iron_claws@0", "relic": "hollow_lantern@0",
			"corrupt_slot": "grave_mace@0",
		},
	}), "Legacy equipment fixture must restore")
	_expect(
		legacy.loadout.get("right_hand", "") == "bone_bow@2"
		and not legacy.loadout.has("left_hand")
		and legacy.loadout.get("talisman", "") == "soul_locket@0"
		and legacy.loadout.get("body", "") == "rotting_mail@0"
		and Rules.base_item_id(String(legacy.loadout.get("hands", ""))) == "leather_gloves",
		"Legacy physical slots must migrate without admitting an impossible two-handed loadout",
	)
	_expect(
		legacy.inventory.get("pilgrim_shield@0", 0) == 1
		and legacy.inventory.get("hollow_lantern@0", 0) == 1
		and legacy.inventory.get("grave_mace@0", 0) == 1,
		"Two-handed offhand, relic conflicts and corrupt slot IDs must return valid items to inventory",
	)
	var locked := RunState.new()
	_expect(locked.restore_save_data({
		"character_name": "Locked slot", "absorbed_souls": 0,
		"loadout": {"armor": "rotting_mail@0"},
	}), "Locked-slot migration fixture must restore")
	_expect(
		locked.loadout.size() == 1
		and locked.loadout.get("jacket", "") == Rules.permanent_jacket_key()
		and locked.inventory.get("rotting_mail@0", 0) == 1,
		"Valid gear in a form-locked slot must move to inventory without loss",
	)


func _test_asset_contracts() -> void:
	for path in WORLD_ASSETS:
		_test_rgba_asset(path, Vector2i(264, 264), 4)
	for path in PORTRAIT_ASSETS:
		_test_rgba_asset(path, Vector2i(264, 264), 4)
	for path in ICON_ASSETS:
		_test_rgba_asset(path, Vector2i(132, 132), 4)
	for path in CHARACTER_FULLBODY_ASSETS:
		_test_character_fullbody_asset(path)
		_expect(FileAccess.get_sha256(path) == CHARACTER_FULLBODY_HASHES[path], "Character full-body runtime PNG must remain byte-for-byte unchanged: %s" % path)
	for item_id in Rules.EQUIPMENT:
		var icon_path := String(Rules.EQUIPMENT[item_id].get("icon", ""))
		_expect(ICON_ASSETS.has(icon_path), "Existing item %s must map to its own runtime icon" % item_id)
	var rat_texture := load("res://assets/dungeon/enemy-grave-rat.png") as Texture2D
	if rat_texture != null:
		var rat := rat_texture.get_image()
		var rat_bounds := rat.get_used_rect()
		_expect(rat_bounds.size.x > rat_bounds.size.y, "Grave Rat must use a readable side-profile silhouette")
	for reference_path in APPROVED_REFERENCE_HASHES:
		_expect(
			FileAccess.get_sha256(reference_path) == APPROVED_REFERENCE_HASHES[reference_path],
			"Approved master reference must remain byte-for-byte unchanged: %s" % reference_path,
		)
	_expect(
		FileAccess.get_sha256(CHARACTER_LINEUP_PATH) == CHARACTER_LINEUP_SHA256,
		"Approved five-form full-body lineup must remain byte-for-byte unchanged",
	)


func _test_character_fullbody_asset(path: String) -> void:
	_test_rgba_asset(path, Vector2i(264, 704), 8)
	var texture := load(path) as Texture2D
	if texture == null:
		return
	var image := texture.get_image()
	var used := image.get_used_rect()
	var source := Rect2i(
		Vector2i(int(CharacterSheetLayout.FIGURE_SOURCE_RECT.position.x), int(CharacterSheetLayout.FIGURE_SOURCE_RECT.position.y)),
		Vector2i(int(CharacterSheetLayout.FIGURE_SOURCE_RECT.size.x), int(CharacterSheetLayout.FIGURE_SOURCE_RECT.size.y)),
	)
	_expect(
		source.encloses(used)
		and used.position.x - source.position.x >= 4
		and used.position.y - source.position.y >= 4
		and source.end.x - used.end.x >= 4
		and source.end.y - used.end.y >= 4,
		"Shared source crop must preserve at least four transparent pixels around %s" % path,
	)
	var mapped_alpha_bottom := (
		CharacterSheetLayout.FIGURE_RECT.position.y
		+ float(used.end.y - source.position.y)
		* CharacterSheetLayout.FIGURE_RECT.size.y / CharacterSheetLayout.FIGURE_SOURCE_RECT.size.y
	)
	_expect(absf(mapped_alpha_bottom - CharacterSheetLayout.FIGURE_BASELINE_Y) <= 1.0, "Every form must retain the same visible foot anchor at the Character baseline: %s" % path)
	_expect(used.size.x >= 224 and used.size.x <= 248, "Full-body cutout width must follow the approved runtime contract: %s" % path)
	_expect(used.size.y >= 676 and used.size.y <= 688, "Full-body cutout height must follow the approved runtime contract: %s" % path)
	_expect(used.position.x >= 8 and used.end.x <= 256, "Full-body cutout must keep eight transparent horizontal pixels: %s" % path)
	_expect(used.position.y >= 8 and used.end.y <= 696, "Full-body cutout must use the common lower anchor without touching an edge: %s" % path)
	var import_text := FileAccess.get_file_as_string(path + ".import")
	_expect(import_text.contains("compress/mode=0"), "Character UI cutout import must remain lossless: %s" % path)
	_expect(import_text.contains("mipmaps/generate=false"), "Character UI cutout must not use mipmaps: %s" % path)
	_expect(import_text.contains("process/fix_alpha_border=true"), "Character UI cutout must use alpha border correction: %s" % path)


func _test_rgba_asset(path: String, expected_size: Vector2i, minimum_border: int) -> void:
	var texture := load(path) as Texture2D
	_expect(texture != null, "Runtime asset must load: %s" % path)
	if texture == null:
		return
	var image := texture.get_image()
	_expect(image.get_size() == expected_size, "Runtime asset must use its exact dimensions: %s" % path)
	_expect(image.get_format() == Image.FORMAT_RGBA8, "Runtime asset must be RGBA8: %s" % path)
	var used := image.get_used_rect()
	_expect(used.has_area(), "Runtime asset must contain visible pixels: %s" % path)
	_expect(
		used.position.x >= minimum_border and used.position.y >= minimum_border
		and used.end.x <= expected_size.x - minimum_border
		and used.end.y <= expected_size.y - minimum_border,
		"Runtime asset must preserve transparent edge padding: %s" % path,
	)
	_expect(
		image.get_pixel(0, 0).a == 0.0
		and image.get_pixel(expected_size.x - 1, expected_size.y - 1).a == 0.0,
		"Runtime asset corners must stay transparent: %s" % path,
	)
	_expect(FileAccess.file_exists(path + ".import"), "Runtime asset must have Godot import metadata: %s" % path)


func _test_renderer_contracts() -> void:
	_expect(Renderer.PLAYER_FOOT_GLOW_FOOTPRINT == Vector2(0.46, 0.16), "Player marker must be a small foot glow")
	_expect(Renderer.PLAYER_FOOT_GLOW_ALPHA <= 0.18, "Player foot glow must remain visually quiet")
	_expect(Renderer.SELECTION_BORDER_WIDTH >= 1.0 and Renderer.SELECTION_BORDER_WIDTH <= 2.0, "Selection border must remain 1-2 physical pixels")
	_expect(Renderer.DUNGEON_ENEMY_HP_RECT.size.y <= 8.0, "Enemy HP must use only the compact right-inspection gauge")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/ui/game_renderer.gd")
	_expect(not renderer_source.contains("_draw_health_bar"), "World renderer must contain no permanent entity HP-bar draw path")
	_expect(renderer_source.contains("draw_texture_rect_region") and renderer_source.contains("CharacterSheetLayout.FIGURE_SOURCE_RECT"), "Character-sheet renderer must use the one shared clipped source region")
	_expect(
		not Loc.STRINGS["ru"].has("BASE_SUBTITLE")
		and not Loc.STRINGS["en"].has("BASE_SUBTITLE")
		and not renderer_source.contains("BASE_SUBTITLE")
		and not renderer_source.contains("caption_rect"),
		"Base rendering must contain neither the obsolete subtitle nor its decorative overlay band",
	)


func _test_hit_feedback_and_character_slots(tree: SceneTree) -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	tree.root.add_child(main)
	await tree.process_frame
	main.state.configure_character("Visual", Rules.default_attributes())
	main.screen = main.Screen.DUNGEON
	main.player_pos = Vector2i(2, 2)
	main.floor_data = {
		"width": 5, "height": 5, "tiles": {Vector2i(2, 2): "floor", Vector2i(3, 2): "floor"},
		"enemies": [{
			"uid": "flash-rat", "id": "grave_rat", "pos": Vector2i(3, 2),
			"hp": 2, "max_hp": 2, "damage": 1, "accuracy": 1, "dodge": 0,
			"vision": 4, "souls": 1,
		}],
		"items": [], "start": Vector2i(2, 2), "exit": Vector2i(4, 4),
		"base_gate": Vector2i(-1, -1), "cradle": Vector2i(-1, -1),
		"visible_cells": {Vector2i(2, 2): true, Vector2i(3, 2): true},
		"explored_cells": {Vector2i(2, 2): true, Vector2i(3, 2): true},
		"observed_cells": {Vector2i(2, 2): true, Vector2i(3, 2): true},
	}
	var first_hit: Dictionary = main._damage_enemy_by_uid("flash-rat", 1)
	_expect(not first_hit.get("killed", true) and is_equal_approx(float(main.enemy_hit_flashes.get("flash-rat", 0.0)), main.HIT_FLASH_DURATION), "A real hit must start one deterministic enemy flash")
	main._update_hit_effects(0.10)
	_expect(float(main.enemy_hit_flashes.get("flash-rat", 0.0)) < main.HIT_FLASH_DURATION, "Hit flash must fade without blocking a turn")
	main._damage_enemy_by_uid("flash-rat", 0)
	_expect(float(main.enemy_hit_flashes.get("flash-rat", 0.0)) < main.HIT_FLASH_DURATION, "Zero damage/rejected attacks must not restart hit flash")
	var souls_before: int = main.state.get_total_souls()
	var lethal: Dictionary = main._damage_enemy_by_uid("flash-rat", 1)
	var souls_after: int = main.state.get_total_souls()
	_expect(
		lethal.get("killed", false) and main.floor_data["enemies"].is_empty()
		and main.lethal_hit_afterimages.size() == 1 and souls_after > souls_before,
		"Lethal hit must create one ephemeral afterimage after logical removal",
	)
	main._damage_enemy_by_uid("flash-rat", 1)
	_expect(main.state.get_total_souls() == souls_after and main.lethal_hit_afterimages.size() == 1, "Lethal feedback must never duplicate rewards")
	main._update_hit_effects(main.LETHAL_AFTERIMAGE_DURATION + 0.01)
	_expect(main.lethal_hit_afterimages.is_empty(), "Lethal afterimage expiry must be deterministic")
	main.state.current_form_id = "skeleton"
	main.state.loadout = {"jacket": Rules.permanent_jacket_key(), "right_hand": "bone_knife@0"}
	main.state.add_or_refresh_status("rested", 500, 5)
	main._show_character()
	main._select_character_panel("inventory")
	main._refresh_character_sheet()
	_expect(
		main.character_soul_level_label.text.contains("\n")
		and Rect2(main.character_soul_level_label.position, main.character_soul_level_label.size)
		== Rect2(28, 88, 252, 48),
		"Soul Level, actual form and appearance must use the dedicated Inventory stats area",
	)
	_expect(
		main.character_equipment_buttons["jacket"].icon != null
		and main.character_equipment_glyphs["jacket"].visible
		and main.character_equipment_glyphs["jacket"].permanent
		and main.character_equipment_buttons["jacket"].tooltip_text.contains(Loc.text("INVENTORY_PERMANENT_LOCKED"))
		and main.character_equipment_buttons["jacket"].accessibility_name == main.character_equipment_buttons["jacket"].tooltip_text,
		"Permanent jacket slot must stay visibly occupied with calm lock treatment",
	)
	_expect(main.character_status_strip.visible and main.character_status_strip.get_child_count() == 1, "Inventory must show the same Rested status source in its reserved strip")
	_expect(
		main.character_equipment_buttons["right_hand"].icon != null
		and main.character_equipment_buttons["right_hand"].text.is_empty(),
		"Occupied Character slot must render only the real item icon",
	)
	_expect(
		main.character_equipment_buttons["body"].icon == null
		and main.character_equipment_glyphs["body"].visible
		and main.character_equipment_glyphs["body"].locked,
		"Locked Character slot must render a calm dim category/lock treatment",
	)
	var left_column := ["head", "body", "hands", "legs", "feet", "ring_1"]
	var right_column := ["jacket", "talisman", "back", "right_hand", "left_hand", "ring_2"]
	for row in range(6):
		var left_button: Button = main.character_equipment_buttons[left_column[row]]
		var right_button: Button = main.character_equipment_buttons[right_column[row]]
		_expect(left_button.focus_neighbor_right == right_button.get_path(), "Focus right must cross equipment row %d" % row)
		_expect(right_button.focus_neighbor_left == left_button.get_path(), "Focus left must cross equipment row %d" % row)
		if row > 0:
			_expect(left_button.focus_neighbor_top == main.character_equipment_buttons[left_column[row - 1]].get_path(), "Focus up must remain in the left column at row %d" % row)
			_expect(right_button.focus_neighbor_top == main.character_equipment_buttons[right_column[row - 1]].get_path(), "Focus up must remain in the right column at row %d" % row)
		if row < 5:
			_expect(left_button.focus_neighbor_bottom == main.character_equipment_buttons[left_column[row + 1]].get_path(), "Focus down must remain in the left column at row %d" % row)
			_expect(right_button.focus_neighbor_bottom == main.character_equipment_buttons[right_column[row + 1]].get_path(), "Focus down must remain in the right column at row %d" % row)
	main._select_character_panel("skills")
	for slot_id in Rules.EQUIPMENT_SLOT_ORDER:
		_expect(not main.character_equipment_buttons[slot_id].visible, "Skills must hide Character slot %s" % slot_id)
	_expect(not main.inventory_panel.visible, "Skills must hide the Character inventory panel")
	_expect(not main.character_status_strip.visible, "Skills must hide the Character status strip")
	for slot_id in Rules.EQUIPMENT_SLOT_ORDER:
		var button: Button = main.character_equipment_buttons[slot_id]
		_expect(
			not button.focus_neighbor_left.is_empty()
			or not button.focus_neighbor_right.is_empty()
			or not button.focus_neighbor_top.is_empty()
			or not button.focus_neighbor_bottom.is_empty(),
			"Character equipment slot %s must participate in spatial focus navigation" % slot_id,
		)
	main.queue_free()
	await tree.process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
