class_name PlayerMapPresentation
extends RefCounted

## Presentation-only interpolation for the map avatar. Logical position, turns,
## combat, RNG, visibility and persistence remain owned by Main/RunState.

const FRAME_COUNT := 4
const MAX_STEP_DURATION := 0.10
const EXPECTED_INTERVAL_FRACTION := 0.75

var active_sex := ""
var active_form := ""
var active_frames: Array[Texture2D] = []
var contact_frame := 0
var transition_frame := 1
var next_contact_frame := 2
var last_horizontal_facing := -1
var step_direction := Vector2i.ZERO
var step_elapsed := 0.0
var step_duration := 0.0
var moving := false


func activate(sex: String, form_id: String) -> void:
	var safe_sex := sex if sex in ["female", "male"] else "male"
	if safe_sex == active_sex and form_id == active_form and active_frames.size() == FRAME_COUNT:
		return
	active_sex = safe_sex
	active_form = form_id
	active_frames.clear()
	for frame_index in range(FRAME_COUNT):
		var path := frame_path(safe_sex, form_id, frame_index)
		var texture := load(path) as Texture2D if ResourceLoader.exists(path) else null
		if texture != null:
			active_frames.append(texture)
	reset(true)


func begin_step(direction: Vector2i, expected_next_interval: float) -> void:
	# A new logical step owns the presentation immediately. Snap any unfinished
	# interpolation first; never queue presentation moves behind gameplay.
	finish_step()
	if direction == Vector2i.ZERO:
		return
	face(direction)
	step_direction = direction
	step_elapsed = 0.0
	step_duration = minf(
		MAX_STEP_DURATION,
		maxf(0.0, EXPECTED_INTERVAL_FRACTION * expected_next_interval),
	)
	transition_frame = 1 if contact_frame == 0 else 3
	next_contact_frame = 2 if contact_frame == 0 else 0
	moving = step_duration > 0.0
	if not moving:
		finish_step()


func face(direction: Vector2i) -> void:
	if direction.x != 0:
		last_horizontal_facing = signi(direction.x)


func update(delta: float) -> bool:
	if not moving:
		return false
	step_elapsed = minf(step_duration, step_elapsed + maxf(0.0, delta))
	if step_elapsed >= step_duration:
		finish_step()
	return true


func finish_step() -> void:
	if moving:
		contact_frame = next_contact_frame
	moving = false
	step_elapsed = 0.0
	step_duration = 0.0
	step_direction = Vector2i.ZERO


func reset(reset_gait := false) -> void:
	moving = false
	step_elapsed = 0.0
	step_duration = 0.0
	step_direction = Vector2i.ZERO
	if reset_gait:
		contact_frame = 0
		transition_frame = 1
		next_contact_frame = 2


func visual() -> Dictionary:
	if active_frames.size() != FRAME_COUNT:
		return {"flip_h": last_horizontal_facing > 0}
	var progress := step_progress()
	var frame_index := contact_frame
	if moving and progress >= 0.5:
		frame_index = transition_frame
	var offset := Vector2.ZERO
	if moving:
		offset = Vector2(-step_direction).lerp(Vector2.ZERO, progress)
	return {
		"texture": active_frames[frame_index],
		"offset_cells": offset,
		"flip_h": last_horizontal_facing > 0,
		"frame_index": frame_index,
		"moving": moving,
		"progress": progress,
	}


func step_progress() -> float:
	if not moving or step_duration <= 0.0:
		return 1.0
	return clampf(step_elapsed / step_duration, 0.0, 1.0)


static func frame_path(sex: String, form_id: String, frame_index: int) -> String:
	if sex == "female" and form_id == "ghoul":
		return "res://assets/dungeon/female-ghoul/frames/walk-%02d.png" % frame_index
	return "res://assets/dungeon/player-forms/%s/%s/walk-%02d.png" % [
		sex, form_id, frame_index,
	]
