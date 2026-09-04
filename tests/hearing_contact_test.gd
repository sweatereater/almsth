class_name HearingContactTestSuite
extends RefCounted

const HearingContacts := preload("res://scripts/game/hearing_contact_system.gd")
const Loc := preload("res://scripts/localization/localization.gd")
const Renderer := preload("res://scripts/ui/game_renderer.gd")
const Snapshot := preload("res://scripts/system/run_snapshot.gd")
const FloorGeneratorScript := preload("res://scripts/world/floor_generator.gd")
const GridNavigationScript := preload("res://scripts/world/grid_navigation.gd")

var failures: Array[String] = []


func run(_tree: SceneTree) -> Array[String]:
	_test_radius_contract()
	_test_proximity_without_los_or_fog_writes()
	_test_attack_memory_ttl_and_priority()
	_test_pruning_and_deduplication()
	_test_snapshot_acceptance_matches_restore()
	_test_renderer_contracts()
	await _test_locked_and_purchase_contract(_tree)
	await _test_main_turn_input_and_automation(_tree)
	return failures


func _test_snapshot_acceptance_matches_restore() -> void:
	var state := RunState.new()
	state.configure_character("Hearing snapshot", GameRules.default_attributes())
	state.current_floor = 99
	state.absorbed_souls = int(GameRules.FORMS.ghoul.threshold)
	state.lifetime_souls_earned = state.absorbed_souls
	state.current_form_id = "ghoul"
	state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("ghoul")
	state.soul_level = 1
	state.skill_levels.ears = 1
	var state_data := state.to_snapshot_data()
	var random := RandomNumberGenerator.new()
	random.seed = 299099
	var floor: Dictionary = FloorGeneratorScript.new().generate(99, 299099, 0.0)
	var hidden_enemy := {}
	var second_hidden_enemy := {}
	var sealed_enemy := {}
	for value in floor.enemies:
		var enemy: Dictionary = value
		if GridNavigationScript.is_in_sealed_room(floor, enemy.pos):
			if sealed_enemy.is_empty():
				sealed_enemy = enemy
		elif hidden_enemy.is_empty():
			hidden_enemy = enemy
		elif second_hidden_enemy.is_empty():
			second_hidden_enemy = enemy
	_expect(
		not hidden_enemy.is_empty() and not sealed_enemy.is_empty(),
		"Hearing snapshot fixture must include ordinary and sealed-room enemies",
	)
	if hidden_enemy.is_empty() or sealed_enemy.is_empty():
		return
	var memory := {
		"uid": String(hidden_enemy.uid),
		"pos": hidden_enemy.pos,
		"expires_after_turn": 1,
	}
	var hearing := {"attack_memories": {String(hidden_enemy.uid): memory}, "event_revision": 1}
	var canonical := Snapshot.capture("dungeon", floor, floor.start, random, hearing)
	var decoded: Dictionary = Snapshot.restore(canonical, state_data)
	var restored_contacts := HearingContacts.new()
	if not decoded.is_empty():
		restored_contacts.restore_snapshot_data(
			decoded.hearing, decoded.floor_data.enemies, decoded.player_pos,
			state.get_hearing_radius(), decoded.floor_data.visible_cells, decoded.floor_data,
		)
	_expect(
		not decoded.is_empty()
		and restored_contacts.to_snapshot_data().attack_memories == hearing.attack_memories,
		"Every accepted hidden hearing memory must survive immediate runtime synchronization",
	)
	var long_ttl := hearing.duplicate(true)
	long_ttl.attack_memories[String(hidden_enemy.uid)].expires_after_turn = 5
	_expect(
		Snapshot.restore(
			Snapshot.capture("dungeon", floor, floor.start, random, long_ttl), state_data,
		).is_empty(),
		"A hidden-attack memory TTL must be exactly the next completed turn",
	)
	var displaced_cell := Vector2i(-1, -1)
	for cell_value in floor.tiles:
		var cell: Vector2i = cell_value
		if (
			floor.tiles[cell] == "floor"
			and cell != hidden_enemy.pos
			and not bool(floor.visible_cells.get(cell, false))
			and not GridNavigationScript.is_in_sealed_room(floor, cell)
		):
			displaced_cell = cell
			break
	var displaced := hearing.duplicate(true)
	displaced.attack_memories[String(hidden_enemy.uid)].pos = displaced_cell
	_expect(
		displaced_cell != Vector2i(-1, -1)
		and Snapshot.restore(
			Snapshot.capture("dungeon", floor, floor.start, random, displaced), state_data,
		).is_empty(),
		"A hidden-attack memory origin must equal the persisted enemy position",
	)
	var zero_revision := hearing.duplicate(true)
	zero_revision.event_revision = 0
	_expect(
		Snapshot.restore(
			Snapshot.capture("dungeon", floor, floor.start, random, zero_revision), state_data,
		).is_empty(),
		"Nonempty hearing memory requires a positive event revision",
	)
	if not second_hidden_enemy.is_empty():
		var undersized_revision := hearing.duplicate(true)
		undersized_revision.attack_memories[String(second_hidden_enemy.uid)] = {
			"uid": String(second_hidden_enemy.uid),
			"pos": second_hidden_enemy.pos,
			"expires_after_turn": 1,
		}
		_expect(
			Snapshot.restore(
				Snapshot.capture(
					"dungeon", floor, floor.start, random, undersized_revision,
				),
				state_data,
			).is_empty(),
			"Hearing revision must cover every persisted attack-memory event",
		)

	var without_ears := state.to_snapshot_data()
	without_ears.skill_levels.ears = 0
	_expect(
		Snapshot.restore(canonical, without_ears).is_empty(),
		"Nonempty hearing history requires the current state to have Ears",
	)
	var visible_floor := floor.duplicate(true)
	visible_floor.visible_cells[hidden_enemy.pos] = true
	_expect(
		Snapshot.restore(
			Snapshot.capture("dungeon", visible_floor, visible_floor.start, random, hearing),
			state_data,
		).is_empty(),
		"A visible enemy memory must reject instead of being accepted then pruned",
	)
	var wall_cell := Vector2i(-1, -1)
	for cell in floor.tiles:
		if floor.tiles[cell] == "wall":
			wall_cell = cell
			break
	var nonwalkable_hearing := hearing.duplicate(true)
	nonwalkable_hearing.attack_memories[String(hidden_enemy.uid)].pos = wall_cell
	_expect(
		wall_cell != Vector2i(-1, -1)
		and Snapshot.restore(
			Snapshot.capture(
				"dungeon", floor, floor.start, random, nonwalkable_hearing,
			),
			state_data,
		).is_empty(),
		"A hearing memory origin must remain walkable",
	)
	var sealed_hearing := {
		"attack_memories": {
			String(sealed_enemy.uid): {
				"uid": String(sealed_enemy.uid),
				"pos": sealed_enemy.pos,
				"expires_after_turn": 1,
			},
		},
		"event_revision": 1,
	}
	_expect(
		Snapshot.restore(
			Snapshot.capture("dungeon", floor, floor.start, random, sealed_hearing),
			state_data,
		).is_empty(),
		"A sealed-room memory must reject instead of being accepted then pruned",
	)


