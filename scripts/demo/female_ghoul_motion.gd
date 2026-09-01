extends RefCounted

## Isolated presentation experiment: no turns, randomness, survival or persistence.
const STEP_SECONDS := 0.36
const CYCLE_SECONDS := STEP_SECONDS * 2.0
const FRAME_COUNT := 4
const START_CELL := Vector2i(3, 4)

var cell := START_CELL
var from_cell := START_CELL
var direction := Vector2i.ZERO
var step_elapsed := 0.0
var moving := false
var facing_right := false
var contact_frame := 0
var next_contact_frame := 2


func reset() -> void:
	cell = START_CELL
	from_cell = cell
	direction = Vector2i.ZERO
	step_elapsed = 0.0
	moving = false
	facing_right = false
	contact_frame = 0
	next_contact_frame = 2


func can_enter(floor_data: Dictionary, target: Vector2i) -> bool:
	if floor_data["tiles"].get(target, "wall") != "floor":
		return false
	for item in floor_data.get("items", []):
		if item["pos"] == target:
			return false
	return true


func begin_step(floor_data: Dictionary, requested: Vector2i) -> bool:
	if moving or absi(requested.x) + absi(requested.y) != 1:
		return false
	if not can_enter(floor_data, cell + requested):
		return false
	from_cell = cell
	cell += requested
	direction = requested
	step_elapsed = 0.0
	moving = true
	next_contact_frame = 2 if contact_frame == 0 else 0
	if requested.x != 0:
		facing_right = requested.x > 0
	return true


func advance(delta: float) -> void:
	if not moving:
		return
	step_elapsed = minf(STEP_SECONDS, step_elapsed + maxf(delta, 0.0))
	if step_elapsed >= STEP_SECONDS:
		moving = false
		contact_frame = next_contact_frame
		from_cell = cell


func offset_cells() -> Vector2:
	if not moving:
		return Vector2.ZERO
	# Move the image and renderer foot marker together; no full-body bob.
	return -Vector2(direction) * (1.0 - step_elapsed / STEP_SECONDS)


func frame_index() -> int:
	if not moving:
		return contact_frame
	# Four painted keyframes, 180 ms each, in a deliberately shuffling 0.72 s cycle.
	# Stop on either planted contact, never snap back to frame zero.
	return contact_frame if step_elapsed < STEP_SECONDS * 0.5 else contact_frame + 1


static func make_floor() -> Dictionary:
	var tiles := {}
	var visible := {}
	for y in range(7):
		for x in range(12):
			var pos := Vector2i(x, y)
			tiles[pos] = "wall" if x == 0 or x == 11 or y == 0 or y == 6 else "floor"
			visible[pos] = true
	for pos in [Vector2i(7, 1), Vector2i(7, 2), Vector2i(7, 4), Vector2i(7, 5), Vector2i(4, 2)]:
		tiles[pos] = "wall"
	return {
		"width": 12, "height": 7, "tiles": tiles,
		"start": Vector2i(-1, -1), "base_gate": Vector2i(-1, -1),
		"exit": Vector2i(-1, -1), "exit_known": false,
		"cradle": Vector2i(-1, -1), "cradle_known": false,
		"rooms": [{"door": Vector2i(7, 3), "outward": Vector2i.LEFT}],
		"items": [{"pos": Vector2i(9, 2), "appearance": "chest"}],
		"enemies": [], "visible_cells": visible,
		"explored_cells": visible.duplicate(), "observed_cells": visible.duplicate(),
	}
