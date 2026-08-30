class_name RunState
extends RefCounted

const Loc := preload("res://scripts/localization/localization.gd")
const AbilitySystem := preload("res://scripts/game/skill_system.gd")
const StatusSystem := preload("res://scripts/game/status_system.gd")

## Persistent state and current-run state are kept together for the prototype,
## but all transitions happen through methods so they can be split later.

var banked_souls := 0
var carried_souls := 0
var absorbed_souls := 0
## Monotonic total awarded through add_souls(). Older saves cannot reconstruct souls
## already spent at the base, so their banked + carried + absorbed sum is a safe lower bound.
var lifetime_souls_earned := 0
var character_name := ""
var attributes := GameRules.default_attributes()
var current_form_id := "skeleton"
## Optional cosmetic override. Empty means the appearance follows current_form_id.
## Gameplay rules must continue to read current_form_id/get_form(), never this field.
var display_form_id := ""
## Permanent progression gate for body evolution. Death never reduces it.
var soul_level := GameRules.SOUL_LEVEL_START
var base_level := 0
var checkpoint_floor := 100
## Lowest-numbered floor (closest to the surface) from which the player has
## safely returned. Floor 100 is the sentinel for an unused rope.
var rope_floor := 100
var current_floor := 99
var hp := 1
var mana := 0
var loadout: Dictionary = {
	GameRules.PERMANENT_JACKET_SLOT_ID: GameRules.permanent_jacket_key(),
}
## Unequipped items are stacked by their stable key (for example bone_knife@2).
## Equipment worn by the character lives in loadout and is therefore not
## duplicated in the inventory count.
var inventory: Dictionary = {}
var resources := {
	"wood": 0,
	"stone": 0,
	"cloth": 0,
}
var camp_upgrades := {
	"crusher": false,
	"whetstone": false,
	"ritual_table": false,
	"campfire": false,
}
var skill_levels: Dictionary = GameRules.default_skill_levels()
var ability_loadout: Dictionary = AbilitySystem.default_loadout()
var ability_cooldowns: Dictionary = {}
var active_statuses: Dictionary = {}
var unspent_attribute_points := 0
var highest_unlocked_form_index := 0
var food := 0
var hunger := 100
var hunger_turn_progress := 0
var regeneration_progress := 0
var mana_regeneration_progress := 0.0
var total_turns := 0
var cradle_miss_streak := 0


func _init() -> void:
	hp = get_max_hp()
	mana = get_max_mana()


func get_form() -> Dictionary:
	return GameRules.get_form(current_form_id)


func configure_character(name_value: String, attribute_values: Dictionary) -> void:
	character_name = name_value.strip_edges()
	attributes = attribute_values.duplicate(true)
	_ensure_permanent_jacket()
	hp = get_max_hp()
	mana = get_max_mana()


func to_save_data() -> Dictionary:
	_ensure_permanent_jacket()
	return {
		"character_name": character_name,
		"attributes": attributes.duplicate(true),
		"banked_souls": banked_souls,
		"carried_souls": carried_souls,
		"absorbed_souls": absorbed_souls,
		"lifetime_souls_earned": maxi(
			lifetime_souls_earned, banked_souls + carried_souls + absorbed_souls,
		),
		"base_level": base_level,
		"checkpoint_floor": checkpoint_floor,
		"rope_floor": rope_floor,
		"current_form_id": current_form_id,
		"display_form_id": display_form_id,
		"soul_level": maxi(soul_level, _minimum_soul_level_for_progress()),
		"hp": hp,
		"mana": mana,
		"loadout": loadout.duplicate(true),
		"inventory": inventory.duplicate(true),
		"resources": resources.duplicate(true),
		"camp_upgrades": camp_upgrades.duplicate(true),
		"skill_levels": _complete_skill_levels(),
		"ability_loadout": AbilitySystem.sanitize_loadout(ability_loadout, skill_levels),
		"ability_cooldowns": AbilitySystem.sanitize_cooldowns(ability_cooldowns),
		"active_statuses": StatusSystem.sanitize(active_statuses),
		"unspent_attribute_points": unspent_attribute_points,
		"highest_unlocked_form_index": highest_unlocked_form_index,
		"food": food,
		"hunger": hunger,
		"hunger_turn_progress": hunger_turn_progress,
		"regeneration_progress": regeneration_progress,
		"mana_regeneration_progress": mana_regeneration_progress,
		"total_turns": total_turns,
		"cradle_miss_streak": cradle_miss_streak,
	}


func _complete_skill_levels() -> Dictionary:
	var result := GameRules.default_skill_levels()
	for skill_id in GameRules.SKILLS:
		result[skill_id] = clampi(
			int(skill_levels.get(skill_id, 0)),
			0,
			int(GameRules.SKILLS[skill_id]["max_level"]),
		)
	return result


func _minimum_soul_level_for_progress(use_permanent_bonus := true) -> int:
	var highest_index := clampi(highest_unlocked_form_index, 0, GameRules.FORM_ORDER.size() - 1)
	var highest_form_id: String = GameRules.FORM_ORDER[highest_index]
	var jacket_bonus := (
		int(GameRules.EQUIPMENT[GameRules.PERMANENT_JACKET_ITEM_ID].get("soul_level_bonus", 0))
		if use_permanent_bonus else 0
	)
	return maxi(
		maxi(
			maxi(GameRules.SOUL_LEVEL_START, GameRules.required_soul_level(current_form_id) - jacket_bonus),
			maxi(GameRules.SOUL_LEVEL_START, GameRules.required_soul_level(highest_form_id) - jacket_bonus),
		),
		GameRules.SOUL_LEVEL_START + (
			GameRules.CAMPFIRE_SOUL_LEVEL_BONUS
			if bool(camp_upgrades.get("campfire", false)) else 0
		),
	)


