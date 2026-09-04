extends RefCounted

const Rules := preload("res://scripts/game/game_rules.gd")
const State := preload("res://scripts/game/run_state.gd")
const Save := preload("res://scripts/system/persistence.gd")
var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func run(tree: SceneTree) -> Array[String]:
	failures.clear()
	_test_catalogue_names()
	_test_asset_contracts()
	_test_items_and_marks()
	_test_preparation()
	_test_milestones()
	_test_generation()
	await _test_enemy_preparation(tree)
	await _test_exact_preparation_resume(tree)
	await _test_inventory_camp_ui(tree)
	await _test_state_only_corruption(tree)
	return failures


func _test_catalogue_names() -> void:
	var loc = preload("res://scripts/localization/localization.gd")
	var previous: String = loc.current_locale
	loc.set_locale("en")
	check(loc.text("ENEMY_ARACHNID") == "Crypt Arachnid", "E03 English name preserves the approved catalogue")
	check(loc.text("CAMP_KETTLE") == "Expedition Kettle" and loc.text("CAMP_BUILT_KETTLE") == "Expedition Kettle built", "B02 English name preserves the approved catalogue")
	check(loc.text("CAMP_STORAGE_CHEST") == "Storage Chest", "B13 English name remains unchanged")
	check(loc.text("BIOME_WEAVING_CRYPTS") == "Weaver Catacombs", "Z01 English name preserves the approved catalogue")
	loc.set_locale("ru")
	check(
		loc.text("CAMP_STORAGE_CHEST") == "Сундук хранения"
		and loc.text("CAMP_BUILD_STORAGE_CHEST").begins_with("Сундук хранения:")
		and loc.text("CAMP_BUILT_STORAGE_CHEST") == "Сундук хранения построен"
		and loc.text("CAMP_OBJECT_STORAGE_CHEST").begins_with("Сундук хранения\n"),
		"B13 uses the exact canonical Russian name across catalogue and service text",
	)
	loc.set_locale(previous)


func _test_asset_contracts() -> void:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://docs/stage1-asset-manifest.json"))
	check(manifest is Array and manifest.size() == 28, "All28 final runtime assets have provenance")
	if not manifest is Array:
		return
	for asset in manifest:
		var path := "res://" + String(asset.path)
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		check(image != null and not image.is_empty(), "Runtime asset exists " + asset.id)
		if image == null or image.is_empty():
			continue
		check(image.get_size() == Vector2i(asset.runtime_size[0], asset.runtime_size[1]), "Canonical runtime size " + asset.id)
		check(FileAccess.get_sha256(path) == asset.runtime_sha256, "Runtime resource matches recorded source export " + asset.id)
		if asset.kind == "tile":
			check(image.detect_alpha() == Image.ALPHA_NONE and image.get_size() == Vector2i(264, 264), "Mosaic is opaque full-area264 tile")
			continue
		check(image.detect_alpha() != Image.ALPHA_NONE, "Cutout retains real transparency " + asset.id)
		var used := image.get_used_rect()
		var padding := 8 if asset.kind in ["icon", "decal"] else 4
		check(used.position.x >= padding and used.position.y >= padding and used.end.x <= image.get_width() - padding and used.end.y <= image.get_height() - padding, "Clear safe margins " + asset.id)
		check(absf(used.position.x + used.size.x / 2.0 - image.get_width() / 2.0) <= 0.5, "Horizontal cutout anchor " + asset.id)
		if asset.kind in ["world", "camp"]:
			check(used.end.y == image.get_height() - 4, "Four-pixel lower support margin " + asset.id)


func _state() -> RunState:
	var state := State.new()
	state.configure_character("Stage one", Rules.default_attributes())
	return state


