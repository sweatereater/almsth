class_name GameRules
extends RefCounted

## All prototype balance lives here. The rest of the game asks this class for
## rules instead of hard-coding thresholds, equipment slots or enemy stats.

const FORM_ORDER := ["skeleton", "zombie", "ghoul", "revenant", "almost_human"]
const SOUL_LEVEL_START := 0
const CAMPFIRE_SOUL_LEVEL_BONUS := 1
const MURAL_SOUL_LEVEL_BONUS := 1
const ROCKING_CHAIR_SOUL_LEVEL_BONUS := 1
const CRADLE_BASE_CHANCE := 0.05
const CRADLE_MISS_BONUS := 0.05
const PLAYER_VISION_BASE_RADIUS := 4
const PLAYER_HEARING_RADIUS_OFFSET := 1
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
const PERMANENT_JACKET_ITEM_ID := "unexpectedly_comfortable_jacket"
const PERMANENT_JACKET_SLOT_ID := "jacket"
const EXPEDITION_BACKPACK_BONUS := 200
const CAMP_KETTLE_DURATION_BONUS := 100
const CAMP_BUNK_DURATION_BONUS := 100
const CAMP_KETTLE_FOOD_COST := 1
const CRYPT_MIN_FLOOR := 80
const CRYPT_MAX_FLOOR := 99
const CRYPT_CHANCE := 0.35
const WEAVING_CRYPTS_MIN_FLOOR := 80
const WEAVING_CRYPTS_MAX_FLOOR := 89
const WEAVING_CRYPTS_THEMATIC_CHANCE := 0.6
const CAMP_DRAW_ORDER: Array[String] = [
	"mural", "bunk", "textile_area", "workbench", "writing_set", "ritual_table",
	"crusher", "whetstone", "campfire", "kettle", "rocking_chair", "record_player",
	"storage_chest",
]
const CAMP_UPGRADES := {
	"kettle": {
		"name": "CAMP_KETTLE",
		"cost": {"wood": 6, "stone": 8, "cloth": 2},
		"requires": ["campfire"],
	},
	"bunk": {
		"name": "CAMP_BUNK",
		"cost": {"wood": 8, "cloth": 6},
	},
	"mural": {
		"name": "CAMP_MURAL",
		"cost": {"wood": 12, "stone": 20, "cloth": 5},
		"banked_souls": 60,
		"minotaur_tail": 1,
	},
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
	"workbench": {
		"name": "CAMP_WORKBENCH",
		"cost": {},
	},
	"writing_set": {
		"name": "CAMP_WRITING_SET",
		"cost": {},
		"requires": ["workbench"],
	},
	"textile_area": {
		"name": "CAMP_TEXTILE_AREA",
		"cost": {},
	},
	"rocking_chair": {
		"name": "CAMP_ROCKING_CHAIR",
		"cost": {"wood": 30},
	},
	"record_player": {
		"name": "CAMP_RECORD_PLAYER",
		"cost": {},
	},
	"storage_chest": {
		"name": "CAMP_STORAGE_CHEST",
		"cost": {"wood": 20, "stone": 4, "cloth": 3},
	},
}

const INTRINSIC_FEATURES := {}


static func has_intrinsic_feature(form_id: String, feature_id: String) -> bool:
	if not INTRINSIC_FEATURES.has(feature_id):
		return false
	var required_stage := String(INTRINSIC_FEATURES[feature_id].get("stage", "skeleton"))
	return FORM_ORDER.find(form_id) >= FORM_ORDER.find(required_stage)

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