func restore_save_data(data: Dictionary) -> bool:
	var restored_name := String(data.get("character_name", "")).strip_edges()
	if restored_name.is_empty():
		return false
	character_name = restored_name.left(24)
	var restored_attributes: Dictionary = GameRules.default_attributes()
	var saved_attributes = data.get("attributes", {})
	if saved_attributes is Dictionary:
		for attribute_id in GameRules.ATTRIBUTE_ORDER:
			restored_attributes[attribute_id] = maxi(
				GameRules.STARTING_ATTRIBUTE_VALUE,
				int(saved_attributes.get(attribute_id, GameRules.STARTING_ATTRIBUTE_VALUE)),
			)
	attributes = restored_attributes
	banked_souls = maxi(0, int(data.get("banked_souls", 0)))
	carried_souls = maxi(0, int(data.get("carried_souls", 0)))
	absorbed_souls = maxi(0, int(data.get("absorbed_souls", 0)))
	lifetime_souls_earned = maxi(
		banked_souls + carried_souls + absorbed_souls,
		int(data.get(
			"lifetime_souls_earned",
			banked_souls + carried_souls + absorbed_souls,
		)),
	)
	base_level = maxi(0, int(data.get("base_level", 0)))
	checkpoint_floor = clampi(int(data.get("checkpoint_floor", 100)), 1, 100)
	rope_floor = clampi(int(data.get("rope_floor", 100)), 1, 100)
	current_floor = 100
	current_form_id = GameRules.form_for_absorbed_souls(absorbed_souls)
	highest_unlocked_form_index = clampi(
		maxi(
			GameRules.FORM_ORDER.find(current_form_id),
			int(data.get("highest_unlocked_form_index", 0)),
		),
		0,
		GameRules.FORM_ORDER.size() - 1,
	)
	skill_levels = GameRules.default_skill_levels()
	var saved_skills = data.get("skill_levels", {})
	if saved_skills is Dictionary:
		for skill_id in GameRules.SKILLS:
			skill_levels[skill_id] = clampi(
				int(saved_skills.get(skill_id, 0)),
				0,
				int(GameRules.SKILLS[skill_id]["max_level"]),
			)
	ability_loadout = AbilitySystem.sanitize_loadout(
		data.get("ability_loadout", null),
		skill_levels,
	)
	ability_cooldowns = AbilitySystem.sanitize_cooldowns(data.get("ability_cooldowns", {}))
	active_statuses = StatusSystem.sanitize(data.get("active_statuses", {}))
	display_form_id = String(data.get("display_form_id", ""))
	if (
		display_form_id == current_form_id
		or not available_display_form_ids().has(display_form_id)
		or get_skill_level("choose_appearance") <= 0
	):
		display_form_id = ""
	unspent_attribute_points = maxi(0, int(data.get("unspent_attribute_points", 0)))
	food = maxi(0, int(data.get("food", 0)))
	hunger = clampi(int(data.get("hunger", 100)), 0, 100)
	hunger_turn_progress = clampi(int(data.get("hunger_turn_progress", 0)), 0, 9)
	regeneration_progress = maxi(0, int(data.get("regeneration_progress", 0)))
	mana_regeneration_progress = maxf(0.0, float(data.get("mana_regeneration_progress", 0.0)))
	total_turns = maxi(0, int(data.get("total_turns", 0)))
	cradle_miss_streak = maxi(0, int(data.get("cradle_miss_streak", 0)))
	resources = {"wood": 0, "stone": 0, "cloth": 0}
	var saved_resources = data.get("resources", {})
	if saved_resources is Dictionary:
		for resource_id in resources:
			resources[resource_id] = maxi(0, int(saved_resources.get(resource_id, 0)))
	camp_upgrades = {
		"crusher": false,
		"whetstone": false,
		"ritual_table": false,
		"campfire": false,
	}
	var saved_camp_upgrades = data.get("camp_upgrades", {})
	if saved_camp_upgrades is Dictionary:
		for upgrade_id in camp_upgrades:
			camp_upgrades[upgrade_id] = bool(saved_camp_upgrades.get(upgrade_id, false))
	# Soul Level was introduced after camp/highest-form persistence. Presence-aware
	# migration prevents a built Campfire from granting its one-time bonus on every load.
	# Saves that already serialize Soul Level store the raw permanent value. Their
	# progress floor is reduced by the canonical jacket bonus so a reload never
	# turns an effective level N into N + 1. Older saves without the field retain
	# the previous safe raw minimum, then receive the jacket bonus exactly once.
	var minimum_soul_level := _minimum_soul_level_for_progress(data.has("soul_level"))
	soul_level = maxi(
		minimum_soul_level,
		int(data.get("soul_level", minimum_soul_level)) if data.has("soul_level") else minimum_soul_level,
	)
	inventory.clear()
	var saved_inventory = data.get("inventory", {})
	if saved_inventory is Dictionary:
		for saved_key in saved_inventory:
			var item_key := _sanitized_item_key(String(saved_key))
			var count := maxi(0, int(saved_inventory[saved_key]))
			if not item_key.is_empty() and GameRules.is_item_movable(item_key) and count > 0:
				inventory[item_key] = int(inventory.get(item_key, 0)) + count
	loadout.clear()
	var saved_loadout = data.get("loadout", {})
	if saved_loadout is Dictionary:
		var restore_order: Array[String] = []
		for physical_slot in GameRules.EQUIPMENT_SLOT_ORDER:
			if saved_loadout.has(physical_slot):
				restore_order.append(physical_slot)
		for legacy_slot in ["weapon", "offhand", "charm", "armor", "hands", "mutation", "relic"]:
			if saved_loadout.has(legacy_slot) and not restore_order.has(legacy_slot):
				restore_order.append(legacy_slot)
		for saved_slot in saved_loadout:
			if not restore_order.has(String(saved_slot)):
				restore_order.append(String(saved_slot))
		for saved_slot in restore_order:
			var item_key := _sanitized_item_key(String(saved_loadout.get(saved_slot, "")))
			if item_key.is_empty():
				continue
			if GameRules.base_item_id(item_key) == GameRules.PERMANENT_JACKET_ITEM_ID:
				continue
			var destination := (
				saved_slot
				if GameRules.EQUIPMENT_SLOTS.has(saved_slot)
				else String(GameRules.LEGACY_SLOT_MIGRATION.get(saved_slot, ""))
			)
			if (
				not destination.is_empty()
				and GameRules.is_slot_unlocked(current_form_id, destination)
				and GameRules.item_fits_slot(item_key, destination)
				and not loadout.has(destination)
			):
				loadout[destination] = item_key
			else:
				add_item_key(item_key)
	_ensure_permanent_jacket()
	hp = clampi(int(data.get("hp", get_max_hp())), 1, get_max_hp())
	mana = clampi(int(data.get("mana", get_max_mana())), 0, get_max_mana())
	return true