func _test_radius_contract() -> void:
	var state := RunState.new()
	_expect(
		state.get_vision_radius() == 4 and not state.has_hearing()
		and state.get_hearing_radius() == 0,
		"Hearing must remain fully locked for a new character",
	)
	state.current_form_id = "ghoul"
	state.absorbed_souls = int(GameRules.FORMS["ghoul"]["threshold"])
	state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("ghoul")
	state.display_form_id = "skeleton"
	state.skill_levels["ears"] = 1
	_expect(
		state.has_hearing() and state.get_hearing_radius() == 5,
		"An actual Ghoul with Ears must hear at current vision plus one under any display form",
	)
	state.skill_levels["sharp_vision"] = 1
	_expect(
		state.get_vision_radius() == 5 and state.get_hearing_radius() == 6,
		"The one Sharp Vision level must automatically extend hearing through effective vision",
	)
	state.current_form_id = "zombie"
	state.display_form_id = "ghoul"
	_expect(
		not state.has_hearing() and state.get_hearing_radius() == 0,
		"A cosmetic Ghoul must never unlock Ears for an actual Zombie",
	)


func _test_proximity_without_los_or_fog_writes() -> void:
	var contacts := HearingContacts.new()
	var visible := {Vector2i(0, 0): true, Vector2i(1, 0): true}
	var visible_before := visible.duplicate(true)
	var enemies := [
		_enemy("d5", Vector2i(3, 2)),
		_enemy("d6", Vector2i(3, 3)),
		_enemy("visible", Vector2i(1, 0)),
		_enemy("dead", Vector2i(2, 0), 0),
	]
	var result := contacts.sync_proximity(enemies, Vector2i.ZERO, 5, visible)
	_expect(
		contacts.presentation_positions() == [Vector2i(3, 2)]
		and result["new_uids"] == ["d5"],
		"Hearing must use inclusive Manhattan distance and exclude visible/dead enemies",
	)
	_expect(visible == visible_before, "Hearing sync must never mutate visibility/fog dictionaries")
	var revision := contacts.event_revision
	contacts.sync_proximity(enemies, Vector2i.ZERO, 5, visible)
	_expect(contacts.event_revision == revision, "Continuous contacts must not retrigger every sync")
	contacts.sync_proximity([], Vector2i.ZERO, 5, visible)
	contacts.sync_proximity(enemies, Vector2i.ZERO, 5, visible)
	_expect(contacts.event_revision == revision + 1, "Disappearance and re-entry must rearm proximity")


