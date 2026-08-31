class_name RunSnapshot
extends RefCounted

## JSON-safe, data-only snapshots. Cell maps are arrays to preserve insertion order;
## neither Variant object deserialization nor floor generation is used on load.
const FORMAT_VERSION := 2


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
	if not snapshot is Dictionary or snapshot.get("format") != FORMAT_VERSION:
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
		if int(state_data["current_floor"]) > 99 or not _valid_floor(floor, position):
			return {}
		if not _valid_hearing(hearing, floor, int(state_data["total_turns"])):
			return {}
		floor["cradle_roll_chance"] = float(floor["cradle_roll_chance"])
	elif not floor.is_empty() or not hearing.is_empty() or position != Vector2i.ZERO:
		return {}
	return {"context": context, "floor_data": floor, "player_pos": position,
		"rng_seed": int(snapshot["rng_seed"]), "rng_state": int(snapshot["rng_state"]),
		"hearing": hearing}


static func _valid_floor(floor: Dictionary, position: Vector2i) -> bool:
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
	if floor.has("fixed_layout") and not floor.fixed_layout is bool:
		return false
	if not _walkable(position, floor):
		return false
	for field in ["start", "exit", "base_gate", "cradle"]:
		if not floor.get(field) is Vector2i:
			return false
		if field in ["base_gate", "cradle"] and floor[field] == Vector2i(-1, -1):
			continue
		if not _walkable(floor[field], floor):
			return false
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
		if not GameRules.ENEMIES.has(enemy.get("id")) or occupied.has(enemy.pos) or enemy.pos == position:
			return false
		occupied[enemy.pos] = true
		for field in ["hp", "max_hp", "damage", "accuracy", "dodge", "vision", "souls"]:
			if not _integer(enemy.get(field)) or int(enemy[field]) < 0:
				return false
		if int(enemy.hp) <= 0 or int(enemy.hp) > int(enemy.max_hp):
			return false
		if enemy.has("last_seen_player") and not _in_bounds(enemy.last_seen_player, floor):
			return false
		if enemy.has("has_seen_player") and not enemy.has_seen_player is bool:
			return false
		if enemy.has("attack_type") and enemy.attack_type not in ["melee", "ranged"]:
			return false
		if enemy.has("range") and (not _integer(enemy.range) or int(enemy.range) < 0):
			return false
		if enemy.has("ability_cooldowns") and not _valid_cooldowns(enemy.ability_cooldowns):
			return false
		for field in ["special_cooldown", "recovery_remaining"]:
			var limit := int(GameRules.ENEMIES[enemy.id].get("attack_cooldown" if field == "special_cooldown" else "recovery_turns", 0))
			if enemy.has(field) and (not _integer(enemy[field]) or int(enemy[field]) < 0 or int(enemy[field]) > limit):
				return false
		if enemy.has("preparation"):
			var preparation: Variant = enemy.preparation
			var rules: Dictionary = GameRules.ENEMIES[enemy.id]
			if not preparation is Dictionary or not _integer(preparation.get("remaining")) or int(preparation.remaining) < 1 or int(preparation.remaining) > int(rules.get("preparation_turns", 0)) or not _walkable(preparation.get("target"), floor):
				return false
		if enemy.has("abilities"):
			if not enemy.abilities is Array:
				return false
			for ability in enemy.abilities:
				if not ability is String or not RunState.AbilitySystem.ABILITIES.has(ability):
					return false
	var item_positions := {}
	for item in floor.items:
		if not item is Dictionary or not _valid_entity(item, floor, uids) or not GameRules.EQUIPMENT.has(item.get("id")):
			return false
		if item_positions.has(item.pos):
			return false
		item_positions[item.pos] = true
		if item.get("appearance") not in ["chest", "crypt"]:
			return false
		for field in ["wood", "stone"]:
			if not _integer(item.get(field)) or int(item[field]) < 0:
				return false
	# Every v15/format2 dungeon is produced with durable cosmetic records. Their
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
	if not floor.get("rooms", []) is Array:
		return false
	for room in floor.get("rooms", []):
		if not room is Dictionary or not _in_bounds(room.get("door"), floor) or not room.get("outward") is Vector2i:
			return false
		if absi(room.outward.x) + absi(room.outward.y) != 1 or floor.tiles.get(room.door) not in ["door_closed", "floor"]:
			return false
		for field in ["cells", "reserved"]:
			if not room.get(field) is Dictionary:
				return false
			for cell in room[field]:
				if not _in_bounds(cell, floor) or not room[field][cell] is bool:
					return false
	if floor.has("boss_uid"):
		if not floor.boss_uid is String or not floor.get("boss_defeated") is bool or not floor.get("boss_door_open") is bool:
			return false
		if not _in_bounds(floor.get("boss_door"), floor) or floor.boss_door_open != floor.boss_defeated:
			return false
		if floor.tiles.get(floor.boss_door) != ("floor" if floor.boss_door_open else "boss_door_closed"):
			return false
		if uids.has(floor.boss_uid) == floor.boss_defeated:
			return false
	return true


static func _valid_entity(entity: Dictionary, floor: Dictionary, uids: Dictionary) -> bool:
	var uid: Variant = entity.get("uid")
	if not uid is String or uid.is_empty() or uids.has(uid) or not _walkable(entity.get("pos"), floor):
		return false
	uids[uid] = true
	return true


static func _valid_hearing(hearing: Dictionary, floor: Dictionary, turn: int) -> bool:
	if not _integer(hearing.get("event_revision")) or int(hearing.event_revision) < 0 or not hearing.get("attack_memories") is Dictionary:
		return false
	var enemies := {}
	for enemy in floor.enemies:
		enemies[enemy.uid] = true
	for uid in hearing.attack_memories:
		var memory: Variant = hearing.attack_memories[uid]
		if not enemies.has(uid) or not memory is Dictionary or memory.get("uid") != uid or not _in_bounds(memory.get("pos"), floor):
			return false
		if not _integer(memory.get("expires_after_turn")) or int(memory.expires_after_turn) <= turn:
			return false
	return true


static func _valid_cooldowns(value: Variant) -> bool:
	return value is Dictionary and RunState.AbilitySystem.sanitize_cooldowns(value) == value


static func _in_bounds(value: Variant, floor: Dictionary) -> bool:
	return value is Vector2i and value.x >= 0 and value.y >= 0 and value.x < floor.width and value.y < floor.height


static func _walkable(value: Variant, floor: Dictionary) -> bool:
	return _in_bounds(value, floor) and floor.tiles.get(value) == "floor"


static func _integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value) and absf(value) < 9007199254740992.0)


static func _int64_string(value: Variant) -> bool:
	return value is String and value.is_valid_int() and str(int(value)) == value