func get_derived_stats() -> Dictionary:
	var result := GameRules.calculate_derived_stats(attributes, current_form_id, loadout, base_level)
	result["max_hp"] += get_skill_level("strong_bones") * 3
	result["mana"] += get_skill_level("magic_awakening") * 5
	result["damage"] += StatusSystem.modifier(active_statuses, "damage")
	result["ranged_damage"] += StatusSystem.modifier(active_statuses, "ranged_damage")
	return result


func get_effective_soul_level() -> int:
	# This bonus is canonical progression, not an equipment sum. Reading exactly
	# one rules entry prevents malformed duplicate loadout/save values from stacking.
	return maxi(GameRules.SOUL_LEVEL_START, soul_level) + int(
		GameRules.EQUIPMENT[GameRules.PERMANENT_JACKET_ITEM_ID].get("soul_level_bonus", 0)
	)


func get_max_hp() -> int:
	return int(get_derived_stats()["max_hp"])


func get_max_mana() -> int:
	return int(get_derived_stats()["mana"])


func get_damage() -> int:
	return int(get_derived_stats()["damage"])


func get_ranged_damage() -> int:
	return int(get_derived_stats()["ranged_damage"])


func get_equipped_weapon_key() -> String:
	return String(loadout.get("right_hand", ""))


func get_equipped_weapon_type() -> String:
	return GameRules.weapon_type(get_equipped_weapon_key())


func has_ranged_weapon() -> bool:
	return get_equipped_weapon_type() == "ranged"


func get_ranged_range() -> int:
	return GameRules.weapon_range(get_equipped_weapon_key())


func get_accuracy() -> int:
	return int(get_derived_stats()["accuracy"])


func get_vision_radius() -> int:
	return (
		GameRules.PLAYER_VISION_BASE_RADIUS
		+ get_skill_level("sharp_vision") * GameRules.SHARP_VISION_BONUS_PER_LEVEL
	)


func get_hearing_radius() -> int:
	return get_vision_radius() + GameRules.PLAYER_HEARING_RADIUS_OFFSET


func get_mana_regeneration_percent() -> int:
	return int(get_derived_stats()["mana_regeneration_percent"])


func can_cast_magic_missile() -> bool:
	return get_skill_level("magic_missile") > 0


func get_magic_missile_damage() -> int:
	if not can_cast_magic_missile():
		return 0
	return (
		GameRules.MAGIC_MISSILE_BASE_DAMAGE
		+ get_skill_level("magic_missile") - 1
		+ int(get_derived_stats()["spell_power"])
	)


func get_magic_missile_range() -> int:
	if not can_cast_magic_missile():
		return 0
	return (
		GameRules.MAGIC_MISSILE_BASE_RANGE
		+ GameRules.MAGIC_MISSILE_RANGE_BONUS * get_skill_level("magic_missile_range")
	)


func get_magic_ricochet_chance() -> float:
	var level := get_skill_level("magic_ricochet")
	if level <= 0:
		return 0.0
	return (
		GameRules.MAGIC_RICOCHET_BASE_CHANCE
		+ (level - 1) * GameRules.MAGIC_RICOCHET_LEVEL_BONUS
	)


func spend_mana(amount: int) -> bool:
	if amount < 0 or mana < amount:
		return false
	mana -= amount
	return true


func get_dodge() -> int:
	return int(get_derived_stats()["dodge"])


func get_soul_bonus() -> int:
	var result := 0
	for item_key in loadout.values():
		result += int(GameRules.item_rules(String(item_key)).get("soul_bonus", 0))
	return result


func begin_expedition(start_floor := 99) -> void:
	_ensure_permanent_jacket()
	current_floor = clampi(start_floor, 1, 99)
	hp = get_max_hp()
	mana = get_max_mana()
	mana_regeneration_progress = 0.0


func has_rope_destination() -> bool:
	return rope_floor < 100


func add_souls(base_amount: int) -> int:
	var amount := maxi(0, base_amount + get_soul_bonus())
	carried_souls += amount
	lifetime_souls_earned += amount
	return amount


func add_food(amount: int) -> int:
	food += maxi(0, amount)
	return maxi(0, amount)


func get_cradle_chance() -> float:
	return minf(1.0, GameRules.CRADLE_BASE_CHANCE + cradle_miss_streak * GameRules.CRADLE_MISS_BONUS)


func record_cradle_result(appeared: bool) -> void:
	if appeared:
		cradle_miss_streak = 0
	else:
		cradle_miss_streak += 1


