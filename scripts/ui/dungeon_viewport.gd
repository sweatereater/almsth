class_name DungeonViewport
extends Control

const Renderer := preload("res://scripts/ui/game_renderer.gd")

signal world_cell_pressed(cell: Vector2i)

const VIEW_RECT := Renderer.DUNGEON_VIEW_RECT
const CELL_SIZE := Renderer.CELL_SIZE


class DungeonCanvas extends Control:
	var draw_callback: Callable


	func _draw() -> void:
		if draw_callback.is_valid():
			draw_callback.call(self)


class FrameCanvas extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Renderer.COLOR_PANEL_BORDER, false, 2.0)


var world_canvas: DungeonCanvas
var frame_canvas: FrameCanvas
var camera := Vector2.ZERO
var padding := Vector2.ZERO
var map_size := Vector2i.ZERO
var player_cell := Vector2i.ZERO
var presentation: Dictionary = {}


func _ready() -> void:
	position = VIEW_RECT.position
	size = VIEW_RECT.size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	world_canvas = DungeonCanvas.new()
	world_canvas.name = "WorldCanvas"
	world_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_canvas.draw_callback = _draw_world
	add_child(world_canvas)
	frame_canvas = FrameCanvas.new()
	frame_canvas.name = "ViewportFrame"
	frame_canvas.position = Vector2.ZERO
	frame_canvas.size = size
	frame_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame_canvas)
	_update_transform()


func set_presentation(
	floor_data: Dictionary,
	state: RunState,
	player_pos: Vector2i,
	magic_traces: Array[Dictionary],
	projectile_traces: Array[Dictionary],
	inspection_cell: Vector2i,
	has_inspection: bool,
	manual_inspection: bool,
	ability_target_cells: Array[Vector2i],
	ability_target_cursor: Vector2i,
) -> void:
	presentation = {
		"floor_data": floor_data,
		"state": state,
		"magic_traces": magic_traces,
		"projectile_traces": projectile_traces,
		"inspection_cell": inspection_cell,
		"has_inspection": has_inspection,
		"manual_inspection": manual_inspection,
		"ability_target_cells": ability_target_cells,
		"ability_target_cursor": ability_target_cursor,
	}
	map_size = Vector2i(
		int(floor_data.get("width", 0)),
		int(floor_data.get("height", 0)),
	)
	player_cell = player_pos
	_update_transform()
	world_canvas.queue_redraw()


func clear_presentation() -> void:
	presentation.clear()
	map_size = Vector2i.ZERO
	player_cell = Vector2i.ZERO
	_update_transform()
	world_canvas.queue_redraw()


static func world_pixel_size(map_dimensions: Vector2i) -> Vector2:
	return Vector2(maxi(map_dimensions.x, 0), maxi(map_dimensions.y, 0)) * CELL_SIZE


static func max_camera(map_dimensions: Vector2i, view_size := VIEW_RECT.size) -> Vector2:
	var world_size := world_pixel_size(map_dimensions)
	return Vector2(
		maxf(world_size.x - view_size.x, 0.0),
		maxf(world_size.y - view_size.y, 0.0),
	)


static func camera_for(
	map_dimensions: Vector2i,
	focus_cell: Vector2i,
	view_size := VIEW_RECT.size,
) -> Vector2:
	var desired := (Vector2(focus_cell) + Vector2(0.5, 0.5)) * CELL_SIZE - view_size * 0.5
	var maximum := max_camera(map_dimensions, view_size)
	return Vector2(
		roundf(clampf(desired.x, 0.0, maximum.x)),
		roundf(clampf(desired.y, 0.0, maximum.y)),
	)


static func padding_for(map_dimensions: Vector2i, view_size := VIEW_RECT.size) -> Vector2:
	var world_size := world_pixel_size(map_dimensions)
	return Vector2(
		maxf((view_size.x - world_size.x) * 0.5, 0.0),
		maxf((view_size.y - world_size.y) * 0.5, 0.0),
	)


static func child_origin_for(
	map_dimensions: Vector2i,
	focus_cell: Vector2i,
	view_size := VIEW_RECT.size,
) -> Vector2:
	return padding_for(map_dimensions, view_size) - camera_for(
		map_dimensions, focus_cell, view_size,
	)


static func world_cell_from_screen(
	screen_position: Vector2,
	view_rect: Rect2,
	map_dimensions: Vector2i,
	focus_cell: Vector2i,
) -> Vector2i:
	var local := screen_position - view_rect.position
	# Rect2.has_point follows the required exclusive right/bottom convention, but
	# keep it explicit here because this helper is also the input contract.
	if local.x < 0.0 or local.y < 0.0 or local.x >= view_rect.size.x or local.y >= view_rect.size.y:
		return Vector2i(-1, -1)
	var origin := child_origin_for(map_dimensions, focus_cell, view_rect.size)
	var world_pixel := local - origin
	var world_size := world_pixel_size(map_dimensions)
	if (
		world_pixel.x < 0.0 or world_pixel.y < 0.0
		or world_pixel.x >= world_size.x or world_pixel.y >= world_size.y
	):
		return Vector2i(-1, -1)
	return Vector2i(floori(world_pixel.x / CELL_SIZE), floori(world_pixel.y / CELL_SIZE))


func world_to_screen_center(cell: Vector2i) -> Vector2:
	return global_position + world_canvas.position + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE


func screen_to_world_cell(screen_position: Vector2) -> Vector2i:
	return world_cell_from_screen(screen_position, Rect2(global_position, size), map_size, player_cell)


func _update_transform() -> void:
	if world_canvas == null:
		return
	camera = camera_for(map_size, player_cell, size)
	padding = padding_for(map_size, size)
	world_canvas.position = padding - camera
	world_canvas.size = world_pixel_size(map_size)


func _gui_input(event: InputEvent) -> void:
	var screen_position := Vector2(-1, -1)
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
			return
		screen_position = event.position
	elif event is InputEventScreenTouch:
		if not event.pressed:
			return
		screen_position = event.position
	else:
		return
	# GUI input coordinates are local to this Control; the public inverse accepts
	# screen coordinates so callers and tests share one explicit contract.
	var cell := screen_to_world_cell(global_position + screen_position)
	if cell.x < 0:
		accept_event()
		return
	world_cell_pressed.emit(cell)
	accept_event()


func _draw_world(canvas: CanvasItem) -> void:
	if presentation.is_empty():
		return
	Renderer.draw_dungeon(
		canvas,
		presentation["floor_data"],
		presentation["state"],
		player_cell,
		presentation["magic_traces"],
		presentation["projectile_traces"],
		presentation["inspection_cell"],
		presentation["has_inspection"],
		presentation["manual_inspection"],
		presentation["ability_target_cells"],
		presentation["ability_target_cursor"],
	)
