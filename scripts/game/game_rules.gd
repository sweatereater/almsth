class_name GameRules
extends RefCounted

## All prototype balance lives here. The rest of the game asks this class for
## rules instead of hard-coding thresholds, equipment slots or enemy stats.

const FORM_ORDER := ["skeleton", "zombie", "ghoul", "revenant", "almost_human"]
const CRADLE_BASE_CHANCE := 0.05
const CRADLE_MISS_BONUS := 0.05
const PLAYER_VISION_BASE_RADIUS := 4
const SHARP_VISION_BONUS_PER_LEVEL := 1
const MANA_REGENERATION_BASE_PERCENT := 2
const MANA_REGENERATION_WISDOM_STEP := 5
const MAGIC_MISSILE_MANA_COST := 10
const MAGIC_MISSILE_BASE_DAMAGE := 3
const MAGIC_MISSILE_BASE_RANGE := 3
const MAGIC_MISSILE_RANGE_BONUS := 2
const MAGIC_RICOCHET_BASE_CHANCE := 0.20
const MAGIC_RICOCHET_LEVEL_BONUS := 0.05
const MAGIC_RICOCHET_RANGE := 4
const ITEM_KEY_SEPARATOR := "@"
const ITEM_BOUND_SUFFIX := ":bound"
const WEAPON_UPGRADE_CHANCES := {1: 1.0, 2: 0.5, 3: 0.15}
const WEAPON_UPGRADE_COST := {"wood": 2, "stone": 10, "cloth": 1}
const ITEM_BINDING_SOUL_COST := 25
const CAMPFIRE_MAX_HP_BONUS := 1
const CAMP_UPGRADES := {
	"crusher": {
		"name": "CAMP_CRUSHER",
		"cost": {"wood": 5, "stone": 5, "cloth": 0},
	},
	"whetstone": {
		"name": "CAMP_WHETSTONE",
		"cost": {"wood": 10, "stone": 10, "cloth": 5},
	},
	"ritual_table": {
		"name": "CAMP_RITUAL_TABLE",
		"cost": {"wood": 10, "stone": 10, "cloth": 5},
	},
	"campfire": {
		"name": "CAMP_CAMPFIRE",
		"cost": {"wood": 3, "stone": 3, "cloth": 0},
	},
}

const ATTRIBUTE_ORDER := ["strength", "agility", "perception", "vitality", "wisdom"]
const ATTRIBUTE_NAMES := {
	"strength": "ATTR_STRENGTH",
	"agility": "ATTR_AGILITY",
	"perception": "ATTR_PERCEPTION",
	"vitality": "ATTR_VITALITY",
	"wisdom": "ATTR_WISDOM",
}
const STARTING_ATTRIBUTE_VALUE := 1
const STARTING_FREE_ATTRIBUTE_POINTS := 5

## Coefficients transcribed from the design spreadsheet. Keep them separate from
## presentation and combat code so the balance model can be replaced cheaply.
const ATTRIBUTE_EFFECTS := {
	"damage_per_strength": 0.5,
	"dodge_per_agility": 1.0,
	"accuracy_per_perception": 1.0,
	"ranged_damage_per_perception": 0.5,
	"hp_per_vitality": 2.0,
	"regeneration_per_vitality": 0.1,
	"mana_per_wisdom": 5.0,
	"spell_power_per_wisdom": 0.1,
}

const FORMS := {
	"skeleton": {
		"name": "FORM_SKELETON",
		"threshold": 0,
		"max_hp": 6,
		"damage": 0,
		"regeneration": 0,
		"color": "b8c0cc",
		"slots": ["weapon", "charm"],
		"trait": "TRAIT_SKELETON",
	},
	"zombie": {
		"name": "FORM_ZOMBIE",
		"threshold": 10,
		"max_hp": 9,
		"damage": 0,
		"regeneration": 1,
		"color": "78966b",
		"slots": ["weapon", "charm", "armor"],
		"trait": "TRAIT_ZOMBIE",
	},
	"ghoul": {
		"name": "FORM_GHOUL",
		"threshold": 24,
		"max_hp": 11,
		"damage": 1,
		"regeneration": 1,
		"color": "9a7bb5",
		"slots": ["weapon", "charm", "armor", "hands"],
		"trait": "TRAIT_GHOUL",
	},
	"revenant": {
		"name": "FORM_REVENANT",
		"threshold": 48,
		"max_hp": 13,
		"damage": 1,
		"regeneration": 1,
		"color": "6fa8b8",
		"slots": ["weapon", "charm", "armor", "hands", "relic"],
		"trait": "TRAIT_REVENANT",
	},
	"almost_human": {
		"name": "FORM_ALMOST_HUMAN",
		"threshold": 80,
		"max_hp": 16,
		"damage": 2,
		"regeneration": 1,
		"color": "d4a07a",
		"slots": ["weapon", "charm", "armor", "hands", "relic", "offhand"],
		"trait": "TRAIT_ALMOST_HUMAN",
	},
}

