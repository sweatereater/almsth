class_name FloorGenerator
extends RefCounted

const WIDTH := 40
const HEIGHT := 40
const CARDINAL_DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const ENEMY_COUNT_BASE := 5
const ENEMY_COUNT_MAX := 12
const ENEMY_COUNT_DEPTH_INTERVAL := 12
const ENEMY_HP_DEPTH_INTERVAL := 20
const ENEMY_DAMAGE_DEPTH_INTERVAL := 35
const ENEMY_ACCURACY_DEPTH_INTERVAL := 25
const ENEMY_DODGE_DEPTH_INTERVAL := 30
const ENEMY_SOULS_DEPTH_INTERVAL := 30

var rng := RandomNumberGenerator.new()


static func enemy_count_for_depth(depth: int) -> int:
	return mini(
		ENEMY_COUNT_MAX,
		ENEMY_COUNT_BASE + floori(depth / float(ENEMY_COUNT_DEPTH_INTERVAL)),
	)


static func enemy_stat_bonus_for_depth(depth: int, interval: int) -> int:
	return floori(depth / float(interval))


func generate(floor_number: int, seed_value: int, cradle_chance := 0.0) -> Dictionary:
	rng.seed = seed_value
	var rooms := _plan_rooms()
	var tiles := _make_irregular_room(rooms)
	var floor_cells := _get_floor_cells(tiles)
	var start: Vector2i = floor_cells[rng.randi_range(0, floor_cells.size() - 1)]
	var exit := _pick_distant_floor_cell(start, floor_cells, [])
	var base_gate := _pick_distant_floor_cell(start, floor_cells, [exit])
	var protected_cells := [start, exit, base_gate]

	for room in rooms:
		protected_cells.append(room["door"] + room["outward"])
	_add_connected_walls(tiles, protected_cells, 24 + rng.randi_range(0, 12))

	var occupied := {}
	for cell in protected_cells:
		occupied[cell] = true

	var enemies := _spawn_enemies(tiles, occupied, start, floor_number)
	for enemy in enemies:
		occupied[enemy["pos"]] = true
	var items := _spawn_items(tiles, occupied, start, floor_number)
	for item in items:
		occupied[item["pos"]] = true
	var cradle := Vector2i(-1, -1)
	if rng.randf() < clampf(float(cradle_chance), 0.0, 1.0):
		cradle = _find_spawn_cell(tiles, occupied, start, 3)
	for room in rooms:
		var room_tiles := {}
		for cell in room["cells"]:
			tiles[cell] = "floor"
			room_tiles[cell] = "floor"
		tiles[room["door"]] = "door_closed"
		enemies.append_array(_spawn_enemies(
			room_tiles, occupied, start, floor_number, rng.randi_range(2, 3), enemies.size(), 0,
		))
		items.append_array(_spawn_items(
			room_tiles, occupied, start, floor_number, rng.randi_range(0, 1), items.size(), 0,
		))
	_build_wall_outline(tiles)

	var result := {
		"width": WIDTH,
		"height": HEIGHT,
		"tiles": tiles,
		"rooms": rooms,
		"start": start,
		"exit": exit,
		"exit_known": false,
		"base_gate": base_gate,
		"enemies": enemies,
		"items": items,
		"cradle": cradle,
		"cradle_known": false,
		"cradle_pity_resolved": false,
		"cradle_used": false,
		"visible_cells": {},
		"explored_cells": {},
		"observed_cells": {},
		"cradle_roll_chance": clampf(float(cradle_chance), 0.0, 1.0),
		"seed": seed_value,
	}

	FloorDecoration.populate(result, floor_number)
	return result


func _plan_rooms() -> Array:
	# Reserve separated edge sectors first: every seed has enough space for all
	# rooms, without placement retries or a fallback that silently drops a room.
	var sides := [0, 1, 2, 3]
	var rooms: Array = []
	for _index in range(rng.randi_range(2, 3)):
		var side_index := rng.randi_range(0, sides.size() - 1)
		var side: int = sides.pop_at(side_index)
		var center := rng.randi_range(17, 22)
		var half_width := rng.randi_range(3, 4)
		var top := rng.randi_range(2, 4)
		var cells := {}
		var reserved := {}
		for y in range(top - 1, 10):
			for x in range(center - half_width - 1, center + half_width + 2):
				reserved[_rotate_cell(Vector2i(x, y), side)] = true
		for y in range(top, 9):
			# Unequal shoulders keep the outline irregular while the central spine
			# and the floor immediately behind the doorway are always connected.
			var inset_left := rng.randi_range(0, 1) if y < 8 else 1
			var inset_right := rng.randi_range(0, 1) if y < 8 else 1
			for x in range(center - half_width + inset_left, center + half_width + 1 - inset_right):
				cells[_rotate_cell(Vector2i(x, y), side)] = true
		var door := _rotate_cell(Vector2i(center, 9), side)
		rooms.append({
			"cells": cells, "reserved": reserved, "door": door,
			"outward": _rotate_cell(Vector2i(center, 10), side) - door,
		})
	return rooms