func evolve_at_cradle() -> Dictionary:
	_ensure_permanent_jacket()
	var next := GameRules.next_form(current_form_id)
	if next.is_empty():
		return {"ok": false, "reason": "maximum"}
	var required_soul_level := GameRules.required_soul_level(String(next["id"]))
	var effective_soul_level := get_effective_soul_level()
	if effective_soul_level < required_soul_level:
		return {
			"ok": false,
			"reason": "soul_level",
			"required_soul_level": required_soul_level,
			"soul_level": effective_soul_level,
		}
	var cost := GameRules.evolution_cost(current_form_id)
	if carried_souls < cost:
		return {"ok": false, "reason": "souls", "cost": cost}

	var old_form := current_form_id
	var old_max_hp := get_max_hp()
	var old_max_mana := get_max_mana()
	carried_souls -= cost
	absorbed_souls = int(next["threshold"])
	current_form_id = String(next["id"])
	var form_index := GameRules.FORM_ORDER.find(current_form_id)
	highest_unlocked_form_index = maxi(highest_unlocked_form_index, form_index)
	if old_form == "skeleton" and form_index >= GameRules.FORM_ORDER.find("zombie"):
		hunger = 100
		hunger_turn_progress = 0
	var new_max_hp := get_max_hp()
	hp = mini(new_max_hp, hp + 1 + maxi(0, new_max_hp - old_max_hp))
	var new_max_mana := get_max_mana()
	mana = mini(new_max_mana, mana + maxi(0, new_max_mana - old_max_mana))
	return {
		"ok": true,
		"cost": cost,
		"old_form": old_form,
		"new_form": current_form_id,
	}


func equip(item_id: String, destination_slot := "") -> Dictionary:
## Direct equipping is kept as a setup helper for tests and debug tools. Normal
## play uses equip_from_inventory(), which moves a real stack entry.
	var item_key := _sanitized_item_key(item_id)
	var item: Dictionary = GameRules.item_rules(item_key)
	if item.is_empty():
		return {"ok": false, "message": Loc.text("MSG_UNKNOWN_ITEM")}
	if not GameRules.is_item_movable(item_key):
		_ensure_permanent_jacket()
		return {"ok": false, "reason": "permanent", "message": Loc.text("INVENTORY_PERMANENT_LOCKED")}
	var candidates := GameRules.compatible_slots(item_key)
	var destination := GameRules.resolve_physical_slot(
		candidates, current_form_id, loadout, destination_slot,
	)
	if not bool(destination.get("ok", false)):
		if String(destination.get("reason", "")) == "slot_choice_required":
			return destination
		var rejected_slot := String(destination.get("slot", destination_slot))
		return {
			"ok": false,
			"reason": "slot_locked",
			"slot": rejected_slot,
			"message": Loc.text("MSG_FORM_CANNOT_USE", [
				Loc.text(String(get_form()["name"])),
				Loc.text(String(item["name"])),
			]),
		}
	var slot := String(destination["slot"])
	if not GameRules.item_fits_slot(item_key, slot):
		return {"ok": false, "reason": "slot_locked", "slot": slot}

	var old_max_hp := get_max_hp()
	var old_max_mana := get_max_mana()
	var replaced_id: String = loadout.get(slot, "")
	loadout[slot] = item_key
	var hp_difference := get_max_hp() - old_max_hp
	hp = clampi(hp + hp_difference, 1, get_max_hp())
	var mana_difference := get_max_mana() - old_max_mana
	mana = clampi(mana + mana_difference, 0, get_max_mana())
	return {
		"ok": true,
		"item_name": Loc.text(String(item["name"])),
		"slot": slot,
		"replaced_id": replaced_id,
	}


func add_item(item_id: String, upgrade_level := 0, count := 1) -> String:
	var item_key := GameRules.make_item_key(item_id, upgrade_level)
	if not GameRules.EQUIPMENT.has(item_id) or not GameRules.is_item_movable(item_key) or count <= 0:
		return ""
	inventory[item_key] = int(inventory.get(item_key, 0)) + count
	return item_key


func add_item_key(item_key: String, count := 1) -> String:
	item_key = _sanitized_item_key(item_key)
	if item_key.is_empty() or not GameRules.is_item_movable(item_key) or count <= 0:
		return ""
	inventory[item_key] = int(inventory.get(item_key, 0)) + count
	return item_key


func remove_item(item_key: String, count := 1) -> bool:
	item_key = _sanitized_item_key(item_key)
	if item_key.is_empty() or not GameRules.is_item_movable(item_key):
		return false
	var available := int(inventory.get(item_key, 0))
	if count <= 0 or available < count:
		return false
	if available == count:
		inventory.erase(item_key)
	else:
		inventory[item_key] = available - count
	return true


func get_inventory_keys() -> Array:
	var keys := inventory.keys()
	keys.sort_custom(func(a, b):
		var item_a := GameRules.item_rules(String(a))
		var item_b := GameRules.item_rules(String(b))
		var slot_compare := GameRules.item_category(String(a)) < GameRules.item_category(String(b))
		if GameRules.item_category(String(a)) == GameRules.item_category(String(b)):
			return String(a) < String(b)
		return slot_compare
	)
	return keys


func equip_from_inventory(item_key: String, destination_slot := "") -> Dictionary:
	item_key = _sanitized_item_key(item_key)
	if not GameRules.is_item_movable(item_key):
		_ensure_permanent_jacket()
		return {"ok": false, "reason": "permanent"}
	if int(inventory.get(item_key, 0)) <= 0:
		return {"ok": false, "reason": "missing"}
	var item := GameRules.item_rules(item_key)
	if item.is_empty():
		return {"ok": false, "reason": "unknown"}
	var destination := GameRules.resolve_physical_slot(
		GameRules.compatible_slots(item_key), current_form_id, loadout, destination_slot,
	)
	if not bool(destination.get("ok", false)):
		return destination
	var slot := String(destination["slot"])
	if not GameRules.item_fits_slot(item_key, slot):
		return {"ok": false, "reason": "slot_locked", "slot": slot}
	if not remove_item(item_key):
		return {"ok": false, "reason": "missing"}
	var replaced_key := String(loadout.get(slot, ""))
	var result := equip(item_key, slot)
	if not bool(result.get("ok", false)):
		add_item_key(item_key)
		return result
	if not replaced_key.is_empty():
		add_item_key(replaced_key)
	result["replaced_id"] = replaced_key
	return result