const SLOT_NAMES := {
	"weapon": "SLOT_WEAPON",
	"charm": "SLOT_CHARM",
	"armor": "SLOT_ARMOR",
	"hands": "SLOT_HANDS",
	"relic": "SLOT_RELIC",
	"offhand": "SLOT_OFFHAND",
}

const EQUIPMENT := {
	"bone_knife": {
		"name": "ITEM_BONE_KNIFE",
		"slot": "weapon",
		"damage": 1,
		"max_hp": 0,
		"soul_bonus": 0,
		"accuracy": 1,
		"min_depth": 0,
		"salvage": {"wood": 1, "stone": 1},
	},
	"grave_mace": {
		"name": "ITEM_GRAVE_MACE",
		"slot": "weapon",
		"damage": 2,
		"max_hp": 0,
		"soul_bonus": 0,
		"accuracy": -1,
		"min_depth": 8,
		"salvage": {"wood": 1, "stone": 2},
	},
	"bone_bow": {
		"name": "ITEM_BONE_BOW",
		"slot": "weapon",
		"weapon_type": "ranged",
		"range": 5,
		"damage": 0,
		"ranged_damage": 1,
		"max_hp": 0,
		"soul_bonus": 0,
		"accuracy": 0,
		"min_depth": 0,
		"salvage": {"wood": 2, "cloth": 1},
	},
	"soul_locket": {
		"name": "ITEM_SOUL_LOCKET",
		"slot": "charm",
		"damage": 0,
		"max_hp": 0,
		"soul_bonus": 1,
		"mana": 5,
		"spell_power": 1,
		"min_depth": 0,
		"salvage": {"stone": 1},
	},
	"rotting_mail": {
		"name": "ITEM_ROTTING_MAIL",
		"slot": "armor",
		"damage": 0,
		"max_hp": 3,
		"soul_bonus": 0,
		"dodge": -1,
		"min_depth": 3,
		"salvage": {"cloth": 2},
	},
	"leather_gloves": {
		"name": "ITEM_LEATHER_GLOVES",
		"slot": "hands",
		"damage": 0,
		"max_hp": 1,
		"soul_bonus": 0,
		"accuracy": 1,
		"min_depth": 10,
		"salvage": {"cloth": 1},
	},
	"hollow_lantern": {
		"name": "ITEM_HOLLOW_LANTERN",
		"slot": "relic",
		"damage": 0,
		"max_hp": 2,
		"soul_bonus": 1,
		"mana": 10,
		"spell_power": 1,
		"min_depth": 18,
		"salvage": {"wood": 1, "stone": 1},
	},
	"pilgrim_shield": {
		"name": "ITEM_PILGRIM_SHIELD",
		"slot": "offhand",
		"damage": 0,
		"max_hp": 4,
		"soul_bonus": 0,
		"dodge": -1,
		"min_depth": 28,
		"salvage": {"wood": 2, "stone": 1},
	},
}

