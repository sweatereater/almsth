extends SceneTree

const FLOOR_SAMPLES := 500
const RANDOM_ACTIONS := 1200
const CARDINAL_DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var failures: Array[String] = []
var generated_floors := 0
var cradle_encounters := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_soak_floor_generation()
	_soak_cradle_pity()
	_soak_progression_and_survival()
	await _soak_random_ui_actions()
	if failures.is_empty():
		print("SOAK TEST PASSED: %d floors, %d Cradles, %d random actions" % [
			generated_floors, cradle_encounters, RANDOM_ACTIONS,
		])
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("SOAK TEST FAILED: %d failure(s)" % failures.size())
	quit(1)


func _soak_floor_generation() -> void:
	var generator := FloorGenerator.new()
	for sample in range(FLOOR_SAMPLES):
		var floor_number := 99 - (sample % 99)
		var chance := float(sample % 21) * 0.05
		var floor_data := generator.generate(floor_number, 10_000 + sample, chance)
		generated_floors += 1
		var tiles: Dictionary = floor_data["tiles"]
		var start: Vector2i = floor_data["start"]
		var exit: Vector2i = floor_data["exit"]
		var base_gate: Vector2i = floor_data["base_gate"]
		_check(
			floor_data.get("visible_cells", {}).is_empty()
			and floor_data.get("explored_cells", {}).is_empty()
			and floor_data.get("observed_cells", {}).is_empty(),
			"Generated floor visibility began dirty at sample %d" % sample,
		)
		_check(tiles.get(start, "void") == "floor", "Start spawned off the floor at sample %d" % sample)
		_check(tiles.get(exit, "void") == "floor", "Exit spawned off the floor at sample %d" % sample)
		_check(tiles.get(base_gate, "void") == "floor", "Base gate spawned off the floor at sample %d" % sample)
		_check(start != exit and start != base_gate and exit != base_gate, "Mandatory cells overlap at sample %d" % sample)
		_check(generator._all_floor_cells_connected(tiles), "Disconnected floor at sample %d" % sample)
		var occupied := {start: "start", exit: "exit", base_gate: "base"}
		for enemy in floor_data["enemies"]:
			_check(tiles.get(enemy["pos"], "void") == "floor", "Enemy off-floor at sample %d" % sample)
			_check(not occupied.has(enemy["pos"]), "Enemy overlap at sample %d" % sample)
			occupied[enemy["pos"]] = "enemy"
		for item in floor_data["items"]:
			_check(tiles.get(item["pos"], "void") == "floor", "Item off-floor at sample %d" % sample)
			_check(not occupied.has(item["pos"]), "Item overlap at sample %d" % sample)
			occupied[item["pos"]] = "item"
		var cradle: Vector2i = floor_data["cradle"]
		if cradle.x >= 0:
			cradle_encounters += 1
			_check(tiles.get(cradle, "void") == "floor", "Cradle off-floor at sample %d" % sample)
			_check(not occupied.has(cradle), "Cradle overlap at sample %d" % sample)
		if chance >= 1.0:
			_check(cradle.x >= 0, "Guaranteed Cradle failed at sample %d" % sample)


func _soak_cradle_pity() -> void:
	var generator := FloorGenerator.new()
	var state := RunState.new()
	var gap := 0
	var maximum_gap := 0
	for sample in range(1000):
		var floor_data := generator.generate(99, 50_000 + sample, state.get_cradle_chance())
		var appeared: bool = floor_data["cradle"] != Vector2i(-1, -1)
		state.record_cradle_result(appeared)
		if appeared:
			maximum_gap = maxi(maximum_gap, gap)
			gap = 0
		else:
			gap += 1
		_check(state.get_cradle_chance() >= 0.05 and state.get_cradle_chance() <= 1.0, "Cradle chance escaped its range")
	_check(maximum_gap <= 19, "Cradle pity allowed %d misses before an encounter" % maximum_gap)