const EQUIPMENT_SLOT_ORDER: Array[String] = [
	"head", "body", "hands", "legs", "feet", "ring_1",
	"jacket", "talisman", "back", "right_hand", "left_hand", "ring_2",
]
const EQUIPMENT_SLOTS := {
	"right_hand": {"name": "SLOT_RIGHT_HAND", "category": "weapon", "allowed_tags": ["weapon"], "portrait_position": Vector2(599, 378), "filter_order": 1},
	"left_hand": {"name": "SLOT_LEFT_HAND", "category": "offhand", "allowed_tags": ["offhand"], "portrait_position": Vector2(599, 472), "filter_order": 2},
	"feet": {"name": "SLOT_FEET", "category": "feet", "allowed_tags": ["feet"], "portrait_position": Vector2(282, 472), "filter_order": 3},
	"body": {"name": "SLOT_BODY", "category": "body", "allowed_tags": ["body"], "portrait_position": Vector2(282, 190), "filter_order": 4},
	"legs": {"name": "SLOT_LEGS", "category": "legs", "allowed_tags": ["legs"], "portrait_position": Vector2(282, 378), "filter_order": 5},
	"hands": {"name": "SLOT_HANDS", "category": "hands", "allowed_tags": ["hands"], "portrait_position": Vector2(282, 284), "filter_order": 6},
	"head": {"name": "SLOT_HEAD", "category": "head", "allowed_tags": ["head"], "portrait_position": Vector2(282, 96), "filter_order": 7},
	"talisman": {"name": "SLOT_TALISMAN", "category": "talisman", "allowed_tags": ["talisman"], "portrait_position": Vector2(599, 190), "filter_order": 8},
	"ring_1": {"name": "SLOT_RING_1", "category": "ring", "allowed_tags": ["ring"], "portrait_position": Vector2(282, 566), "filter_order": 9},
	"ring_2": {"name": "SLOT_RING_2", "category": "ring", "allowed_tags": ["ring"], "portrait_position": Vector2(599, 566), "filter_order": 9},
	"back": {"name": "SLOT_BACK", "category": "back", "allowed_tags": ["back"], "portrait_position": Vector2(599, 284), "filter_order": 10},
	"jacket": {"name": "SLOT_JACKET", "category": "body", "allowed_tags": ["jacket"], "portrait_position": Vector2(599, 96), "filter_order": 4},
}
const EQUIPMENT_CATEGORY_ORDER: Array[String] = [
	"weapon", "offhand", "feet", "body", "legs", "hands", "head", "talisman", "ring", "back",
]
const EQUIPMENT_CATEGORY_NAMES := {
	"weapon": "CATEGORY_WEAPON", "offhand": "CATEGORY_OFFHAND", "feet": "CATEGORY_FEET",
	"body": "CATEGORY_BODY", "legs": "CATEGORY_LEGS", "hands": "CATEGORY_HANDS",
	"head": "CATEGORY_HEAD", "talisman": "CATEGORY_TALISMAN", "ring": "CATEGORY_RING",
	"back": "CATEGORY_BACK",
}
const LEGACY_SLOT_MIGRATION := {
	"weapon": "right_hand", "offhand": "left_hand", "charm": "talisman",
	"armor": "body", "hands": "hands", "mutation": "hands", "relic": "left_hand",
}

const FORMS := {
	"skeleton": {
		"name": "FORM_SKELETON",
		"required_soul_level": 1,
		"threshold": 0,
		"max_hp": 6,
		"damage": 0,
		"regeneration": 0,
		"color": "b8c0cc",
		"slots": ["jacket", "right_hand", "left_hand", "talisman"],
		"trait": "TRAIT_SKELETON",
	},
	"zombie": {
		"name": "FORM_ZOMBIE",
		"required_soul_level": 1,
		"threshold": 10,
		"max_hp": 9,
		"damage": 0,
		"regeneration": 1,
		"color": "78966b",
		"slots": ["jacket", "right_hand", "left_hand", "talisman", "feet", "head"],
		"trait": "TRAIT_ZOMBIE",
	},
	"ghoul": {
		"name": "FORM_GHOUL",
		"required_soul_level": 2,
		"threshold": 24,
		"max_hp": 11,
		"damage": 1,
		"regeneration": 1,
		"color": "9a7bb5",
		"slots": ["jacket", "right_hand", "left_hand", "talisman", "feet", "head", "body", "legs", "hands"],
		"trait": "TRAIT_GHOUL",
	},
	"revenant": {
		"name": "FORM_REVENANT",
		"required_soul_level": 3,
		"threshold": 48,
		"max_hp": 13,
		"damage": 1,
		"regeneration": 1,
		"color": "6fa8b8",
		"slots": ["jacket", "right_hand", "left_hand", "talisman", "feet", "head", "body", "legs", "hands", "back"],
		"trait": "TRAIT_REVENANT",
	},
	"almost_human": {
		"name": "FORM_ALMOST_HUMAN",
		"required_soul_level": 4,
		"threshold": 80,
		"max_hp": 16,
		"damage": 2,
		"regeneration": 1,
		"color": "d4a07a",
		"slots": EQUIPMENT_SLOT_ORDER,
		"trait": "TRAIT_ALMOST_HUMAN",
	},
}