func _rotate_cell(cell: Vector2i, turns: int) -> Vector2i:
	for _turn in range(turns):
		cell = Vector2i(WIDTH - 1 - cell.y, cell.x)
	return cell


func _make_irregular_room(rooms: Array = []) -> Dictionary:
	var tiles := {}
	for y in range(HEIGHT):
		for x in range(WIDTH):
			tiles[Vector2i(x, y)] = "void"

	for room in rooms:
		for cell in room["reserved"]:
			tiles[cell] = "wall"
	var target_floor_count := rng.randi_range(720, 860)
	var first_cell := Vector2i(20, 20)
	# Connected approach spines are part of the main hall, never part of a room.
	tiles[first_cell] = "floor"
	for room in rooms:
		var cursor := first_cell
		var approach: Vector2i = room["door"] + room["outward"]
		while cursor != approach:
			if cursor.x != approach.x:
				cursor.x += signi(approach.x - cursor.x)
			else:
				cursor.y += signi(approach.y - cursor.y)
			tiles[cursor] = "floor"
	var carved: Array = _get_floor_cells(tiles)
	var frontier: Array = []
	for cell in carved:
		_append_frontier(tiles, cell, frontier)

	while carved.size() < target_floor_count and not frontier.is_empty():
		var frontier_index := rng.randi_range(0, frontier.size() - 1)
		var candidate: Vector2i = frontier[frontier_index]
		frontier.remove_at(frontier_index)
		if tiles[candidate] != "void":
			continue
		tiles[candidate] = "floor"
		carved.append(candidate)
		_append_frontier(tiles, candidate, frontier)

	_build_wall_outline(tiles)
	return tiles


func _append_frontier(tiles: Dictionary, cell: Vector2i, frontier: Array) -> void:
	for direction in CARDINAL_DIRECTIONS:
		var neighbor: Vector2i = cell + direction
		if not _is_inner_cell(neighbor):
			continue
		if tiles[neighbor] == "void" and not frontier.has(neighbor):
			frontier.append(neighbor)


func _build_wall_outline(tiles: Dictionary) -> void:
	var outline := {}
	for cell in _get_floor_cells(tiles):
		for y_offset in range(-1, 2):
			for x_offset in range(-1, 2):
				var neighbor: Vector2i = cell + Vector2i(x_offset, y_offset)
				if tiles.get(neighbor, "void") == "void":
					outline[neighbor] = true
	for cell in outline:
		if tiles.has(cell):
			tiles[cell] = "wall"


func _pick_distant_floor_cell(origin: Vector2i, floor_cells: Array, excluded: Array) -> Vector2i:
	var best: Vector2i = floor_cells[0]
	var best_score := -1
	for candidate in floor_cells:
		if candidate == origin or excluded.has(candidate):
			continue
		var score := _manhattan(candidate, origin)
		for cell in excluded:
			score = mini(score, _manhattan(candidate, cell))
		if score > best_score or (score == best_score and rng.randf() > 0.5):
			best = candidate
			best_score = score
	return best


func _add_connected_walls(tiles: Dictionary, protected_cells: Array, target_count: int) -> void:
	var added := 0
	var attempts := 0
	while added < target_count and attempts < target_count * 12:
		attempts += 1
		var floor_cells := _get_floor_cells(tiles)
		var candidate: Vector2i = floor_cells[rng.randi_range(0, floor_cells.size() - 1)]
		if protected_cells.has(candidate):
			continue
		tiles[candidate] = "wall"
		if _all_floor_cells_connected(tiles):
			added += 1
		else:
			tiles[candidate] = "floor"


func _all_floor_cells_connected(tiles: Dictionary, allow_closed_doors := false) -> bool:
	var floor_cells := _get_floor_cells(tiles)
	if allow_closed_doors:
		for cell in tiles:
			if tiles[cell] == "door_closed":
				floor_cells.append(cell)
	if floor_cells.is_empty():
		return false
	var reachable := _reachable_floor_cells(tiles, floor_cells[0], allow_closed_doors)
	return reachable.size() == floor_cells.size()


func _has_path(tiles: Dictionary, from: Vector2i, to: Vector2i) -> bool:
	return _reachable_floor_cells(tiles, from).has(to)