const ENEMIES := {
	"grave_rat": {
		"name": "ENEMY_GRAVE_RAT",
		"glyph": "GLYPH_GRAVE_RAT",
		"max_hp": 2,
		"damage": 1,
		"souls": 1,
		"accuracy": 2,
		"dodge": 2,
		"vision": 3,
		"meat": true,
		"color": "a07856",
	},
	"hollow_guard": {
		"name": "ENEMY_HOLLOW_GUARD",
		"glyph": "GLYPH_HOLLOW_GUARD",
		"max_hp": 4,
		"damage": 1,
		"souls": 2,
		"accuracy": 3,
		"dodge": 1,
		"vision": 5,
		"meat": false,
		"color": "a85b5b",
	},
	"soul_leech": {
		"name": "ENEMY_SOUL_LEECH",
		"glyph": "GLYPH_SOUL_LEECH",
		"max_hp": 5,
		"damage": 2,
		"souls": 3,
		"accuracy": 4,
		"dodge": 2,
		"vision": 4,
		"meat": false,
		"color": "7858a6",
	},
	"skeletal_archer": {
		"name": "ENEMY_SKELETAL_ARCHER",
		"glyph": "GLYPH_SKELETAL_ARCHER",
		"max_hp": 4,
		"damage": 1,
		"souls": 2,
		"accuracy": 3,
		"dodge": 1,
		"vision": 6,
		"meat": false,
		"attack_type": "ranged",
		"range": 5,
		"min_depth": 6,
		"color": "a88965",
	},
	"minotaur": {
		"name": "ENEMY_MINOTAUR",
		"glyph": "GLYPH_MINOTAUR",
		"max_hp": 36,
		"damage": 2,
		"souls": 12,
		"accuracy": 4,
		"dodge": 0,
		"vision": 6,
		"meat": true,
		"draw_scale": 2.5,
		"abilities": ["dash"],
		"color": "8f4c3e",
	},
}

const SKILLS := {
	"strong_bones": {
		"name": "SKILL_STRONG_BONES",
		"description": "SKILL_STRONG_BONES_DESC",
		"stage": "skeleton",
		"max_level": 10,
		"base_cost": 5,
		"cost_step": 5,
		"requires": {},
		"kind": "passive",
	},
	"fundamentals": {
		"name": "SKILL_FUNDAMENTALS",
		"description": "SKILL_FUNDAMENTALS_DESC",
		"stage": "skeleton",
		"max_level": 1,
		"base_cost": 25,
		"cost_step": 0,
		"requires": {"strong_bones": 1},
		"kind": "passive",
	},
	"magic_awakening": {
		"name": "SKILL_MAGIC_AWAKENING",
		"description": "SKILL_MAGIC_AWAKENING_DESC",
		"stage": "skeleton",
		"max_level": 1,
		"base_cost": 40,
		"cost_step": 0,
		"requires": {},
		"kind": "passive",
	},
	"magic_missile": {
		"name": "SKILL_MAGIC_MISSILE",
		"description": "SKILL_MAGIC_MISSILE_DESC",
		"stage": "skeleton",
		"max_level": 3,
		"base_cost": 30,
		"cost_step": 15,
		"requires": {"magic_awakening": 1},
		"kind": "active",
		"ability_id": "magic_missile",
	},
	"magic_missile_range": {
		"name": "SKILL_MAGIC_MISSILE_RANGE",
		"description": "SKILL_MAGIC_MISSILE_RANGE_DESC",
		"stage": "skeleton",
		"max_level": 1,
		"base_cost": 50,
		"cost_step": 0,
		"requires": {"magic_missile": 1},
		"kind": "passive",
	},
	"magic_ricochet": {
		"name": "SKILL_MAGIC_RICOCHET",
		"description": "SKILL_MAGIC_RICOCHET_DESC",
		"stage": "skeleton",
		"max_level": 4,
		"base_cost": 60,
		"cost_step": 20,
		"requires": {"magic_missile_range": 1},
		"kind": "passive",
	},
	"flesh_regeneration": {
		"name": "SKILL_FLESH_REGENERATION",
		"description": "SKILL_FLESH_REGENERATION_DESC",
		"stage": "zombie",
		"max_level": 1,
		"base_cost": 20,
		"cost_step": 0,
		"requires": {},
		"kind": "passive",
	},
	"dash": {
		"name": "SKILL_DASH",
		"description": "SKILL_DASH_DESC",
		"stage": "ghoul",
		"max_level": 1,
		"base_cost": 50,
		"cost_step": 0,
		"requires": {},
		"kind": "active",
		"ability_id": "dash",
	},
	"double_attack": {
		"name": "SKILL_DOUBLE_ATTACK",
		"description": "SKILL_DOUBLE_ATTACK_DESC",
		"stage": "ghoul",
		"max_level": 1,
		"base_cost": 75,
		"cost_step": 0,
		"requires": {},
		"kind": "active",
		"ability_id": "double_attack",
	},
	"sharp_vision": {
		"name": "SKILL_SHARP_VISION",
		"description": "SKILL_SHARP_VISION_DESC",
		"stage": "revenant",
		"max_level": 2,
		"base_cost": 80,
		"cost_step": 40,
		"requires": {},
		"kind": "passive",
	},
	"almost_double_strike": {
		"name": "SKILL_ALMOST_DOUBLE_STRIKE",
		"description": "SKILL_ALMOST_DOUBLE_STRIKE_DESC",
		"stage": "almost_human",
		"max_level": 11,
		"base_cost": 50,
		"cost_step": 10,
		"requires": {},
		"kind": "passive",
	},
	"circular_attack": {
		"name": "SKILL_CIRCULAR_ATTACK",
		"description": "SKILL_CIRCULAR_ATTACK_DESC",
		"stage": "almost_human",
		"max_level": 1,
		"base_cost": 100,
		"cost_step": 0,
		"requires": {},
		"kind": "active",
		"ability_id": "circular_attack",
	},
}