const SLOT_NAMES := {
	"right_hand": "SLOT_RIGHT_HAND", "left_hand": "SLOT_LEFT_HAND", "feet": "SLOT_FEET",
	"body": "SLOT_BODY", "legs": "SLOT_LEGS", "hands": "SLOT_HANDS", "head": "SLOT_HEAD",
	"talisman": "SLOT_TALISMAN", "ring_1": "SLOT_RING_1", "ring_2": "SLOT_RING_2", "back": "SLOT_BACK",
	"jacket": "SLOT_JACKET",
}

const EQUIPMENT := {
	"rusty_sabre": {
		"name": "ITEM_RUSTY_SABRE",
		"category": "weapon",
		"tags": ["weapon"],
		"slots": ["right_hand"],
		"icon": "res://assets/items/item-rusty-sabre.png",
		"damage": 1,
		"attack_type": "melee",
		"grip": "one_handed",
		"accuracy": 2,
		"min_depth": 5,
		"salvage": {"stone": 1, "wood": 1},
	},
	"short_crossbow": {
		"name": "ITEM_SHORT_CROSSBOW",
		"category": "weapon",
		"tags": ["weapon"],
		"slots": ["right_hand"],
		"icon": "res://assets/items/item-short-crossbow.png",
		"attack_type": "ranged",
		"grip": "two_handed",
		"ranged_damage": 3,
		"range": 4,
		"accuracy": -1,
		"min_depth": 12,
		"salvage": {"wood": 2, "cloth": 1},
	},
	"bone_buckler": {
		"name": "ITEM_BONE_BUCKLER",
		"category": "offhand",
		"tags": ["offhand"],
		"slots": ["left_hand"],
		"icon": "res://assets/items/item-bone-buckler.png",
		"max_hp": 2,
		"dodge": 1,
		"min_depth": 8,
		"salvage": {"stone": 1, "wood": 1},
	},
	"gravediggers_lamp": {
		"name": "ITEM_GRAVEDIGGERS_LAMP",
		"category": "offhand",
		"tags": ["offhand"],
		"slots": ["left_hand"],
		"icon": "res://assets/items/item-gravediggers-lamp.png",
		"vision": 1,
		"min_depth": 6,
		"salvage": {"wood": 1, "stone": 1},
	},
	"watchmans_cap": {
		"name": "ITEM_WATCHMANS_CAP",
		"category": "head",
		"tags": ["head"],
		"slots": ["head"],
		"icon": "res://assets/items/item-watchmans-cap.png",
		"max_hp": 2,
		"min_depth": 4,
		"salvage": {"cloth": 1},
	},
	"archivists_mask": {
		"name": "ITEM_ARCHIVISTS_MASK",
		"category": "head",
		"tags": ["head"],
		"slots": ["head"],
		"icon": "res://assets/items/item-archivists-mask.png",
		"mana": 5,
		"spell_power": 1,
		"accuracy": -1,
		"min_depth": 18,
		"salvage": {"cloth": 1, "stone": 1},
	},
	"wanderers_gambeson": {
		"name": "ITEM_WANDERERS_GAMBESON",
		"category": "body",
		"tags": ["body"],
		"slots": ["body"],
		"icon": "res://assets/items/item-wanderers-gambeson.png",
		"max_hp": 2,
		"dodge": 1,
		"min_depth": 10,
		"salvage": {"cloth": 2},
	},
	"lamellar_vest": {
		"name": "ITEM_LAMELLAR_VEST",
		"category": "body",
		"tags": ["body"],
		"slots": ["body"],
		"icon": "res://assets/items/item-lamellar-vest.png",
		"max_hp": 7,
		"dodge": -2,
		"min_depth": 15,
		"salvage": {"cloth": 2, "stone": 2},
	},
	"scouts_trousers": {
		"name": "ITEM_SCOUTS_TROUSERS",
		"category": "legs",
		"tags": ["legs"],
		"slots": ["legs"],
		"icon": "res://assets/items/item-scouts-trousers.png",
		"dodge": 1,
		"max_hp": 2,
		"min_depth": 14,
		"salvage": {"cloth": 1},
	},
	"heavy_leg_wraps": {
		"name": "ITEM_HEAVY_LEG_WRAPS",
		"category": "legs",
		"tags": ["legs"],
		"slots": ["legs"],
		"icon": "res://assets/items/item-heavy-leg-wraps.png",
		"max_hp": 3,
		"min_depth": 9,
		"salvage": {"cloth": 2},
	},
	"pilgrims_boots": {
		"name": "ITEM_PILGRIMS_BOOTS",
		"category": "feet",
		"tags": ["feet"],
		"slots": ["feet"],
		"icon": "res://assets/items/item-pilgrims-boots.png",
		"max_hp": 2,
		"min_depth": 4,
		"salvage": {"cloth": 1, "wood": 1},
	},
	"aiming_ring": {
		"name": "ITEM_AIMING_RING",
		"category": "ring",
		"tags": ["ring"],
		"slots": ["ring_1", "ring_2"],
		"icon": "res://assets/items/item-aiming-ring.png",
		"accuracy": 2,
		"dodge": -1,
		"min_depth": 15,
		"salvage": {"stone": 1},
	},
	"thickblood_ring": {
		"name": "ITEM_THICKBLOOD_RING",
		"category": "ring",
		"tags": ["ring"],
		"slots": ["ring_1", "ring_2"],
		"icon": "res://assets/items/item-thickblood-ring.png",
		"max_hp": 3,
		"mana": -5,
		"min_depth": 15,
		"salvage": {"stone": 1, "cloth": 1},
	},
	"expedition_backpack": {
		"name": "ITEM_EXPEDITION_BACKPACK",
		"category": "back",
		"tags": ["back"],
		"slots": ["back"],
		"icon": "res://assets/items/item-expedition-backpack.png",
		"preparation": EXPEDITION_BACKPACK_BONUS,
		"min_depth": 15,
		"salvage": {"cloth": 3, "wood": 1},
	},
	"unexpectedly_comfortable_jacket": {
		"name": "ITEM_UNEXPECTEDLY_COMFORTABLE_JACKET",
		"description": "ITEM_UNEXPECTEDLY_COMFORTABLE_JACKET_DESC",
		"category": "body", "tags": ["jacket"], "slots": ["jacket"],
		"icon": "res://assets/items/item-unexpectedly-comfortable-jacket.png",
		"soul_level_bonus": 1,
		"lootable": false,
		"movable": false,
		"permanent": true,
		"min_depth": 0,
		"salvage": {},
	},
	"bone_knife": {
		"name": "ITEM_BONE_KNIFE",
		"category": "weapon", "tags": ["weapon"], "slots": ["right_hand"],
		"icon": "res://assets/items/item-bone-knife.png",
		"damage": 1,
		"attack_type": "melee",
		"grip": "one_handed",
		"max_hp": 0,
		"soul_bonus": 0,
		"accuracy": 1,
		"min_depth": 0,
		"salvage": {"wood": 1, "stone": 1},
	},
	"grave_mace": {
		"name": "ITEM_GRAVE_MACE",
		"category": "weapon", "tags": ["weapon"], "slots": ["right_hand"],
		"icon": "res://assets/items/item-grave-mace.png",
		"damage": 2,
		"attack_type": "melee",
		"grip": "one_handed",
		"max_hp": 0,
		"soul_bonus": 0,
		"accuracy": -1,
		"min_depth": 8,
		"salvage": {"wood": 1, "stone": 2},
	},
	"bone_bow": {
		"name": "ITEM_BONE_BOW",
		"category": "weapon", "tags": ["weapon"], "slots": ["right_hand"],
		"icon": "res://assets/items/item-bone-bow.png",
		"attack_type": "ranged",
		"grip": "two_handed",
		"range": 5,
		"damage": 0,
		"ranged_damage": 1,
		"max_hp": 0,
		"soul_bonus": 0,
		"accuracy": 0,
		"min_depth": 0,
		"salvage": {"wood": 2, "cloth": 1},
	},
	"old_claymore": {
		"name": "ITEM_OLD_CLAYMORE",
		"description": "ITEM_OLD_CLAYMORE_DESC",
		"category": "weapon", "tags": ["weapon"], "slots": ["right_hand"],
		"icon": "res://assets/items/item-old-claymore.png",
		"attack_type": "melee",
		"grip": "two_handed",
		"damage": 3,
		"accuracy": 2,
		"min_depth": 14,
		"salvage": {"wood": 1, "stone": 3},
	},
	"soul_locket": {
		"name": "ITEM_SOUL_LOCKET",
		"category": "talisman", "tags": ["talisman"], "slots": ["talisman"],
		"icon": "res://assets/items/item-soul-locket.png",
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
		"category": "body", "tags": ["body"], "slots": ["body"],
		"icon": "res://assets/items/item-rotting-mail.png",
		"damage": 0,
		"max_hp": 3,
		"soul_bonus": 0,
		"dodge": -1,
		"min_depth": 3,
		"salvage": {"cloth": 2},
	},
	"leather_gloves": {
		"name": "ITEM_LEATHER_GLOVES",
		"category": "hands", "tags": ["hands"], "slots": ["hands"],
		"icon": "res://assets/items/item-leather-gloves.png",
		"damage": 0,
		"max_hp": 1,
		"soul_bonus": 0,
		"accuracy": 1,
		"min_depth": 10,
		"salvage": {"cloth": 1},
	},
	"hollow_lantern": {
		"name": "ITEM_HOLLOW_LANTERN",
		"category": "offhand", "tags": ["offhand"], "slots": ["left_hand"],
		"icon": "res://assets/items/item-hollow-lantern.png",
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
		"category": "offhand", "tags": ["offhand"], "slots": ["left_hand"],
		"icon": "res://assets/items/item-pilgrim-shield.png",
		"damage": 0,
		"max_hp": 4,
		"soul_bonus": 0,
		"dodge": -1,
		"min_depth": 28,
		"salvage": {"wood": 2, "stone": 1},
	},
}

