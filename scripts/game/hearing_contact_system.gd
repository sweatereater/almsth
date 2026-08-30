class_name HearingContactSystem
extends RefCounted

## Ephemeral, identity-free presentation model for sounds outside true vision.
## Main owns one instance for the current dungeon context. Nothing here is saved.

var event_revision := 0
var _proximity_positions: Dictionary = {}
var _attack_memories: Dictionary = {}


func clear() -> void:
	_proximity_positions.clear()
	_attack_memories.clear()
	event_revision = 0


func remove_uid(uid: String) -> void:
	if uid.is_empty():
		return
	_proximity_positions.erase(uid)
	_attack_memories.erase(uid)


func sync_proximity(
	enemies: Array,
	player_pos: Vector2i,
	hearing_radius: int,
	visible_cells: Dictionary,
	floor_data: Dictionary = {},
) -> Dictionary:
	var living_hidden: Dictionary = {}
	var all_living: Dictionary = {}
	var newly_heard: Array[String] = []
	var radius := maxi(0, hearing_radius)
	for value in enemies:
		if not value is Dictionary:
			continue
		var enemy: Dictionary = value
		var uid := String(enemy.get("uid", ""))
		var pos_value: Variant = enemy.get("pos")
		if uid.is_empty() or not pos_value is Vector2i or int(enemy.get("hp", 0)) <= 0:
			continue
		if GridNavigation.is_in_sealed_room(floor_data, pos_value):
			continue
		all_living[uid] = true
		var pos: Vector2i = pos_value
		if visible_cells.get(pos, false):
			continue
		if _manhattan(player_pos, pos) <= radius:
			living_hidden[uid] = pos
			if not _proximity_positions.has(uid):
				newly_heard.append(uid)
				event_revision += 1

	# Visibility and removal invalidate every source for that UID. A living hidden
	# enemy outside hearing only loses its continuous source; its attack snapshot stays.
	for uid_value in _attack_memories.keys():
		var uid := String(uid_value)
		if not all_living.has(uid):
			_attack_memories.erase(uid)
			continue
		var enemy := _find_enemy(enemies, uid)
		if not enemy.is_empty() and visible_cells.get(enemy.get("pos", Vector2i(-1, -1)), false):
			_attack_memories.erase(uid)
	_proximity_positions = living_hidden
	return {
		"new_uids": newly_heard,
		"has_new": not newly_heard.is_empty(),
		"event_revision": event_revision,
	}


func record_hidden_attack(uid: String, origin: Vector2i, accepted_turn_serial: int) -> bool:
	if uid.is_empty():
		return false
	_attack_memories[uid] = {
		"uid": uid,
		"pos": origin,
		"expires_after_turn": maxi(0, accepted_turn_serial) + 1,
	}
	event_revision += 1
	return true


func prune_after_round(completed_turn_serial: int) -> void:
	for uid_value in _attack_memories.keys():
		var memory: Dictionary = _attack_memories[uid_value]
		if completed_turn_serial >= int(memory.get("expires_after_turn", 0)):
			_attack_memories.erase(uid_value)


func presentation_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	var occupied: Dictionary = {}
	var uids: Array[String] = []
	for uid_value in _proximity_positions.keys():
		uids.append(String(uid_value))
	for uid_value in _attack_memories.keys():
		var uid := String(uid_value)
		if not uids.has(uid):
			uids.append(uid)
	uids.sort()
	for uid in uids:
		var pos_value: Variant
		if _proximity_positions.has(uid):
			pos_value = _proximity_positions[uid]
		else:
			pos_value = _attack_memories.get(uid, {}).get("pos")
		if not pos_value is Vector2i:
			continue
		var pos: Vector2i = pos_value
		if occupied.has(pos):
			continue
		occupied[pos] = true
		positions.append(pos)
	positions.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return positions


func has_contact_at(pos: Vector2i) -> bool:
	return presentation_positions().has(pos)


## One shared presentation/input contract for anonymous hearing markers. A raw
## contact remains in the ephemeral model while a visible entity temporarily
## occupies its cell, but it must neither draw nor intercept that cell.
static func is_contact_presented(
	has_raw_contact: bool,
	floor_data: Dictionary,
	player_pos: Vector2i,
	cell: Vector2i,
) -> bool:
	if not has_raw_contact:
		return false
	if (
		cell.x < 0 or cell.y < 0
		or cell.x >= int(floor_data.get("width", 0))
		or cell.y >= int(floor_data.get("height", 0))
		or cell == player_pos
	):
		return false
	var visible_cells: Dictionary = floor_data.get("visible_cells", {})
	if not bool(visible_cells.get(cell, false)):
		return true
	for enemy_variant in floor_data.get("enemies", []):
		var enemy: Dictionary = enemy_variant
		if enemy.get("pos", Vector2i(-1, -1)) == cell:
			return false
	for item_variant in floor_data.get("items", []):
		var item: Dictionary = item_variant
		if item.get("pos", Vector2i(-1, -1)) == cell:
			return false
	return true


func proximity_count() -> int:
	return _proximity_positions.size()


func attack_memory_count() -> int:
	return _attack_memories.size()


func _find_enemy(enemies: Array, uid: String) -> Dictionary:
	for value in enemies:
		if value is Dictionary and String(value.get("uid", "")) == uid:
			return value
	return {}


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