func _test_items_and_marks() -> void:
	var state := _state()
	check(Rules.available_equipment_ids(95).has("rusty_sabre"), "Sabre enters at depth5")
	check(not Rules.available_equipment_ids(96).has("rusty_sabre"), "Sabre absent before depth5")
	check(bool(state.equip("gravediggers_lamp").ok), "Skeleton can hold lamp")
	check(state.get_vision_radius() == 5 and state.get_hearing_radius() == 0, "Lamp raises vision without granting Ears")
	check(not bool(state.equip("watchmans_cap").ok), "Skeleton cannot wear zombie cap")
	state.current_form_id = "almost_human"
	state.equip("thickblood_ring", "ring_1")
	state.equip("thickblood_ring", "ring_2")
	check(state.get_max_mana() == 0, "Mana clamps after two negative rings")
	state.skill_levels.magic_awakening = 2
	check(state.get_max_mana() == 5, "Mana clamps after skill bonuses, not before")
	state.camp_upgrades.crusher = true
	state.camp_upgrades.whetstone = true
	state.camp_upgrades.ritual_table = true
	state.resources = {"wood": 100, "stone": 100, "cloth": 100}
	state.banked_souls = 100
	var knife := state.add_item("bone_knife", 0, 2)
	state.set_item_mark(knife, "keep")
	state.add_item_key(knife)
	check(state.item_mark(knife) == "keep", "Keep wins merge with unmarked loot")
	check(state.dismantle_item(knife).get("reason") == "keep_confirmation", "Single Keep salvage requires confirmation")
	check(not state.dismantle_all_items().ok, "Bulk does not destroy Keep")
	state.equip_from_inventory(knife, "right_hand")
	check(state.item_mark(knife, "equipped", "right_hand") == "keep", "Mark follows equip")
	state.upgrade_weapon(knife, 0.0, 1.0, "right_hand")
	var upgraded := String(state.loadout.right_hand)
	state.bind_item(upgraded, "equipped", "right_hand")
	var bound := String(state.loadout.right_hand)
	state.unequip("right_hand")
	check(state.item_mark(bound) == "keep", "Mark follows upgrade, binding and unequip")
	var mace := state.add_item("grave_mace")
	state.set_item_mark(mace, "salvage")
	state.add_item_key(mace)
	check(state.item_mark(mace).is_empty(), "Marked plus unmarked merges conservatively")
	state.set_item_mark(mace, "salvage")
	var bulk := state.dismantle_all_items(true)
	check(bulk.ok and bulk.count == 2 and state.inventory.has(knife) and state.inventory.has(bound), "Marked-only bulk selects only intended stacks")
	state.die()
	check(state.inventory.has(bound) and state.item_mark(bound) == "keep" and not state.inventory.has(knife), "Marks persist for bound items but do not prevent death loss")


func _test_preparation() -> void:
	var state := _state()
	state.current_form_id = "revenant"
	state.skill_levels.stomach = 1
	state.skill_levels.nervous_system = 1
	state.equip("expedition_backpack", "back")
	state.camp_upgrades.campfire = true
	state.camp_upgrades.kettle = true
	state.camp_upgrades.bunk = true
	state.food = 2
	state.hp = 1
	state.hunger = 3
	state.begin_expedition()
	check(state.hp == 1 and state.hunger == 3 and state.active_statuses.is_empty(), "New departure neither heals nor grants unearned effects")
	state.safe_return()
	check(state.hp == state.get_max_hp() and state.hunger == 100 and state.active_statuses.is_empty(), "Return restores HP/satiety, defers timed effects")
	check(state.select_kettle_preparation(true) and state.food == 2, "Selecting kettle does not pay")
	state.select_kettle_preparation(false)
	check(state.food == 2, "Cancel kettle is free")
	state.select_kettle_preparation(true)
	state.hp -= 1
	var hp_before := state.hp
	check(state.begin_expedition(), "Prepared departure succeeds")
	check(state.hp == hp_before and state.food == 1, "Exit preserves HP and spends exactly one food")
	check(state.status_remaining("satiated") == 700 and state.status_remaining("rested") == 800, "Camp + backpack durations700/800")
	state.finish_completed_round()
	state.begin_expedition()
	check(state.food == 1 and state.status_remaining("satiated") == 699, "Repeated exit does not refresh or spend")
	state.add_item("expedition_backpack")
	state.equip_from_inventory("expedition_backpack@0", "back")
	check(state.status_remaining("satiated") == 499 and state.status_remaining("rested") == 599, "Replacing backpack removes200 once")
	state.unequip("back")
	state.equip_from_inventory("expedition_backpack@0", "back")
	check(state.status_remaining("satiated") == 499, "Re-equip does not restore or remove twice")
	state.die()
	check(not state.camp_preparation.pending and state.active_statuses.is_empty(), "Death clears preparation and timed effects")
	var late_stomach := _state()
	late_stomach.current_form_id = "ghoul"
	late_stomach.safe_return()
	late_stomach.skill_levels.stomach = 1
	late_stomach.begin_expedition()
	check(not late_stomach.has_status("satiated"), "Buying Stomach after a Ghoul return cannot invent preparation")


