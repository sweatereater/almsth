class_name FixedFloor90
extends RefCounted

## Hand-authored boss floor. Symbols keep the arena readable and cheap to edit:
## # wall, . floor, D closed boss door, > exit, S start, M boss.

const FLOOR_NUMBER := 90
const WIDTH := 20
const HEIGHT := 14
const DOOR_TILE := "boss_door_closed"
const BOSS_ID := "minotaur"
const BOSS_UID := "boss_minotaur_90"

const LAYOUT := [
	"      #########     ",
	"      #.......#     ",
	"      #...>...#     ",
	"  ########D#######  ",
	"  #..............#  ",
	"  #..............#  ",
	"  #..##......##..#  ",
	"  #.......M......#  ",
	"  #..............#  ",
	"  #..##......##..#  ",
	"  #..............#  ",
	"  #.......S......#  ",
	"  ################  ",
	"                    ",
]


static func create() -> Dictionary:
	var tiles: Dictionary = {}
	var start := Vector2i(-1, -1)
	var exit := Vector2i(-1, -1)
	var base_gate := Vector2i(-1, -1)
	var door := Vector2i(-1, -1)
	var boss_position := Vector2i(-1, -1)

	for y in range(HEIGHT):
		var row: String = LAYOUT[y]
		assert(row.length() == WIDTH, "Fixed level 90 rows must match WIDTH")
		for x in range(WIDTH):
			var cell := Vector2i(x, y)
			var symbol := row.substr(x, 1)
			match symbol:
				"#":
					tiles[cell] = "wall"
				"D":
					tiles[cell] = DOOR_TILE
					door = cell
				"S":
					tiles[cell] = "floor"
					start = cell
				"B":
					tiles[cell] = "floor"
					base_gate = cell
				">":
					tiles[cell] = "floor"
					exit = cell
				"M":
					tiles[cell] = "floor"
					boss_position = cell
				".":
					tiles[cell] = "floor"
				_:
					tiles[cell] = "void"

	assert(start.x >= 0 and exit.x >= 0, "Fixed level 90 needs its entry and upward route")
	assert(door.x >= 0 and boss_position.x >= 0, "Fixed level 90 needs its door and boss")

	var boss_rules: Dictionary = GameRules.ENEMIES[BOSS_ID]
	var boss_max_hp := int(boss_rules["max_hp"])
	return {
		"width": WIDTH,
		"height": HEIGHT,
		"tiles": tiles,
		"start": start,
		"exit": exit,
		"exit_known": false,
		"base_gate": base_gate,
		"enemies": [{
			"uid": BOSS_UID,
			"id": BOSS_ID,
			"pos": boss_position,
			"hp": boss_max_hp,
			"max_hp": boss_max_hp,
			"damage": int(boss_rules["damage"]),
			"accuracy": int(boss_rules["accuracy"]),
			"dodge": int(boss_rules["dodge"]),
			"vision": int(boss_rules["vision"]),
			"souls": int(boss_rules["souls"]),
			"abilities": boss_rules.get("abilities", []).duplicate(),
		}],
		"items": [
			{"uid": "item_reward_0", "id": "bone_bow", "pos": Vector2i(8, 1), "wood": 1, "stone": 1},
			{"uid": "item_reward_1", "id": "pilgrim_shield", "pos": Vector2i(12, 1), "wood": 1, "stone": 1},
		],
		"cradle": Vector2i(-1, -1),
		"cradle_known": false,
		"cradle_pity_resolved": false,
		"cradle_used": false,
		"visible_cells": {},
		"explored_cells": {},
		"observed_cells": {},
		"cradle_roll_chance": 0.0,
		"seed": 0,
		"fixed_layout": true,
		"boss_uid": BOSS_UID,
		"boss_defeated": false,
		"boss_door": door,
		"boss_door_open": false,
	}