static func get_form(form_id: String) -> Dictionary:
	return FORMS.get(form_id, FORMS["skeleton"])


static func form_for_absorbed_souls(absorbed_souls: int) -> String:
	var result := "skeleton"
	for form_id in FORM_ORDER:
		if absorbed_souls >= int(FORMS[form_id]["threshold"]):
			result = form_id
	return result


static func next_form(form_id: String) -> Dictionary:
	var index := FORM_ORDER.find(form_id)
	if index < 0 or index >= FORM_ORDER.size() - 1:
		return {}
	var next_id: String = FORM_ORDER[index + 1]
	var data: Dictionary = FORMS[next_id].duplicate(true)
	data["id"] = next_id
	return data


static func evolution_cost(form_id: String) -> int:
	var next := next_form(form_id)
	if next.is_empty():
		return 0
	return int(next["threshold"]) - int(get_form(form_id)["threshold"])


static func default_attributes() -> Dictionary:
	var result := {}
	for attribute_id in ATTRIBUTE_ORDER:
		result[attribute_id] = STARTING_ATTRIBUTE_VALUE
	return result


static func default_skill_levels() -> Dictionary:
	var result := {}
	for skill_id in SKILLS:
		result[skill_id] = 0
	return result


static func calculate_derived_stats(
	attributes: Dictionary,
	form_id: String,
	loadout: Dictionary = {},
	base_level: int = 0
) -> Dictionary:
	var strength := int(attributes.get("strength", STARTING_ATTRIBUTE_VALUE))
	var agility := int(attributes.get("agility", STARTING_ATTRIBUTE_VALUE))
	var perception := int(attributes.get("perception", STARTING_ATTRIBUTE_VALUE))
	var vitality := int(attributes.get("vitality", STARTING_ATTRIBUTE_VALUE))
	var wisdom := int(attributes.get("wisdom", STARTING_ATTRIBUTE_VALUE))
	var form := get_form(form_id)
	var regeneration := int(form.get("regeneration", 0))
	# Bones cannot regenerate. Vitality and equipment start contributing only
	# once the zombie stage supplies living flesh and a base regeneration point.
	if regeneration > 0:
		regeneration += roundi(vitality * ATTRIBUTE_EFFECTS["regeneration_per_vitality"])
		regeneration += roundi(_equipment_bonus(loadout, "regeneration"))

	return {
		"damage": roundi(strength * ATTRIBUTE_EFFECTS["damage_per_strength"])
			+ int(form["damage"]) + roundi(_equipment_bonus(loadout, "damage")),
		"accuracy": roundi(perception * ATTRIBUTE_EFFECTS["accuracy_per_perception"])
			+ roundi(_equipment_bonus(loadout, "accuracy")),
		"max_hp": int(form["max_hp"])
			+ roundi(vitality * ATTRIBUTE_EFFECTS["hp_per_vitality"])
			+ base_level + roundi(_equipment_bonus(loadout, "max_hp")),
		"dodge": roundi(agility * ATTRIBUTE_EFFECTS["dodge_per_agility"])
			+ roundi(_equipment_bonus(loadout, "dodge")),
		"mana": roundi(wisdom * ATTRIBUTE_EFFECTS["mana_per_wisdom"])
			+ roundi(_equipment_bonus(loadout, "mana")),
		"spell_power": roundi(wisdom * ATTRIBUTE_EFFECTS["spell_power_per_wisdom"])
			+ roundi(_equipment_bonus(loadout, "spell_power")),
		"mana_regeneration_percent": MANA_REGENERATION_BASE_PERCENT
			+ floori(wisdom / float(MANA_REGENERATION_WISDOM_STEP)),
		"regeneration": regeneration,
		"ranged_damage": roundi(perception * ATTRIBUTE_EFFECTS["ranged_damage_per_perception"])
			+ roundi(_equipment_bonus(loadout, "ranged_damage")),
	}