func _test_milestones() -> void:
	var state := _state()
	check(not state.is_camp_upgrade_revealed("mural"), "Mural hidden before tail")
	check(state.record_enemy_defeat("minotaur"), "First Minotaur victory awards trophy")
	check(not state.record_enemy_defeat("minotaur") and state.trophies.minotaur_tail == 1, "Repeated defeat cannot duplicate tail")
	state.die()
	check(state.milestones.minotaur_defeated and state.trophies.minotaur_tail == 1, "Tail/history survive death")
	state.resources = {"wood": 12, "stone": 20, "cloth": 5}
	state.banked_souls = 59
	state.carried_souls = 100
	check(not state.build_camp_upgrade("mural").ok and state.resources.wood == 12, "Mural cannot substitute carried souls or partly charge")
	state.banked_souls = 60
	state.lifetime_souls_earned = state.banked_souls + state.carried_souls
	var previous_level := state.soul_level
	check(state.build_camp_upgrade("mural").ok, "Mural builds with exact cost")
	check(state.banked_souls == 0 and state.resources.wood == 0 and state.trophies.minotaur_tail == 0 and state.soul_level == previous_level + 1, "Mural consumes exact materials/souls/tail, grants one level")
	check(not state.build_camp_upgrade("mural").ok and state.soul_level == previous_level + 1, "Mural cannot grant twice")
	var snapshot := state.to_snapshot_data()
	var restored := _state()
	check(restored.restore_snapshot_data(snapshot) and restored.to_snapshot_data() == snapshot, "New state fields round-trip exactly")
	check(not restored.record_enemy_defeat("minotaur"), "Reload preserves one-time reward history")


