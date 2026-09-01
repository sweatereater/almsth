class_name StatusCooldownTestSuite
extends RefCounted

const AbilitySystem := preload("res://scripts/game/skill_system.gd")
const StatusSystem := preload("res://scripts/game/status_system.gd")
const StatusStripClass := preload("res://scripts/ui/status_strip.gd")
const Loc := preload("res://scripts/localization/localization.gd")
const BaseLayout := preload("res://scripts/ui/base_layout.gd")

var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	_test_registry_and_sanitation()
	_test_status_lifecycle_and_damage()
	_test_satiated_round_boundary()
	_test_cooldown_boundaries()
	_test_camp_entry_contract()
	await _test_base_status_presentation(tree)
	await _test_action_integration(tree)
	return failures


func _test_registry_and_sanitation() -> void:
	_expect(
		AbilitySystem.base_cooldown("dash") == 20
		and AbilitySystem.base_cooldown("double_attack") == 15
		and AbilitySystem.base_cooldown("magic_missile") == 0,
		"Ability metadata must be the single base-cooldown source",
	)
	var cooldowns := AbilitySystem.sanitize_cooldowns({
		"dash": 999.9,
		"double_attack": 4.8,
		"magic_missile": 6,
		"unknown": 8,
		"bad_bool": true,
	})
	_expect(
		cooldowns == {"dash": 20, "double_attack": 4},
		"Cooldown sanitation must floor numeric fractions, clamp maxima and drop bool/unknown/zero values",
	)
	var statuses := StatusSystem.sanitize({
		"rested": {"remaining_turns": 999.7, "temporary_hp": 99.2, "damage": 100},
		"satiated": {"remaining_turns": 777.9, "temporary_hp": 88.4, "regeneration": 100},
		"unknown": {"remaining_turns": 50},
	})
	_expect(
		statuses == {
			"rested": {"remaining_turns": 800, "temporary_hp": 5},
			"satiated": {"remaining_turns": 700, "temporary_hp": 3},
		},
		"Status saves must retain only clamped mutable fields for Rested and Satiated",
	)
	_expect(
		StatusSystem.sanitize({"rested": {"remaining_turns": true, "temporary_hp": 5}}).is_empty()
		and StatusSystem.sanitize({"satiated": {"remaining_turns": false, "temporary_hp": 3}}).is_empty()
		and StatusSystem.sanitize([]).is_empty(),
		"Malformed and boolean status durations must safely restore as empty",
	)
	var serialization_state := RunState.new()
	serialization_state.ability_cooldowns = {
		"dash": 999.4, "double_attack": false, "unknown": 2,
	}
	serialization_state.active_statuses = {
		"rested": {"remaining_turns": 42.9, "temporary_hp": 99, "damage": 999},
		"satiated": {"remaining_turns": 23.8, "temporary_hp": 99, "regeneration": 999},
		"unknown": {"remaining_turns": 7},
	}
	serialization_state.current_form_id = "ghoul"
	serialization_state.skill_levels["stomach"] = 1
	var serialized := serialization_state.to_save_data()
	_expect(
		serialized["ability_cooldowns"] == {"dash": 20}
		and serialized["active_statuses"] == {
			"rested": {"remaining_turns": 42, "temporary_hp": 5},
			"satiated": {"remaining_turns": 23, "temporary_hp": 3},
		},
		"Serialization must sanitize cooldown/status dictionaries as strictly as restore",
	)