const ENEMIES := {
	"blind_scavenger": {
		"name": "ENEMY_BLIND_SCAVENGER",
		"glyph": "GLYPH_BLIND_SCAVENGER",
		"max_hp": 12,
		"damage": 1,
		"accuracy": 2,
		"dodge": 1,
		"vision": 2,
		"souls": 1,
		"min_depth": 4,
		"meat": true,
		"color": "9a8875",
	},
	"arachnid": {
		"name": "ENEMY_ARACHNID",
		"glyph": "GLYPH_ARACHNID",
		"max_hp": 7,
		"damage": 2,
		"accuracy": 4,
		"dodge": 3,
		"vision": 5,
		"souls": 3,
		"min_depth": 11,
		"meat": false,
		"abilities": ["double_attack"],
		"color": "8c807c",
	},
	"bone_crossbowman": {
		"name": "ENEMY_BONE_CROSSBOWMAN",
		"glyph": "GLYPH_BONE_CROSSBOWMAN",
		"max_hp": 5,
		"damage": 2,
		"accuracy": 4,
		"dodge": 0,
		"vision": 6,
		"range": 5,
		"souls": 3,
		"min_depth": 20,
		"meat": false,
		"attack_type": "ranged",
		"preparation_turns": 2,
		"attack_cooldown": 3,
		"recovery_turns": 1,
		"cancel_recovery_turns": 2,
		"color": "b6a58b",
	},
	"slag_smith": {
		"name": "ENEMY_SLAG_SMITH",
		"glyph": "GLYPH_SLAG_SMITH",
		"max_hp": 10,
		"damage": 2,
		"accuracy": 4,
		"dodge": 0,
		"vision": 5,
		"souls": 5,
		"min_depth": 15,
		"meat": false,
		"preparation_turns": 1,
		"heavy_damage": 5,
		"attack_cooldown": 6,
		"color": "9e6550",
	},
	"grave_rat": {
		"name": "ENEMY_GRAVE_RAT",
		"glyph": "GLYPH_GRAVE_RAT",
		"min_depth": 0,
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
		"min_depth": 6,
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
		"min_depth": 15,
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
		"boss": true,
		"max_hp": 36,
		"damage": 2,
		"souls": 12,
		"accuracy": 4,
		"dodge": 0,
		"vision": 6,
		"meat": true,
		"draw_footprint": Vector2(1.5, 2.0),
		"abilities": ["dash"],
		"color": "8f4c3e",
	},
}