func _test_generation() -> void:
	var generator := FloorGenerator.new()
	var thematic_count := 0
	var general_count := 0
	for seed in range(30):
		var floor := generator.generate(85, seed, 0.2)
		check(floor == generator.generate(85, seed, 0.2), "Generation and decoration deterministic for seed%d" % seed)
		check(floor.biome == "weaving_crypts", "Weaving Crypts correctly assigned")
		var cocoons := 0
		var patches := {}
		for cell in floor.decorations:
			var decoration: Dictionary = floor.decorations[cell]
			check(floor.tiles[cell] == "floor", "Decorations are floor-only")
			if decoration.kind == "cocoon":
				cocoons += 1
			else:
				patches[decoration.patch] = int(patches.get(decoration.patch, 0)) + 1
		check(cocoons >= 2 and cocoons <= 4, "Biomes have2–4 cocoons")
		var skeletons: bool = floor.initial_enemy_kinds.has("skeletal_archer") or floor.initial_enemy_kinds.has("bone_crossbowman")
		check((patches.size() >= 1 and patches.size() <= 2) if skeletons else patches.is_empty(), "Mosaic follows initial skeletal population")
		for count in patches.values():
			check(count >= 8 and count <= 16, "Mosaic patches contain8–16 cells")
		var original_decor: Dictionary = floor.decorations.duplicate(true)
		for enemy in floor.enemies:
			if enemy.id == "arachnid":
				thematic_count += 1
			else:
				general_count += 1
		floor.enemies.clear()
		check(floor.decorations == original_decor, "Enemy deaths do not change floor art")
	check(float(thematic_count) / (thematic_count + general_count) > 0.50 and float(thematic_count) / (thematic_count + general_count) < 0.70, "Thematic sampling is near60 percent without doubling Arachnid weight")
	check(Rules.biome_id(89) == "weaving_crypts" and Rules.biome_id(80) == "weaving_crypts" and Rules.biome_id(90).is_empty() and Rules.biome_id(79).is_empty(), "Biome bounds89–80")
	for entry in [["blind_scavenger", 4], ["arachnid", 11], ["bone_crossbowman", 20], ["slag_smith", 15]]:
		check(Rules.enemy_pool(100 - entry[1]).has(entry[0]) and not Rules.enemy_pool(101 - entry[1]).has(entry[0]), "Enemy threshold " + entry[0])
	var arena := FixedFloor90.create()
	check(arena.enemies.size() == 1 and arena.enemies[0].id == "minotaur" and arena.items.size() == 2 and arena.biome.is_empty(), "Arena keeps exact population and reward count")


func _main(tree: SceneTree):
	var main = load("res://scenes/main.tscn").instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	tree.root.add_child(main)
	await tree.process_frame
	main.state = _state()
	main._show_base("")
	main._begin_expedition_at(80)
	main.state.attributes.vitality = 100
	main.state.hp = main.state.get_max_hp()
	main.player_pos = Vector2i(4, 4)
	var tiles := {}
	var visible := {}
	for y in range(10):
		for x in range(12):
			var cell := Vector2i(x, y)
			tiles[cell] = (
				"wall" if x == 0 or x == 11 or y == 0 or y == 9 else "floor"
			)
			visible[cell] = true
	tiles[Vector2i(1, 2)] = "wall"
	tiles[Vector2i(10, 7)] = "wall"
	main.floor_data = {
		"width": 12, "height": 10, "tiles": tiles, "enemies": [], "items": [],
		"rooms": [
			{
				"door": Vector2i(2, 1), "outward": Vector2i.RIGHT,
				"cells": {Vector2i(1, 1): true},
				"reserved": {Vector2i(1, 1): true, Vector2i(2, 1): true},
			},
			{
				"door": Vector2i(9, 8), "outward": Vector2i.LEFT,
				"cells": {Vector2i(10, 8): true},
				"reserved": {Vector2i(10, 8): true, Vector2i(9, 8): true},
			},
		],
		"start": Vector2i(2, 2), "exit": Vector2i(9, 7),
		"base_gate": Vector2i(1, 7), "cradle": Vector2i(-1, -1),
		"visible_cells": visible, "observed_cells": visible.duplicate(),
		"explored_cells": visible.duplicate(), "exit_known": false,
		"cradle_known": false, "cradle_used": false, "cradle_pity_resolved": false,
		"cradle_roll_chance": 0.0, "seed": 123,
	}
	# Synthetic combat fixture explicitly supplies the current-format records;
	# production restore never supplies missing decoration defaults for us.
	main.floor_data.merge({"biome": "", "initial_enemy_kinds": [], "decorations": {}})
	return main