func unequip(slot: String) -> Dictionary:
	if not loadout.has(slot):
		return {"ok": false, "reason": "empty"}
	if slot == GameRules.PERMANENT_JACKET_SLOT_ID or not GameRules.is_item_movable(String(loadout[slot])):
		_ensure_permanent_jacket()
		return {"ok": false, "reason": "permanent", "message": Loc.text("INVENTORY_PERMANENT_LOCKED")}
	var old_max_hp := get_max_hp()
	var old_max_mana := get_max_mana()
	var item_key := String(loadout[slot])
	loadout.erase(slot)
	add_item_key(item_key)
	hp = clampi(hp + get_max_hp() - old_max_hp, 1, get_max_hp())
	mana = clampi(mana + get_max_mana() - old_max_mana, 0, get_max_mana())
	return {"ok": true, "item_key": item_key, "slot": slot}


func add_resources(gains: Dictionary) -> Dictionary:
	var added := {"wood": 0, "stone": 0, "cloth": 0}
	for resource_id in added:
		var amount := maxi(0, int(gains.get(resource_id, 0)))
		resources[resource_id] = int(resources.get(resource_id, 0)) + amount
		added[resource_id] = amount
	return added


func can_build_camp_upgrade(upgrade_id: String) -> bool:
	if not GameRules.CAMP_UPGRADES.has(upgrade_id) or bool(camp_upgrades.get(upgrade_id, false)):
		return false
	var cost: Dictionary = GameRules.CAMP_UPGRADES[upgrade_id]["cost"]
	for resource_id in cost:
		if int(resources.get(resource_id, 0)) < int(cost[resource_id]):
			return false
	return true


func build_camp_upgrade(upgrade_id: String) -> Dictionary:
	if not GameRules.CAMP_UPGRADES.has(upgrade_id):
		return {"ok": false, "reason": "unknown"}
	if bool(camp_upgrades.get(upgrade_id, false)):
		return {"ok": false, "reason": "built"}
	if not can_build_camp_upgrade(upgrade_id):
		return {"ok": false, "reason": "resources"}
	var cost: Dictionary = GameRules.CAMP_UPGRADES[upgrade_id]["cost"]
	for resource_id in cost:
		resources[resource_id] = int(resources.get(resource_id, 0)) - int(cost[resource_id])
	camp_upgrades[upgrade_id] = true
	if upgrade_id == "campfire":
		soul_level += GameRules.CAMPFIRE_SOUL_LEVEL_BONUS
	return {"ok": true, "upgrade_id": upgrade_id}


func can_bind_item(item_key: String, source := "inventory", equipped_slot := "") -> bool:
	item_key = _sanitized_item_key(item_key)
	if (
		item_key.is_empty()
		or not GameRules.is_item_movable(item_key)
		or GameRules.is_item_bound(item_key)
		or not bool(camp_upgrades.get("ritual_table", false))
		or get_total_souls() < GameRules.ITEM_BINDING_SOUL_COST
	):
		return false
	if source == "equipped":
		return not equipped_slot.is_empty() and String(loadout.get(equipped_slot, "")) == item_key
	return source == "inventory" and int(inventory.get(item_key, 0)) > 0


func bind_item(item_key: String, source := "inventory", equipped_slot := "") -> Dictionary:
	item_key = _sanitized_item_key(item_key)
	if not GameRules.is_item_movable(item_key):
		_ensure_permanent_jacket()
		return {"ok": false, "reason": "permanent"}
	if not bool(camp_upgrades.get("ritual_table", false)):
		return {"ok": false, "reason": "ritual_table"}
	if item_key.is_empty():
		return {"ok": false, "reason": "missing"}
	if GameRules.is_item_bound(item_key):
		return {"ok": false, "reason": "bound"}
	if get_total_souls() < GameRules.ITEM_BINDING_SOUL_COST:
		return {
			"ok": false,
			"reason": "souls",
			"cost": GameRules.ITEM_BINDING_SOUL_COST,
		}
	var result_key := GameRules.bound_item_key(item_key)
	if source == "equipped":
		if equipped_slot.is_empty() or String(loadout.get(equipped_slot, "")) != item_key:
			return {"ok": false, "reason": "missing"}
		loadout[equipped_slot] = result_key
	elif source == "inventory":
		if not remove_item(item_key):
			return {"ok": false, "reason": "missing"}
		add_item_key(result_key)
	else:
		return {"ok": false, "reason": "source"}
	spend_souls(GameRules.ITEM_BINDING_SOUL_COST)
	return {
		"ok": true,
		"cost": GameRules.ITEM_BINDING_SOUL_COST,
		"item_key": result_key,
		"source": source,
		"equipped_slot": equipped_slot,
	}


func dismantle_item(item_key: String) -> Dictionary:
	item_key = _sanitized_item_key(item_key)
	if not GameRules.is_item_movable(item_key):
		_ensure_permanent_jacket()
		return {"ok": false, "reason": "permanent"}
	if not bool(camp_upgrades.get("crusher", false)):
		return {"ok": false, "reason": "crusher"}
	var item := GameRules.item_rules(item_key)
	if item.is_empty() or int(inventory.get(item_key, 0)) <= 0:
		return {"ok": false, "reason": "missing"}
	if GameRules.is_item_bound(item_key):
		return {"ok": false, "reason": "bound"}
	if not remove_item(item_key):
		return {"ok": false, "reason": "missing"}
	var salvage: Dictionary = item.get("salvage", {})
	var gained := add_resources(salvage)
	return {"ok": true, "gained": gained, "item_key": item_key}