func _test_attack_memory_ttl_and_priority() -> void:
	var contacts := HearingContacts.new()
	contacts.record_hidden_attack("archer", Vector2i(9, 9), 10)
	_expect(
		contacts.presentation_positions() == [Vector2i(9, 9)]
		and contacts.attack_memory_count() == 1,
		"A hidden attack must record its origin even outside hearing range",
	)
	contacts.sync_proximity([_enemy("archer", Vector2i(2, 1))], Vector2i.ZERO, 5, {})
	_expect(
		contacts.presentation_positions() == [Vector2i(2, 1)],
		"Current dynamic proximity position must override stale attack origin for one UID",
	)
	contacts.sync_proximity(
		[_enemy("archer", Vector2i(8, 8))], Vector2i.ZERO, 5,
		{Vector2i(9, 9): true},
	)
	_expect(
		contacts.presentation_positions() == [Vector2i(9, 9)],
		"Attack origin must survive after its living owner leaves proximity",
	)
	contacts.prune_after_round(10)
	_expect(contacts.attack_memory_count() == 1, "Attack memory must survive its attack round")
	contacts.prune_after_round(11)
	_expect(contacts.attack_memory_count() == 0, "Attack memory must expire after the next completed round")


func _test_pruning_and_deduplication() -> void:
	var contacts := HearingContacts.new()
	contacts.record_hidden_attack("a", Vector2i(7, 7), 1)
	contacts.record_hidden_attack("b", Vector2i(7, 7), 1)
	_expect(
		contacts.presentation_positions() == [Vector2i(7, 7)],
		"Multiple hidden attackers on one cell must produce one anonymous marker",
	)
	contacts.sync_proximity([_enemy("a", Vector2i(7, 7))], Vector2i.ZERO, 3, {})
	_expect(
		contacts.attack_memory_count() == 1,
		"Missing enemies must immediately lose their attack memories",
	)
	contacts.sync_proximity([_enemy("a", Vector2i(1, 0))], Vector2i.ZERO, 3, {Vector2i(1, 0): true})
	_expect(contacts.presentation_positions().is_empty(), "Visible owners must clear every hearing source")
	contacts.record_hidden_attack("a", Vector2i(1, 0), 2)
	contacts.remove_uid("a")
	_expect(contacts.presentation_positions().is_empty(), "Explicit removal must clear every source for a UID")
	contacts.clear()
	_expect(
		contacts.event_revision == 0 and contacts.presentation_positions().is_empty(),
		"Context clear must reset all ephemeral hearing state",
	)


func _test_renderer_contracts() -> void:
	_expect(
		Renderer.HEARING_MARKER_RADIUS == 13.0
		and Renderer.HEARING_MARKER_OUTLINE_WIDTH == 2.0
		and Renderer.HEARING_MARKER_FONT_SIZE == 22,
		"Hearing marker geometry must stay fixed in virtual pixels at every dungeon zoom",
	)
	var floor := _floor_fixture()
	var cell := Vector2i(6, 3)
	_expect(
		HearingContacts.is_contact_presented(true, floor, Vector2i(2, 3), cell),
		"An unknown or remembered empty contact cell must remain drawable",
	)
	floor["enemies"] = [_game_enemy("visible", cell, 0, 0, 0)]
	floor["visible_cells"][cell] = true
	_expect(
		not HearingContacts.is_contact_presented(true, floor, Vector2i(2, 3), cell),
		"A visible enemy must suppress an anonymous marker on the same cell",
	)
	floor["enemies"].clear()
	floor["items"] = [{"uid": "chest", "pos": cell, "id": "bone_knife"}]
	_expect(
		not HearingContacts.is_contact_presented(true, floor, Vector2i(2, 3), cell)
		and not HearingContacts.is_contact_presented(true, floor, cell, cell)
		and not HearingContacts.is_contact_presented(false, floor, Vector2i(2, 3), cell),
		"Visible items and the player must suppress a marker without revealing anything else",
	)
	var original_cell_size := Renderer.runtime_cell_size
	for zoom in [44, 66, 88]:
		Renderer.set_runtime_cell_size(zoom)
		_expect(
			Renderer.HEARING_MARKER_RADIUS == 13.0
			and Renderer.HEARING_MARKER_OUTLINE_WIDTH == 2.0,
			"Hearing marker radius/stroke must not scale with cell size %d" % zoom,
		)
	Renderer.set_runtime_cell_size(original_cell_size)


