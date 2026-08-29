class_name FloorGenerator
extends RefCounted

const WIDTH := 20
const HEIGHT := 14
const CARDINAL_DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const ENEMY_COUNT_BASE := 4
const ENEMY_COUNT_MAX := 9
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
	var tiles := _make_irregular_room()
	var floor_cells := _get_floor_cells(tiles)
	var start: Vector2i = floor_cells[rng.randi_range(0, floor_cells.size() - 1)]
	var exit := _pick_distant_floor_cell(start, floor_cells, [])
	var base_gate := _pick_distant_floor_cell(start, floor_cells, [exit])
	var protected_cells := [start, exit, base_gate]

	_add_connected_walls(tiles, protected_cells, 12 + rng.randi_range(0, 8))

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

	return {
		"width": WIDTH,
		"height": HEIGHT,
		"tiles": tiles,
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


func _make_irregular_room() -> Dictionary:
	var tiles := {}
	for y in range(HEIGHT):
		for x in range(WIDTH):
			tiles[Vector2i(x, y)] = "void"

	var target_floor_count := rng.randi_range(115, 150)
	var first_cell := Vector2i(
		rng.randi_range(4, WIDTH - 5),
		rng.randi_range(3, HEIGHT - 4),
	)
	var carved: Array = [first_cell]
	var frontier: Array = []
	tiles[first_cell] = "floor"
	_append_frontier(tiles, first_cell, frontier)

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


func _all_floor_cells_connected(tiles: Dictionary) -> bool:
	var floor_cells := _get_floor_cells(tiles)
	if floor_cells.is_empty():
		return false
	var reachable := _reachable_floor_cells(tiles, floor_cells[0])
	return reachable.size() == floor_cells.size()


func _has_path(tiles: Dictionary, from: Vector2i, to: Vector2i) -> bool:
	return _reachable_floor_cells(tiles, from).has(to)


func _reachable_floor_cells(tiles: Dictionary, from: Vector2i) -> Dictionary:
	var frontier: Array = [from]
	var visited := {from: true}
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for direction in CARDINAL_DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if visited.has(neighbor) or tiles.get(neighbor, "void") != "floor":
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
	floor_number: int
) -> Array:
	var enemies: Array = []
	var depth := 100 - floor_number
	var count := enemy_count_for_depth(depth)
	var pool := GameRules.enemy_pool(floor_number)
	for _index in range(count):
		var cell := _find_spawn_cell(tiles, occupied, start, 4)
		if cell.x < 0:
			break
		occupied[cell] = true
		var enemy_id := String(pool[rng.randi_range(0, pool.size() - 1)])
		var rules: Dictionary = GameRules.ENEMIES[enemy_id]
		var tier_bonus := enemy_stat_bonus_for_depth(depth, ENEMY_HP_DEPTH_INTERVAL)
		var max_hp := int(rules["max_hp"]) + tier_bonus
		enemies.append({
			"uid": "enemy_%d" % _index,
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
	floor_number: int
) -> Array:
	var items: Array = []
	var available := GameRules.available_equipment_ids(floor_number)
	var count := 1 + int(rng.randf() > 0.65)
	for _index in range(count):
		var cell := _find_spawn_cell(tiles, occupied, start, 3)
		if cell.x < 0 or available.is_empty():
			break
		occupied[cell] = true
		items.append({
			"uid": "item_%d" % _index,
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
	var floor_cells := _get_floor_cells(tiles)
	for _attempt in range(120):
		var candidate: Vector2i = floor_cells[rng.randi_range(0, floor_cells.size() - 1)]
		if (
			tiles.get(candidate, "wall") == "floor"
			and not occupied.has(candidate)
			and _manhattan(candidate, start) >= minimum_distance
		):
			return candidate
	return Vector2i(-1, -1)


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