func dismantle_all_items() -> Dictionary:
	_ensure_permanent_jacket()
	if not bool(camp_upgrades.get("crusher", false)):
		return {"ok": false, "reason": "crusher"}
	if count_unbound_inventory_items() <= 0:
		return {"ok": false, "reason": "empty"}
	var total_gained := {"wood": 0, "stone": 0, "cloth": 0}
	var dismantled_count := 0
	for item_key in inventory.keys():
		if GameRules.is_item_bound(String(item_key)) or not GameRules.is_item_movable(String(item_key)):
			continue
		var count := int(inventory[item_key])
		var salvage: Dictionary = GameRules.item_rules(String(item_key)).get("salvage", {})
		for resource_id in total_gained:
			total_gained[resource_id] += int(salvage.get(resource_id, 0)) * count
		dismantled_count += count
	for item_key in inventory.keys():
		if not GameRules.is_item_bound(String(item_key)) and GameRules.is_item_movable(String(item_key)):
			inventory.erase(item_key)
	add_resources(total_gained)
	return {
		"ok": true,
		"count": dismantled_count,
		"gained": total_gained,
	}


func count_unbound_inventory_items() -> int:
	_ensure_permanent_jacket()
	var result := 0
	for item_key in inventory:
		if not GameRules.is_item_bound(String(item_key)) and GameRules.is_item_movable(String(item_key)):
			result += int(inventory[item_key])
	return result


func can_afford_weapon_upgrade() -> bool:
	for resource_id in GameRules.WEAPON_UPGRADE_COST:
		if (
			int(resources.get(resource_id, 0))
			< int(GameRules.WEAPON_UPGRADE_COST[resource_id])
		):
			return false
	return true


func upgrade_weapon(
	item_key: String,
	success_roll: float,
	downgrade_roll: float,
	equipped_slot := ""
) -> Dictionary:
	item_key = _sanitized_item_key(item_key)
	if not GameRules.is_item_movable(item_key):
		_ensure_permanent_jacket()
		return {"ok": false, "reason": "permanent"}
	if not bool(camp_upgrades.get("whetstone", false)):
		return {"ok": false, "reason": "whetstone"}
	var item := GameRules.item_rules(item_key)
	if item.is_empty() or not GameRules.is_weapon(item_key):
		return {"ok": false, "reason": "weapon"}
	var upgrading_equipped := not equipped_slot.is_empty()
	if upgrading_equipped:
		if String(loadout.get(equipped_slot, "")) != item_key:
			return {"ok": false, "reason": "missing"}
	elif int(inventory.get(item_key, 0)) <= 0:
		return {"ok": false, "reason": "missing"}
	var old_level := GameRules.item_upgrade_level(item_key)
	if old_level >= 3:
		return {"ok": false, "reason": "maximum"}
	if not can_afford_weapon_upgrade():
		return {
			"ok": false,
			"reason": "resources",
			"cost": GameRules.WEAPON_UPGRADE_COST.duplicate(true),
		}
	for resource_id in GameRules.WEAPON_UPGRADE_COST:
		resources[resource_id] = (
			int(resources.get(resource_id, 0))
			- int(GameRules.WEAPON_UPGRADE_COST[resource_id])
		)
	var target_level := old_level + 1
	var chance := float(GameRules.WEAPON_UPGRADE_CHANCES[target_level])
	var new_level := old_level
	var outcome := "unchanged"
	if chance >= 1.0 or clampf(success_roll, 0.0, 1.0) < chance:
		new_level = target_level
		outcome = "upgraded"
	elif old_level > 0 and clampf(downgrade_roll, 0.0, 1.0) < 0.05:
		new_level = old_level - 1
		outcome = "downgraded"
	var result_item_key := GameRules.make_item_key(
		GameRules.base_item_id(item_key),
		new_level,
		GameRules.is_item_bound(item_key),
	)
	if new_level != old_level:
		if upgrading_equipped:
			loadout[equipped_slot] = result_item_key
		else:
			remove_item(item_key)
			add_item_key(result_item_key)
	return {
		"ok": true,
		"outcome": outcome,
		"old_level": old_level,
		"new_level": new_level,
		"chance": chance,
		"cost": GameRules.WEAPON_UPGRADE_COST.duplicate(true),
		"item_key": result_item_key,
		"equipped_slot": equipped_slot,
	}


func _sanitized_item_key(value: String) -> String:
	var item_id := GameRules.base_item_id(value)
	if item_id == "iron_claws":
		item_id = "leather_gloves"
	if not GameRules.EQUIPMENT.has(item_id):
		return ""
	return GameRules.make_item_key(
		item_id,
		GameRules.item_upgrade_level(value),
		GameRules.is_item_bound(value),
	)


func apply_damage(amount: int) -> Dictionary:
	var remaining := maxi(0, amount)
	var absorbed := 0
	for status_id in StatusSystem.ordered_active_ids(active_statuses):
		if remaining <= 0:
			break
		var entry: Dictionary = active_statuses[status_id]
		var pool := maxi(0, int(entry.get("temporary_hp", 0)))
		var consumed := mini(pool, remaining)
		if consumed <= 0:
			continue
		entry["temporary_hp"] = pool - consumed
		active_statuses[status_id] = entry
		absorbed += consumed
		remaining -= consumed
	hp -= remaining
	return {
		"requested": maxi(0, amount),
		"temporary_hp_absorbed": absorbed,
		"hp_damage": remaining,
		"died": hp <= 0,
	}


func take_damage(amount: int) -> bool:
	return bool(apply_damage(amount)["died"])


func get_temporary_hp() -> int:
	var result := 0
	for status_id in StatusSystem.ordered_active_ids(active_statuses):
		result += maxi(0, int(active_statuses[status_id].get("temporary_hp", 0)))
	return result


func get_effective_health() -> int:
	return hp + get_temporary_hp()


func has_status(status_id: String) -> bool:
	return active_statuses.has(status_id)


func add_or_refresh_status(status_id: String, duration := -1, temporary_hp := -1) -> bool:
	return StatusSystem.add_or_refresh(active_statuses, status_id, duration, temporary_hp)


func status_remaining(status_id: String) -> int:
	return int(active_statuses.get(status_id, {}).get("remaining_turns", 0))


func cooldown_remaining(ability_id: String) -> int:
	return maxi(0, int(ability_cooldowns.get(ability_id, 0)))