func _test_locked_and_purchase_contract(tree: SceneTree) -> void:
	var main = await _new_main(tree, false)
	main.state.current_form_id = "ghoul"
	main.state.absorbed_souls = int(GameRules.FORMS["ghoul"]["threshold"])
	main.state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("ghoul")
	main.state.hp = main.state.get_max_hp()
	main.player_pos = Vector2i(2, 3)
	main.floor_data = _floor_fixture()
	main.floor_data["enemies"] = [_game_enemy("locked-archer", Vector2i(8, 3), 0, 10, 10)]
	main._update_player_visibility(false)
	main.held_direction = Vector2i.RIGHT
	main.auto_explore_active = true
	main.auto_travel_active = true
	_expect(
		not main._sync_hearing_proximity()
		and main.hearing_contacts.event_revision == 0
		and main.hearing_contacts.presentation_positions().is_empty()
		and main.held_direction == Vector2i.RIGHT
		and main.auto_explore_active and main.auto_travel_active,
		"Locked hearing must create no proximity event or hearing-only automation interruption",
	)
	main.auto_explore_active = false
	main.auto_travel_active = true
	main._log_action("locked hidden attack")
	main._try_enemy_ranged_attack(0, 1)
	main._flush_hidden_attack_hearing_log()
	_expect(
		main.hearing_contacts.event_revision == 0
		and main.hearing_contacts.attack_memory_count() == 0
		and not _history_contains(main, Loc.text("MSG_HEARING_HIDDEN_ATTACK"))
		and main.held_direction == Vector2i.RIGHT
		and not main.auto_explore_active and main.auto_travel_active,
		"A locked hidden miss must keep normal ranged interruption but add no hearing snapshot, log, or route stop",
	)
	main.auto_travel_active = false
	main.floor_data["enemies"][0]["accuracy"] = 100
	main.floor_data["enemies"][0]["damage"] = 1
	main.wait_turn_count = 10
	var hp_before_locked_hit: int = main.state.hp
	var turns_before_locked_hit: int = main.state.total_turns
	main._on_wait_pressed()
	_expect(
		main.state.total_turns == turns_before_locked_hit + 1
		and main.state.hp == hp_before_locked_hit - 1
		and _latest_history_text(main) == Loc.text("MSG_WAIT_INTERRUPTED_HP", [1])
		and main.hearing_contacts.event_revision == 0
		and not _history_contains(main, Loc.text("MSG_HEARING_HIDDEN_ATTACK")),
		"Locked hearing must not change real damage or HP-loss interruption from a hidden hit",
	)
	main.hearing_contacts.record_hidden_attack("stale-locked", Vector2i(7, 3), main.state.total_turns)
	main.inspected_target = {"kind": "noise", "pos": Vector2i(7, 3)}
	main._refresh_dungeon_viewport()
	_expect(
		main.hearing_contacts.event_revision == 0
		and main.hearing_contacts.presentation_positions().is_empty()
		and main.inspected_target.is_empty(),
		"Locked presentation refresh must clear stale pre-unlock contacts and noise inspection",
	)
	main.floor_data["enemies"].clear()
	main.hearing_contacts.record_hidden_attack("stale-wait", Vector2i(7, 3), main.state.total_turns)
	main.auto_travel_active = false
	main.wait_turn_count = 10
	var turns_before_locked_wait: int = main.state.total_turns
	main._on_wait_pressed()
	_expect(
		main.state.total_turns == turns_before_locked_wait + 10
		and _latest_history_text(main) == Loc.text("MSG_WAIT_COMPLETED", [10])
		and main.hearing_contacts.event_revision == 0,
		"Locked long wait must ignore and clear stale hearing revision without a hearing interruption",
	)

	main.floor_data["enemies"] = [_game_enemy("purchase-nearby", Vector2i(7, 3), 0, 0, 0)]
	main.state.banked_souls = 20
	main.screen = main.Screen.DUNGEON
	main._show_character()
	main._on_skill_purchase_pressed("ears")
	_expect(
		main.state.get_skill_level("ears") == 1 and main.state.get_total_souls() == 0
		and main.state.has_hearing() and main.state.get_hearing_radius() == 5
		and main.hearing_contacts.event_revision == 1
		and main.hearing_contacts.presentation_positions() == [Vector2i(7, 3)]
		and _history_contains(main, Loc.text("MSG_HEARING_MOVEMENT")),
		"Buying Ears in a dungeon must cost 20 souls and immediately sync current nearby noise",
	)
	var restored := RunState.new()
	_expect(
		restored.restore_save_data(main.state.to_save_data())
		and restored.get_skill_level("ears") == 1 and restored.has_hearing(),
		"Learned Ears must round-trip additively in save version 13",
	)
	var legacy_source := RunState.new()
	legacy_source.configure_character("Legacy Listener", GameRules.default_attributes())
	var legacy_data := legacy_source.to_save_data()
	legacy_data["current_form_id"] = "ghoul"
	legacy_data["absorbed_souls"] = int(GameRules.FORMS["ghoul"]["threshold"])
	legacy_data["highest_unlocked_form_index"] = GameRules.FORM_ORDER.find("ghoul")
	var legacy := RunState.new()
	_expect(
		legacy.restore_save_data(legacy_data)
		and legacy.get_skill_level("ears") == 0
		and not legacy.has_hearing() and legacy.get_hearing_radius() == 0,
		"Legacy saves must never receive Ears automatically",
	)
	main.queue_free()
	await tree.process_frame