func _test_status_lifecycle_and_damage() -> void:
	var state := RunState.new()
	state.current_form_id = "ghoul"
	state.skill_levels["stomach"] = 1
	state.hp = state.get_max_hp()
	_expect(
		state.add_or_refresh_status("rested")
		and state.status_remaining("rested") == 500
		and state.get_temporary_hp() == 5,
		"Rested must grant its exact duration and own temporary-HP pool",
	)
	state.apply_damage(3)
	_expect(
		state.get_temporary_hp() == 2 and state.hp == state.get_max_hp(),
		"Temporary HP must absorb ordinary damage before permanent HP",
	)
	state.add_or_refresh_status("rested")
	_expect(
		state.status_remaining("rested") == 500 and state.get_temporary_hp() == 5,
		"Refreshing Rested must restore, not stack, duration and temporary HP",
	)
	var base_damage := GameRules.calculate_derived_stats(
		state.attributes, state.current_form_id, state.loadout, state.base_level,
	)
	_expect(
		state.get_damage() == int(base_damage["damage"]) + 1
		and state.get_ranged_damage() == int(base_damage["ranged_damage"]) + 1
		and state.get_magic_missile_damage() == 0,
		"Rested must modify physical melee/ranged damage without granting spell power",
	)
	state.hunger = 0
	state.active_statuses["rested"]["temporary_hp"] = 1
	var hp_before := state.hp
	var starvation := state.advance_survival_turn()
	_expect(
		int(starvation.get("temporary_hp_absorbed", 0)) == 1
		and state.hp == hp_before,
		"Starvation must use the centralized temporary-HP damage path",
	)
	state.active_statuses["rested"] = {"remaining_turns": 1, "temporary_hp": 4}
	var expiry_events := state.finish_completed_round()
	_expect(
		not state.has_status("rested") and state.get_temporary_hp() == 0 and state.hp == hp_before
		and expiry_events == [{"type": "expired", "status_id": "rested"}],
		"Status expiry must discard unused own temporary HP without reducing permanent HP",
	)
	state.add_or_refresh_status("rested", 2, 2)
	_expect(
		StatusSystem.remove(state.active_statuses, "rested")
		and not StatusSystem.remove(state.active_statuses, "rested"),
		"Generic status removal must report a real removal exactly once",
	)
	state.hunger = 37
	state.hunger_turn_progress = 9
	_expect(
		state.add_or_refresh_status("satiated")
		and state.status_remaining("satiated") == 400
		and state.hunger == 100 and state.hunger_turn_progress == 0
		and state.get_temporary_hp() == 3,
		"Satiated must pin satiety immediately and grant its exact 400/+3 pool",
	)
	_expect(
		int(state.get_derived_stats()["regeneration"]) == int(base_damage["regeneration"]) + 1,
		"Satiated must add exactly one point through the shared regeneration modifier path",
	)
	state.add_or_refresh_status("rested")
	_expect(state.get_temporary_hp() == 8, "Rested and Satiated temporary HP must coexist additively")
	state.apply_damage(6)
	_expect(
		int(state.active_statuses["rested"]["temporary_hp"]) == 0
		and int(state.active_statuses["satiated"]["temporary_hp"]) == 2
		and state.hp == state.get_max_hp(),
		"Overlapping temporary HP must keep the registry's deterministic Rested-first consumption order",
	)
	state.add_or_refresh_status("satiated")
	_expect(
		state.get_temporary_hp() == 3
		and int(state.active_statuses["rested"]["temporary_hp"]) == 0,
		"Refreshing Satiated must reset only its own +3 pool without stacking or refreshing Rested",
	)
	state.add_or_refresh_status("rested")
	state.ability_cooldowns = {"dash": 7}
	state.die()
	_expect(
		state.active_statuses.is_empty() and state.ability_cooldowns.is_empty(),
		"Death must clear statuses, temporary HP and player cooldowns",
	)


func _test_satiated_round_boundary() -> void:
	var state := RunState.new()
	state.current_form_id = "ghoul"
	state.absorbed_souls = int(GameRules.FORMS["ghoul"]["threshold"])
	state.skill_levels["stomach"] = 1
	state.hunger = 14
	state.hunger_turn_progress = 9
	state.add_or_refresh_status("satiated")
	for _round in range(399):
		var survival := state.advance_survival_turn()
		state.finish_completed_round()
		_expect(
			state.hunger == 100 and state.hunger_turn_progress == 0
			and not bool(survival["hunger_changed"]),
			"Satiated must pin satiety without accumulating deferred progress",
		)
	_expect(
		state.status_remaining("satiated") == 1,
		"Satiated must remain active after exactly 399 completed rounds",
	)
	state.skill_levels["flesh_regeneration"] = 1
	state.regeneration_progress = 98
	state.hp = state.get_max_hp() - 1
	var final_survival := state.advance_survival_turn()
	var final_events := state.finish_completed_round()
	_expect(
		int(final_survival["healed"]) == 1
		and state.hunger == 100 and state.hunger_turn_progress == 0
		and not state.has_status("satiated")
		and final_events == [{"type": "expired", "status_id": "satiated"}],
		"The 400th round must receive Satiated survival benefits and expire only at its end",
	)
	state.advance_survival_turn()
	_expect(
		state.hunger == 100 and state.hunger_turn_progress == 1,
		"Normal satiety countdown must resume fresh on the next accepted turn after expiry",
	)