func _enemy(id: String, position: Vector2i) -> Dictionary:
	var enemy: Dictionary = Rules.ENEMIES[id].duplicate(true)
	enemy.id = id
	enemy.uid = "test_" + id
	enemy.pos = position
	var depth := 20
	enemy.max_hp = int(enemy.max_hp) + FloorGenerator.enemy_stat_bonus_for_depth(
		depth, FloorGenerator.ENEMY_HP_DEPTH_INTERVAL,
	)
	enemy.hp = enemy.max_hp
	enemy.damage = int(enemy.damage) + FloorGenerator.enemy_stat_bonus_for_depth(
		depth, FloorGenerator.ENEMY_DAMAGE_DEPTH_INTERVAL,
	)
	enemy.accuracy = int(enemy.accuracy) + FloorGenerator.enemy_stat_bonus_for_depth(
		depth, FloorGenerator.ENEMY_ACCURACY_DEPTH_INTERVAL,
	)
	enemy.dodge = int(enemy.dodge) + FloorGenerator.enemy_stat_bonus_for_depth(
		depth, FloorGenerator.ENEMY_DODGE_DEPTH_INTERVAL,
	)
	enemy.souls = int(enemy.souls) + FloorGenerator.enemy_stat_bonus_for_depth(
		depth, FloorGenerator.ENEMY_SOULS_DEPTH_INTERVAL,
	)
	enemy.attack_type = String(enemy.get("attack_type", "melee"))
	enemy.range = int(enemy.get("range", 1))
	enemy.has_seen_player = true
	enemy.accuracy = 100
	return enemy


func _test_enemy_preparation(tree: SceneTree) -> void:
	var main = await _main(tree)
	var crossbow := _enemy("bone_crossbowman", Vector2i(8, 4))
	main.floor_data.enemies = [crossbow]
	var health: int = main.state.hp
	main._enemy_turn()
	check(crossbow.get("preparation", {}).get("remaining") == 2 and main.state.hp == health, "Crossbow starts2-turn preparation without firing")
	var renderer = preload("res://scripts/ui/game_renderer.gd")
	check(not renderer.enemy_telegraph_cells(main.floor_data, crossbow).is_empty(), "Crossbow telegraph appears on preparation start")
	main.floor_data.visible_cells.erase(crossbow.pos)
	check(renderer.enemy_telegraph_cells(main.floor_data, crossbow).is_empty(), "Hidden shooter never leaks telegraph")
	main.floor_data.visible_cells[crossbow.pos] = true
	main._enemy_turn()
	check(crossbow.preparation.remaining == 1 and main.state.hp == health, "First full reaction turn remains safe")
	crossbow.accuracy = int(Rules.ENEMIES.bone_crossbowman.accuracy)
	var snapshot := preload("res://scripts/system/run_snapshot.gd").capture("dungeon", main.floor_data, main.player_pos, main.rng, main.hearing_contacts.to_snapshot_data())
	var resume := preload("res://scripts/system/run_snapshot.gd").restore(JSON.parse_string(JSON.stringify(snapshot)), main.state.to_snapshot_data())
	check(not resume.is_empty() and resume.floor_data.enemies[0].preparation.remaining == 1, "Active preparation round-trips at exact phase")
	var displaced_preparation_floor: Dictionary = main.floor_data.duplicate(true)
	displaced_preparation_floor.enemies[0].preparation.target = main.player_pos + Vector2i.RIGHT
	var displaced_preparation := preload("res://scripts/system/run_snapshot.gd").capture(
		"dungeon", displaced_preparation_floor, main.player_pos, main.rng,
		main.hearing_contacts.to_snapshot_data(),
	)
	check(
		preload("res://scripts/system/run_snapshot.gd").restore(
			displaced_preparation, main.state.to_snapshot_data(),
		).is_empty(),
		"Persisted preparation must still target the saved player cell",
	)
	crossbow.accuracy = 100
	main._enemy_turn()
	check(main.state.hp == health - 2 and not crossbow.has("preparation") and crossbow.special_cooldown == 3, "Second reaction turn resolves one shot then cooldown3")
	var position: Vector2i = crossbow.pos
	main._enemy_turn()
	check(crossbow.pos == position and crossbow.recovery_remaining == 0 and main.state.hp == health - 2, "First post-shot action is immobile idle")
	main._enemy_turn()
	check(not crossbow.has("preparation"), "Cooldown second action cannot prepare")
	main._enemy_turn()
	check(not crossbow.has("preparation"), "Cooldown third action cannot prepare")
	main._enemy_turn()
	check(crossbow.has("preparation"), "Crossbow restarts only after all3cooldown actions")
	main.floor_data.tiles[Vector2i(5, 4)] = "wall"
	crossbow.pos = Vector2i(8, 4)
	main._enemy_turn()
	check(
		not crossbow.has("preparation")
		and crossbow.recovery_remaining == 2
		and main.state.hp == health - 2,
		"Lost LOS spends the cancellation action and schedules two exact idle actions",
	)
	main.floor_data.tiles[Vector2i(5, 4)] = "floor"
	position = crossbow.pos
	main._enemy_turn()
	check(
		crossbow.pos == position and crossbow.recovery_remaining == 1
		and not crossbow.has("preparation"),
		"First post-cancellation Crossbow action is idle",
	)
	main._enemy_turn()
	check(
		crossbow.pos == position and crossbow.recovery_remaining == 0
		and not crossbow.has("preparation"),
		"Second post-cancellation Crossbow action is idle",
	)
	main._enemy_turn()
	check(
		crossbow.has("preparation") and crossbow.preparation.remaining == 2,
		"Third post-cancellation Crossbow action may prepare again",
	)
	var smith := _enemy("slag_smith", Vector2i(5, 4))
	main.floor_data.enemies = [smith]
	main._enemy_turn()
	check(smith.preparation.target == Vector2i(4, 4), "Smith records the original threatened cell")
	check(renderer.enemy_telegraph_cells(main.floor_data, smith) == [Vector2i(4, 4)], "Smith telegraph returns its typed visible target cell")
	main.player_pos = Vector2i(5, 5)
	main._enemy_turn()
	check(main.state.hp == health - 2 and smith.special_cooldown == 6, "Sidestep dodges fixed-cell heavy strike, costs enemy action")
	var spider := _enemy("arachnid", Vector2i(5, 4))
	main.floor_data.enemies = [spider]
	var before_double: int = main.state.hp
	main._enemy_turn()
	check(main.state.hp == before_double - 4 and spider.ability_cooldowns.double_attack == 15, "Arachnid executes two ordinary strikes in one action")
	main._enemy_turn()
	check(main.state.hp == before_double - 6 and spider.ability_cooldowns.double_attack == 14, "Arachnid cooldown uses a single ordinary attack")
	main.queue_free()
	await tree.process_frame