func effective_cooldown(ability_id: String) -> int:
	var base := AbilitySystem.base_cooldown(ability_id)
	return maxi(0, base - StatusSystem.cooldown_reduction(active_statuses, ability_id))


func finish_completed_round(pending_ability_id := "", pending_duration := 0) -> Array[Dictionary]:
	var running_ids := ability_cooldowns.keys()
	for ability_id in running_ids:
		var remaining := maxi(0, int(ability_cooldowns.get(ability_id, 0)) - 1)
		if remaining <= 0:
			ability_cooldowns.erase(ability_id)
		else:
			ability_cooldowns[ability_id] = remaining
	var events := StatusSystem.tick(active_statuses)
	if not pending_ability_id.is_empty() and pending_duration > 0 and hp > 0:
		ability_cooldowns[pending_ability_id] = pending_duration
	return events


func get_skill_level(skill_id: String) -> int:
	return int(skill_levels.get(skill_id, 0))


func get_display_form_id() -> String:
	return display_form_id if available_display_form_ids().has(display_form_id) else current_form_id


func available_display_form_ids() -> Array[String]:
	var result: Array[String] = []
	var maximum_index := clampi(highest_unlocked_form_index, 0, GameRules.FORM_ORDER.size() - 1)
	for index in range(maximum_index + 1):
		result.append(GameRules.FORM_ORDER[index])
	return result


func set_display_form_id(form_id: String) -> bool:
	if get_skill_level("choose_appearance") <= 0:
		return false
	if form_id == current_form_id or form_id.is_empty():
		display_form_id = ""
		return true
	if not available_display_form_ids().has(form_id):
		return false
	display_form_id = form_id
	return true


func get_slotted_ability(slot_id: String) -> String:
	if slot_id == "attack":
		return String(ability_loadout.get(slot_id, "basic_attack"))
	return String(ability_loadout.get(slot_id, ""))


func assign_ability(slot_id: String, ability_id: String) -> bool:
	if not AbilitySystem.SLOT_ORDER.has(slot_id):
		return false
	if ability_id.is_empty() and slot_id != "attack":
		ability_loadout[slot_id] = ""
		return true
	if (
		not AbilitySystem.slot_accepts(slot_id, ability_id)
		or not AbilitySystem.is_learned(ability_id, skill_levels)
	):
		return false
	for other_slot in AbilitySystem.SLOT_ORDER:
		if other_slot != slot_id and String(ability_loadout.get(other_slot, "")) == ability_id:
			ability_loadout[other_slot] = "" if other_slot != "attack" else "basic_attack"
	ability_loadout[slot_id] = ability_id
	return true


func can_use_ability(ability_id: String) -> bool:
	return AbilitySystem.can_use_in_form(ability_id, current_form_id, skill_levels)


func is_stage_unlocked(stage_id: String) -> bool:
	var stage_index := GameRules.FORM_ORDER.find(stage_id)
	return stage_index >= 0 and highest_unlocked_form_index >= stage_index


func purchase_skill(skill_id: String) -> Dictionary:
	if not GameRules.SKILLS.has(skill_id):
		return {"ok": false, "reason": "unknown"}
	var skill: Dictionary = GameRules.SKILLS[skill_id]
	if not is_stage_unlocked(String(skill["stage"])):
		return {"ok": false, "reason": "stage_locked"}
	var current_level := get_skill_level(skill_id)
	if current_level >= int(skill["max_level"]):
		return {"ok": false, "reason": "max_level"}
	for required_skill in skill["requires"]:
		if get_skill_level(required_skill) < int(skill["requires"][required_skill]):
			return {"ok": false, "reason": "prerequisite", "skill": required_skill}
	var cost := GameRules.skill_cost(skill_id, current_level)
	if get_total_souls() < cost:
		return {"ok": false, "reason": "souls", "cost": cost}
	var old_max_hp := get_max_hp()
	var old_max_mana := get_max_mana()
	spend_souls(cost)
	skill_levels[skill_id] = current_level + 1
	if skill_id == "fundamentals":
		unspent_attribute_points += 5
	var new_max_hp := get_max_hp()
	hp = clampi(hp + maxi(0, new_max_hp - old_max_hp), 1, new_max_hp)
	var new_max_mana := get_max_mana()
	mana = clampi(mana + maxi(0, new_max_mana - old_max_mana), 0, new_max_mana)
	return {"ok": true, "level": current_level + 1, "cost": cost}


func get_total_souls() -> int:
	return carried_souls + banked_souls


func spend_souls(amount: int) -> bool:
	if amount < 0 or get_total_souls() < amount:
		return false
	var carried_spent := mini(carried_souls, amount)
	carried_souls -= carried_spent
	banked_souls -= amount - carried_spent
	return true


func spend_attribute_point(attribute_id: String) -> bool:
	if unspent_attribute_points <= 0 or not attributes.has(attribute_id):
		return false
	var old_max_hp := get_max_hp()
	var old_max_mana := get_max_mana()
	attributes[attribute_id] = int(attributes[attribute_id]) + 1
	unspent_attribute_points -= 1
	var new_max_hp := get_max_hp()
	hp = clampi(hp + maxi(0, new_max_hp - old_max_hp), 1, new_max_hp)
	var new_max_mana := get_max_mana()
	mana = clampi(mana + maxi(0, new_max_mana - old_max_mana), 0, new_max_mana)
	return true


func uses_hunger() -> bool:
	return GameRules.FORM_ORDER.find(current_form_id) >= GameRules.FORM_ORDER.find("zombie")


func has_regeneration_skill() -> bool:
	return uses_hunger() and get_skill_level("flesh_regeneration") > 0


func camp_and_eat() -> Dictionary:
	if not uses_hunger():
		return {"ok": false, "reason": "no_hunger"}
	if hunger >= 100:
		return {"ok": false, "reason": "full"}
	if food <= 0:
		return {"ok": false, "reason": "food"}
	food -= 1
	hunger = mini(100, hunger + 10)
	return {"ok": true, "hunger": hunger, "food": food}