func _test_cooldown_boundaries() -> void:
	var state := RunState.new()
	state.current_form_id = "ghoul"
	state.hp = state.get_max_hp()
	state.add_or_refresh_status("rested", 1, 5)
	var pending_dash := state.effective_cooldown("dash")
	_expect(
		pending_dash == 10 and state.effective_cooldown("double_attack") == 10,
		"Rested must snapshot exact 10-turn Dash and Double Attack cooldowns",
	)
	state.finish_completed_round("dash", pending_dash)
	_expect(
		state.cooldown_remaining("dash") == 10 and not state.has_status("rested"),
		"A newly installed cooldown must remain full after its application round even when Rested expires",
	)
	state.finish_completed_round()
	_expect(state.cooldown_remaining("dash") == 9, "The next accepted player turn must tick Dash from 10 to 9")
	for _index in range(9):
		state.finish_completed_round()
	_expect(state.cooldown_remaining("dash") == 0, "Ten subsequent completed turns must make a 10-turn cooldown ready")
	state.finish_completed_round("dash", 20)
	for expected in range(19, -1, -1):
		state.finish_completed_round()
		_expect(
			state.cooldown_remaining("dash") == expected,
			"Base Dash cooldown must deterministically tick through %d" % expected,
		)


func _test_camp_entry_contract() -> void:
	var skeleton := RunState.new()
	skeleton.display_form_id = "ghoul"
	skeleton.skill_levels["nervous_system"] = 1
	skeleton.safe_return()
	var unlearned_revenant := RunState.new()
	unlearned_revenant.current_form_id = "revenant"
	var learned_revenant := RunState.new()
	learned_revenant.current_form_id = "revenant"
	learned_revenant.skill_levels["nervous_system"] = 1
	_expect(
		not skeleton.has_status("rested") and not skeleton.has_status("satiated")
		and not skeleton.has_nervous_system()
		and not unlearned_revenant.has_nervous_system()
		and learned_revenant.has_nervous_system(),
		"Only a learned Nervous System on the actual Revenant+ body may enable Rested; display form is cosmetic",
	)
	var zombie := RunState.new()
	zombie.current_form_id = "zombie"
	zombie.absorbed_souls = int(GameRules.FORMS["zombie"]["threshold"])
	zombie.hunger = 17
	zombie.hunger_turn_progress = 8
	zombie.safe_return()
	_expect(
		zombie.hunger == 17 and zombie.hunger_turn_progress == 8
		and not zombie.has_status("satiated") and not zombie.has_status("rested"),
		"Actual Zombie camp entry must not activate Ghoul Satiety or Satiated",
	)
	var field_locked := RunState.new()
	field_locked.current_form_id = "ghoul"
	field_locked.absorbed_souls = int(GameRules.FORMS["ghoul"]["threshold"])
	field_locked.hunger = 80
	field_locked.food = 1
	_expect(
		field_locked.camp_and_eat()["reason"] == "no_hunger"
		and field_locked.hunger == 80 and field_locked.food == 1
		and not field_locked.has_status("satiated"),
		"A Ghoul without Stomach must not eat in the field or receive Satiated",
	)
	var ghoul := RunState.new()
	ghoul.configure_character("Camp Tester", GameRules.default_attributes())
	ghoul.current_form_id = "revenant"
	ghoul.absorbed_souls = int(GameRules.FORMS["revenant"]["threshold"])
	ghoul.highest_unlocked_form_index = GameRules.FORM_ORDER.find("revenant")
	ghoul.skill_levels["nervous_system"] = 1
	ghoul.hunger = 8
	ghoul.hunger_turn_progress = 6
	ghoul.safe_return()
	_expect(
		ghoul.hunger == 8 and ghoul.hunger_turn_progress == 6
		and not ghoul.has_status("satiated")
		and not ghoul.has_status("rested") and ghoul.camp_preparation.rested,
		"A learned Nervous System on Revenant earns Rested without unlocking Satiety before Stomach",
	)
	ghoul.begin_expedition()
	ghoul.banked_souls = 20
	_expect(
		bool(ghoul.purchase_skill("stomach")["ok"])
		and ghoul.hunger == 100 and ghoul.hunger_turn_progress == 0
		and not ghoul.has_status("satiated") and ghoul.get_total_souls() == 0,
		"Learning Stomach must initialize Satiety for 20 souls without granting Satiated",
	)
	ghoul.apply_camp_entry_effects()
	_expect(not ghoul.has_status("satiated"), "Entry does not grant Satiated before departure")
	ghoul.begin_expedition()
	_expect(
		ghoul.status_remaining("satiated") == 400
		and ghoul.status_remaining("rested") == 500 and ghoul.get_temporary_hp() == 8,
		"The departure after a true Revenant return grants overlapping Satiated and Rested",
	)
	ghoul.active_statuses["rested"] = {"remaining_turns": 3, "temporary_hp": 1}
	ghoul.active_statuses["satiated"] = {"remaining_turns": 2, "temporary_hp": 1}
	ghoul.apply_camp_entry_effects()
	_expect(ghoul.status_remaining("rested") == 3 and ghoul.status_remaining("satiated") == 2, "Entry preserves running timers")
	ghoul.begin_expedition()
	_expect(
		ghoul.status_remaining("rested") == 500
		and ghoul.status_remaining("satiated") == 400 and ghoul.get_temporary_hp() == 8,
		"A new earned departure refreshes both statuses without stacking",
	)
	ghoul.active_statuses["rested"] = {"remaining_turns": 17, "temporary_hp": 2}
	ghoul.active_statuses["satiated"] = {"remaining_turns": 23, "temporary_hp": 1}
	ghoul.food = 1
	ghoul.hunger = 80
	ghoul.camp_and_eat()
	_expect(
		ghoul.status_remaining("rested") == 17
		and ghoul.status_remaining("satiated") == 23 and ghoul.get_temporary_hp() == 3
		and ghoul.hunger == 100 and ghoul.food == 1,
		"Field camp_and_eat must pin active satiety but never grant or refresh camp-entry statuses",
	)
	var saved_ghoul := ghoul.to_save_data()
	saved_ghoul["hunger"] = 12
	saved_ghoul["hunger_turn_progress"] = 7
	var loaded := RunState.new()
	_expect(
		loaded.restore_save_data(saved_ghoul)
		and loaded.hunger == 100 and loaded.hunger_turn_progress == 0
		and loaded.status_remaining("rested") == 17
		and loaded.status_remaining("satiated") == 23 and loaded.get_temporary_hp() == 3,
		"Loading must preserve, not refresh, statuses while enforcing active satiety (rest=%d sat=%d)" % [
			loaded.status_remaining("rested"), loaded.status_remaining("satiated"),
		],
	)
	var no_status := RunState.new()
	no_status.configure_character("No Camp Entry", GameRules.default_attributes())
	no_status.current_form_id = "ghoul"
	no_status.absorbed_souls = int(GameRules.FORMS["ghoul"]["threshold"])
	var no_status_loaded := RunState.new()
	_expect(
		no_status.active_statuses.is_empty()
		and no_status_loaded.restore_save_data(no_status.to_save_data())
		and no_status_loaded.active_statuses.is_empty(),
		"Character creation and loading a save without statuses must never grant Satiated",
	)
	var cosmetic_gate := RunState.new()
	cosmetic_gate.current_form_id = "zombie"
	cosmetic_gate.display_form_id = "ghoul"
	cosmetic_gate.skill_levels["stomach"] = 1
	_expect(
		not cosmetic_gate.uses_hunger(),
		"A cosmetic Ghoul display must not unlock Satiety for an actual Zombie",
	)
	cosmetic_gate.current_form_id = "ghoul"
	cosmetic_gate.display_form_id = "skeleton"
	_expect(
		cosmetic_gate.uses_hunger(),
		"An actual Ghoul with Stomach must keep Satiety under a cosmetic Skeleton display",
	)
	var malformed_skeleton := no_status.to_save_data()
	malformed_skeleton["absorbed_souls"] = 0
	malformed_skeleton["current_form_id"] = "skeleton"
	malformed_skeleton["active_statuses"] = {
		"satiated": {"remaining_turns": 400, "temporary_hp": 3},
	}
	var sanitized_skeleton := RunState.new()
	_expect(
		sanitized_skeleton.restore_save_data(malformed_skeleton)
		and not sanitized_skeleton.has_status("satiated"),
		"A malformed save must not restore Satiated onto a form without the satiety mechanic",
	)