func _test_main_turn_input_and_automation(tree: SceneTree) -> void:
	var main = await _new_main(tree)
	main.player_pos = Vector2i(2, 3)
	main.floor_data = _floor_fixture()
	main.floor_data["enemies"] = [_game_enemy("hidden_archer", Vector2i(8, 3), 0, 10, 10)]
	main._update_player_visibility(false)
	_expect(
		main.hearing_contacts.presentation_positions().is_empty(),
		"An enemy at Manhattan six must begin beyond base hearing",
	)

	main._log_action("fixture")
	var turns_before_wait: int = main.state.total_turns
	main.wait_turn_count = 10
	main._on_wait_pressed()
	_expect(
		main.state.total_turns == turns_before_wait + 1
		and main.hearing_contacts.attack_memory_count() == 1,
		"A hidden attack during Wait 10 must finish exactly the current turn and then interrupt",
	)
	_expect(
		_history_contains(main, Loc.text("MSG_HEARING_HIDDEN_ATTACK"))
		and _history_semantic_for_text(main, Loc.text("MSG_HEARING_HIDDEN_ATTACK")) == "incoming"
		and _latest_history_text(main) == Loc.text("MSG_WAIT_INTERRUPTED_RANGED", [1]),
		"A hidden ranged miss must preserve incoming semantics and the ranged wait priority",
	)
	main.action_history.clear()
	main.floor_data["enemies"][0]["accuracy"] = 100
	main.floor_data["enemies"][0]["damage"] = 1
	var hp_before_hit_wait: int = main.state.get_effective_health()
	var turns_before_hundred_wait: int = main.state.total_turns
	main.wait_turn_count = 100
	main._on_wait_pressed()
	_expect(
		main.state.total_turns == turns_before_hundred_wait + 1
		and main.state.get_effective_health() == hp_before_hit_wait - 1
		and _latest_history_text(main) == Loc.text("MSG_WAIT_INTERRUPTED_HP", [1]),
		"A hidden ranged hit must preserve HP-loss priority over ranged and hearing reasons",
	)

	# A moving melee enemy can create a pure hearing event without damage or a
	# ranged attack; that event must still stop a multi-turn wait.
	main.action_history.clear()
	main._clear_hearing_context()
	main.floor_data["enemies"] = [_melee_enemy("heard-only", Vector2i(8, 3), 10)]
	main._update_player_visibility(false)
	var hp_before_hearing_wait: int = main.state.get_effective_health()
	var turns_before_hearing_wait: int = main.state.total_turns
	main.wait_turn_count = 10
	main._on_wait_pressed()
	_expect(
		main.state.total_turns == turns_before_hearing_wait + 1
		and main.state.get_effective_health() == hp_before_hearing_wait
		and _latest_history_text(main) == Loc.text("MSG_WAIT_INTERRUPTED_HEARING", [1]),
		"A pure newly-heard movement event must retain the hearing wait reason",
	)
	main.floor_data["enemies"] = [_game_enemy("hidden_archer", Vector2i(8, 3), 0, 10, 10)]

	var revision_after_miss: int = main.hearing_contacts.event_revision
	main.floor_data["enemies"][0]["accuracy"] = 100
	main.floor_data["enemies"][0]["damage"] = 0
	main._try_enemy_ranged_attack(0, 20)
	_expect(
		main.hearing_contacts.event_revision == revision_after_miss + 1,
		"Both hidden misses and hidden hits must refresh the attack memory event",
	)
	var attack_origin := Vector2i(8, 3)
	main.floor_data["enemies"][0]["pos"] = Vector2i(9, 3)
	main.floor_data["enemies"][0]["vision"] = 0
	main.floor_data["enemies"][0]["range"] = 0
	main._sync_hearing_proximity()
	_expect(
		main.hearing_contacts.presentation_positions() == [attack_origin],
		"Attack memory must retain an exact origin while its hidden owner moves away",
	)

	var turn_before_noise_click: int = main.state.total_turns
	await _send_viewport_mouse_cell(main, tree, attack_origin)
	_expect(
		main.state.total_turns == turn_before_noise_click
		and main.inspected_target == {"kind": "noise", "pos": attack_origin}
		and main._get_inspection_target().get("kind", "") == "noise",
		"Clicking an exact contact must create only anonymous noise inspection and spend no turn",
	)

	# Raw stale contacts hidden under visible subjects are not presented and must
	# not intercept the real mouse/touch behavior for those subjects.
	var visible_enemy_cell := Vector2i(3, 3)
	main.floor_data["enemies"] = [_game_enemy("visible-subject", visible_enemy_cell, 0, 0, 0)]
	main.floor_data["visible_cells"][visible_enemy_cell] = true
	main.hearing_contacts.record_hidden_attack(
		"stale-under-enemy", visible_enemy_cell, main.state.total_turns,
	)
	var turn_before_enemy_mouse: int = main.state.total_turns
	await _send_viewport_mouse_cell(main, tree, visible_enemy_cell)
	_expect(
		main.state.total_turns == turn_before_enemy_mouse + 1
		and String(main.inspected_target.get("kind", "")) == "enemy",
		"A mouse click on a visible enemy must win over a suppressed raw hearing contact",
	)
	var visible_item_cell := Vector2i(5, 4)
	main.floor_data["items"] = [{
		"uid": "visible-item", "pos": visible_item_cell, "id": "bone_knife",
		"wood": 0, "stone": 0,
	}]
	main.floor_data["visible_cells"][visible_item_cell] = true
	main.floor_data["observed_cells"][visible_item_cell] = true
	main.hearing_contacts.record_hidden_attack(
		"stale-under-item", visible_item_cell, main.state.total_turns,
	)
	var turn_before_item_touch: int = main.state.total_turns
	await _send_viewport_touch_cell(main, tree, visible_item_cell)
	_expect(
		main.state.total_turns == turn_before_item_touch
		and String(main.inspected_target.get("kind", "")) == "item",
		"A touch on a visible item must win over a suppressed raw hearing contact",
	)
	main.hearing_contacts.record_hidden_attack("stale-under-player", main.player_pos, main.state.total_turns)
	main.inspected_target = {"kind": "noise", "pos": main.player_pos}
	var resolved_player_noise: Dictionary = main._get_inspection_target()
	_expect(
		main.inspected_target.is_empty()
		and String(resolved_player_noise.get("kind", "")) != "noise",
		"A contact suppressed by the player must not revalidate anonymous noise inspection",
	)
	main.floor_data["items"].clear()
	main.floor_data["enemies"] = [_game_enemy("hidden_archer", Vector2i(9, 3), 0, 0, 0)]
	var fallback_noise_cell := Vector2i(8, 3)
	main.hearing_contacts.record_hidden_attack(
		"selected-noise", fallback_noise_cell, main.state.total_turns,
	)
	main.inspected_target = {"kind": "noise", "pos": fallback_noise_cell}
	var visible_decoy := _game_enemy("visible-decoy", Vector2i(3, 3), 0, 0, 0)
	main.floor_data["enemies"].append(visible_decoy)
	main.floor_data["visible_cells"][Vector2i(3, 3)] = true
	main.state.loadout["right_hand"] = "bone_bow@0"
	main.state.skill_levels["magic_awakening"] = 1
	main.state.skill_levels["magic_missile"] = 1
	main.state.mana = main.state.get_max_mana()
	var mana_before_noise_cast: int = main.state.mana
	_expect(
		main._resolve_adjacent_enemy_uid().is_empty()
		and not bool(main._resolve_ranged_target().get("ok", false))
		and not main._cast_magic_missile()
		and main.state.mana == mana_before_noise_cast,
		"A selected noise contact must block melee/ranged/magic fallback to a different visible enemy",
	)
	main.floor_data["enemies"].pop_back()
	var memory_before_noop: int = main.hearing_contacts.attack_memory_count()
	main.ability_targeting_id = "dash"
	main._cancel_ability_targeting(false)
	var noop_turn: int = main.state.total_turns
	var noop_result: bool = main._attempt_player_action(Vector2i(-2, 0))
	_expect(
		not noop_result and main.state.total_turns == noop_turn
		and main.hearing_contacts.attack_memory_count() == memory_before_noop,
		"Cancel and rejected wall actions must not tick or expire attack memories",
	)

	var revision_before_overlays: int = main.hearing_contacts.event_revision
	var memories_before_overlays: int = main.hearing_contacts.attack_memory_count()
	main._open_main_menu()
	main._resume_from_main_menu()
	main._show_character()
	main._close_character()
	_expect(
		main.hearing_contacts.event_revision == revision_before_overlays
		and main.hearing_contacts.attack_memory_count() == memories_before_overlays,
		"Menus and Character must neither clear nor expire hearing memory",
	)

	# The next completed round expires an unrefreshed origin only after its enemy phase.
	main._log_action("expiry")
	main._complete_player_turn()
	_expect(
		main.hearing_contacts.attack_memory_count() == 0,
		"An unrefreshed attack origin must expire after the next complete enemy response",
	)

	# A newly continuous contact interrupts all repeating movement modes, but the
	# single manual move that caused it still commits its normal turn.
	main._clear_hearing_context()
	main.player_pos = Vector2i(2, 3)
	main.floor_data["enemies"] = [_game_enemy("approach", Vector2i(8, 3), 0, 0, 0)]
	main._update_player_visibility(false)
	main.held_direction = Vector2i.RIGHT
	main.auto_explore_active = true
	main.auto_travel_active = true
	var turns_before_move: int = main.state.total_turns
	var moved: bool = main._attempt_player_action(Vector2i.RIGHT)
	_expect(
		moved and main.player_pos == Vector2i(3, 3)
		and main.state.total_turns == turns_before_move + 1,
		"The manual action that discovers a hearing contact must still complete normally",
	)
	_expect(
		main.held_direction == Vector2i.ZERO
		and not main.auto_explore_active and not main.auto_travel_active,
		"A new proximity contact must stop held keyboard/gamepad movement and both automatic routes",
	)

	main.hearing_contacts.record_hidden_attack("clear-me", Vector2i(7, 7), main.state.total_turns)
	main.screen = main.Screen.DUNGEON
	main.player_pos = Vector2i(2, 3)
	main.floor_data["enemies"] = [_game_enemy("sharp-heard", Vector2i(8, 3), 0, 0, 0)]
	main.hearing_contacts.clear()
	main.state.skill_levels["sharp_vision"] = 0
	main._update_player_visibility(false)
	_expect(main.hearing_contacts.presentation_positions().is_empty(), "Distance six must be silent before Sharp Vision")
	main._show_character()
	main.state.skill_levels["sharp_vision"] = 1
	main._update_player_visibility(false)
	_expect(
		main.hearing_contacts.presentation_positions() == [Vector2i(8, 3)],
		"Sharp Vision learned from Character must immediately refresh effective hearing",
	)
	main._close_character()
	main.hearing_contacts.record_hidden_attack("clear-me", Vector2i(7, 7), main.state.total_turns)
	main._show_base("base", "none")
	_expect(main.hearing_contacts.presentation_positions().is_empty(), "Returning to base must clear hearing context")
	main.screen = main.Screen.DUNGEON
	main.hearing_contacts.record_hidden_attack("old-floor", Vector2i(7, 7), main.state.total_turns)
	main._load_floor(99)
	_expect(
		main.hearing_contacts.attack_memory_count() == 0,
		"Floor load must clear old attack snapshots before recomputing current proximity",
	)
	main.hearing_contacts.record_hidden_attack("victory", Vector2i(7, 7), main.state.total_turns)
	main._show_victory()
	_expect(main.hearing_contacts.presentation_positions().is_empty(), "Victory must clear hearing context")
	main.hearing_contacts.record_hidden_attack("new-game", Vector2i(7, 7), main.state.total_turns)
	main._reset_for_new_character()
	_expect(main.hearing_contacts.presentation_positions().is_empty(), "New game must clear hearing context")
	main.hearing_contacts.record_hidden_attack("death", Vector2i(7, 7), main.state.total_turns)
	main._handle_death()
	_expect(main.hearing_contacts.presentation_positions().is_empty(), "Death must clear hearing context")
	main.queue_free()
	await tree.process_frame


