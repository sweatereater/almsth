class_name BodySkillTestSuite
extends RefCounted

const Rules := preload("res://scripts/game/game_rules.gd")

var failures: Array[String] = []


func run() -> Array[String]:
	failures.clear()
	_test_effective_attributes_and_real_body_gates()
	_test_purchase_prices_and_one_time_effects()
	_test_rest_preparation_and_strict_semantics()
	return failures


func _test_effective_attributes_and_real_body_gates() -> void:
	var state := RunState.new()
	state.configure_character("Body Skills", Rules.default_attributes())
	state.skill_levels["strong_bones"] = 5
	state.skill_levels["flexible_joints"] = 1
	state.skill_levels["strong_spine"] = 1
	state.skill_levels["sharp_vision"] = 1
	state.skill_levels["muscle_fibers"] = 2
	state.skill_levels["stomach"] = 1
	state.skill_levels["flesh_regeneration"] = 1
	state.skill_levels["ears"] = 1
	state.skill_levels["nervous_system"] = 1
	state.current_form_id = "skeleton"
	state.display_form_id = "almost_human"
	var skeleton_effective := state.get_effective_attributes()
	_expect(
		state.attributes == Rules.default_attributes()
		and skeleton_effective.agility == 3
		and skeleton_effective.vitality == 2
		and skeleton_effective.strength == 1,
		"Effective body attributes must not mutate base attributes and must ignore later-stage skills on a Skeleton body",
	)
	_expect(state.get_max_hp() == 25, "Five Sturdy Bones levels must grant exactly +15 max HP")
	_expect(
		state.get_vision_radius() == Rules.PLAYER_VISION_BASE_RADIUS
		and not state.uses_hunger() and not state.has_hearing()
		and not state.has_regeneration_skill() and not state.has_nervous_system(),
		"Cosmetic appearance must not activate later-stage body mechanics",
	)

	state.current_form_id = "zombie"
	var zombie_effective := state.get_effective_attributes()
	_expect(
		zombie_effective.strength == 3
		and zombie_effective.agility == 3
		and zombie_effective.vitality == 2,
		"Two Muscle Fibers levels must add exactly +2 effective Strength on a real Zombie body",
	)
	_expect(
		state.get_vision_radius() == Rules.PLAYER_VISION_BASE_RADIUS + 1
		and not state.has_regeneration_skill(),
		"Sharp Vision must add exactly one cell on Zombie while Ghoul regeneration stays inactive",
	)

	state.current_form_id = "ghoul"
	_expect(
		state.uses_hunger() and state.has_hearing() and state.has_regeneration_skill()
		and not state.has_nervous_system(),
		"Stomach, Circulatory System and Ears must activate on Ghoul while Nervous System waits for Revenant",
	)
	state.current_form_id = "revenant"
	_expect(state.has_nervous_system(), "A learned Nervous System must activate on the real Revenant body")


func _test_purchase_prices_and_one_time_effects() -> void:
	var bones := RunState.new()
	bones.configure_character("Bones", Rules.default_attributes())
	bones.carried_souls = 100
	var costs: Array[int] = []
	for _index in range(5):
		var purchase: Dictionary = bones.purchase_skill("strong_bones")
		_expect(bool(purchase.get("ok", false)), "Each approved Sturdy Bones level must be purchasable")
		costs.append(int(purchase.get("cost", -1)))
	_expect(costs == [5, 10, 15, 20, 25], "Sturdy Bones prices must be exactly 5/10/15/20/25")
	_expect(bones.purchase_skill("strong_bones").get("reason") == "max_level", "Sturdy Bones must stop at level 5")

	var almost := _state_at_form("almost_human")
	almost.carried_souls = 10
	almost.banked_souls = 50
	var base_attributes := almost.attributes.duplicate(true)
	var first: Dictionary = almost.purchase_skill("fundamentals")
	_expect(
		first == {"ok": true, "level": 1, "cost": 25}
		and almost.carried_souls == 0 and almost.banked_souls == 35
		and almost.unspent_attribute_points == 5 and almost.attributes == base_attributes,
		"Fundamentals must spend carried souls first and grant exactly five free points without changing base attributes",
	)
	var second: Dictionary = almost.purchase_skill("fundamentals")
	_expect(
		second.get("reason") == "max_level" and almost.unspent_attribute_points == 5,
		"Fundamentals must grant its five points exactly once",
	)


func _test_rest_preparation_and_strict_semantics() -> void:
	var late_purchase := _state_at_form("revenant")
	late_purchase.banked_souls = 200
	late_purchase.lifetime_souls_earned = 1000
	late_purchase.safe_return()
	_expect(
		late_purchase.camp_preparation.pending and not late_purchase.camp_preparation.rested,
		"A safe return without Nervous System must not prepare Rested",
	)
	_expect(bool(late_purchase.purchase_skill("nervous_system").get("ok", false)), "Nervous System must be purchasable at the Revenant stage")
	_expect(
		not late_purchase.camp_preparation.rested,
		"Buying Nervous System after the safe return must not grant Rested preparation retroactively",
	)
	var late_data := late_purchase.to_save_data()
	_expect(
		RunState.is_stage1_save_data_valid(late_data),
		"Strict v18 validation must allow an eligible preparation field to remain false",
	)

	var unauthorized := _state_at_form("revenant")
	unauthorized.lifetime_souls_earned = 1000
	unauthorized.safe_return()
	unauthorized.camp_preparation.rested = true
	_expect(
		not RunState.is_stage1_save_data_valid(unauthorized.to_save_data()),
		"Strict v18 validation must reject Rested preparation without a learned Nervous System",
	)
	unauthorized.camp_preparation.rested = false
	unauthorized.add_or_refresh_status("rested")
	_expect(
		not RunState.is_stage1_save_data_valid(unauthorized.to_save_data()),
		"Strict v18 validation must reject an active Rested status without entitlement",
	)

	var entitled := _state_at_form("revenant")
	entitled.skill_levels["nervous_system"] = 1
	entitled.safe_return()
	_expect(entitled.camp_preparation.rested, "A learned Nervous System and real Revenant body must prepare Rested on safe return")
	entitled.grant_departure_preparation()
	_expect(entitled.has_status("rested"), "Eligible departure preparation must grant the existing Rested status")


func _state_at_form(form_id: String) -> RunState:
	var state := RunState.new()
	state.configure_character("Body Fixture", Rules.default_attributes())
	state.current_form_id = form_id
	state.absorbed_souls = int(Rules.FORMS[form_id]["threshold"])
	state.highest_unlocked_form_index = Rules.FORM_ORDER.find(form_id)
	state.soul_level = maxi(0, Rules.required_soul_level(form_id) - 1)
	state.lifetime_souls_earned = state.absorbed_souls
	state.hp = state.get_max_hp()
	state.mana = state.get_max_mana()
	return state


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