func _test_base_status_presentation(tree: SceneTree) -> void:
	Loc.set_locale("ru")
	var main = await _new_main(tree)
	main.state.configure_character("Base Status", GameRules.default_attributes())
	_configure_form(main, "revenant")
	main.state.skill_levels["stomach"] = 1
	main.state.skill_levels["nervous_system"] = 1
	var shared_strip_id: int = main.status_strip.get_instance_id()
	main._show_base("", "none")
	await tree.process_frame
	var base_rect := Rect2(main.status_strip.position, main.status_strip.size)
	var base_sidebar: Rect2 = BaseLayout.SIDEBAR_RECT
	_expect(
		main.status_strip.visible
		and base_rect == main.BASE_STATUS_RECT
		and base_sidebar.encloses(base_rect)
		and not base_rect.intersects(BaseLayout.STATS_RECT)
		and not base_rect.intersects(BaseLayout.PROGRESS_RECT)
		and not base_rect.intersects(BaseLayout.HP_RECT)
		and not base_rect.intersects(BaseLayout.MANA_RECT)
		and base_rect.end.x <= 1280,
		"Base status strip must occupy its exact non-overlapping 1280-wide sidebar rect",
	)
	_expect(
		main.status_strip.get_child_count() == 0
		and main.status_strip.status_snapshot.is_empty(),
		"A base with zero statuses must show an empty shared strip",
	)

	main.state.add_or_refresh_status("rested", 321, 4)
	main._refresh_interface()
	await tree.process_frame
	var rested_chip = main.status_strip.get_child(0)
	_expect(
		main.status_strip.get_child_count() == 1
		and String(rested_chip.status_id) == "rested"
		and String(rested_chip.tooltip_text).contains("Отдых")
		and String(rested_chip.tooltip_text).contains("321")
		and rested_chip.accessibility_name == rested_chip.tooltip_text
		and rested_chip.focus_mode == Control.FOCUS_ALL
		and rested_chip.mouse_filter == Control.MOUSE_FILTER_PASS
		and main.status_strip.mouse_filter == Control.MOUSE_FILTER_PASS,
		"One Rest status on base must expose exact turns, tooltip, accessibility and non-blocking input",
	)

	main.state.add_or_refresh_status("satiated", 17, 2)
	main._refresh_interface()
	await tree.process_frame
	var actual_order: Array[String] = []
	for child in main.status_strip.get_children():
		actual_order.append(String(child.status_id))
	var expected_order := StatusSystem.ordered_active_ids(main.state.active_statuses)
	var satiated_chip = main.status_strip.get_child(1)
	_expect(
		actual_order == expected_order
		and actual_order == ["rested", "satiated"]
		and actual_order.size() == StatusSystem.STATUSES.size()
		and String(satiated_chip.tooltip_text).contains(Loc.text("STATUS_SATIATED"))
		and String(satiated_chip.tooltip_text).contains("17")
		and main.status_strip.status_snapshot == StatusSystem.sanitize(
			main.state.active_statuses
		),
		"Base must show both/all known statuses once in registry priority order from active_statuses",
	)

	var overflow_counts := StatusStripClass.presentation_counts(
		StatusStripClass.MAX_VISIBLE_STATUSES + 3
	)
	var summary_chip = StatusStripClass.StatusChip.new()
	main.add_child(summary_chip)
	await tree.process_frame
	summary_chip.configure_summary(3)
	var generic_chip = StatusStripClass.StatusChip.new()
	main.add_child(generic_chip)
	await tree.process_frame
	generic_chip.configure("future_known_status", {"remaining_turns": 73})
	_expect(
		overflow_counts == Vector2i(StatusStripClass.MAX_VISIBLE_STATUSES, 3)
		and summary_chip.summary_count == 3
		and String(summary_chip.tooltip_text).contains("3")
		and summary_chip.accessibility_name == summary_chip.tooltip_text
		and generic_chip.status_id == "future_known_status"
		and String(generic_chip.tooltip_text).contains("future_known_status")
		and String(generic_chip.tooltip_text).contains("73")
		and generic_chip.accessibility_name == generic_chip.tooltip_text,
		"StatusStrip must retain capped overflow summary and accessible generic-chip fallback",
	)
	summary_chip.queue_free()
	generic_chip.queue_free()

	main.state.active_statuses.clear()
	main.state.safe_return()
	main._show_base("Safe return with statuses", "none")
	await tree.process_frame
	_expect(main.status_strip.get_child_count() == 0 and main.state.camp_preparation.pending, "Return UI defers timed effects until departure")
	main.state.begin_expedition()
	main._refresh_interface()
	await tree.process_frame
	_expect(
		main.status_strip.get_child_count() == 2
		and String(main.status_strip.get_child(0).tooltip_text).contains("500")
		and String(main.status_strip.get_child(1).tooltip_text).contains("400"),
		"Prepared departure starts Rest500/Satiety400; the shared UI presents current effects",
	)
	Loc.set_locale("en")
	main._apply_locale()
	await tree.process_frame
	_expect(
		String(main.status_strip.get_child(0).tooltip_text).contains("Rested")
		and String(main.status_strip.get_child(1).tooltip_text).contains("Satiated"),
		"Base status tooltips must refresh from the same strip in English",
	)
	Loc.set_locale("ru")
	main._apply_locale()
	await tree.process_frame

	var restored := RunState.new()
	_expect(
		restored.restore_save_data(main.state.to_save_data()),
		"Base status loading fixture must restore its saved run state",
	)
	main.state = restored
	main._show_base(Loc.text("MSG_GAME_LOADED"), "none")
	await tree.process_frame
	_expect(
		main.status_strip.status_snapshot == StatusSystem.sanitize(
			main.state.active_statuses
		)
		and main.status_strip.get_child_count() == 2,
		"Loading a base save must refresh every preserved status without granting another copy",
	)

	main.screen = main.Screen.DUNGEON
	main._apply_dungeon_layout(true)
	main._show_base("Return with statuses", "none")
	await tree.process_frame
	_expect(
		main.status_strip.get_instance_id() == shared_strip_id
		and main.status_strip.status_snapshot == StatusSystem.sanitize(
			main.state.active_statuses
		)
		and main.status_strip.get_child_count() == StatusSystem.STATUSES.size(),
		"Dungeon and base must reposition one StatusStrip instance without duplicating runtime status state",
	)
	main.queue_free()
	await tree.process_frame


