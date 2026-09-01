class_name RunSnapshot
extends RefCounted

const FixedFloor90Script := preload("res://scripts/world/fixed_floor_90.gd")
const FloorGeneratorScript := preload("res://scripts/world/floor_generator.gd")
const GridNavigationScript := preload("res://scripts/world/grid_navigation.gd")

## JSON-safe, data-only snapshots. Cell maps are arrays to preserve insertion order;
## neither Variant object deserialization nor floor generation is used on load.
const FORMAT_VERSION := 2
const ENVELOPE_FIELDS := [
	"format", "context", "floor_data", "player_pos", "rng_seed", "rng_state", "hearing",
]


static func capture(context: String, floor: Dictionary, position: Vector2i,
		random: RandomNumberGenerator, hearing: Dictionary) -> Dictionary:
	return {
		"format": FORMAT_VERSION,
		"context": context,
		"floor_data": encode(floor if context == "dungeon" else {}),
		"player_pos": encode(position if context == "dungeon" else Vector2i.ZERO),
		"rng_seed": str(random.seed),
		"rng_state": str(random.state),
		"hearing": encode(hearing if context == "dungeon" else {}),
	}


static func encode(value: Variant) -> Variant:
	if value is float:
		# Decimal JSON parsing can change the last bit even with full_precision.
		# Eight explicitly encoded bytes keep fractional accumulators deterministic.
		var bytes := PackedByteArray()
		bytes.resize(8)
		bytes.encode_double(0, value)
		return {"$float64": bytes.hex_encode()}
	if value is Vector2i:
		return {"$cell": [value.x, value.y]}
	if value is Dictionary:
		if not value.is_empty() and value.keys()[0] is Vector2i:
			var cells: Array = []
			for cell in value:
				cells.append([cell.x, cell.y, encode(value[cell])])
			return {"$cells": cells}
		var result := {}
		for key in value:
			result[key] = encode(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry in value:
			result.append(encode(entry))
		return result
	return value


static func decode(value: Variant, errors: Array, depth := 0) -> Variant:
	if depth > 24:
		errors.append("depth")
		return null
	if value is Dictionary:
		if value.has("$float64"):
			var encoded: Variant = value["$float64"]
			if value.size() != 1 or not encoded is String or encoded.length() != 16:
				errors.append("float64")
				return null
			for character in encoded:
				if not "0123456789abcdef".contains(character):
					errors.append("float64 digit")
					return null
			var number: float = encoded.hex_decode().decode_double(0)
			if not is_finite(number):
				errors.append("float64 finite")
				return null
			return number
		if value.has("$cell"):
			var pair: Variant = value["$cell"]
			if value.size() != 1 or not pair is Array or pair.size() != 2 or not _integer(pair[0]) or not _integer(pair[1]):
				errors.append("cell")
				return null
			return Vector2i(int(pair[0]), int(pair[1]))
		if value.has("$cells"):
			var rows: Variant = value["$cells"]
			if value.size() != 1 or not rows is Array or rows.size() > 10000:
				errors.append("cells")
				return null
			var result := {}
			for row in rows:
				if not row is Array or row.size() != 3 or not _integer(row[0]) or not _integer(row[1]):
					errors.append("row")
					return null
				var cell := Vector2i(int(row[0]), int(row[1]))
				if result.has(cell):
					errors.append("duplicate cell")
				result[cell] = decode(row[2], errors, depth + 1)
			return result
		var result := {}
		for key in value:
			if not key is String:
				errors.append("key")
				return null
			result[key] = decode(value[key], errors, depth + 1)
		return result
	if value is Array:
		if value.size() > 10000:
			errors.append("array")
			return null
		var result: Array = []
		for entry in value:
			result.append(decode(entry, errors, depth + 1))
		return result
	if value is float:
		if not is_finite(value):
			errors.append("number")
		return int(value) if _integer(value) else value
	if value == null or value is String or value is bool or value is int:
		return value
	errors.append("type")
	return null


static func restore(snapshot: Variant, state_data: Dictionary) -> Dictionary:
	if (
		not snapshot is Dictionary
		or snapshot.size() != ENVELOPE_FIELDS.size()
		or snapshot.get("format") != FORMAT_VERSION
	):
		return {}
	for field in ENVELOPE_FIELDS:
		if not snapshot.has(field):
			return {}
	if not RunState.is_snapshot_data_valid(state_data):
		return {}
	var context: Variant = snapshot.get("context")
	if context not in ["base", "dungeon", "victory"]:
		return {}
	if not _int64_string(snapshot.get("rng_seed")) or not _int64_string(snapshot.get("rng_state")):
		return {}
	var errors: Array = []
	var floor: Variant = decode(snapshot.get("floor_data"), errors)
	var position: Variant = decode(snapshot.get("player_pos"), errors)
	var hearing: Variant = decode(snapshot.get("hearing"), errors)
	if not errors.is_empty() or not floor is Dictionary or not position is Vector2i or not hearing is Dictionary:
		return {}
	if context == "dungeon":
		var floor_number := int(state_data["current_floor"])
		if floor_number > 99 or not _valid_floor(floor, position, floor_number, state_data):
			return {}
		if not _valid_hearing(
			hearing, floor, int(state_data["total_turns"]), _state_has_hearing(state_data),
		):
			return {}
		floor["cradle_roll_chance"] = float(floor["cradle_roll_chance"])
	elif not floor.is_empty() or not hearing.is_empty() or position != Vector2i.ZERO:
		return {}
	return {"context": context, "floor_data": floor, "player_pos": position,
		"rng_seed": int(snapshot["rng_seed"]), "rng_state": int(snapshot["rng_state"]),
		"hearing": hearing}


static func _valid_floor(
	floor: Dictionary, position: Vector2i, floor_number: int, state_data: Dictionary,
) -> bool:
	if not _integer(floor.get("width")) or not _integer(floor.get("height")):
		return false
	if int(floor.width) < 1 or int(floor.width) > 100 or int(floor.height) < 1 or int(floor.height) > 100:
		return false
	for field in ["tiles", "visible_cells", "explored_cells", "observed_cells"]:
		if not floor.get(field) is Dictionary:
			return false
		for cell in floor[field]:
			if not _in_bounds(cell, floor):
				return false
			if field == "tiles":
				if floor[field][cell] not in ["floor", "wall", "void", "door_closed", "boss_door_closed"]:
					return false
			elif not floor[field][cell] is bool:
				return false
	if floor.tiles.size() != int(floor.width) * int(floor.height):
		return false
	if not _integer(floor.get("seed")) or not (floor.get("cradle_roll_chance") is float or floor.get("cradle_roll_chance") is int):
		return false
	if float(floor.cradle_roll_chance) < 0.0 or float(floor.cradle_roll_chance) > 1.0:
		return false
	var is_boss_floor := floor_number == FixedFloor90Script.FLOOR_NUMBER
	var boss_fields := ["boss_uid", "boss_defeated", "boss_door", "boss_door_open"]
	if is_boss_floor:
		if (
			floor.get("fixed_layout") != true
			or floor.has("rooms")
			or int(floor.width) != FixedFloor90Script.WIDTH
			or int(floor.height) != FixedFloor90Script.HEIGHT
			or int(floor.seed) != 0
		):
			return false
		for field in boss_fields:
			if not floor.has(field):
				return false
	else:
		if floor.has("fixed_layout"):
			return false
		for field in boss_fields:
			if floor.has(field):
				return false
		if (
			not floor.get("rooms") is Array
			or floor.rooms.size() < 2
			or floor.rooms.size() > 3
		):
			return false
	if not _walkable(position, floor):
		return false
	var landmarks := {}
	for field in ["start", "exit", "base_gate", "cradle"]:
		if not floor.get(field) is Vector2i:
			return false
		if field in ["base_gate", "cradle"] and floor[field] == Vector2i(-1, -1):
			continue
		if not _walkable(floor[field], floor):
			return false
		if landmarks.has(floor[field]):
			return false
		landmarks[floor[field]] = field
	for field in ["exit_known", "cradle_known", "cradle_used", "cradle_pity_resolved"]:
		if not floor.get(field) is bool:
			return false
	if not floor.get("enemies") is Array or not floor.get("items") is Array:
		return false
	var uids := {}
	var occupied := {}
	for enemy in floor.enemies:
		if not enemy is Dictionary or not _valid_entity(enemy, floor, uids):
			return false
		if (
			not GameRules.ENEMIES.has(enemy.get("id"))
			or (
				is_boss_floor
				and (
					enemy.get("id") != FixedFloor90Script.BOSS_ID
					or enemy.get("uid") != FixedFloor90Script.BOSS_UID
				)
			)
			or (
				not is_boss_floor
				and not GameRules.enemy_pool(floor_number).has(enemy.get("id"))
			)
			or occupied.has(enemy.pos)
			or enemy.pos == position
			or landmarks.has(enemy.pos)
		):
			return false
		occupied[enemy.pos] = true
		var rules: Dictionary = GameRules.ENEMIES[enemy.id]
		var depth := 100 - floor_number
		var expected_stats := {
			"max_hp": int(rules.max_hp) + FloorGeneratorScript.enemy_stat_bonus_for_depth(
				depth, FloorGeneratorScript.ENEMY_HP_DEPTH_INTERVAL,
			),
			"damage": int(rules.damage) + FloorGeneratorScript.enemy_stat_bonus_for_depth(
				depth, FloorGeneratorScript.ENEMY_DAMAGE_DEPTH_INTERVAL,
			),
			"accuracy": int(rules.accuracy) + FloorGeneratorScript.enemy_stat_bonus_for_depth(
				depth, FloorGeneratorScript.ENEMY_ACCURACY_DEPTH_INTERVAL,
			),
			"dodge": int(rules.dodge) + FloorGeneratorScript.enemy_stat_bonus_for_depth(
				depth, FloorGeneratorScript.ENEMY_DODGE_DEPTH_INTERVAL,
			),
			"vision": int(rules.vision),
			"souls": int(rules.souls) + FloorGeneratorScript.enemy_stat_bonus_for_depth(
				depth, FloorGeneratorScript.ENEMY_SOULS_DEPTH_INTERVAL,
			),
		}
		for field in ["hp", "max_hp", "damage", "accuracy", "dodge", "vision", "souls"]:
			if not _integer(enemy.get(field)) or int(enemy[field]) < 0:
				return false
			if field != "hp" and int(enemy[field]) != int(expected_stats[field]):
				return false
		if int(enemy.hp) <= 0 or int(enemy.hp) > int(enemy.max_hp):
			return false
		if enemy.has("last_seen_player") and not _walkable(enemy.last_seen_player, floor):
			return false
		if enemy.has("has_seen_player") and not enemy.has_seen_player is bool:
			return false
		if (
			not enemy.has("attack_type")
			or enemy.attack_type != String(rules.get("attack_type", "melee"))
		):
			return false
		if (
			not enemy.has("range")
			or (
				not _integer(enemy.range)
				or int(enemy.range) != int(rules.get("range", 1))
			)
		):
			return false
		if (
			enemy.has("ability_cooldowns")
			and not _valid_enemy_cooldowns(enemy.ability_cooldowns, rules)
		):
			return false
		for field in ["special_cooldown", "recovery_remaining"]:
			var limit := int(GameRules.ENEMIES[enemy.id].get("attack_cooldown" if field == "special_cooldown" else "recovery_turns", 0))
			if enemy.has(field) and (not _integer(enemy[field]) or int(enemy[field]) < 0 or int(enemy[field]) > limit):
				return false
		if enemy.has("preparation"):
			var preparation: Variant = enemy.preparation
			if (
				not preparation is Dictionary
				or preparation.size() != 2
				or not _integer(preparation.get("remaining"))
				or int(preparation.remaining) < 1
				or int(preparation.remaining) > int(rules.get("preparation_turns", 0))
				or preparation.get("target") != position
			):
				return false
		var canonical_abilities: Array = rules.get("abilities", [])
		if (
			(not canonical_abilities.is_empty() and not enemy.has("abilities"))
			or (
				enemy.has("abilities")
				and (
					not enemy.abilities is Array
					or enemy.abilities != canonical_abilities
				)
			)
		):
			return false
	var item_positions := {}
	for item in floor.items:
		if not item is Dictionary or not _valid_entity(item, floor, uids) or not GameRules.EQUIPMENT.has(item.get("id")):
			return false
		if (
			item_positions.has(item.pos)
			or occupied.has(item.pos)
			or item.pos == position
			or landmarks.has(item.pos)
		):
			return false
		item_positions[item.pos] = true
		if item.get("appearance") not in ["chest", "crypt"]:
			return false
		for field in ["wood", "stone"]:
			if not _integer(item.get(field)) or int(item[field]) < 0 or int(item[field]) > 2:
				return false
	# Every current v17/format2 dungeon is produced with durable cosmetic records. Their
	# absence is corruption, not an older floor to regenerate or quietly default.
	if floor.get("biome") not in ["", "weaving_crypts"]:
		return false
	if not floor.get("initial_enemy_kinds") is Array or not floor.get("decorations") is Dictionary:
		return false
	for kind in floor.initial_enemy_kinds:
		if not GameRules.ENEMIES.has(kind):
			return false
	for cell in floor.decorations:
		var decoration: Variant = floor.decorations[cell]
		if not _walkable(cell, floor) or not decoration is Dictionary or decoration.get("kind") not in ["mosaic", "cocoon"] or not _integer(decoration.get("variant")):
			return false
		if int(decoration.variant) < 0 or int(decoration.variant) >= (3 if decoration.kind == "mosaic" else 2):
			return false
		if decoration.kind == "mosaic" and (not _integer(decoration.get("patch")) or int(decoration.patch) < 0):
			return false
	var rooms: Array = floor.get("rooms", [])
	var room_doors := {}
	var claimed_room_cells := {}
	for room in rooms:
		if not room is Dictionary or not _in_bounds(room.get("door"), floor) or not room.get("outward") is Vector2i:
			return false
		if (
			absi(room.outward.x) + absi(room.outward.y) != 1
			or floor.tiles.get(room.door) not in ["door_closed", "floor"]
			or room_doors.has(room.door)
			or landmarks.has(room.door)
			or not _walkable(room.door + room.outward, floor)
		):
			return false
		room_doors[room.door] = true
		for field in ["cells", "reserved"]:
			if not room.get(field) is Dictionary or room[field].is_empty():
				return false
			for cell in room[field]:
				if not _in_bounds(cell, floor) or room[field][cell] != true:
					return false
		if not room.reserved.has(room.door) or room.cells.has(room.door):
			return false
		var inside: Vector2i = room.door - room.outward
		var canonical_cells := _floor_component_without_door(floor, inside, room.door)
		if canonical_cells.is_empty() or room.cells != canonical_cells:
			return false
		for cell in room.cells:
			if (
				not room.reserved.has(cell)
				or claimed_room_cells.has(cell)
				or landmarks.has(cell)
			):
				return false
			claimed_room_cells[cell] = true
	if is_boss_floor:
		if (
			floor.boss_uid != FixedFloor90Script.BOSS_UID
			or not floor.get("boss_defeated") is bool
			or not floor.get("boss_door_open") is bool
		):
			return false
		if not _in_bounds(floor.get("boss_door"), floor) or floor.boss_door_open != floor.boss_defeated:
			return false
		if floor.tiles.get(floor.boss_door) != ("floor" if floor.boss_door_open else "boss_door_closed"):
			return false
		if uids.has(floor.boss_uid) == floor.boss_defeated:
			return false
		if floor.enemies.size() != (0 if floor.boss_defeated else 1):
			return false
		if (
			bool(state_data.milestones.get("minotaur_defeated", false))
			!= bool(floor.boss_defeated)
			or bool(state_data.milestones.get("minotaur_tail_awarded", false))
			!= bool(floor.boss_defeated)
		):
			return false
		if not floor.boss_defeated:
			var found_canonical_boss := false
			for enemy in floor.enemies:
				if enemy.uid == floor.boss_uid:
					found_canonical_boss = enemy.id == FixedFloor90Script.BOSS_ID
					break
			if not found_canonical_boss:
				return false
	return true


static func _valid_entity(entity: Dictionary, floor: Dictionary, uids: Dictionary) -> bool:
	var uid: Variant = entity.get("uid")
	if not uid is String or uid.is_empty() or uids.has(uid) or not _walkable(entity.get("pos"), floor):
		return false
	uids[uid] = true
	return true


static func _valid_hearing(
	hearing: Dictionary, floor: Dictionary, turn: int, state_has_hearing: bool,
) -> bool:
	if (
		hearing.size() != 2
		or not hearing.has("event_revision")
		or not hearing.has("attack_memories")
		or not _integer(hearing.get("event_revision"))
		or int(hearing.event_revision) < 0
		or not hearing.get("attack_memories") is Dictionary
	):
		return false
	if (
		not state_has_hearing
		and (int(hearing.event_revision) != 0 or not hearing.attack_memories.is_empty())
	):
		return false
	if int(hearing.event_revision) < hearing.attack_memories.size():
		return false
	var enemies := {}
	for enemy in floor.enemies:
		enemies[enemy.uid] = enemy
	for uid in hearing.attack_memories:
		var memory: Variant = hearing.attack_memories[uid]
		if (
			not enemies.has(uid)
			or not memory is Dictionary
			or memory.size() != 3
			or not memory.has("uid")
			or not memory.has("pos")
			or not memory.has("expires_after_turn")
			or memory.get("uid") != uid
			or not _walkable(memory.get("pos"), floor)
		):
			return false
		var enemy: Dictionary = enemies[uid]
		if (
			bool(floor.visible_cells.get(enemy.pos, false))
			or bool(floor.visible_cells.get(memory.pos, false))
			or GridNavigationScript.is_in_sealed_room(floor, enemy.pos)
			or GridNavigationScript.is_in_sealed_room(floor, memory.pos)
		):
			return false
		if not _integer(memory.get("expires_after_turn")) or int(memory.expires_after_turn) <= turn:
			return false
		if (
			int(memory.expires_after_turn) != turn + 1
			or memory.pos != enemy.pos
			or int(hearing.event_revision) <= 0
		):
			return false
	return true


static func _state_has_hearing(state_data: Dictionary) -> bool:
	return (
		GameRules.FORM_ORDER.find(String(state_data.current_form_id))
		>= GameRules.FORM_ORDER.find("ghoul")
		and int(state_data.skill_levels.get("ears", 0)) > 0
	)


static func _floor_component_without_door(
	floor: Dictionary, start: Vector2i, blocked_door: Vector2i,
) -> Dictionary:
	if not _walkable(start, floor) or start == blocked_door:
		return {}
	var result := {start: true}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		for direction: Vector2i in [
			Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
		]:
			var neighbor: Vector2i = cell + direction
			if neighbor == blocked_door or result.has(neighbor) or not _walkable(neighbor, floor):
				continue
			result[neighbor] = true
			frontier.append(neighbor)
	return result


static func _valid_cooldowns(value: Variant) -> bool:
	return value is Dictionary and RunState.AbilitySystem.sanitize_cooldowns(value) == value


static func _valid_enemy_cooldowns(value: Variant, rules: Dictionary) -> bool:
	if not _valid_cooldowns(value):
		return false
	var allowed: Array = rules.get("abilities", [])
	for ability_id in value:
		if not allowed.has(ability_id):
			return false
	return true


static func _in_bounds(value: Variant, floor: Dictionary) -> bool:
	return value is Vector2i and value.x >= 0 and value.y >= 0 and value.x < floor.width and value.y < floor.height


static func _walkable(value: Variant, floor: Dictionary) -> bool:
	return _in_bounds(value, floor) and floor.tiles.get(value) == "floor"


static func _integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value) and absf(value) < 9007199254740992.0)


static func _int64_string(value: Variant) -> bool:
	return value is String and value.is_valid_int() and str(int(value)) == value