func _reachable_floor_cells(tiles: Dictionary, from: Vector2i, allow_closed_doors := false) -> Dictionary:
	var frontier: Array = [from]
	var visited := {from: true}
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for direction in CARDINAL_DIRECTIONS:
			var neighbor: Vector2i = current + direction
			var tile: String = tiles.get(neighbor, "void")
			if visited.has(neighbor) or (tile != "floor" and not (allow_closed_doors and tile == "door_closed")):
				continue
			visited[neighbor] = true
			frontier.append(neighbor)
	return visited


func _get_floor_cells(tiles: Dictionary) -> Array:
	var result: Array = []
	for cell in tiles:
		if tiles[cell] == "floor":
			result.append(cell)
	return result


func _is_inner_cell(cell: Vector2i) -> bool:
	return cell.x > 0 and cell.y > 0 and cell.x < WIDTH - 1 and cell.y < HEIGHT - 1


func _spawn_enemies(
	tiles: Dictionary,
	occupied: Dictionary,
	start: Vector2i,
	floor_number: int,
	count_override := -1, uid_offset := 0, minimum_distance := 4,
) -> Array:
	var enemies: Array = []
	var depth := 100 - floor_number
	var count := enemy_count_for_depth(depth) if count_override < 0 else count_override
	var pool := GameRules.enemy_pool(floor_number)
	var thematic := GameRules.biome_id(floor_number) == "weaving_crypts"
	if thematic:
		pool.erase("arachnid")
	for _index in range(count):
		var cell := _find_spawn_cell(tiles, occupied, start, minimum_distance)
		if cell.x < 0:
			break
		occupied[cell] = true
		var enemy_id := "arachnid" if thematic and rng.randf() < GameRules.WEAVING_CRYPTS_THEMATIC_CHANCE else String(pool[rng.randi_range(0, pool.size() - 1)])
		var rules: Dictionary = GameRules.ENEMIES[enemy_id]
		var tier_bonus := enemy_stat_bonus_for_depth(depth, ENEMY_HP_DEPTH_INTERVAL)
		var max_hp := int(rules["max_hp"]) + tier_bonus
		enemies.append({
			"uid": "enemy_%d" % (_index + uid_offset),
			"id": enemy_id,
			"pos": cell,
			"hp": max_hp,
			"max_hp": max_hp,
			"damage": int(rules["damage"]) + enemy_stat_bonus_for_depth(
				depth, ENEMY_DAMAGE_DEPTH_INTERVAL,
			),
			"accuracy": int(rules["accuracy"]) + enemy_stat_bonus_for_depth(
				depth, ENEMY_ACCURACY_DEPTH_INTERVAL,
			),
			"dodge": int(rules["dodge"]) + enemy_stat_bonus_for_depth(
				depth, ENEMY_DODGE_DEPTH_INTERVAL,
			),
			"vision": int(rules["vision"]),
			"souls": int(rules["souls"]) + enemy_stat_bonus_for_depth(
				depth, ENEMY_SOULS_DEPTH_INTERVAL,
			),
			"attack_type": String(rules.get("attack_type", "melee")),
			"range": int(rules.get("range", 1)),
		})
	return enemies


func _spawn_items(
	tiles: Dictionary,
	occupied: Dictionary,
	start: Vector2i,
	floor_number: int,
	count_override := -1, uid_offset := 0, minimum_distance := 3,
) -> Array:
	var items: Array = []
	var available := GameRules.available_equipment_ids(floor_number)
	var count := 1 + int(rng.randf() > 0.65) if count_override < 0 else count_override
	for _index in range(count):
		var cell := _find_spawn_cell(tiles, occupied, start, minimum_distance)
		if cell.x < 0 or available.is_empty():
			break
		occupied[cell] = true
		items.append({
			"uid": "item_%d" % (_index + uid_offset),
			"id": available[rng.randi_range(0, available.size() - 1)],
			"pos": cell,
			"wood": rng.randi_range(1, 2) if rng.randf() < 0.55 else 0,
			"stone": rng.randi_range(1, 2) if rng.randf() < 0.55 else 0,
		})
	return items


func _find_spawn_cell(
	tiles: Dictionary,
	occupied: Dictionary,
	start: Vector2i,
	minimum_distance: int
) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for candidate in _get_floor_cells(tiles):
		if (
			tiles.get(candidate, "wall") == "floor"
			and not occupied.has(candidate)
			and _manhattan(candidate, start) >= minimum_distance
		):
			candidates.append(candidate)
	if not candidates.is_empty():
		return candidates[rng.randi_range(0, candidates.size() - 1)]
	return Vector2i(-1, -1)


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
