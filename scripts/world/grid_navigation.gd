class_name GridNavigation
extends RefCounted

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func find_path(
	tiles: Dictionary,
	start: Vector2i,
	goal: Vector2i,
	known_cells: Dictionary = {},
	known_only := false,
	blocked_cells: Dictionary = {},
) -> Array[Vector2i]:
	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		if cell == goal:
			break
		for direction in CARDINAL_DIRECTIONS:
			var candidate := cell + direction
			if came_from.has(candidate):
				continue
			if tiles.get(candidate, "void") != "floor":
				continue
			if known_only and not bool(known_cells.get(candidate, false)):
				continue
			if bool(blocked_cells.get(candidate, false)):
				continue
			came_from[candidate] = cell
			frontier.append(candidate)
	return _reconstruct_path(came_from, start, goal)


static func next_step(
	tiles: Dictionary,
	start: Vector2i,
	goal: Vector2i,
	blocked_cells: Dictionary = {},
) -> Vector2i:
	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		if cell == goal:
			break
		for direction in CARDINAL_DIRECTIONS:
			var candidate := cell + direction
			if came_from.has(candidate):
				continue
			if tiles.get(candidate, "void") != "floor":
				continue
			# The target itself may be occupied; intermediate occupied cells block.
			if candidate != goal and bool(blocked_cells.get(candidate, false)):
				continue
			came_from[candidate] = cell
			frontier.append(candidate)
	if not came_from.has(goal):
		return start
	var step := goal
	while came_from[step] != start:
		step = came_from[step]
	return step


static func supercover_trace(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	## Deterministic grid supercover shared by sight, projectiles and movement
	## abilities. Corner crossings include both touched flank cells, so callers do
	## not accidentally allow passage through a one-pixel diagonal gap.
	var result: Array[Vector2i] = [from]
	if from == to:
		return result
	var delta := to - from
	var step_x := signi(delta.x)
	var step_y := signi(delta.y)
	var count_x := absi(delta.x)
	var count_y := absi(delta.y)
	var crossed_x := 0
	var crossed_y := 0
	var cell := from
	while crossed_x < count_x or crossed_y < count_y:
		var decision := (
			(1 + 2 * crossed_x) * count_y
			- (1 + 2 * crossed_y) * count_x
		)
		if decision == 0:
			var horizontal := cell + Vector2i(step_x, 0)
			var vertical := cell + Vector2i(0, step_y)
			_append_trace_cell(result, horizontal)
			_append_trace_cell(result, vertical)
			cell += Vector2i(step_x, step_y)
			crossed_x += 1
			crossed_y += 1
		elif decision < 0:
			cell.x += step_x
			crossed_x += 1
		else:
			cell.y += step_y
			crossed_y += 1
		_append_trace_cell(result, cell)
	return result


static func line_blocker(
	tiles: Dictionary,
	from: Vector2i,
	to: Vector2i,
	occupied_blockers: Dictionary = {},
) -> Dictionary:
	var trace := supercover_trace(from, to)
	for index in range(1, trace.size()):
		var cell := trace[index]
		if bool(occupied_blockers.get(cell, false)):
			return {"kind": "occupied", "cell": cell}
		# Preserve projectile/vision behavior: their target may contain an actor,
		# while only intermediate opaque tiles block. Movement abilities validate
		# their endpoint tile separately.
		if cell != to and tiles.get(cell, "void") != "floor":
			return {"kind": "tile", "cell": cell}
	return {}


static func has_clear_line(
	tiles: Dictionary,
	from: Vector2i,
	to: Vector2i,
	occupied_blockers: Dictionary = {},
) -> bool:
	return line_blocker(tiles, from, to, occupied_blockers).is_empty()


static func _reconstruct_path(
	came_from: Dictionary,
	start: Vector2i,
	goal: Vector2i,
) -> Array[Vector2i]:
	if not came_from.has(goal):
		return []
	var path: Array[Vector2i] = [goal]
	var cursor := goal
	while cursor != start:
		cursor = came_from[cursor]
		path.push_front(cursor)
	return path


static func _append_trace_cell(trace: Array[Vector2i], cell: Vector2i) -> void:
	if not trace.has(cell):
		trace.append(cell)