func _new_main(tree: SceneTree, with_hearing := true):
	var packed := load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate()
	main.persistence_enabled = false
	tree.root.add_child(main)
	await tree.process_frame
	main.main_menu_open = false
	main.save_menu_panel.close()
	main.screen = main.Screen.DUNGEON
	main.state = RunState.new()
	main.state.configure_character("Hearing Test", GameRules.default_attributes())
	if with_hearing:
		main.state.current_form_id = "ghoul"
		main.state.absorbed_souls = int(GameRules.FORMS["ghoul"]["threshold"])
		main.state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("ghoul")
		main.state.skill_levels["ears"] = 1
		main.state.hp = main.state.get_max_hp()
	main._apply_dungeon_layout(true)
	return main


func _floor_fixture() -> Dictionary:
	var tiles := {}
	for y in range(8):
		for x in range(12):
			tiles[Vector2i(x, y)] = "floor" if x > 0 and x < 11 and y > 0 and y < 7 else "wall"
	return {
		"width": 12, "height": 8, "tiles": tiles,
		"start": Vector2i(2, 3), "base_gate": Vector2i(1, 1), "exit": Vector2i(10, 6),
		"exit_known": false, "cradle": Vector2i(-1, -1), "cradle_known": false,
		"cradle_pity_resolved": true, "cradle_used": false,
		"items": [], "enemies": [], "visible_cells": {}, "explored_cells": {},
		"observed_cells": {},
	}