func _test_action_integration(tree: SceneTree) -> void:
	var main = await _new_main(tree)
	_configure_form(main, "ghoul")
	main.state.skill_levels["stomach"] = 1
	main.state.skill_levels["dash"] = 1
	main.state.skill_levels["double_attack"] = 1
	main.state.assign_ability("active_1", "dash")
	main.state.assign_ability("attack", "double_attack")
	main.floor_data = _floor_fixture()
	main.player_pos = Vector2i(3, 3)
	_reveal_floor(main)
	var turns_before: int = main.state.total_turns
	main._begin_dash_targeting()
	main._cancel_ability_targeting()
	_expect(
		main.state.total_turns == turns_before
		and main.state.cooldown_remaining("dash") == 0,
		"Dash target entry/cancel must consume zero turns and start no cooldown",
	)
	main._begin_dash_targeting()
	main.floor_data["enemies"] = [_enemy("blocker", Vector2i(5, 3), 50)]
	_expect(
		not main._confirm_dash(Vector2i(6, 3))
		and main.state.total_turns == turns_before
		and main.state.cooldown_remaining("dash") == 0,
		"Dash confirmation must revalidate blockers with zero-turn rejection",
	)
	main.floor_data["enemies"].clear()
	main._refresh_dash_partition()
	_expect(main._confirm_dash(Vector2i(5, 3)), "A valid Dash fixture must commit")
	_expect(
		main.state.total_turns == turns_before + 1
		and main.state.cooldown_remaining("dash") == 20,
		"Successful base Dash must install 20 only after its completed round",
	)
	var cooldown_turns: int = main.state.total_turns
	_expect(
		not main._activate_ability_slot("active_1")
		and main.state.total_turns == cooldown_turns
		and main.state.cooldown_remaining("dash") == 20,
		"Using a cooling active Dash must do nothing and tick nothing",
	)
	main._on_wait_pressed()
	_expect(
		main.state.total_turns == cooldown_turns + 1
		and main.state.cooldown_remaining("dash") == 19,
		"An accepted wait must tick an already-running cooldown exactly once",
	)

	main.player_pos = Vector2i(3, 3)
	main.state.ability_cooldowns.erase("double_attack")
	main.floor_data["enemies"].clear()
	var no_target_turns: int = main.state.total_turns
	_expect(
		not main._activate_ability_slot("attack")
		and main.state.total_turns == no_target_turns
		and main.state.cooldown_remaining("double_attack") == 0,
		"Double Attack without a valid target must spend no turn and start no cooldown",
	)
	main.floor_data["enemies"] = [_enemy("target", Vector2i(4, 3), 50)]
	_expect(
		main._activate_ability_slot("attack", {
			"target_uid": "target", "attack_rolls": [1, 1],
		}),
		"A valid Double Attack target must commit even when both independent strikes miss",
	)
	_expect(
		main.state.cooldown_remaining("double_attack") == 15,
		"Committed Double Attack must start its exact 15-turn cooldown after misses",
	)
	main._refresh_hotbar()
	_expect(
		main._effective_attack_ability() == "basic_attack"
		and main.attack_button.text.contains(Loc.text("ABILITY_BASIC_ATTACK"))
		and main.attack_button.text.contains("15")
		and main.hotbar_cooldown_badges["attack"].visible,
		"A cooling assigned Double Attack must visibly fall back to usable Basic Attack",
	)
	main.state.loadout["right_hand"] = "bone_bow@0"
	main._refresh_hotbar()
	_expect(
		main._effective_attack_ability() == "basic_attack" and not main.attack_button.disabled,
		"A cooling physical skill must never disable the contextual Basic Shot from a bow",
	)
	main.state.loadout.erase("right_hand")
	main.state.add_or_refresh_status("rested", 500, 5)
	main.state.add_or_refresh_status("satiated", 400, 3)
	main._refresh_interface()
	await tree.process_frame
	var status_chips: Array[Node] = main.status_strip.get_children()
	var satiated_chip: Node = null
	for chip in status_chips:
		if String(chip.get("status_id")) == "satiated":
			satiated_chip = chip
	_expect(
		main.status_strip.visible and status_chips.size() == 2 and satiated_chip != null
		and String(satiated_chip.tooltip_text).contains(Loc.text("STATUS_SATIATED"))
		and String(satiated_chip.tooltip_text).contains("400")
		and not String(satiated_chip.accessibility_name).is_empty()
		and String(StatusSystem.rules("satiated")["icon"]) == "satiated_meal",
		"The status strip must expose a code-drawn Satiated 400 chip with tooltip/accessibility",
	)
	main.state.active_statuses["satiated"] = {"remaining_turns": 17, "temporary_hp": 2}
	main._show_base("Base view only", "none")
	_expect(
		main.state.status_remaining("satiated") == 17,
		"Merely opening the base screen must not grant or refresh Satiated",
	)
	main.queue_free()
	await tree.process_frame

	var boundary = await _new_main(tree)
	_configure_form(boundary, "ghoul")
	boundary.state.skill_levels["dash"] = 1
	boundary.floor_data = _floor_fixture()
	boundary.player_pos = Vector2i(3, 3)
	boundary.floor_data["enemies"] = [_enemy("response", Vector2i(4, 3), 50)]
	boundary.floor_data["enemies"][0]["accuracy"] = 100
	boundary.floor_data["enemies"][0]["damage"] = 6
	_reveal_floor(boundary)
	boundary.state.add_or_refresh_status("rested", 1, 5)
	var permanent_hp_before: int = boundary.state.hp
	boundary._complete_player_turn("dash", boundary.state.effective_cooldown("dash"))
	_expect(
		boundary.state.hp == permanent_hp_before - 1
		and not boundary.state.has_status("rested")
		and boundary.state.cooldown_remaining("dash") == 10,
		"Rested remaining1 must protect through enemy response, then expire after installing snapshotted Dash10",
	)
	boundary.queue_free()
	await tree.process_frame

	var satiated_boundary = await _new_main(tree)
	_configure_form(satiated_boundary, "ghoul")
	satiated_boundary.state.skill_levels["stomach"] = 1
	satiated_boundary.floor_data = _floor_fixture()
	satiated_boundary.player_pos = Vector2i(3, 3)
	satiated_boundary.floor_data["enemies"] = [_enemy("satiated-response", Vector2i(4, 3), 50)]
	satiated_boundary.floor_data["enemies"][0]["accuracy"] = 100
	satiated_boundary.floor_data["enemies"][0]["damage"] = 4
	_reveal_floor(satiated_boundary)
	satiated_boundary.state.hunger = 12
	satiated_boundary.state.hunger_turn_progress = 9
	satiated_boundary.state.add_or_refresh_status("satiated", 1, 3)
	var satiated_hp_before: int = satiated_boundary.state.hp
	satiated_boundary._complete_player_turn()
	_expect(
		satiated_boundary.state.hp == satiated_hp_before - 1
		and satiated_boundary.state.hunger == 100
		and satiated_boundary.state.hunger_turn_progress == 0
		and not satiated_boundary.state.has_status("satiated"),
		"Satiated remaining1 must pin survival and protect through enemy response before expiry",
	)
	satiated_boundary.floor_data["enemies"].clear()
	satiated_boundary._on_wait_pressed()
	_expect(
		satiated_boundary.state.hunger_turn_progress == 1,
		"The first accepted turn after Satiated expiry must start a fresh satiety countdown",
	)
	satiated_boundary.queue_free()
	await tree.process_frame

	var lethal = await _new_main(tree)
	_configure_form(lethal, "ghoul")
	lethal.floor_data = _floor_fixture()
	lethal.player_pos = Vector2i(3, 3)
	lethal.floor_data["enemies"] = [_enemy("lethal-response", Vector2i(4, 3), 50)]
	lethal.floor_data["enemies"][0]["accuracy"] = 100
	lethal.floor_data["enemies"][0]["damage"] = lethal.state.hp + 50
	_reveal_floor(lethal)
	lethal._complete_player_turn("dash", 20)
	_expect(
		lethal.screen == lethal.Screen.STORY and lethal.story_kind == "death"
		and lethal.state.ability_cooldowns.is_empty()
		and lethal.state.active_statuses.is_empty(),
		"Death during enemy response must clear runtime effects and never install the pending cooldown",
	)
	lethal.queue_free()
	await tree.process_frame