func _test_inventory_camp_ui(tree: SceneTree) -> void:
	var main = await _main(tree)
	main._show_base("")
	main._refresh_interface()
	main._open_camp_build_panel()
	check(not main.camp_build_panel.rows.has("mural"), "Mural offer is absent before trophy")
	main.state.record_enemy_defeat("minotaur")
	main.camp_build_panel.refresh()
	check(main.camp_build_panel.rows.has("mural"), "Mural offer revealed by permanent trophy")
	main.camp_build_panel.close()
	main.state.camp_upgrades.crusher = true
	var key: String = main.state.add_item("rusty_sabre")
	main._open_inventory_service("crusher")
	main.inventory_panel.select_item(key)
	main.inventory_panel.keep_button.pressed.emit()
	check(main.state.item_mark(key) == "keep", "Keep button marks selected real stack")
	main._on_inventory_dismantle_pressed()
	check(main.state.inventory.has(key) and main.inventory_panel.keep_confirmation_key == key, "UI first salvage press confirms protected item")
	main._on_inventory_dismantle_pressed()
	check(not main.state.inventory.has(key), "UI second explicit salvage press consumes one protected item")
	main.queue_free()
	await tree.process_frame


func _test_exact_preparation_resume(tree: SceneTree) -> void:
	var snapshot_system = preload("res://scripts/system/run_snapshot.gd")
	var directory := "res://.tmp/nightly/stage1-preparation-resume"
	var original = await _main(tree)
	original.rng.seed = 570123
	original.state.current_form_id = "revenant"
	original.state.absorbed_souls = int(Rules.FORMS.revenant.threshold)
	original.state.lifetime_souls_earned = original.state.absorbed_souls
	original.state.highest_unlocked_form_index = 3
	original.state.soul_level = 8
	original.state.skill_levels.stomach = 1
	original.state.equip("expedition_backpack", "back")
	original.state.camp_upgrades.campfire = true
	original.state.camp_upgrades.kettle = true
	original.state.camp_upgrades.bunk = true
	original.state.food = 3
	original.state.record_enemy_defeat("minotaur")
	var sabre: String = original.state.add_item("rusty_sabre")
	original.state.set_item_mark(sabre, "keep")
	original.state.safe_return()
	original.state.select_kettle_preparation(true)
	original.state.begin_expedition(80)
	var enemy := _enemy("bone_crossbowman", Vector2i(8, 4))
	enemy.accuracy = 4 # Real hit RNG must continue, not merely the visible phase.
	original.floor_data.enemies = [enemy]
	original._enemy_turn()
	original._enemy_turn()
	var snapshot: Dictionary = snapshot_system.capture("dungeon", original.floor_data, original.player_pos, original.rng, original.hearing_contacts.to_snapshot_data())
	var before_load: Dictionary = original.state.to_snapshot_data()
	check(Save.save_slot(original.state, "prepared", "overwrite", directory, 1, Callable(), {}, Callable(), snapshot).ok, "Prepared attack writes through the real full-save API")
	var resumed = await _main(tree)
	resumed.save_slots_directory = directory
	resumed._on_save_slot_load_requested("prepared")
	check(resumed.state.to_snapshot_data() == before_load and resumed.screen == resumed.Screen.DUNGEON, "Full load neither heals nor refreshes preparation/trophies/marks")
	for round in range(8):
		original._enemy_turn()
		resumed._enemy_turn()
		original.state.finish_completed_round()
		resumed.state.finish_completed_round()
		check(original.state.to_snapshot_data() == resumed.state.to_snapshot_data(), "Prepared save resumes identical HP/statuses/one-time records round%d" % round)
		check(original.floor_data == resumed.floor_data and original.rng.state == resumed.rng.state, "Prepared save resumes identical AI phases/positions/RNG round%d" % round)
	original.state.unequip("back")
	resumed.state.unequip("back")
	check(original.state.to_snapshot_data() == resumed.state.to_snapshot_data() and resumed.state.camp_preparation.backpack_removed, "First backpack removal remains one-time after exact load")

	var cancelled = await _main(tree)
	cancelled.rng.seed = 570124
	var cancelled_enemy := _enemy("bone_crossbowman", Vector2i(8, 4))
	cancelled.floor_data.enemies = [cancelled_enemy]
	cancelled._enemy_turn()
	cancelled.floor_data.tiles[Vector2i(5, 4)] = "wall"
	cancelled._enemy_turn()
	check(
		cancelled_enemy.recovery_remaining == 2 and not cancelled_enemy.has("preparation"),
		"Cancellation resume fixture must begin at the full two-action recovery value",
	)
	# Restore the canonical depth-20 stat after the deterministic combat fixture's
	# forced-hit override so strict live-snapshot validation tests only recovery=2.
	cancelled_enemy.accuracy = int(Rules.ENEMIES.bone_crossbowman.accuracy)
	var cancelled_snapshot: Dictionary = snapshot_system.capture(
		"dungeon", cancelled.floor_data, cancelled.player_pos, cancelled.rng,
		cancelled.hearing_contacts.to_snapshot_data(),
	)
	check(
		Save.save_slot(
			cancelled.state, "cancelled", "overwrite", directory, 2,
			Callable(), {}, Callable(), cancelled_snapshot,
		).ok,
		"Cancelled preparation must write through the strict full-save API",
	)
	var cancelled_resumed = await _main(tree)
	cancelled_resumed.save_slots_directory = directory
	cancelled_resumed._on_save_slot_load_requested("cancelled")
	check(
		cancelled_resumed.floor_data.enemies[0].recovery_remaining == 2,
		"Exact load must retain cancellation recovery=2 without shortening",
	)
	cancelled.floor_data.tiles[Vector2i(5, 4)] = "floor"
	cancelled_resumed.floor_data.tiles[Vector2i(5, 4)] = "floor"
	var cancelled_position: Vector2i = cancelled_enemy.pos
	for idle_index in range(2):
		cancelled._enemy_turn()
		cancelled_resumed._enemy_turn()
		check(
			cancelled_enemy.pos == cancelled_position
			and cancelled_resumed.floor_data.enemies[0].pos == cancelled_position
			and not cancelled_enemy.has("preparation")
			and not cancelled_resumed.floor_data.enemies[0].has("preparation")
			and cancelled_enemy.recovery_remaining == 1 - idle_index
			and cancelled_resumed.floor_data.enemies[0].recovery_remaining == 1 - idle_index,
			"Cancelled preparation idle action %d must remain exact across load" % (idle_index + 1),
		)
	cancelled._enemy_turn()
	cancelled_resumed._enemy_turn()
	check(
		cancelled_enemy.has("preparation")
		and cancelled_resumed.floor_data.enemies[0].has("preparation")
		and cancelled.floor_data == cancelled_resumed.floor_data,
		"The third post-cancellation action may prepare identically after exact load",
	)
	Save.delete_slot("prepared", directory)
	Save.delete_slot("cancelled", directory)
	original.queue_free()
	resumed.queue_free()
	cancelled.queue_free()
	cancelled_resumed.queue_free()
	await tree.process_frame


