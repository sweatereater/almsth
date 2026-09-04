class_name CharacterModalBackdrop
extends Control

## Draws the Warm Archive character composition above a frozen world while a
## neutral semantic scrim consumes all pointer input below it.

const Palette := preload("res://scripts/ui/ui_palette.gd")
const Renderer := preload("res://scripts/ui/game_renderer.gd")
const Artwork := preload("res://scripts/ui/character_artwork.gd")
const Surface := preload("res://scripts/ui/character_sheet_surface.gd")

var run_state: RunState
var panel_mode := "skills"
var selected_stage := "skeleton"


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	Artwork.prepare_sheet()
	Surface.prepare()
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func set_presentation(state_value: RunState, mode_value: String, stage_value: String) -> void:
	run_state = state_value
	panel_mode = mode_value
	selected_stage = stage_value
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.OVERLAY_SCRIM)
	if run_state != null:
		Renderer.draw_character_sheet(self, run_state, panel_mode, selected_stage)