func _game_enemy(uid: String, pos: Vector2i, damage: int, vision: int, attack_range: int) -> Dictionary:
	return {
		"uid": uid, "id": "skeletal_archer", "pos": pos,
		"hp": 4, "max_hp": 4, "damage": damage, "accuracy": -100, "dodge": 0,
		"vision": vision, "souls": 1, "attack_type": "ranged", "range": attack_range,
		"has_seen_player": true, # Hidden-attack tests begin with an alerted shooter.
	}


func _melee_enemy(uid: String, pos: Vector2i, vision: int) -> Dictionary:
	return {
		"uid": uid, "id": "grave_rat", "pos": pos,
		"hp": 2, "max_hp": 2, "damage": 0, "accuracy": -100, "dodge": 0,
		"vision": vision, "souls": 1,
		"has_seen_player": true,
	}


func _send_viewport_mouse_cell(main, tree: SceneTree, cell: Vector2i) -> void:
	main._refresh_dungeon_viewport()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = (
		main.dungeon_viewport.world_to_screen_center(cell)
		- main.dungeon_viewport.global_position
	)
	main.dungeon_viewport._gui_input(event)
	await tree.process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = event.position
	main.dungeon_viewport._gui_input(release)
	await tree.process_frame


func _send_viewport_touch_cell(main, tree: SceneTree, cell: Vector2i) -> void:
	main._refresh_dungeon_viewport()
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = true
	event.position = (
		main.dungeon_viewport.world_to_screen_center(cell)
		- main.dungeon_viewport.global_position
	)
	main.dungeon_viewport._gui_input(event)
	await tree.process_frame
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = event.position
	main.dungeon_viewport._gui_input(release)
	await tree.process_frame


func _enemy(uid: String, pos: Vector2i, hp := 1) -> Dictionary:
	return {"uid": uid, "pos": pos, "hp": hp}


func _latest_history_text(main) -> String:
	return (
		"" if main.action_history.is_empty()
		else main.action_entry_plain_text(main.action_history[0])
	)


func _history_contains(main, text: String) -> bool:
	for entry in main.action_history:
		if main.action_entry_plain_text(entry).contains(text):
			return true
	return false


func _history_semantic_for_text(main, text: String) -> String:
	for entry in main.action_history:
		for segment in main.action_entry_segments(entry):
			if String(segment.get("text", "")).contains(text):
				return String(segment.get("semantic", ""))
	return ""


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