func _test_state_only_corruption(tree: SceneTree) -> void:
	var directory := "res://.tmp/nightly/stage1-helper-corruption"
	var state := _state()
	state.record_enemy_defeat("minotaur")
	var key := state.add_item("rusty_sabre")
	state.set_item_mark(key, "keep")
	check(Save.save_slot(state, "helper", "overwrite", directory, 1).ok, "Current state-only helper writes complete durable records")
	check(Save.save_slot(state, "helper", "overwrite", directory, 2).ok, "State-only helper backup fixture writes")
	var path := directory.path_join("helper.json")
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var main = await _main(tree)
	main.save_slots_directory = directory
	var initial: Dictionary = main.state.to_snapshot_data()
	for field in ["trophies", "milestones", "camp_preparation", "inventory_marks", "camp_upgrades"]:
		var corrupt := valid.duplicate(true)
		corrupt.state[field] = {} if field != "inventory_marks" else {"missing_item@0": "keep"}
		_write_json(path, corrupt)
		_write_json(path + ".bak", valid)
		var recovered := Save.load_slot("helper", directory)
		check(recovered.get("ok", false) and recovered.get("recovered_from_backup", false), "Corrupt state-only %s uses validated backup" % field)
		_write_json(path + ".bak", corrupt)
		main._on_save_slot_load_requested("helper")
		check(main.state.to_snapshot_data() == initial and main.screen == main.Screen.DUNGEON, "Two corrupt state-only %s copies preserve current session" % field)
		var direct := _state()
		check(not direct.restore_save_data(corrupt.state) and direct.trophies.minotaur_tail == 0, "Direct restore rejects bad durable records before mutating state")
	_write_json(path, valid)
	_write_json(path + ".bak", valid)
	main._on_save_slot_load_requested("helper")
	check(main.screen == main.Screen.BASE and main.state.trophies.minotaur_tail == 1, "Valid explicit helper still restores safely")
	Save.delete_slot("helper", directory)
	main.queue_free()
	await tree.process_frame


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