const BODY_SKILL_IDS: Array[String] = [
	"strong_bones", "flexible_joints", "strong_spine",
	"sharp_vision", "muscle_fibers",
	"stomach", "flesh_regeneration", "ears",
	"nervous_system", "choose_appearance", "fundamentals",
]

const SKILLS := {
	"strong_bones": {
		"name": "SKILL_STRONG_BONES",
		"description": "SKILL_STRONG_BONES_DESC",
		"stage": "skeleton",
		"max_level": 5,
		"base_cost": 5,
		"cost_step": 5,
		"requires": {},
		"kind": "passive",
		"icon": "res://assets/ui/skill-icons/body/strong_bones.png",
	},
	"flexible_joints": {
		"name": "SKILL_FLEXIBLE_JOINTS",
		"description": "SKILL_FLEXIBLE_JOINTS_DESC",
		"stage": "skeleton",
		"max_level": 1,
		"base_cost": 15,
		"cost_step": 0,
		"requires": {},
		"kind": "passive",
		"icon": "res://assets/ui/skill-icons/body/flexible_joints.png",
	},
	"strong_spine": {
		"name": "SKILL_STRONG_SPINE",
		"description": "SKILL_STRONG_SPINE_DESC",
		"stage": "skeleton",
		"max_level": 1,
		"base_cost": 20,
		"cost_step": 0,
		"requires": {},
		"kind": "passive",
		"icon": "res://assets/ui/skill-icons/body/strong_spine.png",
	},
	"fundamentals": {
		"name": "SKILL_FUNDAMENTALS",
		"description": "SKILL_FUNDAMENTALS_DESC",
		"stage": "almost_human",
		"max_level": 1,
		"base_cost": 25,
		"cost_step": 0,
		"requires": {},
		"kind": "passive",
		"icon": "res://assets/ui/skill-icons/body/fundamentals.png",
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
		"stage": "ghoul",
		"max_level": 1,
		"base_cost": 20,
		"cost_step": 0,
		"requires": {},
		"kind": "passive",
		"icon": "res://assets/ui/skill-icons/body/flesh_regeneration.png",
	},
	"sharp_vision": {
		"name": "SKILL_SHARP_VISION",
		"description": "SKILL_SHARP_VISION_DESC",
		"stage": "zombie",
		"max_level": 1,
		"base_cost": 80,
		"cost_step": 0,
		"requires": {},
		"kind": "passive",
		"icon": "res://assets/ui/skill-icons/body/sharp_vision.png",
	},
	"muscle_fibers": {
		"name": "SKILL_MUSCLE_FIBERS",
		"description": "SKILL_MUSCLE_FIBERS_DESC",
		"stage": "zombie",
		"max_level": 2,
		"base_cost": 20,
		"cost_step": 10,
		"requires": {},
		"kind": "passive",
		"icon": "res://assets/ui/skill-icons/body/muscle_fibers.png",
	},
	"stomach": {
		"name": "SKILL_STOMACH",
		"description": "SKILL_STOMACH_DESC",
		"stage": "ghoul",
		"max_level": 1,
		"base_cost": 20,
		"cost_step": 0,
		"requires": {},
		"kind": "passive",
		"icon": "res://assets/ui/skill-icons/body/stomach.png",
	},
	"ears": {
		"name": "SKILL_EARS",
		"description": "SKILL_EARS_DESC",
		"stage": "ghoul",
		"max_level": 1,
		"base_cost": 20,
		"cost_step": 0,
		"requires": {},
		"kind": "passive",
		"icon": "res://assets/ui/skill-icons/body/ears.png",
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
	"nervous_system": {
		"name": "SKILL_NERVOUS_SYSTEM",
		"description": "SKILL_NERVOUS_SYSTEM_DESC",
		"stage": "revenant",
		"max_level": 1,
		"base_cost": 80,
		"cost_step": 0,
		"requires": {},
		"kind": "passive",
		"icon": "res://assets/ui/skill-icons/body/nervous_system.png",
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
	"choose_appearance": {
		"name": "SKILL_CHOOSE_APPEARANCE",
		"description": "SKILL_CHOOSE_APPEARANCE_DESC",
		"stage": "almost_human",
		"max_level": 1,
		"base_cost": 100,
		"cost_step": 0,
		"requires": {},
		"kind": "active",
		"ability_id": "choose_appearance",
		"icon": "res://assets/ui/skill-icons/body/choose_appearance.png",
	},
}


static func get_form(form_id: String) -> Dictionary:
	return FORMS.get(form_id, FORMS["skeleton"])


static func is_slot_unlocked(form_id: String, slot_id: String) -> bool:
	return EQUIPMENT_SLOTS.has(slot_id) and get_form(form_id).get("slots", []).has(slot_id)


static func slot_category(slot_id: String) -> String:
	return String(EQUIPMENT_SLOTS.get(slot_id, {}).get("category", ""))


static func item_category(item_key: String) -> String:
	return String(item_rules(item_key).get("category", ""))


static func item_tags(item_key: String) -> Array:
	return item_rules(item_key).get("tags", [])


static func compatible_slots(item_key: String) -> Array[String]:
	var result: Array[String] = []
	var item := item_rules(item_key)
	if item.is_empty():
		return result
	for slot_variant in item.get("slots", []):
		var slot_id := String(slot_variant)
		if EQUIPMENT_SLOTS.has(slot_id):
			result.append(slot_id)
	return result


static func item_fits_slot(item_key: String, slot_id: String) -> bool:
	if not EQUIPMENT_SLOTS.has(slot_id):
		return false
	var item := item_rules(item_key)
	if item.is_empty() or not compatible_slots(item_key).has(slot_id):
		return false
	var allowed: Array = EQUIPMENT_SLOTS[slot_id].get("allowed_tags", [])
	for tag_variant in item.get("tags", []):
		if allowed.has(String(tag_variant)):
			return true
	return false


static func is_weapon(item_key: String) -> bool:
	return item_category(item_key) == "weapon" or item_tags(item_key).has("weapon")


static func default_equip_slot(item_key: String, form_id: String, loadout: Dictionary = {}) -> String:
	var candidates := compatible_slots(item_key)
	for slot_id in candidates:
		if is_slot_unlocked(form_id, slot_id) and not loadout.has(slot_id):
			return slot_id
	if candidates.size() == 1 and is_slot_unlocked(form_id, candidates[0]):
		return candidates[0]
	return ""


static func resolve_physical_slot(
	candidates: Array[String],
	form_id: String,
	loadout: Dictionary = {},
	requested_slot := "",
) -> Dictionary:
	## Resolves a category's compatible physical destinations without knowing the
	## item itself. This keeps dual-position equipment (rings) deterministic and
	## lets the UI request replacement of an exact occupied slot.
	var requested := String(requested_slot)
	if not requested.is_empty():
		if not candidates.has(requested) or not is_slot_unlocked(form_id, requested):
			return {"ok": false, "reason": "slot_locked", "slot": requested}
		return {"ok": true, "slot": requested}
	var unlocked: Array[String] = []
	for slot_id in candidates:
		if not is_slot_unlocked(form_id, slot_id):
			continue
		unlocked.append(slot_id)
		if not loadout.has(slot_id):
			return {"ok": true, "slot": slot_id}
	if unlocked.is_empty():
		return {
			"ok": false,
			"reason": "slot_locked",
			"slot": candidates[0] if not candidates.is_empty() else "",
			"slots": candidates.duplicate(),
		}
	if unlocked.size() > 1:
		return {"ok": false, "reason": "slot_choice_required", "slots": unlocked}
	return {"ok": true, "slot": unlocked[0]}


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


static func required_soul_level(form_id: String) -> int:
	return maxi(SOUL_LEVEL_START, int(get_form(form_id).get("required_soul_level", SOUL_LEVEL_START)))


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
		if not is_weapon(String(item_key)):
			continue
		var type := String(item.get("attack_type", item.get("weapon_type", "melee")))
		if (
			parameter == "accuracy"
			or (parameter == "damage" and type == "melee")
			or (parameter == "ranged_damage" and type == "ranged")
		):
			result += item_upgrade_level(String(item_key))
	return result


static func weapon_type(item_key: String) -> String:
	# Compatibility adapter for callers and old tests. New data and UI use the two
	# independent dimensions exposed by weapon_attack_type() and weapon_grip().
	return weapon_attack_type(item_key)


static func weapon_attack_type(item_key: String) -> String:
	var item := item_rules(item_key)
	if not is_weapon(item_key):
		return ""
	return String(item.get("attack_type", item.get("weapon_type", "melee")))


static func weapon_grip(item_key: String) -> String:
	if not is_weapon(item_key):
		return ""
	return String(item_rules(item_key).get("grip", "one_handed"))


static func is_two_handed_weapon(item_key: String) -> bool:
	return weapon_grip(item_key) == "two_handed"


static func weapon_range(item_key: String) -> int:
	if weapon_attack_type(item_key) != "ranged":
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


static func is_item_lootable(item_key: String) -> bool:
	var rules := item_rules(item_key)
	return not rules.is_empty() and bool(rules.get("lootable", true))


static func is_item_movable(item_key: String) -> bool:
	var rules := item_rules(item_key)
	return not rules.is_empty() and bool(rules.get("movable", true))


static func is_item_permanent(item_key: String) -> bool:
	var rules := item_rules(item_key)
	return not rules.is_empty() and bool(rules.get("permanent", false))


static func permanent_jacket_key() -> String:
	return make_item_key(PERMANENT_JACKET_ITEM_ID)


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
		if bool(EQUIPMENT[item_id].get("lootable", true)) and depth >= int(EQUIPMENT[item_id]["min_depth"]):
			result.append(item_id)
	return result


static func enemy_pool(floor_number: int) -> Array:
	var depth := 100 - floor_number
	var result: Array = []
	for enemy_id in ENEMIES:
		var enemy: Dictionary = ENEMIES[enemy_id]
		if not bool(enemy.get("boss", false)) and depth >= int(enemy.get("min_depth", 0)):
			result.append(enemy_id)
	return result


static func biome_id(floor_number: int) -> String:
	return "weaving_crypts" if floor_number >= WEAVING_CRYPTS_MIN_FLOOR and floor_number <= WEAVING_CRYPTS_MAX_FLOOR else ""