static func _equipment_bonus(loadout: Dictionary, parameter: String) -> float:
	var result := 0.0
	for item_key in loadout.values():
		var item_id := base_item_id(String(item_key))
		var item: Dictionary = EQUIPMENT.get(item_id, {})
		result += float(item.get(parameter, 0.0))
		if item.get("slot", "") != "weapon":
			continue
		var type := String(item.get("weapon_type", "melee"))
		if (
			parameter == "accuracy"
			or (parameter == "damage" and type == "melee")
			or (parameter == "ranged_damage" and type == "ranged")
		):
			result += item_upgrade_level(String(item_key))
	return result


static func weapon_type(item_key: String) -> String:
	var item := item_rules(item_key)
	if item.get("slot", "") != "weapon":
		return ""
	return String(item.get("weapon_type", "melee"))


static func weapon_range(item_key: String) -> int:
	if weapon_type(item_key) != "ranged":
		return 0
	return maxi(0, int(item_rules(item_key).get("range", 0)))


static func make_item_key(item_id: String, upgrade_level := 0, bound := false) -> String:
	var key := "%s%s%d" % [item_id, ITEM_KEY_SEPARATOR, clampi(upgrade_level, 0, 3)]
	return key + ITEM_BOUND_SUFFIX if bound else key


static func base_item_id(item_key: String) -> String:
	return item_key.get_slice(ITEM_KEY_SEPARATOR, 0)


static func item_upgrade_level(item_key: String) -> int:
	if not item_key.contains(ITEM_KEY_SEPARATOR):
		return 0
	var level_text := item_key.get_slice(ITEM_KEY_SEPARATOR, 1).trim_suffix(ITEM_BOUND_SUFFIX)
	return clampi(int(level_text), 0, 3)


static func is_item_bound(item_key: String) -> bool:
	return item_key.ends_with(ITEM_BOUND_SUFFIX)


static func bound_item_key(item_key: String) -> String:
	return make_item_key(base_item_id(item_key), item_upgrade_level(item_key), true)


static func unbound_item_key(item_key: String) -> String:
	return make_item_key(base_item_id(item_key), item_upgrade_level(item_key), false)


static func item_rules(item_key: String) -> Dictionary:
	return EQUIPMENT.get(base_item_id(item_key), {})


static func base_upgrade_cost(base_level: int) -> int:
	return 5 + base_level * 5


static func skill_cost(skill_id: String, current_level: int) -> int:
	var skill: Dictionary = SKILLS.get(skill_id, {})
	if skill.is_empty():
		return 0
	return int(skill["base_cost"]) + current_level * int(skill["cost_step"])


static func available_equipment_ids(floor_number: int) -> Array:
	var depth := 100 - floor_number
	var result: Array = []
	for item_id in EQUIPMENT:
		if depth >= int(EQUIPMENT[item_id]["min_depth"]):
			result.append(item_id)
	return result


static func enemy_pool(floor_number: int) -> Array:
	var depth := 100 - floor_number
	if depth >= 15:
		return ["grave_rat", "hollow_guard", "soul_leech", "skeletal_archer"]
	if depth >= 6:
		return ["grave_rat", "hollow_guard", "skeletal_archer"]
	return ["grave_rat"]