func _new_main(tree: SceneTree):
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	tree.root.add_child(main)
	await tree.process_frame
	main.screen = main.Screen.DUNGEON
	main.state = RunState.new()
	return main


func _configure_form(main, form_id: String) -> void:
	main.state.current_form_id = form_id
	main.state.absorbed_souls = int(GameRules.FORMS[form_id]["threshold"])
	main.state.highest_unlocked_form_index = GameRules.FORM_ORDER.find(form_id)
	main.state.hp = main.state.get_max_hp()
	main.state.mana = main.state.get_max_mana()


func _floor_fixture() -> Dictionary:
	var tiles := {}
	for y in range(7):
		for x in range(8):
			tiles[Vector2i(x, y)] = (
				"floor" if x > 0 and x < 7 and y > 0 and y < 6 else "wall"
			)
	return {
		"width": 8, "height": 7, "tiles": tiles,
		"start": Vector2i(2, 3), "base_gate": Vector2i(1, 1), "exit": Vector2i(6, 5),
		"exit_known": false, "cradle": Vector2i(-1, -1), "cradle_known": false,
		"cradle_pity_resolved": true, "cradle_used": false,
		"items": [], "enemies": [], "visible_cells": {}, "explored_cells": {},
		"observed_cells": {},
	}


func _reveal_floor(main) -> void:
	var visible := {}
	for cell_variant in main.floor_data["tiles"]:
		var cell: Vector2i = cell_variant
		if main.floor_data["tiles"][cell] != "void":
			visible[cell] = true
	main.floor_data["visible_cells"] = visible.duplicate(true)
	main.floor_data["explored_cells"] = visible.duplicate(true)
	main.floor_data["observed_cells"] = visible.duplicate(true)


func _enemy(uid: String, position: Vector2i, hp: int) -> Dictionary:
	var rules: Dictionary = GameRules.ENEMIES["grave_rat"]
	return {
		"uid": uid, "id": "grave_rat", "pos": position, "hp": hp, "max_hp": hp,
		"damage": int(rules["damage"]), "accuracy": -100, "dodge": 100,
		"vision": int(rules["vision"]), "souls": int(rules["souls"]),
		"has_seen_player": true, # Cooldown/status combat fixtures are already alerted.
	}


func _expect(condition: bool, failure_message: String) -> void:
	if not condition:
		failures.append(failure_message)