func advance_survival_turn() -> Dictionary:
	total_turns += 1
	var result := {
		"healed": 0,
		"starvation_damage": 0,
		"hunger_changed": false,
		"hunger": hunger,
		"mana_restored": 0,
		"died": false,
	}
	result["mana_restored"] = _regenerate_mana()
	if not uses_hunger():
		return result

	hunger_turn_progress += 1
	if hunger_turn_progress >= 10:
		hunger_turn_progress = 0
		var old_hunger := hunger
		hunger = maxi(0, hunger - 1)
		result["hunger_changed"] = hunger != old_hunger
		result["hunger"] = hunger

	if hunger <= 0:
		regeneration_progress = 0
		var starvation_damage := maxi(1, ceili(get_max_hp() * 0.02))
		var damage_result := apply_damage(starvation_damage)
		result["starvation_damage"] = starvation_damage
		result["temporary_hp_absorbed"] = damage_result["temporary_hp_absorbed"]
		result["hp_damage"] = damage_result["hp_damage"]
		result["died"] = damage_result["died"]
		return result

	if has_regeneration_skill():
		regeneration_progress += int(get_derived_stats()["regeneration"])
		if regeneration_progress >= 100:
			var regeneration_ticks := floori(regeneration_progress / 100.0)
			regeneration_progress -= regeneration_ticks * 100
			var old_hp := hp
			hp = mini(get_max_hp(), hp + regeneration_ticks)
			result["healed"] = hp - old_hp
	return result


func _regenerate_mana() -> int:
	var maximum := get_max_mana()
	if mana >= maximum:
		mana_regeneration_progress = 0.0
		return 0
	mana_regeneration_progress += maximum * get_mana_regeneration_percent() / 100.0
	var restored := floori(mana_regeneration_progress + 0.000001)
	if restored <= 0:
		return 0
	mana_regeneration_progress -= restored
	var old_mana := mana
	mana = mini(maximum, mana + restored)
	if mana >= maximum:
		mana_regeneration_progress = 0.0
	return mana - old_mana


func activate_checkpoint(floor_number: int) -> bool:
	if floor_number > 0 and floor_number % 5 == 0 and floor_number < checkpoint_floor:
		checkpoint_floor = floor_number
		return true
	return false


func safe_return() -> int:
	_ensure_permanent_jacket()
	var delivered := carried_souls
	rope_floor = mini(rope_floor, current_floor)
	banked_souls += carried_souls
	carried_souls = 0
	hp = get_max_hp()
	mana = get_max_mana()
	mana_regeneration_progress = 0.0
	apply_camp_entry_effects()
	return delivered


func apply_camp_entry_effects() -> Dictionary:
	var result := {"hunger_refilled": false, "rested_granted": false}
	if uses_hunger():
		result["hunger_refilled"] = hunger < 100
		hunger = 100
	if GameRules.has_intrinsic_feature(current_form_id, "nervous_system"):
		add_or_refresh_status("rested", 500, 5)
		result["rested_granted"] = true
	return result


func die() -> Dictionary:
	_ensure_permanent_jacket()
	var lost_souls := carried_souls
	var lost_items := 0
	var kept_inventory: Dictionary = {}
	var kept_loadout: Dictionary = {}
	for item_key in inventory:
		var count := int(inventory[item_key])
		if GameRules.is_item_permanent(String(item_key)):
			continue
		elif GameRules.is_item_bound(String(item_key)):
			kept_inventory[item_key] = count
		else:
			lost_items += count
	for slot in loadout:
		var equipped_key := String(loadout[slot])
		if slot == GameRules.PERMANENT_JACKET_SLOT_ID or GameRules.is_item_permanent(equipped_key):
			continue
		elif GameRules.is_item_bound(equipped_key):
			kept_loadout[slot] = equipped_key
		else:
			lost_items += 1
	carried_souls = 0
	absorbed_souls = 0
	current_form_id = "skeleton"
	display_form_id = ""
	loadout.clear()
	inventory.clear()
	for item_key in kept_inventory:
		inventory[item_key] = int(kept_inventory[item_key])
	for slot in kept_loadout:
		var item_key := String(kept_loadout[slot])
		var item := GameRules.item_rules(item_key)
		if GameRules.is_slot_unlocked(current_form_id, slot) and GameRules.item_fits_slot(item_key, slot):
			loadout[slot] = item_key
		else:
			add_item_key(item_key)
	_ensure_permanent_jacket()
	food = 0
	hunger = 100
	hunger_turn_progress = 0
	regeneration_progress = 0
	mana_regeneration_progress = 0.0
	total_turns = 0
	cradle_miss_streak = 0
	ability_cooldowns.clear()
	active_statuses.clear()
	hp = get_max_hp()
	mana = get_max_mana()
	return {"souls": lost_souls, "items": lost_items}


func _ensure_permanent_jacket() -> void:
	var canonical_key := GameRules.permanent_jacket_key()
	for inventory_key in inventory.keys():
		if GameRules.base_item_id(String(inventory_key)) == GameRules.PERMANENT_JACKET_ITEM_ID:
			inventory.erase(inventory_key)
	for slot in loadout.keys():
		if (
			slot != GameRules.PERMANENT_JACKET_SLOT_ID
			and GameRules.base_item_id(String(loadout[slot])) == GameRules.PERMANENT_JACKET_ITEM_ID
		):
			loadout.erase(slot)
	var displaced_key := _sanitized_item_key(String(loadout.get(GameRules.PERMANENT_JACKET_SLOT_ID, "")))
	if not displaced_key.is_empty() and GameRules.is_item_movable(displaced_key):
		inventory[displaced_key] = int(inventory.get(displaced_key, 0)) + 1
	loadout[GameRules.PERMANENT_JACKET_SLOT_ID] = canonical_key


func can_upgrade_base() -> bool:
	return false


func upgrade_base() -> Dictionary:
	return {"ok": false, "reason": "replaced_by_campfire"}