func _soak_progression_and_survival() -> void:
	var state := RunState.new()
	state.configure_character("Soak", GameRules.default_attributes())
	state.add_souls(100)
	for expected_form in GameRules.FORM_ORDER.slice(1):
		state.soul_level = GameRules.required_soul_level(expected_form)
		var old_souls := state.carried_souls
		var expected_cost := GameRules.evolution_cost(state.current_form_id)
		var result := state.evolve_at_cradle()
		_check(bool(result.get("ok", false)), "Evolution failed before %s" % expected_form)
		_check(state.current_form_id == expected_form, "Evolution skipped or selected the wrong form")
		_check(state.carried_souls == old_souls - expected_cost, "Evolution charged the wrong amount")
	_check(not state.evolve_at_cradle()["ok"], "Final form evolved past its maximum")
	_check(
		state.purchase_skill("stomach") == {"ok": true, "level": 1, "cost": 20},
		"Progression soak could not buy the Ghoul Stomach skill",
	)
	state.apply_camp_entry_effects()
	_check(state.status_remaining("rested") == 500, "Camp did not start the 500-turn Rested soak")
	_check(state.status_remaining("satiated") == 400, "Camp did not start the 400-turn Satiated soak")
	state.finish_completed_round("dash", state.effective_cooldown("dash"))
	_check(state.cooldown_remaining("dash") == 10, "Rested Dash soak did not snapshot 10")
	for status_turn in range(501):
		state.finish_completed_round()
		_check(
			state.cooldown_remaining("dash") >= 0
			and state.cooldown_remaining("dash") <= 10,
			"Cooldown escaped bounds during Rested soak at turn %d" % status_turn,
		)
	_check(not state.has_status("rested"), "Rested must expire within the 501-turn soak")
	_check(not state.has_status("satiated"), "Satiated must expire within the 501-turn soak")
	_check(state.cooldown_remaining("dash") == 0, "Dash cooldown must be ready after 501 turns")

	state.die()
	state.add_souls(24)
	_check(state.evolve_at_cradle()["ok"], "Post-death soak could not restore Zombie form")
	_check(state.evolve_at_cradle()["ok"], "Post-death soak could not restore Ghoul form")
	state.banked_souls = 20
	_check(state.purchase_skill("flesh_regeneration")["ok"], "Post-death soak could not buy Regeneration")
	_check(state.uses_hunger(), "Learned Stomach must reactivate only after restoring a Ghoul body")
	state.attributes["vitality"] = 1000
	state.hp = state.get_max_hp() - 100
	state.mana = 0
	state.food = 20
	for _turn in range(1000):
		if state.hunger <= 80 and state.food > 0:
			state.camp_and_eat()
		var result := state.advance_survival_turn()
		_check(state.hunger >= 0 and state.hunger <= 100, "Satiety escaped its range")
		_check(state.hp <= state.get_max_hp(), "Regeneration exceeded maximum HP")
		_check(state.mana >= 0 and state.mana <= state.get_max_mana(), "Mana regeneration escaped its range")
		_check(not result["died"], "Fed regeneration soak died unexpectedly")

	state.hunger = 0
	state.hp = state.get_max_hp()
	var starvation_turns := 0
	while state.hp > 0 and starvation_turns < 200:
		state.advance_survival_turn()
		starvation_turns += 1
	_check(state.hp <= 0 and starvation_turns < 200, "Starvation did not eventually kill the body")


func _soak_random_ui_actions() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var main := packed.instantiate()
	_check(main.get_script() != null, "Main scene script failed to compile or attach")
	if main.get_script() == null:
		main.queue_free()
		return
	main.persistence_enabled = false
	root.add_child(main)
	await process_frame
	main.name_input.text = "Random"
	main._on_name_confirmed()
	for attribute_id in GameRules.ATTRIBUTE_ORDER:
		main._change_pending_attribute(attribute_id, 1)
	main._on_attributes_confirmed()
	main._advance_story()
	main._advance_story()
	main._advance_story()
	main.state.skill_levels["magic_awakening"] = 1
	main.state.skill_levels["magic_missile"] = 3
	main.state.skill_levels["magic_missile_range"] = 1
	main.state.skill_levels["magic_ricochet"] = 4
	main.state.assign_ability("active_1", "magic_missile")
	main.state.mana = main.state.get_max_mana()
	main.rng.seed = 90_001
	var action_rng := RandomNumberGenerator.new()
	action_rng.seed = 91_001
	for action_index in range(RANDOM_ACTIONS):
		if main.screen == main.Screen.STORY:
			main._advance_story()
			continue
		if main.cradle_confirmation_open:
			if not main.cradle_confirmation_confirm_button.disabled and action_rng.randi_range(0, 1) == 1:
				main._confirm_cradle_evolution()
			else:
				main._close_cradle_confirmation()
			continue
		if main.screen == main.Screen.BASE:
			main._on_start_pressed()
			main._on_beginning_ascent_pressed()
			continue
		if main.screen == main.Screen.VICTORY:
			break
		if main.screen != main.Screen.DUNGEON:
			_check(false, "Random actions entered unexpected screen %d" % main.screen)
			break
		match action_rng.randi_range(0, 9):
			0, 1, 2, 3:
				main._attempt_player_action(CARDINAL_DIRECTIONS[action_rng.randi_range(0, 3)])
			4:
				main._on_wait_pressed()
			5:
				main._on_attack_pressed()
			6:
				main._on_camp_pressed()
			7:
				main._on_interact_pressed()
			8:
				main._show_character()
				main._close_character()
			9:
				main._on_spell_pressed()
		if main.screen == main.Screen.DUNGEON:
			_check(main.state.hp > 0 and main.state.hp <= main.state.get_max_hp(), "Dungeon HP invariant failed at action %d" % action_index)
			_check(main.state.mana >= 0 and main.state.mana <= main.state.get_max_mana(), "Dungeon mana invariant failed at action %d" % action_index)
			_check(main.floor_data["tiles"].get(main.player_pos, "void") == "floor", "Player left walkable floor at action %d" % action_index)
			var camera_dimensions := Vector2i(main.floor_data["width"], main.floor_data["height"])
			var camera_maximum: Vector2 = main.dungeon_viewport.max_camera(camera_dimensions)
			_check(
				main.dungeon_viewport.camera == main.dungeon_viewport.camera_for(camera_dimensions, main.player_pos),
				"Dungeon camera did not follow route position at action %d" % action_index,
			)
			_check(
				main.dungeon_viewport.camera.x >= 0.0
				and main.dungeon_viewport.camera.y >= 0.0
				and main.dungeon_viewport.camera.x <= camera_maximum.x
				and main.dungeon_viewport.camera.y <= camera_maximum.y,
				"Dungeon camera left clamped bounds at action %d" % action_index,
			)
	main.queue_free()


func _check(condition: bool, failure: String) -> void:
	if not condition and not failures.has(failure):
		failures.append(failure)
